import AppKit
import SwiftUI

// Окна приложения — сцены SwiftUI, а открыть их умеет только openWindow из
// окружения SwiftUI. Скрытый вид один раз отдаёт его AppKit-меню.
@MainActor
enum WindowBridge {
    private static var openWindow: OpenWindowAction?
    private static var holder: NSWindow?
    private static var quietSetup: NSWindow?
    private static var pending: [String] = []

    static func install() {
        guard holder == nil else { return }
        let w = NSWindow(contentRect: NSRect(x: -20000, y: -20000, width: 1, height: 1),
                         styleMask: .borderless, backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false
        w.ignoresMouseEvents = true
        w.alphaValue = 0
        w.contentView = NSHostingView(rootView: Catcher())
        w.orderFrontRegardless()
        holder = w
    }

    /// Show an interactive assistant on the built-in display without becoming key
    /// or activating the app. A user click may activate it normally afterwards.
    static func openSetupQuietly() {
        guard let display = NSScreen.screens.first(where: {
            let id = ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
            return CGDisplayIsBuiltin(id) != 0
        }) else { AppLog.write("quiet setup: built-in display unavailable"); return }
        guard !SetupFlow.shared.busy && !SetupFlow.shared.checking else { return }
        SetupFlow.shared.start()
        let window = quietSetup ?? NSWindow(contentRect: NSRect(x: 0, y: 0, width: SetupView.width, height: SetupView.height),
                                            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = L("Мастер настройки")
        window.identifier = NSUserInterfaceItemIdentifier("quiet-setup")
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SetupView())
        let frame = display.visibleFrame
        window.setFrameOrigin(NSPoint(x: frame.midX - window.frame.width / 2, y: frame.midY - window.frame.height / 2))
        quietSetup = window
        NSApp.unhideWithoutActivation()
        window.orderFrontRegardless()
        AppLog.write("quiet setup: visible=\(window.isVisible), active=\(NSApp.isActive), key=\(window.isKeyWindow)")
    }

    static func closeQuietSetup() { quietSetup?.close() }

    static func open(_ id: String) {
        if id == WindowID.setup, let quietSetup {
            quietSetup.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        guard let openWindow else {
            if !pending.contains(id) { pending.append(id) }
            return
        }
        openWindow(id: id)
        NSApp.activate(ignoringOtherApps: true)
    }

    private struct Catcher: View {
        @Environment(\.openWindow) private var openWindow
        var body: some View {
            Color.clear.frame(width: 1, height: 1)
                .onAppear {
                    WindowBridge.openWindow = openWindow
                    let queued = WindowBridge.pending
                    WindowBridge.pending.removeAll()
                    for id in queued { WindowBridge.open(id) }
                    // Окно-носитель больше не нужно на экране.
                    DispatchQueue.main.async { WindowBridge.holder?.orderOut(nil) }
                }
        }
    }
}
