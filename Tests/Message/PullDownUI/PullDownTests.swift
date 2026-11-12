import XCTest
final class PullDownTests: XCTestCase {
    func drag(_ app: XCUIApplication, from: CGVector, to: CGVector) {
        app.coordinate(withNormalizedOffset: from).press(forDuration: 0.05,
            thenDragTo: app.coordinate(withNormalizedOffset: to), withVelocity: .slow, thenHoldForDuration: 0.1)
    }
    func wait(_ element: XCUIElement, visible: Bool, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "hittable == %@", NSNumber(value: visible))
        let exp = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [exp], timeout: 4), .completed, file: file, line: line)
    }
    func testPullThresholdFullScreenAndRepeatedDismissal() {
        let app = XCUIApplication(); app.launch()
        let close = app.buttons["messagePullDown.close"]
        drag(app, from: .init(dx: 0.5, dy: 0.25), to: .init(dx: 0.5, dy: 0.32))
        wait(close, visible: false)
        for index in 0..<2 {
            drag(app, from: .init(dx: 0.5, dy: 0.25), to: .init(dx: 0.5, dy: 0.65))
            wait(close, visible: true)
            XCTAssertFalse(app.tabBars.buttons["我的"].isHittable)
            XCTAssertLessThanOrEqual(close.frame.height, 50)
            if index == 0 {
                let attachment = XCTAttachment(screenshot: app.screenshot())
                attachment.name = "Expanded top page"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            drag(app, from: .init(dx: 0.5, dy: 0.75), to: .init(dx: 0.5, dy: 0.25))
            wait(close, visible: false)
            XCTAssertTrue(app.tabBars.buttons["我的"].isHittable)
        }
        drag(app, from: .init(dx: 0.5, dy: 0.25), to: .init(dx: 0.5, dy: 0.65))
        wait(close, visible: true); close.tap(); wait(close, visible: false)
    }
    func testScrollingAwayFromTopDoesNotOpenAndRowSwipeRemains() {
        let app = XCUIApplication(); app.launch()
        drag(app, from: .init(dx: 0.5, dy: 0.75), to: .init(dx: 0.5, dy: 0.25))
        drag(app, from: .init(dx: 0.5, dy: 0.3), to: .init(dx: 0.5, dy: 0.48))
        wait(app.buttons["messagePullDown.close"], visible: false)
        let row = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '会话 '")).allElementsBoundByIndex.first {
            $0.isHittable && $0.frame.midY > app.frame.height * 0.3 && $0.frame.midY < app.frame.height * 0.7
        }
        XCTAssertNotNil(row)
        if let row {
            row.coordinate(withNormalizedOffset: .init(dx: 0.9, dy: 0.5))
                .press(forDuration: 0.05, thenDragTo:
                    row.coordinate(withNormalizedOffset: .init(dx: 0.35, dy: 0.5)))
        }
        XCTAssertTrue(app.buttons["删除"].waitForExistence(timeout: 3))
    }
}
