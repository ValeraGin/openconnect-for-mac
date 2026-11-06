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
        let csd = SetupFlow(readiness: { _ in (ProfileSystemState(required: true, ready: false), false) }, connect: { connections.append($0) })
        csd.start(profile: existing.fileName)
        var csdSaved = false
        let beforeCSD = ProfileStore.read(existing.fileName)
        csd.saveCSD(wrapper: "", script: "not a script") { csdSaved = $0 }; wait(csd)
        t.check("setup rejects malformed CSD without saving", !csdSaved && ProfileStore.read(existing.fileName) == beforeCSD)
        csd.saveCSD(wrapper: "", script: "") { csdSaved = $0 }; wait(csd)
        t.check("setup rejects empty CSD", !csdSaved && ProfileStore.read(existing.fileName) == beforeCSD)
        let script = "#!/bin/sh\n# synthetic setup fixture, never executed\nexit 0\n"
        csd.saveCSD(wrapper: "", script: script) { csdSaved = $0 }; wait(csd)
        t.check("setup saves embedded CSD to same profile", csdSaved && ProfileStore.load(existing.fileName)?.csdScriptBase64 == Data(script.utf8).base64EncodedString())
        t.check("setup CSD preserves networks and unknown keys", csd.doc.routes == existing.routes && csd.doc.extras.first?.key == "Keep")
        t.check("setup CSD returns to required system preparation without connecting", csd.step == .system && connections.count == 1)
        let changedCSD = (ProfileStore.read(existing.fileName) ?? "") + "\n# external CSD edit\n"
        try? changedCSD.write(toFile: ProfileStore.path(existing.fileName), atomically: true, encoding: .utf8)
        csd.saveCSD(wrapper: "", script: script + "# change\n") { csdSaved = $0 }; wait(csd)
        t.check("setup CSD never overwrites concurrent changes", !csdSaved && ProfileStore.read(existing.fileName) == changedCSD)
        let proxy = SetupFlow(readiness: { doc in (ProfileSystemState(required: false, ready: true), doc.mode == "proxy") }, connect: { connections.append($0) })
        proxy.start(); proxy.doc.url = "proxy.example.com"; proxy.doc.mode = "proxy"
        proxy.saveAndContinue(); wait(proxy)
        t.check("setup SOCKS skips tunnel helper", proxy.step == .verify && !proxy.includesSystem)
        t.check("setup address label preserves port and group", SetupFlow.addressName("https://vpn.example.com:444/group") == "vpn.example.com:444/group")
        var live = Status()
        live.state = .connected; live.profile = existing.fileName; live.tundev = "utun999"
        live.gatewaySession = "123 456"; live.since = Date(timeIntervalSince1970: 123)
        live.gatewayRoutes = ["10.0.0.0/8", "10.20.0.0/16", "10.20.0.0/16", "0.0.0.0/0", "bad"]
        live.dns = ["10.20.0.53"]; live.gatewayDomain = "corp.example.com"
        live.gatewayDNSMode = "split"; live.gatewayDNSSource = "split-list"; live.gatewaySplitDNS = ["corp.example.com"]
        var applies = 0
        let networks = SetupFlow(readiness: { _ in (ProfileSystemState(required: false, ready: true), true) }, connect: { _ in },
                                 status: { live }, apply: { profile, session, digest in
            applies += 1
            t.check("setup applies exact session and file digest", profile == existing.fileName && session == "123 456" && digest.count == 64)
            return .ok("")
        })
        networks.start(profile: existing.fileName)
        let originalProfile = ProfileStore.read(existing.fileName)
        var other = live; other.profile = "unrelated"
        networks.review(other)
        t.check("setup ignores another profile's suggestions", networks.step == .profile)
        networks.review(live)
        t.check("setup filters invalid, duplicate, existing and default routes", networks.proposedRoutes == ["10.20.0.0/16"] && networks.offeredFullTunnel && !networks.fullTunnel)
        t.check("setup gateway DNS uses vpn resolver", networks.proposedZones.first?.resolver == "vpn")
        t.check("setup offers do not write or apply", ProfileStore.read(existing.fileName) == originalProfile && applies == 0)
        networks.skipNetworks()
        t.check("setup skip leaves profile and runtime untouched", ProfileStore.read(existing.fileName) == originalProfile && applies == 0)
        networks.review(live); networks.useDNS = false
        networks.applyNetworks(); wait(networks)
        t.check("setup saves approved routes and applies to live session", applies == 1 && ProfileStore.load(existing.fileName)?.routeNets == ["10.0.0.0/8", "10.20.0.0/16"])
        t.check("setup unchecked DNS and unknown keys preserved", ProfileStore.load(existing.fileName)?.zones.isEmpty == true && ProfileStore.load(existing.fileName)?.extras.first?.key == "Keep")
        networks.review(live); networks.useRoutes = false
        networks.applyNetworks(); wait(networks)
        t.check("setup selected DNS saves domain and gateway resolver", applies == 2 && ProfileStore.load(existing.fileName)?.zones.first?.resolver == "vpn")
        networks.review(live)
        t.check("setup existing DNS is not proposed again", networks.proposedZones.isEmpty)
        let beforeStale = ProfileStore.read(existing.fileName)
        live.gatewaySession = "new session"; networks.fullTunnel = true
        networks.applyNetworks(); wait(networks)
        t.check("setup stale session cannot save or apply", applies == 2 && ProfileStore.read(existing.fileName) == beforeStale && networks.note != nil)
        networks.review(live)
        let external = beforeStale! + "\n# changed during server review\n"
        try? external.write(toFile: ProfileStore.path(existing.fileName), atomically: true, encoding: .utf8)
        networks.applyNetworks(); wait(networks)
        t.check("setup review detects concurrent profile edit", applies == 2 && ProfileStore.read(existing.fileName) == external)
        live.gatewayDomain = ""; live.gatewayRoutes = []; networks.review(live)
        t.check("setup does not infer DNS domain from VPN address", networks.proposedZones.isEmpty && networks.serverDNS == ["10.20.0.53"])
        live.gatewayDomain = "search.example.com"; live.gatewaySplitDNS = []; live.gatewayDNSMode = "all"
        networks.review(live)
        let allDNS = networks.networkCandidate()
        t.check("setup search suffix never becomes split restriction", networks.proposedZones.isEmpty && allDNS.dnsMode == "all" && allDNS.dnsSearchDomain == "search.example.com")
        t.check("setup all DNS preserves explicit overrides", allDNS.zones.count == networks.doc.zones.count)
        let roundtrip = ProfileDoc.parse(allDNS.render(), fileName: allDNS.fileName)
        t.check("DNS policy roundtrips", roundtrip.dnsMode == "all" && roundtrip.dnsSearchDomain == "search.example.com")
        live.gatewayDNSMode = ""; live.gatewayDNSSource = ""; networks.review(live)
        t.check("old session never silently proposes global DNS", !networks.useDNS && networks.proposedZones.isEmpty)
        networks.useDNS = true; networks.proposedDNSMode = "all"
        t.check("old session permits explicit all DNS selection", networks.networkCandidate().dnsMode == "all")
        live.dns = []; networks.review(live)
        t.check("missing DNS cannot enable policy", !networks.useDNS)
        let parsed = Status.parse(json: "{\"gateway_routes\":[\"10.20.0.0/16\"],\"gateway_domain\":\"corp.example.com\",\"gateway_session\":\"123 456\"}")
        t.check("setup status wire carries real gateway suggestions", parsed?.gatewayRoutes == ["10.20.0.0/16"] && parsed?.gatewayDomain == "corp.example.com" && parsed?.gatewaySession == "123 456")
        t.check("setup initial config is not selected implicitly on restart", { flow.start(); return flow.doc.url.isEmpty && flow.savedID == nil }())
    }
}
