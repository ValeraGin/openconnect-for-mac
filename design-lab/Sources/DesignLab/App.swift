import AppKit
import SwiftUI
import Combine

enum LabScreen: String {
    case settings, signin, about, compact, compactEditor
    var size: NSSize {
        switch self {
        case .compact: return NSSize(width: 560, height: 420)
        case .compactEditor: return NSSize(width: 520, height: 360)
        case .settings: return NSSize(width: 680, height: 620)
        case .signin: return NSSize(width: 440, height: 540)
        case .about: return NSSize(width: 440, height: 540)
        }
    }
}

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
final class LabDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow?
    var signInWindow: NSWindow?
    var aboutWindow: NSWindow?
    var subscriptions = Set<AnyCancellable>()
    var model: DemoModel!
    func applicationDidFinishLaunching(_ notification: Notification) {
        let passive = CommandLine.arguments.contains("--capture-passive")
        model = DemoModel(preferences: passive ? nil : UserDefaults(suiteName: "ru.ocmac.designlab"))
        model.language = Language(rawValue: argument("--language") ?? "ru") ?? .ru
        if let scenario = argument("--scenario").flatMap(Scenario.init(rawValue:)) { model.load(scenario) }
        if let page = argument("--page").flatMap(Page.init(rawValue:)) { model.page = page; model.detail = nil }
        if let detail = argument("--page").flatMap(Detail.init(rawValue:)) { model.navigate(detail) }
        if passive, let variant = argument("--variant") { model.applyReviewVariant(variant) }
        model.appearance = argument("--appearance") ?? "system"
        model.compact.layout = CompactLayout(rawValue: argument("--layout") ?? "native") ?? .native
        model.compact.sample(argument("--compact-state") ?? "empty")
        model.showDetails = CommandLine.arguments.contains("--details")
        model.aboutTechnical = CommandLine.arguments.contains("--technical")
        model.aboutLicenses = CommandLine.arguments.contains("--licenses")
        if passive { Task { await PassiveCapture.run(model: model) }; return }
        installMenus()
        let screen = LabScreen(rawValue: argument("--screen") ?? "compact") ?? .compact
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: screen.size),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "OpenConnect for Mac — Demo"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: AppearanceView(model: model, screen: screen))
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
        model.$authPresented.receive(on: RunLoop.main).sink { [weak self] presented in
            self?.showAuxiliary(.signin, presented: presented)
        }.store(in: &subscriptions)
        model.$aboutPresented.receive(on: RunLoop.main).sink { [weak self] presented in
            self?.showAuxiliary(.about, presented: presented)
        }.store(in: &subscriptions)
        model.$language.receive(on: RunLoop.main).sink { [weak self] _ in self?.installMenus() }
            .store(in: &subscriptions)
    }
    private func showAuxiliary(_ screen: LabScreen, presented: Bool) {
        var target = screen == .signin ? signInWindow : aboutWindow
        guard presented else { target?.orderOut(nil); return }
        if target == nil {
            target = NSWindow(contentRect: NSRect(origin: .zero, size: screen.size),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
            target?.isReleasedWhenClosed = false
            target?.delegate = self
            target?.contentView = NSHostingView(rootView: AppearanceView(model: model, screen: screen))
            if screen == .signin { signInWindow = target } else { aboutWindow = target }
        }
        target?.title = screen == .signin ? model.t("Вход — OpenConnect for Mac — Demo", "Sign-in — OpenConnect for Mac — Demo")
            : model.t("О приложении — OpenConnect for Mac", "About — OpenConnect for Mac")
        if let display = window?.screen, let target {
            target.setFrameTopLeftPoint(NSPoint(x: display.visibleFrame.midX - target.frame.width / 2,
                                               y: display.visibleFrame.midY + target.frame.height / 2))
        }
        target?.makeKeyAndOrderFront(nil)
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === signInWindow { model.cancelSignIn() }
        if sender === aboutWindow { model.aboutPresented = false }
        return true
    }
    @objc private func openCompact() { changeScreen(.compact) }
    @objc private func openFull() { changeScreen(.settings) }
    private func changeScreen(_ screen: LabScreen) {
        window?.contentView = NSHostingView(rootView: AppearanceView(model: model, screen: screen))
        window?.setContentSize(screen.size)
    }
    @objc private func openAbout() { model.aboutPresented = true }
    private func installMenus() {
        let menu = NSMenu()
        let appMenu = NSMenu(title: "OpenConnect for Mac")
        let about = appMenu.addItem(withTitle: model.t("О приложении OpenConnect for Mac", "About OpenConnect for Mac"),
                                   action: #selector(openAbout), keyEquivalent: "")
        about.target = self
        let compact = appMenu.addItem(withTitle: model.t("Компактный мастер", "Compact assistant"), action: #selector(openCompact), keyEquivalent: "1"); compact.target = self
        let full = appMenu.addItem(withTitle: model.t("Полный макет настроек", "Full settings prototype"), action: #selector(openFull), keyEquivalent: "2"); full.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: model.t("Завершить OpenConnect for Mac", "Quit OpenConnect for Mac"),
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
    var screen: LabScreen = .settings
    var body: some View {
        Group {
            switch screen {
            case .compact: CompactSetupView(model: model, state: model.compact)
            case .compactEditor: CompactListEditor(model: model, state: model.compact)
            case .settings: LabView(model: model)
            case .signin: SignInView(model: model)
            case .about: AboutView(model: model)
            }
        }
            .preferredColorScheme(model.appearance == "light" ? .light : model.appearance == "dark" ? .dark : nil)
            .environment(\.locale, Locale(identifier: model.language.rawValue))
    }
}
