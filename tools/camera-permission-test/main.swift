import AppKit
import AVFoundation

// Synthetic regression: the real authorization callback is replaced, so this
// exercises nested modal delivery without opening windows or asking for a camera.
setbuf(stdout, nil)
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let foreground = NSWorkspace.shared.frontmostApplication?.processIdentifier
var finished = false
var failures = 0
func check(_ name: String, _ ok: Bool) {
    print("\(ok ? "PASS" : "FAIL"): \(name)")
    if !ok { failures += 1 }
}
func pump(until condition: () -> Bool, timeout: TimeInterval = 0.5) {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
        RunLoop.current.run(mode: .modalPanel, before: Date().addingTimeInterval(0.01))
    }
}
DispatchQueue.main.async {
    // The original main-dispatch callback cannot run while this main-dispatch
    // block is itself pumping a nested modal loop: reproduce without UI.
    var oldDelivered = false
    DispatchQueue.main.async { oldDelivered = true }
    pump(until: { oldDelivered }, timeout: 0.05)
    check("original main-queue delivery stalls inside modal callback", !oldDelivered)

    var granted: Bool?
    let access = CameraPermissionRequest(status: { .notDetermined }, request: { reply in
        DispatchQueue.global().async { reply(true) }
    })
    access.start { granted = $0 }
    pump(until: { granted != nil })
    check("permission reply reaches nested modal loop", granted == true)

    var late: ((Bool) -> Void)?
    var calls = 0
    let cancelled = CameraPermissionRequest(status: { .notDetermined }, request: { late = $0 })
    cancelled.start { _ in calls += 1 }
    cancelled.cancel()
    late?(true)
    pump(until: { calls > 0 }, timeout: 0.05)
    check("late permission after cancellation cannot start capture", calls == 0)

    var callbacks: [(Bool) -> Void] = []
    let reused = CameraPermissionRequest(status: { .notDetermined }, request: { callbacks.append($0) })
    var answers: [Bool] = []
    reused.start { answers.append($0) }
    reused.cancel()
    reused.start { answers.append($0) }
    callbacks[0](true); callbacks[1](false); callbacks[1](true)
    pump(until: { !answers.isEmpty })
    check("stale and duplicate responses cannot override current request", answers == [false])

    for state: AVAuthorizationStatus in [.authorized, .denied, .restricted] {
        var reply: Bool?
        let known = CameraPermissionRequest(status: { state }, request: { _ in failures += 1 })
        known.start { reply = $0 }
        pump(until: { reply != nil })
        check("known authorization state \(state.rawValue) does not request access", reply == (state == .authorized))
    }
    var qrCallback = false
    DispatchQueue.global().async { ModalCallbacks.perform { qrCallback = true } }
    pump(until: { qrCallback })
    check("QR frame callback reaches modal loop", qrCallback)
    check("foreground unchanged", !app.isActive && NSWorkspace.shared.frontmostApplication?.processIdentifier == foreground)
    finished = true
}
let deadline = Date().addingTimeInterval(5)
while !finished && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
check("regression completes without camera or windows", finished)
exit(failures == 0 ? 0 : 1)
