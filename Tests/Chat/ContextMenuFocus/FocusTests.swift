import XCTest

final class FocusTests: XCTestCase {
    @MainActor func testRepeatedCancellationClearsBothFocusStatesWhileMenuIsOpen() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        let input = app.textViews["chatMessageInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        for _ in 0..<4 {
            input.tap()
            expectation(for: NSPredicate(format: "label == %@", "focused"), evaluatedWith: app.staticTexts["focusState"])
            waitForExpectations(timeout: 5)
            app.descendants(matching: .any)["message"].firstMatch.press(forDuration: 1)
            XCTAssertTrue(app.buttons["复制"].waitForExistence(timeout: 5))
            expectation(for: NSPredicate(format: "label == %@", "unfocused"), evaluatedWith: app.staticTexts["focusState"])
            expectation(for: NSPredicate(format: "label == %@", "native-unfocused"), evaluatedWith: app.staticTexts["nativeFocus"])
            waitForExpectations(timeout: 5)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.06)).tap()
            XCTAssertFalse(app.buttons["复制"].waitForExistence(timeout: 1))
            XCTAssertEqual(app.staticTexts["focusState"].label, "unfocused")
            XCTAssertEqual(app.staticTexts["nativeFocus"].label, "native-unfocused")
            XCTAssertEqual(app.keyboards.count, 0)
            XCTAssertEqual(input.value as? String, "保留草稿")
        }
    }
    @MainActor func testBriefLongPressClearsFocus() {
        let app = XCUIApplication(); app.launch()
        let input = app.textViews["chatMessageInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        expectation(for: NSPredicate(format: "label == %@", "focused"), evaluatedWith: app.staticTexts["focusState"])
        waitForExpectations(timeout: 5)
        app.descendants(matching: .any)["message"].firstMatch.press(forDuration: 0.35)
        expectation(for: NSPredicate(format: "label == %@", "unfocused"), evaluatedWith: app.staticTexts["focusState"])
        waitForExpectations(timeout: 5)
        XCTAssertEqual(app.keyboards.count, 0)
        XCTAssertEqual(input.value as? String, "保留草稿")
    }
    @MainActor func testLongPressClearsFocusAndReplyCanRestoreIt() {
        let app = XCUIApplication(); app.launch()
        let input = app.textViews["chatMessageInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        let state = app.staticTexts["focusState"]
        let focused = NSPredicate(format: "label == %@", "focused")
        let unfocused = NSPredicate(format: "label == %@", "unfocused")
        expectation(for: focused, evaluatedWith: state); waitForExpectations(timeout: 5)
        app.descendants(matching: .any)["message"].firstMatch.press(forDuration: 1)
        XCTAssertTrue(app.buttons["复制"].waitForExistence(timeout: 5))
        expectation(for: unfocused, evaluatedWith: state); waitForExpectations(timeout: 5)
        // 不执行任何菜单动作，点击菜单外部取消；系统不得恢复旧first responder。
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.06)).tap()
        XCTAssertFalse(app.buttons["复制"].waitForExistence(timeout: 1))
        expectation(for: unfocused, evaluatedWith: state); waitForExpectations(timeout: 5)
        XCTAssertEqual(app.keyboards.count, 0, "取消长按菜单不能重新弹出键盘")
        input.tap()
        expectation(for: focused, evaluatedWith: state); waitForExpectations(timeout: 5)
        app.descendants(matching: .any)["message"].firstMatch.press(forDuration: 1)
        XCTAssertTrue(app.buttons["复制"].waitForExistence(timeout: 5))
        app.buttons["复制"].tap()
        expectation(for: unfocused, evaluatedWith: state); waitForExpectations(timeout: 5)
        XCTAssertEqual(input.value as? String, "保留草稿")
        XCTAssertEqual(app.keyboards.count, 0)
        input.tap()
        expectation(for: focused, evaluatedWith: state); waitForExpectations(timeout: 5)
        app.descendants(matching: .any)["message"].firstMatch.press(forDuration: 1)
        XCTAssertTrue(app.buttons["引用回复"].waitForExistence(timeout: 5))
        app.buttons["引用回复"].tap()
        expectation(for: focused, evaluatedWith: state); waitForExpectations(timeout: 5)
    }
}
