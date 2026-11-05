import Foundation
import Combine
import CryptoKit

/// A new setup never borrows another profile's routes, login or file name.
@MainActor
final class SetupFlow: ObservableObject {
    static let shared = SetupFlow()
    enum Step: Int { case profile, system, verify, network }
    @Published var doc = ProfileDoc()
    @Published private(set) var step = Step.profile
    @Published private(set) var busy = false
    @Published private(set) var checking = false
    @Published private(set) var system: ProfileSystemState?
    @Published private(set) var helperReady = false
    @Published private(set) var includesSystem = false
    @Published var note: String?
    @Published var proposedRoutes: [String] = []
    @Published var proposedZones: [ZoneLine] = []
    @Published var useRoutes = true
    @Published var useDNS = true
    @Published var fullTunnel = false
    @Published private(set) var serverDNS: [String] = []
    @Published private(set) var offeredFullTunnel = false
    @Published private(set) var networksReviewed = false
    @Published private(set) var awaitingConnection = false
    private var reviewedSession: Status?
    private let sessionStatus: () -> Status
    private let applySelection: (String, String, String) -> OCMacClient.ActionResult
    private var stamp: ProfileStore.DiskStamp?
    private var generation = UUID()
    private let readiness: (ProfileDoc) -> (ProfileSystemState, Bool)
    private let connectProfile: (String) -> Void
    var savedID: String? { stamp == nil ? nil : doc.fileName }
    var ready: Bool { system?.ready == true && helperReady }

    init(readiness: @escaping (ProfileDoc) -> (ProfileSystemState, Bool) = QuickProfileFlow.systemReadiness,
         connect: ((String) -> Void)? = nil,
         status: @escaping () -> Status = { OCMacClient.shared.status() },
         apply: @escaping (String, String, String) -> OCMacClient.ActionResult = {
             OCMacClient.shared.action(["setup-apply", $0, $1, $2], timeout: 60)
         }) {
        self.sessionStatus = status; self.applySelection = apply
        self.readiness = readiness
        self.connectProfile = connect ?? { StatusStore.shared.connect(profile: $0, teach: true) }
    }

    func show(profile: String? = nil) {
        guard !busy && !checking else { return }
        start(profile: profile)
        WindowBridge.open(WindowID.setup)
    }

    func start(profile: String? = nil) {
        guard !busy && !checking else { return }
        awaitingConnection = false; reviewedSession = nil; networksReviewed = false
        proposedRoutes = []; proposedZones = []; serverDNS = []; fullTunnel = false; offeredFullTunnel = false
        generation = UUID(); doc = ProfileDoc(); stamp = nil
        step = .profile; system = nil; helperReady = false; includesSystem = false; note = nil
        if let profile {
            let snapshot = ProfileStore.stamp(profile)
            if let text = snapshot.text {
                doc = ProfileDoc.parse(text, fileName: profile); stamp = snapshot
            }
        }
    }

    static func addressName(_ address: String) -> String {
        let address = address.trimmed
        let normalized = address.contains("://") ? address : "https://" + address
        guard let url = URLComponents(string: normalized), let host = url.host, !host.isEmpty else { return address }
        return host + (url.port.map { ":\($0)" } ?? "") + url.path
    }

    func saveAndContinue() {
        guard !busy && !checking else { return }
        var candidate = doc
        candidate.url = candidate.url.trimmed; candidate.user = candidate.user.trimmed
        if candidate.name.trimmed.isEmpty { candidate.name = Self.addressName(candidate.url) }
        if stamp == nil {
            candidate.fileName = ProfileOpening.identifier(candidate.name, occupied: Set(ProfileStore.list()))
        }
        let problems = ProfileCheck.check(candidate).filter { $0.level == .error }
        guard problems.isEmpty else { note = problems.map(\.text).joined(separator: "\n"); return }
        guard OCMacClient.shared.binary != nil else { note = L("OpenConnect for Mac не найден"); return }
        let expected = stamp ?? ProfileStore.stamp(candidate.fileName)
        let request = generation
        busy = true; note = nil
        ProfileSaveService.save(candidate, expected: expected) { outcome in
            guard self.generation == request else { return }
            self.busy = false
            switch outcome {
            case .saved:
                self.doc = candidate; self.stamp = ProfileStore.stamp(candidate.fileName)
                self.check(advance: true)
            case .changed: self.note = L("Профиль изменился. Откройте его заново, чтобы сохранить актуальные настройки.")
            case .rejected(let why), .failed(let why): self.note = why
            }
        }
    }

