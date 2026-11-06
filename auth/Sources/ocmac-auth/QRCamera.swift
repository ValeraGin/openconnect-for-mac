import AppKit
import AVFoundation
import CoreImage
import CoreVideo

/// Чтение QR второго фактора камерой Mac — с экрана телефона. Экспорт Google
/// Authenticator («Перенос аккаунтов → Экспорт») показывает QR, а снимок
/// экрана телефон часто запрещает; камера его читает.
///
/// Кадры не сохраняются и никуда не уходят: из кадра берётся только строка
/// QR. Камера выключается сразу после совпадения, отмены или тайм-аута.
final class QRCameraScanner: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "ru.ocmac.qr-camera")
    private var last = Date.distantPast
    private var lastPreview = Date.distantPast
    var onPayloads: (([String]) -> Void)?
    // Called on the capture queue; diagnostics never decode or save QR secrets.
    var onFrame: ((CVPixelBuffer) -> Void)?
    var decodeQR = true

    static func cameras() -> [AVCaptureDevice] {
        var types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(macOS 14.0, *) { types += [.external, .continuityCamera] } else { types.append(.externalUnknown) }
        return AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: .unspecified).devices
    }

    /// Встроенная камера — первой: камера iPhone (Continuity) не может снимать
    /// экран того же телефона, на котором открыт аутентификатор.
    static func preferred(_ list: [AVCaptureDevice]) -> AVCaptureDevice? {
        list.first { $0.deviceType == .builtInWideAngleCamera } ?? list.first
    }

    func start(_ device: AVCaptureDevice, completion: @escaping (Error?) -> Void) {
        // Device creation, configuration, start and stop must share one queue.
        // These operations can block on a camera driver; never run them in UI.
        queue.async {
            do {
                self.session.beginConfiguration()
                do {
                    defer { self.session.commitConfiguration() }
                    self.session.inputs.forEach { self.session.removeInput($0) }
                    let input = try AVCaptureDeviceInput(device: device)
                    guard self.session.canAddInput(input) else { throw NSError(domain: "CameraInput", code: 1) }
                    self.session.addInput(input)
                    if self.session.outputs.isEmpty {
                        let out = AVCaptureVideoDataOutput()
                        out.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                        out.alwaysDiscardsLateVideoFrames = true
                        out.setSampleBufferDelegate(self, queue: self.queue)
                        guard self.session.canAddOutput(out) else { throw NSError(domain: "CameraOutput", code: 1) }
                        self.session.addOutput(out)
                    }
                }
                if !self.session.isRunning { self.session.startRunning() }
                guard self.session.isRunning else { throw NSError(domain: "CameraStart", code: 1) }
                ModalCallbacks.perform { completion(nil) }
            } catch {
                ModalCallbacks.perform { completion(error) }
            }
        }
    }

    func stop() {
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let now = Date()
        // Smooth preview and QR detection share the very same camera frames.
        if now.timeIntervalSince(lastPreview) >= 1.0 / 15 {
            lastPreview = now
            onFrame?(pb)
        }
        guard decodeQR, now.timeIntervalSince(last) > 0.25 else { return }
        last = now
        let found = Self.payloads(pixelBuffer: pb)
        if !found.isEmpty { ModalCallbacks.perform { [weak self] in self?.onPayloads?(found) } }
    }

    /// Тот же путь, что у QR из файла. Проверяется без камеры — на кадре,
    /// собранном в памяти (ocmac-auth --learn-selftest).
    static func payloads(pixelBuffer: CVPixelBuffer) -> [String] {
        QRImport.payloads(in: CIImage(cvPixelBuffer: pixelBuffer))
    }
}

/// Окно камеры: предпросмотр, выбор камеры, подсказка и строка состояния.
/// Возвращает запись, которая даёт код, только что введённый человеком, —
/// из экспорта на несколько записей и страниц нужная находится сама.
final class QRCameraWindow: NSObject, NSWindowDelegate {
    private let code: String
    private let at: Date
    private let select: String?
    private let scanner = QRCameraScanner()
    private let permission = CameraPermissionRequest()
    private var cameraGeneration = 0
    private var waitingForPermission = false
    private var window: NSWindow!
    private var status: NSTextField!
    private var picker: NSPopUpButton!
    private var devices: [AVCaptureDevice] = []
    private var result: QRImport.Entry?
    private var seen = Set<String>()
    private var running = false
    private var receivedFrame = false
    private var lastFrameAt = Date.distantPast
    private var frameTimer: Timer?
    private var preview: NSImageView?
    private let previewContext = CIContext()

