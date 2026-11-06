import AppKit
import AVFoundation

/// A modal dialog may be running inside a main-dispatch callback. Enqueuing
/// another main-dispatch block then stalls until that outer callback returns.
/// Run-loop blocks can be serviced by both AppKit's normal and modal loops.
enum ModalCallbacks {
    static func perform(_ body: @escaping () -> Void) {
        RunLoop.main.perform(inModes: [.default, .modalPanel], block: body)
    }
}

/// Cancellation prevents a late macOS permission response from starting capture.
/// Dependencies are injectable so tests never request real camera access.
final class CameraPermissionRequest {
    private var pending = false
    private var generation = 0
    private let status: () -> AVAuthorizationStatus
    private let request: (@escaping (Bool) -> Void) -> Void

    init(status: @escaping () -> AVAuthorizationStatus = { AVCaptureDevice.authorizationStatus(for: .video) },
         request: @escaping (@escaping (Bool) -> Void) -> Void = { AVCaptureDevice.requestAccess(for: .video, completionHandler: $0) }) {
        self.status = status; self.request = request
    }

    func start(_ completion: @escaping (Bool) -> Void) {
        precondition(Thread.isMainThread)
        generation += 1
        let ticket = generation
        pending = true
        let deliver: (Bool) -> Void = { [weak self] granted in
            ModalCallbacks.perform { [weak self] in
                guard let self, self.pending, self.generation == ticket else { return }
                self.pending = false
                completion(granted)
            }
        }
        switch status() {
        case .authorized: deliver(true)
        case .notDetermined: request(deliver)
        default: deliver(false)
        }
    }

    func cancel() {
        precondition(Thread.isMainThread)
        pending = false; generation += 1
    }
}
