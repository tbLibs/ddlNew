import XCTest

final class PageTests: XCTestCase {
    func testTodayAndSignedCalendarMarkers() {
        checkCalendar(signed: true)
    }
    func testTodayWithoutSignIn() {
        checkCalendar(signed: false)
    }
    private func checkCalendar(signed: Bool) {
        let app = XCUIApplication()
        if signed { app.launchArguments = ["--signed-today"] }
        app.launch(); app.buttons["测试每日签到"].tap()
        XCTAssertTrue(app.staticTexts["dailySignIn.currentDate"].waitForExistence(timeout: 5))
        app.swipeUp()
        let calendar = Calendar(identifier: .gregorian), now = Date()
        func cell(_ date: Date) -> XCUIElement {
            let p = calendar.dateComponents([.year, .month, .day], from: date)
            return app.descendants(matching: .any).matching(identifier: "dailySignIn.calendar.\(p.year!)-\(p.month!)-\(p.day!)").firstMatch
        }
        let today = cell(now)
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        XCTAssertEqual(today.value as? String, signed ? "今天，已签到" : "今天")
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        XCTAssertTrue(cell(start).exists, "首周日期不能与星期标题ID冲突而丢失")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.lifetime = .keepAlways; add(shot)
        app.buttons["上个月"].tap()
        XCTAssertFalse(today.exists, "历史月份不能标记为今天")
        if signed {
            let previous = calendar.date(byAdding: .month, value: -1, to: now)!
            XCTAssertEqual(cell(previous).value as? String, "已签到")
        }
    }
    private func open(_ app: XCUIApplication, _ title: String) {
        let button = app.buttons[title]
        for _ in 0..<5 {
            if button.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(button.isHittable, title)
        button.tap()
    }
    private func back(_ app: XCUIApplication) { app.navigationBars.buttons.element(boundBy: 0).tap() }

    func testPushCurrentDateAndReturnFromHistory() {
        let app = XCUIApplication(); app.launch()
        app.buttons["测试每日签到"].tap()
        let date = app.staticTexts["dailySignIn.currentDate"]
        XCTAssertTrue(date.waitForExistence(timeout: 5))
        let expected = Date().formatted(.dateTime.year().month().day().weekday(.wide).locale(Locale(identifier: "zh-Hans")))
        // LabeledContent combines its title and value for accessibility.
        XCTAssertTrue(date.label.hasSuffix(expected), date.label)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.lifetime = .keepAlways; add(shot)
        XCTAssertFalse(app.buttons["关闭"].exists)
        for page in ["签到记录", "积分明细"] {
            open(app, page)
            XCTAssertTrue(app.navigationBars[page].waitForExistence(timeout: 5))
            app.buttons["上个月"].tap()
            app.buttons["下个月"].tap()
            back(app)
            XCTAssertTrue(app.buttons["立即签到"].exists, "push子页不能关闭共享Store")
        }
        back(app)
        XCTAssertTrue(app.buttons["测试每日签到"].waitForExistence(timeout: 5))
        app.buttons["测试每日签到"].tap()
        XCTAssertTrue(date.waitForExistence(timeout: 5), "退出后重新push可重新加载")
    }

    func testRandomRules() {
        let app = XCUIApplication(); app.launch()
        app.buttons["测试每日签到"].tap()
        open(app, "签到规则")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "例如区间值100～200")).firstMatch.waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.lifetime = .keepAlways; add(shot)
    }

    func testReminderPushAndContinuousRules() {
        let app = XCUIApplication(); app.launchArguments = ["--continuous"]; app.launch()
        app.buttons["测试签到助手"].tap()
        XCTAssertTrue(app.navigationBars["签到助手"].waitForExistence(timeout: 5))
        app.buttons["去签到"].tap()
        open(app, "签到规则")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "固定日签积分(10分)")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["当月连续签到成功天数"].exists)
        XCTAssertTrue(app.staticTexts["奖励积分"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.lifetime = .keepAlways; add(shot)
        back(app); back(app)
        XCTAssertTrue(app.navigationBars["签到助手"].waitForExistence(timeout: 5))
    }
}
