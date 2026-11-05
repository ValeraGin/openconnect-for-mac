import Foundation
import Combine

enum CompactStep { case connection, network, system, verify }
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
        return (mode == .all || !routes.isEmpty && routes.allSatisfy { Self.validRoute($0.value) }) && zones.allSatisfy(Self.validZone)
    }
    var canCheckAccess: Bool {
        let url = URLComponents(string: resource)
        return connected && ["http", "https"].contains(url?.scheme ?? "") && !(url?.host?.isEmpty ?? true)
            && !resource.contains(where: { $0.isWhitespace })
    }
    func next() {
        switch step {
        case .connection:
            guard validAddress else { showError = true; return }
            step = .network
        case .network:
            guard validNetwork else { showError = true; return }
            includedSystem = !helperReady && mode != .proxy
            step = includedSystem ? .system : .verify
        case .system:
            guard helperReady else { return }; step = .verify
        case .verify: return
        }
        showError = false
    }
    func back() {
        switch step {
        case .connection: return
        case .network: step = .connection
        case .system: step = .network
        case .verify: step = includedSystem ? .system : .network
        }
        showError = false; connected = false; accessChecked = false
    }
    func edit(_ kind: CompactEditor) {
        draftRoutes = routes; draftZones = zones; editorError = false; editor = kind
    }
    func cancelEditor() { editor = nil; editorError = false }
    func saveEditor() {
        guard let editor else { return }
        let valid = editor == .routes ? draftRoutes.allSatisfy { Self.validRoute($0.value) } : draftZones.allSatisfy(Self.validZone)
        guard valid else { editorError = true; return }
        if editor == .routes { routes = draftRoutes } else { zones = draftZones }
        self.editor = nil; editorError = false; showError = false
    }
    func reset() {
        step = .connection; address = ""; user = ""; browserLogin = true; mode = .selected
        port = "11080"; systemProxy = false; routes = []; zones = []; editor = nil
        helperReady = true; includedSystem = false; connected = false; showError = false
        editorError = false; resource = ""; accessChecked = false
    }
    func sample(_ state: String) {
        reset()
        if state == "empty" { return }
        address = "vpn.example.com/employees"; user = "alex"
        routes = [.init(value: "10.20.0.0/16"), .init(value: "192.168.50.0/24")]
        zones = [.init(zone: "corp.example.com", resolver: "vpn", port: "53")]
        switch state {
        case "long": address = "vpn-europe-production-gateway.example.com/employees/engineering/backup"; user = "alex.engineering.international@example.com"
        case "invalid": address = "http://invalid.example.com"; next()
        case "network": step = .network
        case "network-empty": step = .network; routes = []; zones = []
        case "network-error": step = .network; routes = []; zones = []; next()
        case "full": step = .network; mode = .all
        case "proxy": step = .network; mode = .proxy
        case "system": step = .system; helperReady = false; includedSystem = true
        case "verify": step = .verify
        case "connected": step = .verify; connected = true
        case "routes", "routes-many", "routes-error":
            step = .network; edit(.routes)
            if state == "routes-many" { draftRoutes = (1...20).map { .init(value: "10.\($0).0.0/16") } }
            if state == "routes-error" { draftRoutes[0].value = "10.0.0.999/8"; saveEditor() }
        case "dns", "dns-many":
            step = .network; edit(.dns)
            if state == "dns-many" { draftZones = (1...12).map { .init(zone: "branch-\($0).corp.example.com", resolver: "10.20.0.53", port: "53") } }
        default: break
        }
    }
}
