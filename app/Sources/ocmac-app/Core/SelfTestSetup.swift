import Foundation

extension SelfTest {
    @MainActor static func auditSetup(_ t: Tally) {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("ocmac-setup-test-\(UUID().uuidString)")
        let config = base.appendingPathComponent("config")
        try? fm.createDirectory(at: config.appendingPathComponent("profiles"), withIntermediateDirectories: true)
        let vars = ["OCMAC_CONFIG_DIR": config.path, "OCMAC_USER_STATE": base.appendingPathComponent("state").path,
                    "OCMAC_STATE_DIR": base.appendingPathComponent("root").path, "OCMAC_LOG_DIR": base.appendingPathComponent("logs").path,
                    "OCMAC_SELFTEST_HELPER": "/dev/null"]
        var original: [String: String] = [:]
        for (key, value) in vars { original[key] = ProcessInfo.processInfo.environment[key]; setenv(key, value, 1) }
        defer {
            for key in vars.keys { if let value = original[key] { setenv(key, value, 1) } else { unsetenv(key) } }
            try? fm.removeItem(at: base)
        }
        func wait(_ flow: SetupFlow) {
            let deadline = Date().addingTimeInterval(25)
            while (flow.busy || flow.checking) && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
            t.check("setup asynchronous work finishes", !flow.busy && !flow.checking)
        }
        var connections: [String] = []
        var ready = true
        let flow = SetupFlow(readiness: { _ in (ProfileSystemState(required: false, ready: true), ready) }, connect: { connections.append($0) })
        var existing = ProfileDoc(); existing.fileName = "vpn.example.com-group"; existing.name = "Existing"
        existing.url = "vpn.example.com/group"; existing.user = "existing-user"
        existing.routes = ["10.0.0.0/8"]; existing.extras = [("Custom", "Keep", "yes")]
        t.check("setup fixture writes", ProfileStore.save(existing) == nil)
        let existingText = ProfileStore.read(existing.fileName)
        flow.start()
        t.check("setup starts blank despite existing config", flow.doc.url.isEmpty && flow.doc.user.isEmpty && flow.doc.routes.isEmpty && flow.savedID == nil && flow.step == .profile)
        flow.saveAndContinue(); wait(flow)
        t.check("setup invalid address cannot advance or create config", flow.step == .profile && flow.note != nil && ProfileStore.list().count == 1)
        flow.doc.url = "vpn.example.com/group"; flow.doc.user = "new-user"; flow.doc.routes = ["10.20.0.0/16"]
        flow.saveAndContinue(); wait(flow)
        let id = flow.savedID ?? "missing"
        t.check("setup names profile from address and uses collision-safe ID", flow.doc.name == "vpn.example.com/group" && id == "vpn.example.com-group-2")
        t.check("setup saves real config before skipping prepared system", flow.step == .verify && !flow.includesSystem && ProfileStore.load(id)?.user == "new-user")
        t.check("setup preserves unrelated profile bytes", ProfileStore.read(existing.fileName) == existingText)
        t.check("setup saving never connects automatically", connections.isEmpty)
        flow.connect(); wait(flow)
        t.check("setup connects only selected saved profile", connections == [id])
        ready = false
        flow.connect(); wait(flow)
        t.check("setup rechecks readiness before connection", flow.step == .system && connections.count == 1)
        flow.continueFromSystem(); wait(flow)
        t.check("setup cannot skip missing helper", flow.step == .system)
        ready = true
        flow.continueFromSystem(); wait(flow)
        t.check("setup proceeds after preparation", flow.step == .verify)
        flow.back(); t.check("setup back visits included system step", flow.step == .system)
        flow.back(); t.check("setup back returns to profile", flow.step == .profile)
        flow.doc.user = "updated-user"; flow.saveAndContinue(); wait(flow)
        t.check("setup revisiting step updates same file", flow.savedID == id && ProfileStore.list().count == 2 && ProfileStore.load(id)?.user == "updated-user")
        let beforeConflict = (ProfileStore.read(id) ?? "") + "\n# external edit\n"
        try? beforeConflict.write(toFile: ProfileStore.path(id), atomically: true, encoding: .utf8)
        flow.connect(); wait(flow)
        t.check("setup rejects connection with stale config", connections.count == 1 && flow.note != nil)
        flow.back(); flow.doc.user = "must-not-save"; flow.saveAndContinue(); wait(flow)
        t.check("setup refuses overwrite after outside edit", flow.note != nil && ProfileStore.read(id) == beforeConflict)
        flow.start(profile: existing.fileName)
        flow.doc.user = "changed"; flow.saveAndContinue(); wait(flow)
        t.check("setup contextual flow retains unknown keys and networks", flow.savedID == existing.fileName && flow.doc.routes == existing.routes && flow.doc.extras.first?.key == "Keep")
        let proxy = SetupFlow(readiness: { doc in (ProfileSystemState(required: false, ready: true), doc.mode == "proxy") }, connect: { connections.append($0) })
        proxy.start(); proxy.doc.url = "proxy.example.com"; proxy.doc.mode = "proxy"
        proxy.saveAndContinue(); wait(proxy)
        t.check("setup SOCKS skips tunnel helper", proxy.step == .verify && !proxy.includesSystem)
        t.check("setup address label preserves port and group", SetupFlow.addressName("https://vpn.example.com:444/group") == "vpn.example.com:444/group")
        t.check("setup initial config is not selected implicitly on restart", { flow.start(); return flow.doc.url.isEmpty && flow.savedID == nil }())
    }
}