    /// code — введённый при входе код: по нему находится нужная запись.
    /// Пустой — добавление с нуля: годится единственная запись TOTP в QR
    /// или та, что подходит под select.
    init(code: String, at: Date, select: String? = nil) {
        self.code = code
        self.at = at
        self.select = select
        super.init()
    }

    /// Что делать с записями одного QR: взять одну или сказать человеку,
    /// почему нет, и искать дальше. Молча брать первую из нескольких нельзя —
    /// так в связку ложится чужой секрет.
    static func decide(_ entries: [QRImport.Entry], code: String, at: Date,
                       select: String? = nil) -> (entry: QRImport.Entry?, status: String) {
        if !code.isEmpty {
            if let e = entries.first(where: { fits($0, code: code, at: at) }) { return (e, "") }
            return (nil, entries.count > 1
                ? L("в этом QR записей: %@, ни одна не даёт ваш код — покажите следующий QR экспорта", entries.count)
                : L("эта запись не даёт ваш код — выберите в экспорте учётку VPN"))
        }
        var candidates = entries.filter(\.isTOTP)
        if candidates.isEmpty {
            return (nil, L("это HOTP (код по счётчику) — OpenConnect for Mac его не ведёт"))
        }
        if let want = select?.lowercased(), !want.isEmpty {
            let all = candidates
            candidates = all.filter { $0.label.lowercased().contains(want) }
            if candidates.isEmpty {
                return (nil, L("в QR нет записи, похожей на «%@». Есть: %@", select!, all.map(\.label).joined(separator: ", ")))
            }
        }
        if candidates.count == 1 { return (candidates[0], "") }
        return (nil, L("в QR записей: %@ (%@) — экспортируйте одну учётку VPN", candidates.count, candidates.map(\.label).joined(separator: ", ")))
    }

    static func fits(_ e: QRImport.Entry, code: String, at: Date) -> Bool {
        // Без кода (добавление с нуля) подходит любая запись TOTP: сверять
        // не с чем, а человек сам показывает камере нужный QR.
        if code.isEmpty { return e.isTOTP }
        return TeachDialog.entryMatches(e, code: code, at: at)
    }

