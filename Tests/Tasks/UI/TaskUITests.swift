import XCTest

final class TaskUITests: XCTestCase {
    func testCreateCompleteReopenPersistAndDelete() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--reset-tasks", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let create = app.buttons["tasks.create"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        create.tap()
        let title = app.textFields["tasks.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap(); title.typeText("Prepare launch checklist")
        app.buttons["tasks.save"].tap()
        let item = app.staticTexts["Prepare launch checklist"]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.tap()
        let complete = app.buttons["标记为已完成"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()
        XCTAssertTrue(app.buttons["标记为待处理"].waitForExistence(timeout: 5))
        app.buttons["标记为待处理"].tap()
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Task details after reopening"; attachment.lifetime = .keepAlways
        add(attachment)
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(item.waitForExistence(timeout: 10), "Task survives process restart")
        item.tap()
        app.buttons["编辑"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap(); title.typeText(" updated")
        app.buttons["tasks.save"].tap()
        XCTAssertTrue(app.staticTexts["Prepare launch checklist updated"].waitForExistence(timeout: 5))
        let delete = app.buttons["删除事项"]
        if !delete.isHittable { app.swipeUp() }
        delete.tap()
        app.buttons["删除"].tap()
        XCTAssertTrue(app.staticTexts["暂无符合条件的事项"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["暂无符合条件的事项"].waitForExistence(timeout: 10), "Deletion is persistent")
    }
}
