import Foundation
import Combine

enum Language: String, CaseIterable { case ru, en }
enum Page: String, CaseIterable {
    case connection, login, network, advanced, general
    var icon: String {
        switch self {
        case .connection: return "network"
        case .login: return "person.crop.circle"
        case .network: return "point.3.connected.trianglepath.dotted"
        case .advanced: return "slider.horizontal.3"
        case .general: return "gearshape"
        }
    }
}
enum Scenario: String, CaseIterable {
    case idle, connected, connecting, error, empty, single, many, long, missing, unsaved, proxyWarning
}
enum LinkState { case idle, connecting, connected, failed }
enum RouteMode: String, CaseIterable { case all, selected, proxy }
struct DemoProfile: Identifiable, Equatable {
    var id: String
    var name: String
    var server: String
    var user: String
    var browserLogin = true
    var passwordSaved = false
    var codeSaved = false
    var route: RouteMode = .selected
    var routes = "10.20.0.0/16\n192.168.50.0/24"
    var dns = "corp.example"
    var port = "1080"
    var systemProxy = false
    var reconnect = true
    var certificate = ""
}

/// Entirely synthetic state. No production imports, CLI, keychain or network.
final class DemoModel: ObservableObject {
    @Published var language: Language = .ru
    @Published var page: Page = .connection
    @Published var scenario: Scenario = .idle
    @Published var profiles: [DemoProfile] = []
    @Published var selectedID: String?
    @Published var draft: DemoProfile?
    @Published var activeID: String?
    @Published var link: LinkState = .idle
    @Published var linkTarget: String?
    @Published var pendingSelection: String?
    @Published var showUnsaved = false
    @Published var showValidation = false
    @Published var showDetails = false
    @Published var notice = ""
    @Published var appearance = "system"
    @Published var launchAtLogin = false
    private let preferences: UserDefaults?
    private var lastSelected: String?

    init(preferences: UserDefaults? = nil) {
        self.preferences = preferences
        lastSelected = preferences?.string(forKey: "lastDemoProfile")
        load(.idle)
    }

    func t(_ ru: String, _ en: String) -> String { language == .ru ? ru : en }
    func title(_ page: Page) -> String {
        switch page {
        case .connection: return t("Подключение", "Connection")
        case .login: return t("Вход", "Sign-in")
        case .network: return t("Сеть", "Network")
        case .advanced: return t("Дополнительно", "Advanced")
        case .general: return t("Приложение", "Application")
        }
    }
    func title(_ scenario: Scenario) -> String {
        switch scenario {
        case .idle: return t("Отключено", "Disconnected")
        case .connected: return t("Подключено", "Connected")
        case .connecting: return t("Подключение", "Connecting")
        case .error: return t("Ошибка сервера", "Server error")
        case .empty: return t("Нет профилей", "No profiles")
        case .single: return t("Один профиль", "One profile")
        case .many: return t("20 профилей", "20 profiles")
        case .long: return t("Длинные значения", "Long values")
        case .missing: return t("Нужны данные", "Missing fields")
        case .unsaved: return t("Есть изменения", "Unsaved changes")
        case .proxyWarning: return t("Ошибка SOCKS", "SOCKS warning")
        }
    }
    var dirty: Bool {
        guard let draft else { return false }
        return profiles.first(where: { $0.id == draft.id }) != draft
    }
    var selectedLink: LinkState {
        activeID == selectedID && selectedID != nil ? .connected : linkTarget == selectedID ? link : .idle
    }
    var valid: Bool {
        guard let draft else { return false }
        let url = URL(string: draft.server)
        return !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && url?.scheme == "https" && !(url?.host?.isEmpty ?? true)
            && (draft.route != .proxy || Int(draft.port).map { (1...65535).contains($0) } == true)
    }
    static func initialSelection(ids: [String], active: String?, last: String?) -> String? {
        if let active, ids.contains(active) { return active }
        if let last, ids.contains(last) { return last }
        return ids.first
    }
    func reopen() {
        select(Self.initialSelection(ids: profiles.map(\.id), active: activeID, last: lastSelected))
        page = .connection
    }
    func select(_ id: String?) {
        selectedID = id
        draft = profiles.first { $0.id == id }
        if let id { lastSelected = id; preferences?.set(id, forKey: "lastDemoProfile") }
        showValidation = false
        showDetails = false
        notice = ""
    }
    func requestSelection(_ id: String) {
        guard id != selectedID else { return }
        if dirty { pendingSelection = id; showUnsaved = true }
        else { select(id) }
    }
    func discardAndSelect() {
        let next = pendingSelection
        pendingSelection = nil
        showUnsaved = false
        select(next)
    }
    @discardableResult func save() -> Bool {
        guard valid, let draft else { showValidation = true; return false }
        if let index = profiles.firstIndex(where: { $0.id == draft.id }) { profiles[index] = draft }
        else { profiles.append(draft) }
        showValidation = false
        if let next = pendingSelection { pendingSelection = nil; select(next) }
        return true
    }
    func add() {
        let id = UUID().uuidString
        let profile = DemoProfile(id: id, name: t("Новый профиль", "New profile"), server: "", user: "")
        profiles.append(profile)
        select(id)
        page = .connection
    }
    func toggleConnection() {
        guard let selectedID, !dirty, valid else { showValidation = true; return }
        if activeID == selectedID {
            activeID = nil; link = .idle
        } else if selectedLink == .connecting {
            link = .idle
        } else {
            activeID = selectedID; linkTarget = selectedID; link = .connected
        }
    }
    func load(_ scenario: Scenario) {
        self.scenario = scenario
        profiles = [
            DemoProfile(id: "work", name: t("Работа", "Work"), server: "https://vpn.example.com", user: "alex", passwordSaved: true, codeSaved: true),
            DemoProfile(id: "home", name: t("Дом", "Home"), server: "https://home.example.com", user: "alex", route: .all),
            DemoProfile(id: "lab", name: t("Тестовая сеть", "Test network"), server: "https://lab.example.com", user: "tester", route: .proxy)
        ]
        activeID = nil; link = .idle; linkTarget = "work"; pendingSelection = nil; showUnsaved = false
        if scenario == .empty { profiles = [] }
        if scenario == .single { profiles = Array(profiles.prefix(1)) }
        if scenario == .many {
            profiles += (4...20).map { DemoProfile(id: "team-\($0)", name: t("Команда \($0)", "Team \($0)"), server: "https://team\($0).example.com", user: "alex") }
        }
        if scenario == .long {
            profiles[0].name = t("Рабочая сеть — международная команда разработки и поддержки", "Work network — international engineering and customer support")
            profiles[0].server = "https://remote-access.engineering.staging.example.com/group/international"
            profiles[0].user = "alex.engineering.international@example.com"
        }
        if scenario == .missing { profiles[0].name = ""; profiles[0].server = "vpn.example.com" }
        if scenario == .connected || scenario == .proxyWarning { activeID = "work"; link = .connected }
        if scenario == .proxyWarning { profiles[0].route = .proxy; profiles[0].systemProxy = true }
        if scenario == .connecting { link = .connecting }
        if scenario == .error { link = .failed }
        // Each scenario is deterministic; normal reopening still remembers selection.
        select(Self.initialSelection(ids: profiles.map(\.id), active: activeID, last: scenario == .idle ? lastSelected : nil))
        if scenario == .unsaved { draft?.user = "alex.updated" }
        if scenario == .missing { showValidation = true }
    }
}
