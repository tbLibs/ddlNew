import XCTest

final class PanelTests: XCTestCase {
    func testRecentEmojiSurvivesPanelRecreationAndAppRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-recents"]
        app.launch()
        let selected = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "[脸红]"))
        XCTAssertTrue(selected.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(selected.count, 1)
        selected.firstMatch.tap()
        XCTAssertEqual(selected.count, 2, "选中后出现在最近使用及全部表情")
        app.buttons["收起表情"].tap()
        app.buttons["打开表情"].tap()
        XCTAssertTrue(app.buttons["收起表情"].waitForExistence(timeout: 5))
        XCTAssertTrue(selected.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(selected.count, 2, "重新打开面板仍应保留最近使用")
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(selected.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(selected.count, 2, "重新启动应用仍应保留最近使用")
    }
}