    func check(advance: Bool = false, then: (() -> Void)? = nil) {
        guard savedID != nil, !busy && !checking else { return }
        let request = generation, snapshot = doc, read = readiness
        checking = true; note = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let (state, helper) = read(snapshot)
            DispatchQueue.main.async {
                guard self.generation == request else { return }
                self.checking = false; self.system = state; self.helperReady = helper
                if advance {
                    self.includesSystem = !self.ready
                    self.step = self.ready ? .verify : .system
                }
                then?()
            }
        }
    }

    func continueFromSystem() {
        check { if self.ready { self.step = .verify } }
    }

    func back() {
        guard !busy && !checking else { return }
        if step == .network { step = .verify; note = nil; return }
        awaitingConnection = false
        step = step == .verify && includesSystem ? .system : .profile
        note = nil
    }

    func connect() {
        guard let savedID, let stamp, !busy && !checking else { return }
        guard ProfileStore.stamp(savedID) == stamp else {
            note = L("Профиль изменился. Откройте его заново, чтобы сохранить актуальные настройки."); return
        }
        check {
            // Readiness checks are asynchronous; a file edited during them must not connect.
            guard ProfileStore.stamp(savedID) == stamp else {
                self.note = L("Профиль изменился. Откройте его заново, чтобы сохранить актуальные настройки."); return
            }
            if self.ready { self.awaitingConnection = true; self.networksReviewed = false; self.connectProfile(savedID) }
            else { self.includesSystem = true; self.step = .system }
        }
    }

    nonisolated static func sameSession(_ status: Status, _ expected: Status) -> Bool {
        status.state == .connected && !status.isProxySession && !status.gatewaySession.isEmpty
            && status.profile == expected.profile && status.gatewaySession == expected.gatewaySession
            && status.tundev == expected.tundev && status.since == expected.since
    }

    func observe(_ status: Status, actionBusy: Bool) {
        guard awaitingConnection, !actionBusy, status.state == .connected, status.profile == savedID else { return }
        awaitingConnection = false
        if status.isProxySession { networksReviewed = true; return }
        review(status)
    }

    func review(_ status: Status) {
        guard !busy && !checking, status.state == .connected, !status.isProxySession,
              let id = savedID, status.profile == id else { return }
        guard !status.gatewaySession.isEmpty else { note = L("Клиент не передал данные сессии. Обновите клиент и подключитесь заново."); return }
        // --teach may have saved authentication settings after sign-in. Reload
        // that exact profile once the connection action has completed.
        let current = ProfileStore.stamp(id)
        guard let text = current.text else { note = L("Профиль изменился. Откройте его заново, чтобы сохранить актуальные настройки."); return }
        doc = ProfileDoc.parse(text, fileName: id); stamp = current
        reviewedSession = status; networksReviewed = false; note = nil; fullTunnel = false
        serverDNS = status.dns.filter(ProfileCheck.validIP)
        offeredFullTunnel = status.gatewayRoutes.contains { ProfileCheck.validCIDR($0) && (ProfileCheck.prefixLength($0) ?? 32) < 8 }
        var seen = Set(doc.routeNets)
        proposedRoutes = status.gatewayRoutes.filter {
            ProfileCheck.validCIDR($0) && (ProfileCheck.prefixLength($0) ?? 0) >= 8 && seen.insert($0).inserted
        }
        let domain = status.gatewayDomain.trimmed
        proposedZones = !serverDNS.isEmpty && ProfileCheck.validZone(domain)
            && !doc.zones.contains(where: { $0.zone.lowercased() == domain.lowercased() })
            ? [ZoneLine(zone: domain, resolver: "vpn", port: "53")] : []
        useRoutes = !proposedRoutes.isEmpty; useDNS = !proposedZones.isEmpty
        step = .network
    }

    func skipNetworks() {
        guard !busy && !checking else { return }
        networksReviewed = true; step = .verify; note = nil
    }

    func networkCandidate() -> ProfileDoc {
        var candidate = doc
        var known = Set(candidate.routeNets)
        let added = fullTunnel ? ["0.0.0.0/1", "128.0.0.0/1"] : useRoutes ? proposedRoutes : []
        for net in added where known.insert(net).inserted { candidate.routes.append(net) }
        if useDNS {
            var domains = Set(candidate.zones.map { $0.zone.lowercased() })
            for zone in proposedZones where domains.insert(zone.zone.lowercased()).inserted { candidate.zones.append(zone) }
        }
        return candidate
    }

    func applyNetworks() {
        guard step == .network, !busy && !checking, let stamp, let session = reviewedSession else { return }
        let candidate = networkCandidate(), request = generation, read = sessionStatus, apply = applySelection
        let problems = ProfileCheck.check(candidate).filter { $0.level == .error }
        guard problems.isEmpty else { note = problems.map(\.text).joined(separator: "\n"); return }
        busy = true; note = nil
        ProfileSaveService.save(candidate, expected: stamp, validate: { draft in
            guard Self.sameSession(read(), session) else { return L("VPN-сессия изменилась. Получите настройки сервера заново.") }
            return OCMacClient.shared.profileRejection(draft.render(), name: draft.fileName)
        }) { outcome in
            guard self.generation == request else { return }
            switch outcome {
            case .saved:
                self.doc = candidate; self.stamp = ProfileStore.stamp(candidate.fileName)
                let digest = SHA256.hash(data: Data((self.stamp?.text ?? "").utf8)).map { String(format: "%02x", $0) }.joined()
                DispatchQueue.global(qos: .userInitiated).async {
                    let result: OCMacClient.ActionResult = Self.sameSession(read(), session)
                        ? apply(candidate.fileName, session.gatewaySession, digest)
                        : .failed(1, L("VPN-сессия изменилась. Получите настройки сервера заново."))
                    DispatchQueue.main.async {
                        guard self.generation == request else { return }
                        self.busy = false
                        if case .ok = result { self.networksReviewed = true; self.step = .verify; StatusStore.shared.refresh() }
                        else { self.note = L("Настройки сохранены, но применены не полностью. Проверьте соединение и повторите.") }
                    }
                }
            case .changed:
                self.busy = false; self.note = L("Профиль изменился. Откройте его заново, чтобы сохранить актуальные настройки.")
            case .rejected(let why), .failed(let why): self.busy = false; self.note = why
            }
        }
    }

    /// Only the isolated --stage process may supply screenshot states.
    func stage(step: Int, state: String) {
        guard CommandLine.arguments.contains("--stage") else { return }
        start()
        if step == 0 && state == "empty" { return }
        doc.fileName = "setup-sample"; doc.url = state == "long" ? "vpn-europe-production-gateway.example.com/employees/engineering/backup" : "vpn.example.com/employees"
        doc.name = Self.addressName(doc.url); doc.user = "engineer@example.com"
        if step == 0 && state == "invalid" { doc.url = "not a URL"; note = L("Проверьте адрес VPN.") }
        if state == "all" { doc.routes = ["0.0.0.0/1", "128.0.0.0/1"] }
        if state == "proxy" { doc.mode = "proxy" }
        if state == "dns" { doc.zones = [ZoneLine(zone: "engineering.corp.example.com", resolver: "vpn", port: ""), ZoneLine(zone: "example.org", resolver: "10.20.0.53", port: "53")] }
        if step == 2 || step == 3 { stamp = ProfileStore.stamp(doc.fileName) }
        self.step = Step(rawValue: step) ?? .profile
        if step == 3 {
            proposedRoutes = state == "empty" ? [] : ["10.20.0.0/16", "192.168.50.0/24"]
            proposedZones = state == "empty" ? [] : [ZoneLine(zone: "corp.example.com", resolver: "vpn", port: "53")]
            serverDNS = ["10.20.0.53"]; useRoutes = !proposedRoutes.isEmpty; useDNS = !proposedZones.isEmpty
            offeredFullTunnel = state == "all"
        }
        includesSystem = step == 1
        helperReady = state == "ready"
        system = ProfileSystemState(required: true, ready: helperReady)
    }
}
