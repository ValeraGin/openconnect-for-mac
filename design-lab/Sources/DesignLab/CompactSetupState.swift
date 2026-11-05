import Foundation
import Combine

enum CompactStep { case connection, signin, network, system, verify }
enum CompactLayout: String { case native, library }
enum CompactEditor: String, Identifiable { case routes, dns; var id: String { rawValue } }
struct CompactRoute: Identifiable, Equatable { let id = UUID(); var value = "" }

/// Disposable prototype state. No disk, credentials, CLI or network access.
final class CompactSetupState: ObservableObject {
    @Published var layout = CompactLayout.native
    @Published var step = CompactStep.connection
    @Published var address = ""
    @Published var user = ""
    @Published var browserLogin = true
    @Published var mode = RouteMode.selected
    @Published var port = "11080"
    @Published var systemProxy = false
    @Published var routes: [CompactRoute] = []
    @Published var zones: [DemoZone] = []
    @Published var pendingRoutes: [CompactRoute] = []
    @Published var pendingZones: [DemoZone] = []
    @Published var applyRoutes = true
    @Published var applyDNS = true
    @Published var serverDNS: [String] = []
    @Published var serverOfferedDefaultRoute = false
    @Published var proposalsApplied = false
    private var modeBeforeProposal = RouteMode.selected
    @Published var draftRoutes: [CompactRoute] = []
    @Published var draftZones: [DemoZone] = []
    @Published var editor: CompactEditor?
    @Published var helperReady = true
    @Published var includedSystem = false
    @Published var connected = false
    @Published var showError = false
    @Published var editorError = false
    @Published var resource = ""
    @Published var accessChecked = false
    var validAddress: Bool {
        let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = URLComponents(string: value.contains("://") ? value : "https://" + value)
        return url?.scheme == "https" && !(url?.host?.isEmpty ?? true) && !value.contains(where: { $0.isWhitespace })
    }
    static func validRoute(_ value: String) -> Bool {
        let parts = value.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "/", omittingEmptySubsequences: false)
        return parts.count == 2 && DemoModel.validIPv4(String(parts[0])) && Int(parts[1]).map { (0...32).contains($0) } == true
    }
    static func validZone(_ zone: DemoZone) -> Bool {
        !zone.zone.isEmpty && !zone.zone.contains(where: { $0.isWhitespace })
            && (zone.resolver == "vpn" || DemoModel.validIPv4(zone.resolver))
            && Int(zone.port).map { (1...65535).contains($0) } == true
    }
    var validNetwork: Bool {
        if mode == .proxy { return Int(port).map { (1...65535).contains($0) } == true }
        return (!applyRoutes || mode == .all || pendingRoutes.allSatisfy { Self.validRoute($0.value) }) && (!applyDNS || pendingZones.allSatisfy(Self.validZone))
    }
    var canCheckAccess: Bool {
        let url = URLComponents(string: resource)
        return connected && ["http", "https"].contains(url?.scheme ?? "") && !(url?.host?.isEmpty ?? true)
            && !resource.contains(where: { $0.isWhitespace })
    }
    func next() {
        switch step {
        case .connection:
            guard validAddress, mode != .proxy || validNetwork else { showError = true; return }
            includedSystem = !helperReady && mode != .proxy
            step = includedSystem ? .system : .signin
        case .system:
            guard helperReady else { return }; step = .signin
        case .signin: simulateSignIn()
        case .network:
            guard connected, validNetwork else { showError = true; return }
            if applyRoutes && mode == .selected { routes = pendingRoutes }
            if applyDNS && mode != .proxy { zones = pendingZones }
            modeBeforeProposal = mode
            proposalsApplied = true
            step = .verify
        case .verify: return
        }
        showError = false
    }
    func simulateSignIn() {
        guard step == .signin else { return }
        connected = true
        if mode == .proxy { step = .verify; return }
        receiveServerSettings(routes: ["10.20.0.0/16", "192.168.50.0/24"], dns: ["10.20.0.53"], domain: "corp.example.com")
    }
    /// Synthetic gateway response. Draft proposals never mutate applied settings.
    /// Production integration must bind this response to the current VPN session.
    func receiveServerSettings(routes offered: [String], dns: [String], domain: String) {
        guard connected, mode != .proxy else { return }
        pendingRoutes = routes; pendingZones = zones
        modeBeforeProposal = mode
        serverDNS = dns.filter(DemoModel.validIPv4)
        serverOfferedDefaultRoute = offered.contains { Self.validRoute($0) && $0.split(separator: "/").last.flatMap { Int($0) } == 0 }
        for raw in offered {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard Self.validRoute(value), value.split(separator: "/").last.flatMap({ Int($0) }) != 0,
                  !pendingRoutes.contains(where: { $0.value == value }) else { continue }
            pendingRoutes.append(.init(value: value))
        }
        let zone = DemoZone(zone: domain, resolver: "vpn", port: "53")
        if !serverDNS.isEmpty, Self.validZone(zone), !pendingZones.contains(where: { $0.zone.lowercased() == domain.lowercased() }) {
            pendingZones.append(zone)
        }
        applyRoutes = !pendingRoutes.isEmpty; applyDNS = !pendingZones.isEmpty
        proposalsApplied = false; showError = false; step = .network
    }
    func skipServerSettings() {
        guard step == .network, connected else { return }
        pendingRoutes = routes; pendingZones = zones
        mode = modeBeforeProposal
        proposalsApplied = false; showError = false; step = .verify
    }
    func back() {
        switch step {
        case .connection: return
        case .signin: step = includedSystem ? .system : .connection
        case .network: step = .connection; connected = false
        case .system: step = .connection
        case .verify: step = mode == .proxy ? .connection : .network
        }
        if step == .connection { connected = false }
        showError = false; accessChecked = false
    }
    func edit(_ kind: CompactEditor) {
        draftRoutes = pendingRoutes; draftZones = pendingZones; editorError = false; editor = kind
    }
    func cancelEditor() { editor = nil; editorError = false }
    func saveEditor() {
        guard let editor else { return }
        let valid = editor == .routes ? draftRoutes.allSatisfy { Self.validRoute($0.value) } : draftZones.allSatisfy(Self.validZone)
        guard valid else { editorError = true; return }
        if editor == .routes { pendingRoutes = draftRoutes; applyRoutes = true } else { pendingZones = draftZones; applyDNS = true }
        self.editor = nil; editorError = false; showError = false
    }
    func reset() {
        step = .connection; address = ""; user = ""; browserLogin = true; mode = .selected
        port = "11080"; systemProxy = false; routes = []; zones = []; editor = nil
        pendingRoutes = []; pendingZones = []; draftRoutes = []; draftZones = []
        applyRoutes = true; applyDNS = true; serverDNS = []; serverOfferedDefaultRoute = false; proposalsApplied = false
        helperReady = true; includedSystem = false; connected = false; showError = false
        editorError = false; resource = ""; accessChecked = false
    }
    func sample(_ state: String) {
        reset()
        if state == "empty" { return }
        address = "vpn.example.com/employees"; user = "alex"
        if ["empty", "filled", "long", "invalid", "system", "signin", "proxy"].contains(state) {
            switch state {
            case "long": address = "vpn-europe-production-gateway.example.com/employees/engineering/backup"; user = "alex.engineering.international@example.com"
            case "invalid": address = "http://invalid.example.com"; next()
            case "system": helperReady = false; next()
            case "signin": next()
            case "proxy": mode = .proxy
            default: break
            }
            return
        }
        connected = true
        if state == "server-existing" {
            routes = [.init(value: "172.20.0.0/16")]
            zones = [.init(zone: "corp.example.com", resolver: "172.20.0.53", port: "5353")]
        }
        receiveServerSettings(routes: ["10.20.0.0/16", "192.168.50.0/24"], dns: ["10.20.0.53"], domain: "corp.example.com")
        switch state {
        case "network-empty", "server-empty": receiveServerSettings(routes: [], dns: [], domain: "")
        case "server-dns-only": receiveServerSettings(routes: [], dns: ["10.20.0.53"], domain: "corp.example.com")
        case "server-no-domain": receiveServerSettings(routes: [], dns: ["10.20.0.53"], domain: "")
        case "server-default": receiveServerSettings(routes: ["0.0.0.0/0"], dns: [], domain: "")
        case "network-error": pendingRoutes = [.init(value: "invalid")]; next()
        case "full": mode = .all
        case "verify", "connected": next()
        case "server-skipped": skipServerSettings()
        case "routes", "routes-many", "routes-error":
            edit(.routes)
            if state == "routes-many" { draftRoutes = (1...20).map { .init(value: "10.\($0).0.0/16") } }
            if state == "routes-error" { draftRoutes[0].value = "10.0.0.999/8"; saveEditor() }
        case "dns", "dns-many":
            edit(.dns)
            if state == "dns-many" { draftZones = (1...12).map { .init(zone: "branch-\($0).corp.example.com", resolver: "10.20.0.53", port: "53") } }
        default: break
        }
    }
}