    private func build(withPreview: Bool, passive: Bool = false) {
        let w: CGFloat = 560, h: CGFloat = 520
        let content = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))

        let hint = NSTextField(wrappingLabelWithString: code.isEmpty
            ? L("Поднесите к камере QR второго фактора: тот, что показывает портал при настройке, или экспорт из Google Authenticator (⋮ → «Перенос аккаунтов» → «Экспорт») с одной учёткой VPN. Кадры никуда не сохраняются.")
            : L("На телефоне: Google Authenticator → ⋮ → «Перенос аккаунтов» → «Экспорт», выберите учётку VPN и поднесите QR к камере. Подойдёт только запись, которая даёт код, введённый вами при входе. Кадры никуда не сохраняются."))
        hint.font = .systemFont(ofSize: 12)
        hint.frame = NSRect(x: 16, y: h - 70, width: w - 32, height: 56)
        content.addSubview(hint)

        let preview = NSView(frame: NSRect(x: 16, y: 84, width: w - 32, height: h - 170))
        preview.wantsLayer = true
        preview.layer?.backgroundColor = NSColor.black.cgColor
        preview.layer?.cornerRadius = 8
        if withPreview {
            let image = NSImageView(frame: preview.bounds)
            image.imageScaling = .scaleProportionallyUpOrDown
            image.autoresizingMask = [.width, .height]
            preview.addSubview(image)
            self.preview = image
        }
        content.addSubview(preview)

        status = NSTextField(labelWithString: L("ищу QR…"))
        status.font = .systemFont(ofSize: 12)
        status.textColor = .secondaryLabelColor
        status.lineBreakMode = .byTruncatingTail
        status.frame = NSRect(x: 16, y: 54, width: w - 32, height: 18)
        content.addSubview(status)

        picker = NSPopUpButton(frame: NSRect(x: 16, y: 14, width: 300, height: 26), pullsDown: false)
        picker.addItems(withTitles: devices.isEmpty ? [L("камера")] : devices.map(\.localizedName))
        picker.target = self
        picker.action = #selector(cameraChanged)
        picker.isHidden = devices.count < 2
        content.addSubview(picker)

        let cancel = NSButton(title: L("Отмена"), target: self, action: #selector(cancel))
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        cancel.frame = NSRect(x: w - 116, y: 12, width: 100, height: 30)
        content.addSubview(cancel)

        if passive {
            window = NSPanel(contentRect: content.frame, styleMask: [.titled, .nonactivatingPanel], backing: .buffered, defer: false)
            window.ignoresMouseEvents = true
        } else {
            window = NSWindow(contentRect: content.frame, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        }
        window.title = L("OpenConnect for Mac — QR второго фактора с камеры")
        window.contentView = content
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.center()
    }

    /// Показать окно и ждать записи. nil — отмена, нет камеры, нет доступа
    /// или тайм-аут; в note — что сказать человеку.
    func run(timeout: TimeInterval = 180) -> (entry: QRImport.Entry?, note: String) {
        // Кадры из файлов вместо камеры: весь путь «кадр → запись → ответ»
        // проверяется без человека, без камеры и без окна.
        if let frames = ProcessInfo.processInfo.environment["OCMAC_SELFTEST_CAMERA_FRAMES"], !frames.isEmpty {
            return fromFrames(frames.split(separator: ":").map(String.init))
        }
        build(withPreview: true)
        running = true
        scanner.onPayloads = { [weak self] found in self?.handle(found) }
        scanner.onFrame = { [weak self] pb in
            self?.displayFrame(pb)
            let width = CVPixelBufferGetWidth(pb), height = CVPixelBufferGetHeight(pb)
            ModalCallbacks.perform { [weak self] in
                guard let self, self.running else { return }
                self.lastFrameAt = Date()
                if !self.receivedFrame {
                    self.receivedFrame = true
                    self.setStatus(L("ищу QR…"))
                    Log.info("камера: получен кадр \(width)×\(height)")
                }
            }
        }
        waitingForPermission = true
        setStatus(L("Ожидаю разрешение на камеру…"))
        picker.isEnabled = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        let t = Timer(timeInterval: timeout, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.setStatus(self.waitingForPermission
                ? L("доступ к камере не дан — секрет можно вставить или выбрать файл QR")
                : L("QR с камеры не прочитан — можно вставить секрет или выбрать файл QR"))
            self.finish()
        }
        RunLoop.main.add(t, forMode: .modalPanel)
        permission.start { [weak self] granted in
            guard let self, self.running else { return }
            self.waitingForPermission = false
            guard granted else {
                self.setStatus(L("доступ к камере запрещён: Системные настройки → Конфиденциальность и безопасность → Камера — разрешите OpenConnect for Mac или терминалу, из которого входите"))
                self.finish(); return
            }
            self.setStatus(L("Подключаю камеру…"))
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let devices = QRCameraScanner.cameras()
                ModalCallbacks.perform { [weak self] in
                    guard let self, self.running else { return }
                    self.devices = devices
                    guard let device = QRCameraScanner.preferred(devices) else {
                        self.setStatus(L("камера не найдена")); self.finish(); return
                    }
                    self.picker.removeAllItems()
                    self.picker.addItems(withTitles: devices.map(\.localizedName))
                    self.picker.isHidden = devices.count < 2
                    if let i = devices.firstIndex(of: device) { self.picker.selectItem(at: i) }
                    self.startCamera(device)
                }
            }
        }
        NSApp.runModal(for: window)
        t.invalidate()
        running = false
        frameTimer?.invalidate(); frameTimer = nil
        permission.cancel()
        cameraGeneration += 1
        scanner.stop()
        window.orderOut(nil)
        Log.info("камера: выключена" + (result == nil ? "" : ", запись найдена"))
        return (result, result != nil ? "" : lastStatus.isEmpty
            ? L("QR с камеры не прочитан — можно вставить секрет или выбрать файл QR") : lastStatus)
    }

    /// Render the scanner's frames explicitly. A separate AV preview layer can
    /// stay black inside the authenticator's nested AppKit modal loop.
    private func displayFrame(_ buffer: CVPixelBuffer) {
        let source = CIImage(cvPixelBuffer: buffer)
        let scale = min(1, 1056 / source.extent.width)
        let image = source.transformed(by: CGAffineTransform(scaleX: -scale, y: scale))
        guard let cg = previewContext.createCGImage(image, from: image.extent) else { return }
        ModalCallbacks.perform { [weak self] in
            guard let self else { return }
            self.preview?.image = NSImage(cgImage: cg, size: .zero)
        }
    }

    private func handle(_ payloads: [String]) {
        guard running else { return }
        if let e = consider(payloads) {
            result = e
            finish()
        }
    }

    /// Новые строки QR с кадра: запись, если она нашлась, иначе — почему нет,
    /// в строку состояния. Один путь у камеры и у кадров из файлов.
    private func consider(_ payloads: [String]) -> QRImport.Entry? {
        for p in payloads where !seen.contains(p) {
            seen.insert(p)
            guard let entries = try? QRImport.parse(p) else {
                setStatus(L("это не QR второго фактора — покажите экспорт из аутентификатора"))
                continue
            }
            let d = Self.decide(entries, code: code, at: at, select: select)
            if let e = d.entry { return e }
            setStatus(d.status)
        }
        return nil
    }

    private var lastStatus = ""
    private func setStatus(_ s: String) {
        lastStatus = s
        status?.stringValue = s
    }

    private func fromFrames(_ files: [String]) -> (entry: QRImport.Entry?, note: String) {
        for f in files {
            let found = (try? QRImport.decode(file: f)) ?? []
            if let e = consider(found) { return (e, "") }
        }
        return (nil, lastStatus.isEmpty ? L("QR с камеры не прочитан — можно вставить секрет или выбрать файл QR") : lastStatus)
    }

    @objc private func cameraChanged() {
        let i = picker.indexOfSelectedItem
        guard devices.indices.contains(i) else { return }
        startCamera(devices[i])
    }

    private func startCamera(_ device: AVCaptureDevice) {
        cameraGeneration += 1
        let ticket = cameraGeneration
        picker.isEnabled = false
        receivedFrame = false
        lastFrameAt = .distantPast
        frameTimer?.invalidate()
        setStatus(L("Подключаю камеру…"))
        scanner.start(device) { [weak self] error in
            guard let self, self.running, self.cameraGeneration == ticket else { return }
            if let error {
                self.setStatus(L("камера не включилась: %@", error.localizedDescription))
                self.finish()
            } else {
                self.picker.isEnabled = true
                if !self.receivedFrame { self.setStatus(L("Ожидаю изображение с камеры…")) }
                Log.info("камера: сессия запущена (\(device.localizedName)), ожидаю кадры")
                let timer = Timer(timeInterval: 8, repeats: true) { [weak self] _ in
                    guard let self, self.running, self.cameraGeneration == ticket else { return }
                    if Date().timeIntervalSince(self.lastFrameAt) > 8 {
                        self.receivedFrame = false
                        self.setStatus(L("Камера не передаёт изображение. Выберите другую камеру или откройте её заново."))
                        Log.info("камера: нет новых кадров в течение 8 секунд")
                    }
                }
                self.frameTimer = timer
                RunLoop.main.add(timer, forMode: .modalPanel)
            }
        }
    }

    @objc func cancel() {
        setStatus(L("QR с камеры не прочитан — можно вставить секрет или выбрать файл QR"))
        finish()
    }

    func windowWillClose(_ notification: Notification) { finish() }

    private func finish() {
        guard running else { return }
        running = false
        frameTimer?.invalidate(); frameTimer = nil
        permission.cancel()
        cameraGeneration += 1
        scanner.stop()
        NSApp.stopModal()
    }

    /// Synthetic regression: a scanner frame reaches the actual image view
    /// while the main dispatch callback is inside a nested modal run loop.
    static func previewSelfTest(_ frame: CVPixelBuffer) -> Bool {
        let w = QRCameraWindow(code: "", at: Date())
        w.build(withPreview: true, passive: true)
        DispatchQueue.global(qos: .userInitiated).async { w.displayFrame(frame) }
        let deadline = Date().addingTimeInterval(3)
        while w.preview?.image == nil && Date() < deadline {
            RunLoop.current.run(mode: .modalPanel, before: Date().addingTimeInterval(0.01))
        }
        guard let image = w.preview?.image?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return false }
        return image.width == min(1056, CVPixelBufferGetWidth(frame)) && image.height > 0
    }

    /// Снимок окна без включения камеры — чтобы вид проверялся без человека
    /// (ocmac-auth --camera-window-shot файл.png).
    static func shot(to path: String, adding: Bool = false) -> Bool {
        let w = QRCameraWindow(code: adding ? "" : "123456", at: Date())
        w.devices = []
        w.build(withPreview: false)
        w.window.appearance = NSAppearance(named: .aqua)
        w.status.stringValue = adding
            ? L("в QR записей: %@ (%@) — экспортируйте одну учётку VPN", 2, "Mail/someone, VPN/alice")
            : L("в этом QR записей: %@, ни одна не даёт ваш код — покажите следующий QR экспорта", 3)
        guard let view = w.window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return false }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return false }
        return (try? png.write(to: URL(fileURLWithPath: path))) != nil
    }
}


