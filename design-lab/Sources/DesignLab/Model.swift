import Foundation
import Combine

enum Language: String, CaseIterable { case ru, en }
enum Page: String, CaseIterable {
    case connection, login, network, advanced, general, notifications, diagnostics
    var isGlobal: Bool { [.general, .notifications, .diagnostics].contains(self) }
    var icon: String {
        switch self {
        case .connection: return "network"
        case .login: return "log-in"
        case .network: return "route"
        case .advanced: return "sliders-horizontal"
        case .general: return "settings"
        case .notifications: return "bell"
        case .diagnostics: return "activity"
        }
    }
}
enum Scenario: String, CaseIterable {
    case idle, connected, connecting, error, empty, single, many, long, missing, unsaved, proxyWarning
    case signInSSO, signInPassword, signInCode, signInRejected, signInExpired, signInSuccess
    case credentialPassword, credentialCode, about, addressOnly, totpOffer, totpSetup, smsCode
    case paused, dnsCustom, keepass, commandSource, rulesLearn, notificationsOff, helperMissing, diagnosticsWarning, diskConflict, importPreview, totpQR, totpEight, keepassLocked, dnsInvalid, logsEmpty
}
enum LinkState { case idle, connecting, signIn, connected, paused, failed }
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
    var zones = [DemoZone(zone: "corp.example", resolver: "vpn", port: "53")]
    var options = DemoOptions()
    var port = "11080"
    var systemProxy = false
    var upstreamProxy = ""
    var userAgent = ""
    var displayName: String {
        let custom = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty { return custom }
        let address = server.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = address.contains("://") ? address : "https://" + address
        if let components = URLComponents(string: value), let host = components.host {
            return host + (components.port.map { ":\($0)" } ?? "") + components.path
        }
        return address.isEmpty ? "—" : address
    }
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
    @Published var authPresented = false
    @Published var aboutPresented = false
    @Published var authStage: AuthStage = .sso
    @Published var authTargetID: String?
    @Published var authUsername = ""
    @Published var authPassword = ""
    @Published var authCode = ""
    @Published var authError = false
    @Published var authSecret = ""
    @Published var totpAfterLogin = false
    @Published var recordedCode = ""
    @Published var autoPolicy = "resume"
    @Published var skipNetwork = false
    @Published var aboutLicenses = false
    @Published var aboutTechnical = false
    @Published var detail: Detail?
    @Published var pausedID: String?
    @Published var disabledRoutes = Set<String>()
    @Published var disabledZones = Set<String>()
    @Published var developer = false
    @Published var appLanguage = "system"
    @Published var legacyAvailable = true
    @Published var notifyLogin = true
    @Published var notifyProblems = true
    @Published var notifyEvents = false
    @Published var notificationsAllowed = true
    @Published var helperReady = true
    @Published var diagnosticsIssue = false
    @Published var logSource = "supervisor"
    @Published var logFilter = ""
    @Published var followLog = true
    @Published var conflict = false
    @Published var confirmOverwrite = false
    @Published var learningStep = 0
    @Published var learningSelections = Set<String>()
    @Published var importTrusted = false
    @Published var setupStep = 0
    @Published var accessChecked = false
    @Published var setupResource = ""
    @Published var selectedImport = "branch"
    @Published var selectedQR = "branch"
    @Published var qrSource = "screen"
    @Published var qrDetected = false
    @Published var keepassUnlocked = true

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
        case .notifications: return t("Уведомления", "Notifications")
        case .diagnostics: return t("Диагностика", "Diagnostics")
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
        case .signInSSO: return t("Вход: SSO", "Sign-in: SSO")
        case .signInPassword: return t("Вход: пароль", "Sign-in: password")
        case .signInCode: return t("Вход: код", "Sign-in: code")
        case .signInRejected: return t("Вход: ошибка", "Sign-in: rejected")
        case .signInExpired: return t("Вход: код истёк", "Sign-in: expired")
        case .signInSuccess: return t("Вход: успех", "Sign-in: success")
        case .credentialPassword: return t("Настройка пароля", "Save password")
        case .credentialCode: return t("Секрет TOTP", "TOTP secret")
        case .about: return t("О приложении", "About")
        case .addressOnly: return t("Профиль без имени", "Address as profile name")
        case .totpOffer: return t("Предложить TOTP", "Offer TOTP setup")
        case .totpSetup: return t("Настройка TOTP", "TOTP setup")
        case .smsCode: return t("Код из SMS", "SMS code")
        case .paused: return t("Пауза", "Paused")
        case .dnsCustom: return t("Свой DNS", "Custom DNS")
        case .keepass: return "KeePassXC"
        case .commandSource: return t("Секрет из команды", "Command source")
        case .rulesLearn: return t("Разметка формы", "Teach sign-in")
        case .notificationsOff: return t("Уведомления запрещены", "Notifications blocked")
        case .helperMissing: return t("Нет помощника", "Helper missing")
        case .diagnosticsWarning: return t("Проблема доступа", "Access failure")
        case .diskConflict: return t("Конфликт правок", "File conflict")
        case .importPreview: return t("Импорт профиля", "Import profile")
        case .totpQR: return t("Импорт QR", "QR import")
        case .totpEight: return t("Код из 8 цифр", "Eight-digit code")
        case .keepassLocked: return t("KeePassXC закрыт", "KeePassXC locked")
        case .dnsInvalid: return t("Ошибка DNS", "Invalid DNS")
        case .logsEmpty: return t("Пустой поиск журнала", "No log matches")
        }
    }
    var dirty: Bool {
        guard let draft else { return false }
        return profiles.first(where: { $0.id == draft.id }) != draft
    }
    var selectedLink: LinkState {
        activeID == selectedID && selectedID != nil ? (pausedID == selectedID ? .paused : .connected) : linkTarget == selectedID ? link : .idle
    }
    var canStartConnection: Bool { !dirty && valid && (draft?.route == .proxy || helperReady) }
    var valid: Bool {
        guard let draft else { return false }
        let url = URL(string: draft.server.contains("://") ? draft.server : "https://" + draft.server)
        return !draft.server.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.server.contains(" ") && url?.scheme == "https" && !(url?.host?.isEmpty ?? true)
            && (draft.route != .proxy || Int(draft.port).map { (1...65535).contains($0) } == true)
            && extendedIssues.isEmpty
    }
    static func initialSelection(ids: [String], active: String?, last: String?) -> String? {
        if let active, ids.contains(active) { return active }
        if let last, ids.contains(last) { return last }
        return ids.first
    }
    func reopen() {
        select(Self.initialSelection(ids: profiles.map(\.id), active: activeID, last: lastSelected))
        page = .connection; detail = nil
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
        if conflict { confirmOverwrite = true; return false }
        if let index = profiles.firstIndex(where: { $0.id == draft.id }) { profiles[index] = draft }
        else { profiles.append(draft) }
        showValidation = false
        if let next = pendingSelection { pendingSelection = nil; select(next) }
        return true
    }
    func add() {
        let id = UUID().uuidString
        let profile = DemoProfile(id: id, name: "", server: "", user: "")
        profiles.append(profile)
        select(id)
        page = .connection
    }
    func toggleConnection() {
        guard let selectedID, activeID == selectedID || selectedLink == .connecting || canStartConnection else { showValidation = true; return }
        if activeID == selectedID {
            activeID = nil; pausedID = nil; link = .idle
        } else if selectedLink == .connecting {
            link = .idle
        } else if selectedLink == .signIn && authTargetID == selectedID {
            authPresented = true
        } else {
            beginSignIn()
        }
    }
    func load(_ scenario: Scenario) {
        self.scenario = scenario
        detail = nil; page = .connection; pausedID = nil
        disabledRoutes = []; disabledZones = []; conflict = false; confirmOverwrite = false
        learningStep = 0; learningSelections = []; importTrusted = false
        diagnosticsIssue = false; helperReady = true; notificationsAllowed = true
        accessChecked = false; setupStep = 0; qrSource = "screen"; qrDetected = false
        legacyAvailable = true
        aboutTechnical = false; keepassUnlocked = true; logFilter = ""
        authPresented = false; aboutPresented = false; aboutLicenses = false
        authPassword = ""; authCode = ""; authSecret = ""; recordedCode = ""; authError = false; totpAfterLogin = false
        profiles = [
            DemoProfile(id: "work", name: t("Работа", "Work"), server: "https://vpn.example.com", user: "alex", passwordSaved: true, codeSaved: true),
            DemoProfile(id: "home", name: t("Дом", "Home"), server: "https://home.example.com", user: "alex", route: .all),
            DemoProfile(id: "lab", name: t("Тестовая сеть", "Test network"), server: "https://lab.example.com", user: "tester", route: .proxy)
        ]
        activeID = nil; pausedID = nil; link = .idle; linkTarget = "work"; pendingSelection = nil; showUnsaved = false
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
        if scenario == .missing { profiles[0].name = ""; profiles[0].server = "" }
        if scenario == .addressOnly { profiles[0].name = "" }
        if scenario == .smsCode { profiles[0].browserLogin = false; profiles[0].codeSaved = false }
        if [.signInCode, .totpOffer, .totpSetup].contains(scenario) { profiles[0].codeSaved = false }
        if scenario == .connected || scenario == .proxyWarning { activeID = "work"; link = .connected }
        if scenario == .proxyWarning { profiles[0].route = .proxy; profiles[0].systemProxy = true }
        if scenario == .connecting { link = .connecting }
        if scenario == .error { link = .failed }
        // Each scenario is deterministic; normal reopening still remembers selection.
        select(Self.initialSelection(ids: profiles.map(\.id), active: activeID, last: scenario == .idle ? lastSelected : nil))
        if scenario == .unsaved { draft?.user = "alex.updated" }
        if scenario == .missing { showValidation = true }
        loadExtendedFixture(scenario)
        loadAuthFixture(scenario)
        if scenario == .about { aboutPresented = true }
    }
}
