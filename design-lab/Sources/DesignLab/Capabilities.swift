import Foundation

struct DemoZone: Identifiable, Equatable {
    var id = UUID()
    var zone: String
    var resolver: String
    var port: String
}
struct DemoOptions: Equatable {
    var description = ""
    var fileName = "profile.ocmac"
    var passwordSource = "auto"
    var codeSource = "auto"
    var passwordCommand = ""
    var codeCommand = ""
    var keepassEntry = ""
    var keepassDB = ""
    var keepassKeychain = ""
    var keychainService = "ru.ocmac.client"
    var algorithm = "SHA1"
    var digits = "6"
    var period = "30"
    var csdWrapper = ""
    var embeddedCSD = false
    var idpHosts = ""
    var health = ""
    var rules = ""
    var rulesFile = ""
    var notifications = true
}

enum Detail: String, CaseIterable {
    case sources, totpOptions, qrImport, dns, rules, learning, compatibility, profiles, transfer, setup, logs, report, runtime, filePreview
    var page: Page {
        switch self {
        case .sources, .totpOptions, .qrImport, .rules, .learning: return .login
        case .dns: return .network
        case .compatibility, .filePreview: return .advanced
        case .profiles, .transfer, .setup: return .general
        case .logs, .report: return .diagnostics
        case .runtime: return .connection
        }
    }
    func title(_ language: Language) -> String {
        let pair: (String, String)
        switch self {
        case .sources: pair = ("Источники данных", "Credential sources")
        case .totpOptions: pair = ("Параметры TOTP", "TOTP parameters")
        case .qrImport: pair = ("Добавить TOTP", "Import TOTP")
        case .dns: pair = ("DNS-зоны", "DNS zones")
        case .rules: pair = ("Правила входа", "Sign-in rules")
        case .learning: pair = ("Разметка формы", "Teach sign-in")
        case .compatibility: pair = ("Совместимость", "Compatibility")
        case .profiles: pair = ("Управление профилями", "Manage profiles")
        case .transfer: pair = ("Импорт и экспорт", "Import and export")
        case .setup: pair = ("Мастер настройки", "Setup assistant")
        case .logs: pair = ("Журналы", "Logs")
        case .report: pair = ("Отчёт диагностики", "Diagnostic report")
        case .runtime: pair = ("Текущее соединение", "Current connection")
        case .filePreview: pair = ("Файл профиля", "Profile file")
        }
        return language == .ru ? pair.0 : pair.1
    }
}

extension DemoModel {
    func navigate(_ destination: Detail) {
        if destination == .setup { startSetup(); return }
        page = destination.page; detail = destination; notice = ""
    }
    func startSetup(resume: Bool = false) {
        setupReturnPage = page
        if draft == nil { add() }
        setupNeedsSystemStep = !helperReady && draft?.route != .proxy
        setupStep = resume && valid && !dirty && !conflict ? (setupNeedsSystemStep ? 1 : 2) : 0
        accessChecked = false; setupResource = ""; notice = ""
        page = .general; detail = .setup
    }
    func closeSetup() { page = setupReturnPage; detail = nil; notice = "" }
    func advanceSetup() {
        switch setupStep {
        case 0:
            guard save() else { return }
            accessChecked = false
            setupNeedsSystemStep = !helperReady && draft?.route != .proxy
            setupStep = setupNeedsSystemStep ? 1 : 2
        case 1:
            guard helperReady || draft?.route == .proxy else { return }
            setupStep = 2
        default: break
        }
    }
    func backSetup() {
        setupStep = setupStep == 2 && setupNeedsSystemStep ? 1 : 0
        accessChecked = false
    }
    var canCheckSetupAccess: Bool {
        guard selectedLink == .connected, canStartConnection,
              let url = URL(string: setupResource), ["https", "http"].contains(url.scheme),
              let host = url.host, !host.isEmpty, !setupResource.contains(where: { $0.isWhitespace }) else { return false }
        return true
    }
    func checkSetupAccess() { accessChecked = canCheckSetupAccess }

