import Foundation
import Combine

/// A new setup never borrows another profile's routes, login or file name.
@MainActor
final class SetupFlow: ObservableObject {
    static let shared = SetupFlow()
    enum Step: Int { case profile, system, verify }
    @Published var doc = ProfileDoc()
    @Published private(set) var step = Step.profile
    @Published private(set) var busy = false
    @Published private(set) var checking = false
    @Published private(set) var system: ProfileSystemState?
    @Published private(set) var helperReady = false
    @Published private(set) var includesSystem = false
    @Published var note: String?
    private var stamp: ProfileStore.DiskStamp?
    private var generation = UUID()
    private let readiness: (ProfileDoc) -> (ProfileSystemState, Bool)
    private let connectProfile: (String) -> Void
    var savedID: String? { stamp == nil ? nil : doc.fileName }
    var ready: Bool { system?.ready == true && helperReady }

    init(readiness: @escaping (ProfileDoc) -> (ProfileSystemState, Bool) = QuickProfileFlow.systemReadiness,
         connect: ((String) -> Void)? = nil) {
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
            if self.ready { self.connectProfile(savedID) }
            else { self.includesSystem = true; self.step = .system }
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
        if step == 2 { stamp = ProfileStore.stamp(doc.fileName) }
        self.step = Step(rawValue: step) ?? .profile
        includesSystem = step == 1
        helperReady = state == "ready"
        system = ProfileSystemState(required: true, ready: helperReady)
    }
}