extension QRCameraWindow {
    /// Explicit hardware check: no permissions prompt, QR decoding or saved video.
    /// The caller can capture the passive window after the ready handoff.
    static func check(to path: String, selecting name: String?, requestAccess: Bool = false) -> Bool {
        let foreground = NSWorkspace.shared.frontmostApplication?.processIdentifier
        if requestAccess && AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            let permission = CameraPermissionRequest()
            var replied = false
            permission.start { _ in replied = true }
            let deadline = Date().addingTimeInterval(60)
            while !replied && Date() < deadline { RunLoop.current.run(mode: .modalPanel, before: Date().addingTimeInterval(0.05)) }
            permission.cancel()
        }
        var report: [String: Any] = ["authorized": AVCaptureDevice.authorizationStatus(for: .video) == .authorized]
        func write() { if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: URL(fileURLWithPath: path)) } }
        guard report["authorized"] as? Bool == true else { write(); return false }
        let devices = QRCameraScanner.cameras()
        guard let device = name == nil ? QRCameraScanner.preferred(devices) : devices.first(where: { $0.localizedName.localizedCaseInsensitiveContains(name!) }),
              let screen = NSScreen.screens.first(where: { CGDisplayIsBuiltin(CGDirectDisplayID(($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0)) != 0 }) else {
            report["error"] = "Camera or built-in display unavailable"; write(); return false
        }
        let w = QRCameraWindow(code: "", at: Date())
        w.build(withPreview: true, passive: true)
        w.window.setFrameOrigin(NSPoint(x: screen.visibleFrame.minX + 20, y: screen.visibleFrame.maxY - w.window.frame.height - 20))
        w.window.orderFrontRegardless()
        w.scanner.decodeQR = false
        let lock = NSLock()
        var frames = 0; var width = 0; var height = 0; var luminance = 0.0; var spread = 0.0
        w.scanner.onFrame = { pb in
            w.displayFrame(pb)
            CVPixelBufferLockBaseAddress(pb, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
            guard let base = CVPixelBufferGetBaseAddress(pb) else { return }
            let bytes = base.assumingMemoryBound(to: UInt8.self)
            let stride = CVPixelBufferGetBytesPerRow(pb), ww = CVPixelBufferGetWidth(pb), hh = CVPixelBufferGetHeight(pb)
            var values = [Double]()
            for y in Swift.stride(from: 0, to: hh, by: 32) { for x in Swift.stride(from: 0, to: ww, by: 32) {
                let i = y * stride + x * 4
                values.append((Double(bytes[i]) + Double(bytes[i+1]) + Double(bytes[i+2])) / 3)
            } }
            let mean = values.reduce(0,+) / Double(max(1, values.count))
            let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(max(1, values.count))
            lock.lock(); frames += 1; width = ww; height = hh; luminance = mean; spread = variance.squareRoot(); lock.unlock()
        }
        var started = false; var failure: String?
        w.scanner.start(device) { error in started = error == nil; failure = error?.localizedDescription }
        let deadline = Date().addingTimeInterval(20)
        var handedOff = false
        while Date() < deadline && failure == nil {
            RunLoop.current.run(mode: .modalPanel, before: Date().addingTimeInterval(0.05))
            lock.lock(); let count = frames; lock.unlock()
            if started && count >= 8 && !handedOff {
                w.setStatus("Live frames: \(count)")
                let ready: [String: Any] = ["windowID": w.window.windowNumber, "camera": device.localizedName]
                if let data = try? JSONSerialization.data(withJSONObject: ready) { try? data.write(to: URL(fileURLWithPath: path + ".ready")) }
                handedOff = true
            }
            if handedOff && FileManager.default.fileExists(atPath: path + ".done") { break }
        }
        w.scanner.stop(); w.window.orderOut(nil)
        lock.lock()
        report.merge(["camera": device.localizedName, "frames": frames, "width": width, "height": height,
                      "mean": luminance, "standardDeviation": spread, "running": started,
                      "focusPreserved": foreground == NSWorkspace.shared.frontmostApplication?.processIdentifier && !NSApp.isActive]) { _, new in new }
        let ok = started && frames >= 8 && spread > 2
        lock.unlock()
        if let failure { report["error"] = failure }
        write(); return ok
    }
}
