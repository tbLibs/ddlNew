import XCTest
final class EntryTests: XCTestCase {
    func testRepeatedEntryDisplaysActualLatestMessage() {
        let app = XCUIApplication(); app.launch()
        for _ in 0..<3 {
            app.buttons["打开测试群"].tap()
            let latest = app.staticTexts["message-99"]
            let visible = NSPredicate(format: "exists == true AND hittable == true")
            expectation(for: visible, evaluatedWith: latest)
            waitForExpectations(timeout: 3)
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }
}
