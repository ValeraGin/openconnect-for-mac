import Foundation

private var checks = 0
private var failures = 0
private func check(_ value: Bool, file: StaticString = #file, line: UInt = #line) {
    checks += 1
    if !value { failures += 1; print("FAIL \(file):\(line)") }
}
private func checkEqual<T: Equatable>(_ a: T, _ b: T, file: StaticString = #file, line: UInt = #line) { check(a == b, file: file, line: line) }
private func checkNotEqual<T: Equatable>(_ a: T, _ b: T, file: StaticString = #file, line: UInt = #line) { check(a != b, file: file, line: line) }
private func checkFalse(_ a: Bool, file: StaticString = #file, line: UInt = #line) { check(!a, file: file, line: line) }
private func checkNil<T>(_ a: T?, file: StaticString = #file, line: UInt = #line) { check(a == nil, file: file, line: line) }

@main struct ModelTests {
    static func main() {
        testOpeningPrefersActiveThenLastThenExistingFallback()
        testDirtyProfileDoesNotDisappearOnSelection()
        testInvalidDraftCannotBeSavedOrConnected()
        testReopenAndDiscardFlows()
        testAllFixturesHaveConsistentSelectionAndActiveProfile()
        testConnectionErrorBelongsToItsOwnProfile()
        testSignInRequiresPasswordAndCode()
        testCancelledSwitchPreservesActiveConnection()
        testCredentialEditorChangesOnlyItsOwnDraft()
        testSingleLineValuesDoNotAcceptNewlines()
        testAddressFallbackAndTOTPSetup()
        testExtendedCapabilities()
        testEightDigitTOTP()
        testReviewStateConsistency()
        testSetupFlow()
        print("\(checks - failures) passed; \(failures) failed")
        exit(failures == 0 ? 0 : 1)
    }
    static func testOpeningPrefersActiveThenLastThenExistingFallback() {
        checkEqual(DemoModel.initialSelection(ids: ["a", "b", "c"], active: "c", last: "b"), "c")
        checkEqual(DemoModel.initialSelection(ids: ["a", "b"], active: nil, last: "b"), "b")
        checkEqual(DemoModel.initialSelection(ids: ["a", "b"], active: "deleted", last: "b"), "b")
        checkEqual(DemoModel.initialSelection(ids: ["a"], active: nil, last: "deleted"), "a")
        checkNil(DemoModel.initialSelection(ids: [], active: "deleted", last: "deleted"))
    }
    static func testDirtyProfileDoesNotDisappearOnSelection() {
        let model = DemoModel()
        model.draft?.user = "changed"
        model.requestSelection("home")
        check(model.showUnsaved)
        checkEqual(model.selectedID, "work")
        checkEqual(model.draft?.user, "changed")
        check(model.save())
        checkEqual(model.selectedID, "home")
        checkEqual(model.profiles.first?.user, "changed")
    }
    static func testInvalidDraftCannotBeSavedOrConnected() {
        let model = DemoModel()
        model.draft?.server = "http://invalid.example"
        checkFalse(model.save())
        model.toggleConnection()
        checkNil(model.activeID)
        checkEqual(model.profiles.first?.server, "https://vpn.example.com")
        model.draft?.server = "https://valid.example"
        model.draft?.route = .proxy
        model.draft?.port = "65536"
        checkFalse(model.save())
    }
    static func testReopenAndDiscardFlows() {
        let model = DemoModel()
        model.select("home")
        model.reopen()
        checkEqual(model.selectedID, "home")
        model.activeID = "lab"
        model.reopen()
        checkEqual(model.selectedID, "lab")
        model.draft?.name = "edited"
        model.requestSelection("work")
        model.discardAndSelect()
        checkEqual(model.selectedID, "work")
        checkNotEqual(model.profiles.last?.name, "edited")
    }
    static func testAllFixturesHaveConsistentSelectionAndActiveProfile() {
        let model = DemoModel()
        for scenario in Scenario.allCases {
            model.load(scenario)
            checkEqual(model.profiles.isEmpty, model.selectedID == nil)
            if let active = model.activeID { check(model.profiles.contains { $0.id == active }) }
            checkEqual(model.dirty, scenario == .unsaved || scenario == .diskConflict)
        }
    }
    static func testConnectionErrorBelongsToItsOwnProfile() {
        let model = DemoModel()
        model.load(.error)
        checkEqual(model.selectedLink, .failed)
        model.select("home")
        checkEqual(model.selectedLink, .idle)
        model.toggleConnection()
        checkEqual(model.selectedLink, .signIn)
        model.continueSSO()
        model.authPassword = "demo"
        model.submitPassword()
        model.authCode = "287082"
        model.submitCode()
        checkEqual(model.activeID, "home")
        model.select("work")
        checkEqual(model.selectedLink, .idle)
        model.reopen()
        checkEqual(model.selectedID, "home")
        checkEqual(model.selectedLink, .connected)
    }

    static func testSignInRequiresPasswordAndCode() {
        let model = DemoModel()
        model.beginSignIn()
        check(model.authPresented)
        checkEqual(model.authStage, .sso)
        checkNil(model.activeID)
        model.submitCode()
        checkNil(model.activeID)
        model.continueSSO()
        model.authPassword = "wrong"
        model.toggleConnection()
        checkEqual(model.authPassword, "wrong")
        checkEqual(model.authStage, .password)
        model.submitPassword()
        check(model.authError)
        checkEqual(model.authStage, .password)
        model.authPassword = "demo"
        model.submitPassword()
        checkFalse(model.authError)
        checkEqual(model.authStage, .code)
        checkEqual(model.authPassword, "")
        model.authCode = "000000"
        model.submitCode()
        check(model.authError)
        checkNil(model.activeID)
        model.authStage = .expired
        model.authCode = "287082"
        model.submitCode()
        checkNil(model.activeID)
        model.restartCode()
        checkEqual(model.authCode, "")
        model.authCode = "287082"
        model.select("home")
        model.submitCode()
        checkEqual(model.activeID, "work")
        checkEqual(model.authStage, .success)
        checkEqual(model.authCode, "")
        model.cancelSignIn()
        checkEqual(model.activeID, "work")
        checkFalse(model.authPresented)
    }
    static func testCancelledSwitchPreservesActiveConnection() {
        let model = DemoModel()
        model.load(.connected)
        model.select("home")
        model.beginSignIn()
        checkEqual(model.activeID, "work")
        model.authPassword = "sample"
        model.cancelSignIn()
        checkEqual(model.activeID, "work")
        checkEqual(model.authPassword, "")
        checkEqual(model.selectedLink, .idle)
        model.draft?.name = "unsaved"
        model.beginSignIn()
        checkFalse(model.authPresented)
    }
    static func testCredentialEditorChangesOnlyItsOwnDraft() {
        let model = DemoModel()
        model.select("home")
        model.openCredential(.credentialPassword)
        model.authPassword = "wrong"
        model.saveCredential()
        check(model.authError)
        checkFalse(model.draft!.passwordSaved)
        model.authPassword = "demo"
        model.saveCredential()
        check(model.draft!.passwordSaved)
        checkFalse(model.dirty)
        checkEqual(model.authPassword, "")
        check(model.profiles[1].passwordSaved)
        model.select("work")
        model.openCredential(.credentialCode)
        model.select("home")
        model.authCode = "287082"
        model.saveCredential()
        checkFalse(model.draft!.codeSaved)
        checkFalse(model.authPresented)
    }
    static func testSingleLineValuesDoNotAcceptNewlines() {
        checkEqual(DemoModel.singleCode("123456"), "123456")
        checkEqual(DemoModel.singleCode("7890 12a3"), "789012")
        checkEqual(DemoModel.singleLine("https://vpn.\nexample.com"), "https://vpn.example.com")
        checkEqual(DemoModel.singleLine("long\r\nname\u{2028}end"), "longnameend")
        checkEqual(DemoModel.singleLine(String(repeating: "a", count: 200)), String(repeating: "a", count: 200))
    }
    static func testAddressFallbackAndTOTPSetup() {
        let model = DemoModel()
        model.load(.addressOnly)
        checkEqual(model.draft?.displayName, "vpn.example.com")
        check(model.valid)
        let id = model.selectedID
        model.draft?.server = "vpn.example.com/team"
        check(model.valid)
        checkEqual(model.draft?.displayName, "vpn.example.com/team")
        checkEqual(model.selectedID, id)
        model.draft?.name = "Custom"
        checkEqual(model.draft?.displayName, "Custom")
        model.load(.signInCode)
        model.authCode = DemoModel.sampleCode
        model.submitCode()
        checkEqual(model.authStage, .rememberCode)
        checkFalse(model.profiles[0].codeSaved)
        model.configureTOTPAfterSignIn()
        model.authSecret = DemoModel.sampleCode
        model.saveCredential()
        check(model.authError)
        checkFalse(model.profiles[0].codeSaved)
        model.authSecret = DemoModel.sampleSecret
        model.saveCredential()
        check(model.profiles[0].codeSaved)
        checkEqual(model.authStage, .success)
        checkEqual(model.authSecret, "")
        model.load(.smsCode)
        checkFalse(model.canOfferTOTP)
        model.authCode = DemoModel.sampleCode
        model.submitCode()
        checkEqual(model.authStage, .success)
        checkFalse(model.profiles[0].codeSaved)
        model.load(.totpSetup)
        model.authSecret = "otpauth://hotp/test?secret=" + DemoModel.sampleSecret
        checkFalse(model.secretMatchesRecordedCode())
        model.authSecret = "otpauth://totp/test?secret=" + DemoModel.sampleSecret
        check(model.secretMatchesRecordedCode())
        model.recordedCode = "000000"
        checkFalse(model.secretMatchesRecordedCode())
        model.openCredential(.credentialCode)
        checkEqual(model.recordedCode, "")
    }

    static func testExtendedCapabilities() {
        let model = DemoModel()
        model.load(.connected)
        let saved = model.profiles
        model.togglePause()
        checkEqual(model.selectedLink, .paused)
        checkEqual(model.activeID, "work")
        checkEqual(model.profiles, saved)
        model.togglePause()
        checkEqual(model.selectedLink, .connected)
        model.select("lab")
        model.togglePause()
        checkNil(model.pausedID)
        model.activeID = "home"
        checkEqual(model.runtimeRoutes, ["0.0.0.0/1", "128.0.0.0/1"])
        model.load(.dnsCustom)
        check(model.valid)
        model.draft?.zones[1].port = "65536"
        checkFalse(model.save())
        model.draft?.zones[1].port = "5353"
        model.draft?.zones[1].resolver = "not-an-ip"
        checkFalse(model.valid)
        model.draft?.zones[1].resolver = "10.20.0.53"
        check(model.save())
        checkEqual(model.profiles[0].zones[1].port, "5353")
        model.load(.commandSource)
        check(model.valid)
        model.draft?.options.passwordCommand = ""
        checkFalse(model.valid)
        model.load(.keepass)
        check(model.valid)
        model.draft?.options.keepassDB = ""
        checkFalse(model.valid)
        model.load(.diskConflict)
        checkFalse(model.save())
        check(model.confirmOverwrite)
        checkEqual(model.profiles[0].user, "alex")
        model.resolveConflict(reload: true)
        checkFalse(model.dirty)
        model.load(.diskConflict)
        model.resolveConflict(reload: false)
        checkEqual(model.profiles[0].user, "alex.updated")
        checkFalse(model.conflict)
        model.load(.rulesLearn)
        model.finishLearning()
        checkEqual(model.draft?.options.rules, "")
        model.learningSelections = ["username", "password", "totp"]
        model.finishLearning()
        check(model.dirty)
        check(model.draft!.options.rules.contains("fill totp"))
        check(model.save())
        model.load(.importPreview)
        let count = model.profiles.count
        model.importSample()
        checkEqual(model.profiles.count, count)
        model.selectedQR = "lab"
        model.importTrusted = true
        model.importSample()
        checkEqual(model.profiles.count, count + 1)
        checkEqual(model.draft?.displayName, "branch.example.com")
        let selected = model.selectedID
        model.moveProfile(selected!, by: -1)
        checkEqual(model.selectedID, selected)
        checkEqual(model.profiles[count - 1].id, selected)
        model.navigate(.logs)
        model.logFilter = "does-not-exist"
        check(model.logLines.isEmpty)
        model.logFilter = "DNS"
        checkEqual(model.logLines.count, 1)
        checkFalse(model.profilePreview.contains(DemoModel.sampleSecret))
        model.load(.helperMissing)
        checkFalse(model.canStartConnection)
        model.beginSignIn()
        checkFalse(model.authPresented)
        model.select("lab")
        check(model.canStartConnection)
        model.load(.empty)
        model.navigate(.setup)
        checkEqual(model.draft?.server, "")
        checkEqual(model.page, .general)
    }
    static func testEightDigitTOTP() {
        let model = DemoModel()
        model.draft?.options.digits = "8"
        model.draft?.codeSaved = false
        check(model.save())
        model.beginSignIn()
        checkEqual(model.expectedCode.count, 8)
        checkEqual(DemoModel.singleCode("123456789", digits: 8), "12345678")
        model.continueSSO()
        model.authPassword = "demo"
        model.submitPassword()
        model.authCode = model.expectedCode
        model.submitCode()
        checkEqual(model.authStage, .rememberCode)
        model.configureTOTPAfterSignIn()
        model.authSecret = DemoModel.sampleSecret
        check(model.secretMatchesRecordedCode())
        model.saveCredential()
        checkEqual(model.authStage, .success)
        model.load(.commandSource)
        model.beginSignIn()
        checkFalse(model.canOfferTOTP)
    }

    static func testReviewStateConsistency() {
        let model = DemoModel()
        for language in Language.allCases {
            model.language = language
            model.load(.missing)
            checkEqual(model.draft?.displayName, "—")
            checkEqual(model.profileTitle(model.draft!), language == .ru ? "Новый профиль" : "New profile")
            model.load(.paused)
            check(model.profileMenuTitle(model.draft!).hasSuffix(language == .ru ? " • пауза" : " • paused"))
            model.load(.commandSource)
            checkEqual(model.sourceTitle("command"), language == .ru ? "Команда" : "Command")
            checkEqual(model.sourceTitle("keepassxc"), "KeePassXC")
        }
        model.load(.totpEight)
        checkEqual(model.selectedDemoCode, "94287082")
        checkEqual(model.selectedDemoCode, model.expectedCode)
        model.load(.connected)
        let saved = model.activeProfile
        model.applyReviewVariant("runtime-edited")
        checkEqual(model.activeProfile, saved)
        checkEqual(model.runtimeRoutes, ["10.20.0.0/16", "192.168.50.0/24"])
        model.togglePause()
        checkEqual(model.pausedID, model.selectedID)
        model.load(.idle)
        model.conflict = true
        checkFalse(model.canStartConnection)
        model.load(.credentialCode)
        model.applyReviewVariant("secret-error")
        check(model.authError)
        model.load(.signInCode)
        model.applyReviewVariant("code-error")
        check(model.authError)
        checkNil(model.activeID)
        model.load(.rulesLearn)
        model.applyReviewVariant("second-step")
        checkEqual(model.learningStep, 1)
        model.applyReviewVariant("mapped")
        check(model.dirty)
        checkEqual(model.detail, .rules)
    }

    static func testSetupFlow() {
        let model = DemoModel()
        model.load(.empty)
        model.startSetup()
        checkEqual(model.setupStep, 0)
        checkEqual(model.detail, .setup)
        model.advanceSetup()
        checkEqual(model.setupStep, 0)
        check(model.showValidation)
        model.draft?.server = "vpn.example.com"
        model.advanceSetup()
        checkEqual(model.setupStep, 2)
        checkFalse(model.dirty)
        checkFalse(model.setupNeedsSystemStep)
        model.setupResource = "https://intranet.example.com"
        model.checkSetupAccess()
        checkFalse(model.accessChecked)
        model.beginSignIn(); model.authUsername = "demo"; model.continueSSO()
        model.authPassword = "demo"; model.submitPassword()
        model.authCode = model.expectedCode; model.submitCode()
        checkEqual(model.selectedLink, .connected)
        model.checkSetupAccess()
        check(model.accessChecked)
        model.setupResource = "file:///tmp/test"
        model.checkSetupAccess()
        checkFalse(model.accessChecked)
        model.setupResource = "https://intranet.example.com"
        model.togglePause()
        checkFalse(model.canCheckSetupAccess)
        model.closeSetup()
        checkEqual(model.page, .connection)
        checkNil(model.detail)
        model.load(.helperMissing)
        model.page = .connection
        model.startSetup(resume: true)
        checkEqual(model.setupStep, 1)
        model.advanceSetup()
        checkEqual(model.setupStep, 1)
        model.helperReady = true
        model.advanceSetup()
        checkEqual(model.setupStep, 2)
        model.backSetup()
        checkEqual(model.setupStep, 1)
        model.backSetup()
        checkEqual(model.setupStep, 0)
        model.helperReady = false
        model.draft?.route = .proxy
        model.advanceSetup()
        checkEqual(model.setupStep, 2)
        checkFalse(model.setupNeedsSystemStep)
        model.backSetup()
        checkEqual(model.setupStep, 0)
        model.load(.unsaved)
        let draft = model.draft
        model.startSetup(resume: true)
        checkEqual(model.setupStep, 0)
        checkEqual(model.draft, draft)
        model.load(.diskConflict)
        model.startSetup()
        model.advanceSetup()
        checkEqual(model.setupStep, 0)
        check(model.confirmOverwrite)
        model.load(.idle)
        model.page = .general
        model.startSetup()
        model.closeSetup()
        checkEqual(model.page, .general)
    }

}
