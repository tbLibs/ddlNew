import XCTest
final class GestureTests: XCTestCase {
    @MainActor func testLongDescriptionDoesNotDragHorizontally() {
        let app = XCUIApplication(); app.launch()
        app.buttons["打开用户资料"].tap()
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        scroll.swipeUp()
        let middle = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
        let left = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5))
        middle.press(forDuration: 0.05, thenDragTo: left, withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertEqual(app.staticTexts["horizontalOffset"].label, "0.000", "资料滚动容器发生横向偏移")
    }
}
