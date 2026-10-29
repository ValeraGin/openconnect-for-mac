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
            checkEqual(model.dirty, scenario == .unsaved)
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
        model.authCode = "123456"
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
        model.authCode = "123456"
        model.submitCode()
        checkNil(model.activeID)
        model.restartCode()
        checkEqual(model.authCode, "")
        model.authCode = "123456"
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
        check(model.dirty)
        checkEqual(model.authPassword, "")
        checkFalse(model.profiles[1].passwordSaved)
        model.select("work")
        model.openCredential(.credentialCode)
        model.select("home")
        model.authCode = "123456"
        model.saveCredential()
        checkFalse(model.draft!.codeSaved)
        checkFalse(model.authPresented)
    }
    static func testSingleLineValuesDoNotAcceptNewlines() {
        checkEqual(DemoModel.singleLine("https://vpn.\nexample.com"), "https://vpn.example.com")
        checkEqual(DemoModel.singleLine("long\r\nname\u{2028}end"), "longnameend")
        checkEqual(DemoModel.singleLine(String(repeating: "a", count: 200)), String(repeating: "a", count: 200))
    }
}
