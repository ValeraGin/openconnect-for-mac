import AppKit
import SwiftUI

/// Diagnostic host only: never becomes key/main and never intercepts mouse input.
@MainActor
enum PassiveCapture {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }
    private static func displayID(_ screen: NSScreen) -> CGDirectDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
    static func run(model: DemoModel) async {
        guard let path = argument("--shot"), !NSApp.isActive,
              let screen = NSScreen.screens.first(where: {
                  CGDisplayIsBuiltin(displayID($0)) != 0 && CGDisplayIsInMirrorSet(displayID($0)) == 0
              }) else { fputs("Requires background launch and a non-mirrored built-in screen.\n", stderr); exit(2) }
        var activated = false
        let observer = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                                               object: NSApp, queue: .main) { _ in activated = true }
        defer { NotificationCenter.default.removeObserver(observer) }
        let surface = LabScreen(rawValue: argument("--screen") ?? "settings") ?? .settings
        let panel = Panel(contentRect: NSRect(origin: .zero, size: surface.size),
                          styleMask: [.titled, .closable, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = surface == .settings ? "OpenConnect for Mac — Demo" : surface == .signin
            ? model.t("Вход — OpenConnect for Mac — Demo", "Sign-in — OpenConnect for Mac — Demo")
            : model.t("О приложении — OpenConnect for Mac", "About — OpenConnect for Mac")
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = false
        panel.ignoresMouseEvents = true
        panel.contentView = NSHostingView(rootView: AppearanceView(model: model, screen: surface))
        panel.setContentSize(surface.size)
        panel.setFrameTopLeftPoint(NSPoint(x: screen.visibleFrame.midX - panel.frame.width / 2, y: screen.visibleFrame.maxY))
        guard screen.visibleFrame.contains(panel.frame) else { exit(2) }
        panel.orderFrontRegardless()
        defer { panel.orderOut(nil) }
        try? await Task.sleep(for: .seconds(1))
        func valid() -> Bool {
            !activated && !NSApp.isActive && !panel.isKeyWindow && !panel.isMainWindow && panel.isVisible
            && panel.screen.map(displayID) == displayID(screen) && screen.visibleFrame.contains(panel.frame)
        }
        guard valid() else { exit(2) }
        let output = URL(fileURLWithPath: path)
        let ready = output.deletingPathExtension().appendingPathExtension("ready.json")
        let done = output.deletingPathExtension().appendingPathExtension("capture-done")
        do {
            try JSONSerialization.data(withJSONObject: ["windowID": panel.windowNumber]).write(to: ready, options: .atomic)
        } catch { exit(2) }
        for _ in 0..<150 {
            if FileManager.default.fileExists(atPath: done.path) { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        guard (try? String(contentsOf: done)) == "ok", FileManager.default.fileExists(atPath: path), valid() else {
            try? FileManager.default.removeItem(at: output); exit(2)
        }
        let metadata: [String: Any] = ["focusPreserved": true, "builtInDisplay": true,
            "active": false, "keyWindow": false, "capture": "passive-native-window",
            "displayID": displayID(screen), "scenario": model.scenario.rawValue,
            "page": model.page.rawValue, "language": model.language.rawValue,
            "width": surface.size.width, "height": surface.size.height, "screen": surface.rawValue,
            "syntheticData": true]
        do {
            try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                .write(to: output.deletingPathExtension().appendingPathExtension("json"))
        } catch { exit(2) }
        exit(0)
    }
}
