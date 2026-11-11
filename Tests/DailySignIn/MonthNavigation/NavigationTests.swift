import XCTest

final class NavigationTests: XCTestCase {
    func testRecordsMonthButtons() { checkNavigation(points: false) }
    func testPointsMonthButtons() { checkNavigation(points: true) }

    private func checkNavigation(points: Bool) {
        let app = XCUIApplication()
        if points { app.launchArguments = ["--points"] }
        app.launch()
        let value = app.staticTexts["selectedMonth"]
        XCTAssertTrue(value.waitForExistence(timeout: 10))
        let current = value.label
        app.buttons["上个月"].tap()
        expectation(for: NSPredicate(format: "label != %@", current), evaluatedWith: value)
        waitForExpectations(timeout: 5)
        let previous = value.label
        XCTAssertNotEqual(previous, current)
        // 在List行中点右箭头必须仅执行向后一个月，而非触发左箭头动作。
        app.buttons["下个月"].tap()
        expectation(for: NSPredicate(format: "label == %@", current), evaluatedWith: value)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(app.buttons["下个月"].isEnabled)
    }
}
