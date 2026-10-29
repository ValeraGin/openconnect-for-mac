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
        checkEqual(model.activeID, "home")
        model.select("work")
        checkEqual(model.selectedLink, .idle)
        model.reopen()
        checkEqual(model.selectedID, "home")
        checkEqual(model.selectedLink, .connected)
    }
}
