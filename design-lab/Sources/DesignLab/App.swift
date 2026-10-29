import AppKit
import SwiftUI

func argument(_ name: String) -> String? {
    let args = CommandLine.arguments
    guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
    return args[index + 1]
}

@main
enum DesignLabApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = LabDelegate()
        app.delegate = delegate
        app.setActivationPolicy(CommandLine.arguments.contains("--capture-passive") ? .accessory : .regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class LabDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    var model: DemoModel!
    func applicationDidFinishLaunching(_ notification: Notification) {
        let passive = CommandLine.arguments.contains("--capture-passive")
        model = DemoModel(preferences: passive ? nil : UserDefaults(suiteName: "ru.ocmac.designlab"))
        model.language = Language(rawValue: argument("--language") ?? "ru") ?? .ru
        if let scenario = argument("--scenario").flatMap(Scenario.init(rawValue:)) { model.load(scenario) }
        if let page = argument("--page").flatMap(Page.init(rawValue:)) { model.page = page }
        model.appearance = argument("--appearance") ?? "system"
        model.showDetails = CommandLine.arguments.contains("--details")
        if passive { Task { await PassiveCapture.run(model: model) }; return }
        installMenus()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 620),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "OpenConnect — Design Lab"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: AppearanceView(model: model))
        window.center()
        if let screen = NSScreen.screens.first(where: {
            let id = ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
            return CGDisplayIsBuiltin(id) != 0 && CGDisplayIsInMirrorSet(id) == 0
        }) {
            window.setFrameTopLeftPoint(NSPoint(x: screen.visibleFrame.midX - window.frame.width / 2,
                                               y: screen.visibleFrame.midY + window.frame.height / 2))
        }
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    private func installMenus() {
        let menu = NSMenu()
        let appMenu = NSMenu(title: "Design Lab")
        appMenu.addItem(withTitle: model.t("Завершить Design Lab", "Quit Design Lab"),
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem(); appItem.submenu = appMenu; menu.addItem(appItem)
        let edit = NSMenu(title: model.t("Правка", "Edit"))
        for (ru, en, action, key) in [
            ("Отменить", "Undo", "undo:", "z"), ("Вырезать", "Cut", "cut:", "x"),
            ("Копировать", "Copy", "copy:", "c"), ("Вставить", "Paste", "paste:", "v"),
            ("Выделить всё", "Select All", "selectAll:", "a")
        ] { edit.addItem(withTitle: model.t(ru, en), action: NSSelectorFromString(action), keyEquivalent: key) }
        let editItem = NSMenuItem(); editItem.submenu = edit; menu.addItem(editItem)
        NSApp.mainMenu = menu
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct AppearanceView: View {
    @ObservedObject var model: DemoModel
    var body: some View {
        LabView(model: model)
            .preferredColorScheme(model.appearance == "light" ? .light : model.appearance == "dark" ? .dark : nil)
            .environment(\.locale, Locale(identifier: model.language.rawValue))
    }
}
