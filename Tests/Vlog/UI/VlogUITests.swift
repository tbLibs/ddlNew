import XCTest
final class VlogUITests: XCTestCase {
    private func tab(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        let matches = app.buttons.matching(identifier: name)
        return matches.allElementsBoundByIndex.first { $0.isHittable } ?? matches.firstMatch
    }
    func testLibraryPreviewShareEntryRestartAndDelete() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--reset-vlog", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["Vlog"].firstMatch.waitForExistence(timeout: 10))
        for name in ["消息", "通讯录", "Vlog", "事项", "我的"] { XCTAssertTrue(app.buttons[name].firstMatch.exists) }
        XCTAssertTrue(tab(app, "消息").isSelected)
        tab(app, "Vlog").tap()
        XCTAssertTrue(app.buttons["照片作品"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["视频作品"].waitForExistence(timeout: 20))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Vlog library"; attachment.lifetime = .keepAlways; add(attachment)
        app.buttons["照片作品"].tap()
        XCTAssertTrue(app.buttons["vlog.share"].waitForExistence(timeout: 5))
        app.buttons["vlog.share"].tap()
        XCTAssertTrue(app.navigationBars["选择接收人"].waitForExistence(timeout: 5))
        app.buttons["取消"].tap()
        app.buttons["vlog.delete"].tap(); app.alerts.buttons["取消"].tap()
        XCTAssertTrue(app.buttons["vlog.share"].exists)
        app.buttons["vlog.delete"].tap(); app.alerts.buttons["删除"].tap()
        XCTAssertTrue(app.buttons["视频作品"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["照片作品"].exists)
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); tab(app, "Vlog").tap()
        XCTAssertTrue(app.buttons["视频作品"].waitForExistence(timeout: 10))
        app.buttons["视频作品"].tap()
        XCTAssertTrue(app.buttons["播放视频"].waitForExistence(timeout: 5))
        app.buttons["播放视频"].tap()
        XCTAssertFalse(app.staticTexts["视频无法播放，请检查文件是否完整。"].exists)
        app.buttons["vlog.delete"].tap(); app.alerts.buttons["删除"].tap()
        XCTAssertTrue(app.staticTexts["还没有作品"].waitForExistence(timeout: 5))
    }
}