    var activeProfile: DemoProfile? { profiles.first { $0.id == activeID } }
    var runtimeRoutes: [String] {
        guard let p = activeProfile else { return [] }
        if p.route == .all { return ["0.0.0.0/1", "128.0.0.0/1"] }
        return p.routes.split(separator: "\n").map(String.init).filter { !$0.hasPrefix("#") && !$0.hasPrefix(";") }
    }
    static func validIPv4(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 4 && parts.allSatisfy { !$0.isEmpty && $0.count <= 3 && $0.allSatisfy { "0123456789".contains($0) } && (Int($0) ?? 999) <= 255 }
    }
    var extendedIssues: [String] {
        guard let draft else { return [] }
        var issues: [String] = []
        if draft.route != .proxy {
            for zone in draft.zones {
                if zone.zone.isEmpty || zone.zone.contains(where: { $0.isWhitespace }) || (zone.resolver != "vpn" && !Self.validIPv4(zone.resolver))
                    || Int(zone.port).map({ (1...65535).contains($0) }) != true {
                    issues.append(t("DNS: укажите домен, резолвер и порт 1–65535.", "DNS: enter a domain, resolver and port 1–65535.")); break
                }
            }
            for route in draft.routes.split(separator: "\n") where !route.hasPrefix("#") && !route.hasPrefix(";") {
                let net = route.split(separator: " ").first.map(String.init) ?? ""
                let parts = net.split(separator: "/")
                let octets = parts.first?.split(separator: ".") ?? []
                if parts.count != 2 || octets.count != 4 || !Self.validIPv4(String(parts.first ?? ""))
                    || Int(parts.last ?? "").map({ (0...32).contains($0) }) != true {
                    issues.append(t("Подсеть должна быть в формате 10.0.0.0/8.", "Use a subnet such as 10.0.0.0/8.")); break
                }
            }
        }
        let o = draft.options
        if o.passwordSource == "command" && o.passwordCommand.isEmpty || draft.browserLogin && o.codeSource == "command" && o.codeCommand.isEmpty {
            issues.append(t("Укажите команду выбранного источника.", "Enter the command for the selected source."))
        }
        if o.passwordSource == "keepassxc" || draft.browserLogin && o.codeSource == "keepassxc" {
            if o.keepassEntry.isEmpty || o.keepassDB.isEmpty { issues.append(t("Укажите базу и запись KeePassXC.", "Enter the KeePassXC database and entry.")) }
        }
        if draft.browserLogin && ["auto", "keychain"].contains(o.codeSource)
            && (!TOTPParams.algorithms.contains(o.algorithm) || Int(o.digits).map({ (6...8).contains($0) }) != true || Int(o.period).map({ (10...300).contains($0) }) != true) {
            issues.append(t("TOTP: 6–8 цифр, период 10–300 секунд.", "TOTP: 6–8 digits, period 10–300 seconds."))
        }
        return issues
    }
    func togglePause() {
        guard let id = selectedID, activeID == id, activeProfile?.route != .proxy else { return }
        pausedID = pausedID == id ? nil : id
    }
    func moveProfile(_ id: String, by offset: Int) {
        guard let index = profiles.firstIndex(where: { $0.id == id }), profiles.indices.contains(index + offset) else { return }
        profiles.swapAt(index, index + offset)
    }
    func resolveConflict(reload: Bool) {
        conflict = false; confirmOverwrite = false
        if reload { pendingSelection = nil; select(selectedID) } else { _ = save() }
    }
    func finishLearning() {
        guard var updated = draft, updated.browserLogin, learningSelections.contains("username"), learningSelections.contains("password") else { return }
        updated.options.rules = "# step 1\nfill username input[name=username]\nfill password input[type=password]\nclick button[type=submit]\n# step 2\nfill totp input[name=otp]\nclick button[type=submit]"
        draft = updated
        navigate(.rules)
        notice = t("Правила тестовой формы готовы. Сохраните профиль.", "Sample form rules are ready. Save the profile.")
    }
    func convertLegacySample() {
        guard legacyAvailable, !dirty else { return }
        let profile = DemoProfile(id: "legacy-office", name: "", server: "https://legacy.example.com", user: "alex")
        profiles.append(profile); legacyAvailable = false
        notice = t("Старый тестовый профиль преобразован в .ocmac.", "Legacy sample profile converted to .ocmac.")
    }
    func importSample() {
        guard importTrusted, !dirty else { return }
        let id = "import-" + UUID().uuidString
        let sample = DemoProfile(id: id, name: "", server: "https://\(selectedImport).example.com", user: "alex")
        profiles.append(sample); select(id); page = .connection; detail = nil
    }
    func loadExtendedFixture(_ scenario: Scenario) {
        switch scenario {
        case .paused: activeID = selectedID; pausedID = selectedID; link = .connected
        case .dnsCustom:
            draft?.zones = [DemoZone(zone: "corp.example", resolver: "vpn", port: "53"), DemoZone(zone: "dev.corp.example", resolver: "10.20.0.53", port: "5353")]
            navigate(.dns)
        case .keepass, .keepassLocked:
            keepassUnlocked = scenario != .keepassLocked
            draft?.options.passwordSource = "keepassxc"; draft?.options.codeSource = "keepassxc"
            draft?.options.keepassEntry = "Work/VPN"; draft?.options.keepassDB = "~/Passwords.kdbx"
            draft?.options.keepassKeychain = "demo.keepass"; navigate(.sources)
        case .commandSource:
            draft?.options.passwordSource = "command"; draft?.options.passwordCommand = "op item get VPN --fields password"
            draft?.options.codeSource = "command"; draft?.options.codeCommand = "op item get VPN --otp"; navigate(.sources)
        case .rulesLearn: navigate(.learning)
        case .notificationsOff: page = .notifications; notificationsAllowed = false
        case .helperMissing: helperReady = false; navigate(.setup)
        case .diagnosticsWarning: diagnosticsIssue = true; page = .diagnostics
        case .diskConflict: conflict = true; draft?.user = "alex.updated"
        case .importPreview: navigate(.transfer)
        case .totpQR: navigate(.qrImport); qrDetected = true
        case .totpEight: draft?.options.digits = "8"; draft?.codeSaved = false
        case .dnsInvalid: draft?.zones[0].port = "70000"; showValidation = true; navigate(.dns)
        case .logsEmpty: logFilter = "not-found"; navigate(.logs)
        default: break
        }
        if let draft, let i = profiles.firstIndex(where: { $0.id == draft.id }), [.dnsCustom, .keepass, .keepassLocked, .commandSource, .totpEight, .dnsInvalid].contains(scenario) {
            profiles[i] = draft
        }
    }
    var profilePreview: String {
        guard let p = draft else { return "" }
        let o = p.options
        var text = "# Demo profile — no secrets\n[Connection]\nName = \(p.name)\nDescription = \(o.description)\nURL = \(p.server)\nUser = \(p.user)\nMode = \(p.route == .proxy ? "proxy" : "tunnel")\nAuth = \(p.browserLogin ? "sso" : "password")\nUserAgent = \(p.userAgent)\nUpstreamProxy = \(p.upstreamProxy)\nCsdWrapper = \(o.csdWrapper)\nNotifications = \(o.notifications ? "on" : "off")\n\n[Auth]\nPassword = \(o.passwordSource)\nTOTP = \(o.codeSource)\nTOTPAlgorithm = \(o.algorithm)\nTOTPDigits = \(o.digits)\nTOTPPeriod = \(o.period)\nPasswordCommand = \(o.passwordCommand)\nTOTPCommand = \(o.codeCommand)\nKeePassEntry = \(o.keepassEntry)\nKeePassDB = \(o.keepassDB)\nKeePassKeychain = \(o.keepassKeychain)\nKeychainService = \(o.keychainService)\nIdPHosts = \(o.idpHosts)\nRules = \(o.rulesFile)\n\n[Routes]\n"
        if o.embeddedCSD {
            let script = Data("#!/bin/sh\nexit 0\n".utf8).base64EncodedString()
            text = text.replacingOccurrences(of: "CsdWrapper = \(o.csdWrapper)\n", with: "CsdScriptBase64 = \(script)\n")
        }
        text += p.route == .all ? "0.0.0.0/1\n128.0.0.0/1" : p.routes
        text += "\n\n[DNS]\n" + p.zones.map { "\($0.zone) = \($0.resolver) \($0.port)" }.joined(separator: "\n")
        text += "\n\n[Proxy]\nPort = \(p.port)\nSystemProxy = \(p.systemProxy ? "on" : "off")\n\n[Health]\nCheck = \(o.health)\n\n[Autofill]\n\(o.rules)\n"
        return text
    }
    var diagnosticReport: String {
        "OpenConnect for Mac — DEMO REPORT\nNo live system data was collected.\n\nVersions: sample components\nHelper: \(helperReady ? "ready" : "missing")\nAccess: \(diagnosticsIssue ? "failed" : "ok")\n\n[Log sample — redacted]\nHost: <host-1>\nUser: <user-1>\nRoute: <network-1>\n"
    }
    var logLines: [String] {
        let lines = ["12:00:00 [\(logSource)] starting sample connection", "12:00:01 [\(logSource)] authenticated vpn.example.com", "12:00:02 [\(logSource)] route 10.20.0.0/16 enabled", "12:00:03 [\(logSource)] DNS corp.example → vpn", "12:00:04 [\(logSource)] \(diagnosticsIssue ? "WARN access check failed" : "connection healthy")"]
        return lines.filter { logFilter.isEmpty || $0.localizedCaseInsensitiveContains(logFilter) }
    }
}
