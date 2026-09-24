import XCTest

@MainActor
final class MemberJourneyTests: XCTestCase {
    func testProfileSecondaryNavigationHasOneBar() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["CLUB_UI_TEST_DATABASE_ID"] = UUID().uuidString
        app.launch()
        enter("10001", in: app.textFields["field.shield"])
        app.buttons["connectClub"].tap()
        XCTAssertTrue(app.textFields["field.person"].waitForExistence(timeout: 5))
        enter("YS20260018", in: app.textFields["field.person"])
        enter("123456", in: app.secureTextFields["field.lock"])
        app.buttons["login"].tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        selectTab("我的", in: app)

        let records = app.buttons.containing(.staticText, identifier: "我的报名").firstMatch
        XCTAssertTrue(records.waitForExistence(timeout: 5))
        records.tap()
        screenshot("我的报名-导航栏", app)
        XCTAssertEqual(app.navigationBars.count, 1, app.navigationBars.debugDescription)
        XCTAssertTrue(app.navigationBars["我的报名"].exists)
        app.navigationBars.buttons.firstMatch.tap()

        app.buttons["打开设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.navigationBars.count, 1, app.navigationBars.debugDescription)
        app.buttons["deleteAccountEntry"].tap()
        screenshot("注销账号-导航栏", app)
        XCTAssertTrue(app.navigationBars["注销账号"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.navigationBars.count, 1, app.navigationBars.debugDescription)
        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons["完成"].tap()

        let more = app.tabBars.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "更多", "More")).firstMatch
        more.tap()
        let moreNavigation = app.navigationBars.matching(NSPredicate(format: "identifier == %@ OR identifier == %@", "更多", "More")).firstMatch
        XCTAssertTrue(moreNavigation.waitForExistence(timeout: 5))
        XCTAssertTrue(app.tables.cells.containing(.staticText, identifier: "我的").firstMatch.exists)
    }

    func testLegalDocumentsBeforeLogin() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["CLUB_UI_TEST_DATABASE_ID"] = UUID().uuidString
        app.launch()
        let privacy = app.buttons["openPrivacyPolicy"]
        XCTAssertTrue(privacy.waitForExistence(timeout: 10))
        if !privacy.isHittable { app.swipeUp() }
        privacy.tap()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.webViews.staticTexts["1. 本机处理的信息"].waitForExistence(timeout: 8))
        app.navigationBars.buttons["完成"].tap()
        app.buttons["openSupport"].tap()
        XCTAssertTrue(app.webViews.staticTexts["常见问题"].waitForExistence(timeout: 8))
        app.navigationBars.buttons["完成"].tap()
        XCTAssertTrue(app.buttons["connectClub"].exists)
    }

    func testInvitationKeyboardDismissalAndConnection() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["CLUB_UI_TEST_DATABASE_ID"] = UUID().uuidString
        app.launch()
        let field = app.textFields["field.shield"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        enter("100", in: field)
        let done = app.buttons["keyboardDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        app.buttons["connectClub"].tap()
        XCTAssertTrue(app.staticTexts["未找到对应的俱乐部"].waitForExistence(timeout: 5))
        replace("1234567890", in: field)
        XCTAssertEqual(field.value as? String, "1234567890")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        done.tap()
        app.buttons["connectClub"].tap()
        XCTAssertTrue(app.staticTexts["未找到对应的俱乐部"].waitForExistence(timeout: 5))
        replace("10001", in: field)
        XCTAssertEqual(field.value as? String, "10001")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        done.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["connectClub"].isEnabled)
        XCTAssertTrue(app.buttons["connectClub"].isHittable)
        screenshot("邀请码-键盘收起后", app)
        app.buttons["connectClub"].tap()
        XCTAssertTrue(app.textFields["field.person"].waitForExistence(timeout: 5))
    }

    func testMembershipJourneyAndPersistence() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["CLUB_UI_TEST_DATABASE_ID"] = UUID().uuidString
        app.launch()

        let invite = app.textFields["field.shield"]
        XCTAssertTrue(invite.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["connectClub"].isEnabled)
        screenshot("01-邀请码", app)
        enter("000000", in: invite)
        app.buttons["connectClub"].tap()
        XCTAssertTrue(app.staticTexts["未找到对应的俱乐部"].waitForExistence(timeout: 5))
        screenshot("02-邀请码错误", app)
        replace("10001", in: invite)
        app.buttons["connectClub"].tap()

        let card = app.textFields["field.person"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        screenshot("03-会员登录", app)
        enter("YS20260018", in: card)
        XCTAssertEqual(card.value as? String, "YS20260018")
        dismissKeyboard(in: app)
        enter("wrong", in: app.secureTextFields["field.lock"])
        dismissKeyboard(in: app)
        app.buttons["login"].tap()
        XCTAssertTrue(app.staticTexts["会员卡号或密码不正确，请重新输入。"].waitForExistence(timeout: 5))
        enter("123456", in: app.secureTextFields["field.lock"])
        app.buttons["login"].tap()
        XCTAssertTrue(app.staticTexts["林夏，欢迎回来"].waitForExistence(timeout: 8))
        screenshot("04-首页", app)

        selectTab("活动", in: app)
        XCTAssertTrue(app.buttons["activity.hike"].waitForExistence(timeout: 5))
        let search = app.textFields["activitySearch"]
        enter("park", in: search)
        dismissKeyboard(in: app)
        XCTAssertEqual(search.value as? String, "park")
        app.buttons["清除"].tap()
        screenshot("05-活动列表", app)
        app.buttons["可报名"].tap()
        app.buttons["activity.hike"].tap()
        XCTAssertTrue(app.buttons["立即报名"].waitForExistence(timeout: 5))
        screenshot("06-活动详情", app)
        app.buttons["立即报名"].tap()
        let confirm = app.buttons["confirmRegistration"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertFalse(confirm.isEnabled)
        screenshot("07-报名确认", app)
        app.switches["acceptRules"].tap()
        confirm.tap()
        XCTAssertTrue(app.staticTexts["报名成功"].waitForExistence(timeout: 5))
        screenshot("08-报名成功", app)
        app.buttons["viewParticipation"].tap()
        app.buttons["前往签到"].tap()
        let checkIn = app.textFields["checkInCode"]
        XCTAssertTrue(checkIn.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["confirmCheckIn"].isEnabled)
        enter("00", in: checkIn)
        dismissKeyboard(in: app)
        XCTAssertEqual(checkIn.value as? String, "00")
        enter("00", in: checkIn)
        app.buttons["confirmCheckIn"].tap()
        XCTAssertTrue(app.staticTexts["签到码不正确"].waitForExistence(timeout: 5))
        replace("6812", in: checkIn)
        screenshot("09-签到", app)
        app.buttons["confirmCheckIn"].tap()
        XCTAssertTrue(app.staticTexts["签到成功"].waitForExistence(timeout: 5))
        screenshot("10-签到成功", app)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["林夏，欢迎回来"].waitForExistence(timeout: 8))
        selectTab("活动", in: app)
        app.buttons["activity.hike"].tap()
        XCTAssertTrue(app.buttons["已完成签到"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["已完成签到"].isEnabled)
        app.navigationBars.buttons.firstMatch.tap()

        // Cancel the initial waiting record, then join the full activity again.
        app.buttons["activity.bird"].tap()
        app.swipeUp()
        app.buttons["取消候补"].tap()
        app.alerts.buttons["确认取消"].tap()
        XCTAssertTrue(app.buttons["加入候补"].waitForExistence(timeout: 5))
        app.buttons["加入候补"].tap()
        app.switches["acceptRules"].tap()
        app.buttons["confirmRegistration"].tap()
        XCTAssertTrue(app.staticTexts["已加入候补"].waitForExistence(timeout: 5))
        app.buttons["viewParticipation"].tap()
        XCTAssertTrue(app.buttons["候补等待中"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["候补等待中"].isEnabled)
        app.navigationBars.buttons.firstMatch.tap()

        selectTab("俱乐部", in: app)
        XCTAssertTrue(app.staticTexts["如何参与"].waitForExistence(timeout: 5))
        screenshot("11-俱乐部", app)
        selectTab("我的", in: app)
        XCTAssertTrue(app.staticTexts["林夏"].waitForExistence(timeout: 5))
        screenshot("12-个人中心", app)
    }

    func testContactChatAndMessages() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["CLUB_UI_TEST_DATABASE_ID"] = UUID().uuidString
        app.launch()
        let invite = app.textFields["field.shield"]
        XCTAssertTrue(invite.waitForExistence(timeout: 10))
        enter("10001", in: invite)
        app.buttons["connectClub"].tap()
        let card = app.textFields["field.person"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        enter("YS20260018", in: card)
        enter("123456", in: app.secureTextFields["field.lock"])
        app.buttons["login"].tap()
        XCTAssertTrue(app.tabBars.buttons["消息"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.firstMatch.exists)

        selectTab("消息", in: app)
        XCTAssertTrue(app.buttons["message.hike-reminder"].waitForExistence(timeout: 5))
        screenshot("13-消息列表", app)
        XCTAssertTrue(app.staticTexts["有 3 条未读消息，看看伙伴们的新动态"].exists)
        app.buttons["未读"].tap()
        app.buttons["message.hike-reminder"].tap()
        let chatInput = app.textFields["chatInput"]
        XCTAssertTrue(chatInput.waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["周六日落轻徒步"].exists)
        XCTAssertFalse(app.buttons["sendChatMessage"].isEnabled)
        enter("   ", in: chatInput)
        XCTAssertFalse(app.buttons["sendChatMessage"].isEnabled)
        replace("See you on Saturday!", in: chatInput)
        app.buttons["sendChatMessage"].tap()
        XCTAssertTrue(app.staticTexts["See you on Saturday!"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["sendChatMessage"].isEnabled)
        dismissKeyboard(in: app)
        screenshot("16-聊天页面", app)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["markAllMessagesRead"].waitForExistence(timeout: 5))
        app.buttons["全部"].tap()
        XCTAssertTrue(app.buttons["message.hike-reminder"].label.contains("我：See you on Saturday!"))
        app.buttons["message.hike-reminder"].tap()
        XCTAssertTrue(app.staticTexts["See you on Saturday!"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["有 2 条未读消息，看看伙伴们的新动态"].exists)
        app.buttons["markAllMessagesRead"].tap()
        app.buttons["未读"].tap()
        XCTAssertTrue(app.staticTexts["暂时没有未读消息"].waitForExistence(timeout: 5))
        app.buttons["全部"].tap()
        enter("night-no-match", in: app.textFields["messageSearch"])
        dismissKeyboard(in: app)
        XCTAssertTrue(app.staticTexts["没有找到相关消息"].exists)
        app.buttons["clearCommunitySearch"].tap()

        selectTab("通讯录", in: app)
        XCTAssertTrue(app.buttons["contact.azhe"].waitForExistence(timeout: 5))
        screenshot("14-通讯录", app)
        app.buttons["领队"].firstMatch.tap()
        XCTAssertFalse(app.buttons["contact.chenmo"].exists)
        app.buttons["全部"].tap()
        enter("C", in: app.textFields["contactSearch"])
        dismissKeyboard(in: app)
        XCTAssertTrue(app.buttons["contact.chenmo"].exists)
        XCTAssertFalse(app.buttons["contact.azhe"].exists)
        app.buttons["contact.chenmo"].tap()
        XCTAssertTrue(app.textFields["chatInput"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["陈默"].exists)
        XCTAssertTrue(app.staticTexts["和陈默开始聊天"].exists)
        enter("Hello Chen!", in: app.textFields["chatInput"])
        app.buttons["sendChatMessage"].tap()
        XCTAssertTrue(app.staticTexts["Hello Chen!"].waitForExistence(timeout: 5))
        dismissKeyboard(in: app)
        screenshot("17-通讯录聊天", app)
        app.buttons["chatContactDetails"].tap()
        XCTAssertTrue(app.buttons["toggleFavoriteContact"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["toggleFavoriteContact"].label, "添加为常用联系人")
        screenshot("15-成员资料", app)
        app.buttons["toggleFavoriteContact"].tap()
        XCTAssertEqual(app.buttons["toggleFavoriteContact"].label, "移出常用联系人")
        app.buttons["closeContact"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["contact.chenmo"].waitForExistence(timeout: 5))
        app.buttons["contact.chenmo"].tap()
        XCTAssertTrue(app.staticTexts["Hello Chen!"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["clearCommunitySearch"].tap()
        app.buttons["常用"].tap()
        XCTAssertTrue(app.buttons["contact.chenmo"].exists)
        selectTab("消息", in: app)
        XCTAssertFalse(app.buttons["markAllMessagesRead"].isEnabled)
        let directConversation = app.buttons["message.contact-chenmo"]
        XCTAssertEqual(app.buttons.matching(identifier: "message.contact-chenmo").count, 1)
        XCTAssertTrue(directConversation.label.contains("我：Hello Chen!"))
        directConversation.tap()
        XCTAssertTrue(app.staticTexts["Hello Chen!"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["See you on Saturday!"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        selectTab("俱乐部", in: app)
        XCTAssertTrue(app.staticTexts["如何参与"].waitForExistence(timeout: 5))
        selectTab("我的", in: app)
        XCTAssertTrue(app.staticTexts["林夏"].waitForExistence(timeout: 5))
    }

    func testAccountDeletionAndRestart() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["CLUB_UI_TEST_DATABASE_ID"] = UUID().uuidString
        app.launch()
        let invite = app.textFields["field.shield"]
        XCTAssertTrue(invite.waitForExistence(timeout: 10))
        enter("10001", in: invite)
        app.buttons["connectClub"].tap()
        let card = app.textFields["field.person"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        enter("YS20260018", in: card)
        enter("123456", in: app.secureTextFields["field.lock"])
        app.buttons["login"].tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        selectTab("我的", in: app)
        app.buttons["打开设置"].tap()
        let entry = app.buttons["deleteAccountEntry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        entry.tap()
        let confirm = app.buttons["confirmAccountDeletion"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertFalse(confirm.isEnabled)
        app.swipeUp()
        app.switches["acknowledgeAccountDeletion"].tap()
        XCTAssertTrue(confirm.isEnabled)
        screenshot("18-注销账号", app)
        confirm.tap()
        app.alerts.buttons["取消"].tap()
        XCTAssertTrue(confirm.exists)
        XCTAssertFalse(app.textFields["field.shield"].exists)
        confirm.tap()
        app.buttons.matching(identifier: "executeAccountDeletion").firstMatch.tap()
        XCTAssertTrue(invite.waitForExistence(timeout: 8))
        app.terminate()
        app.launch()
        XCTAssertTrue(invite.waitForExistence(timeout: 10))
        enter("10001", in: invite)
        app.buttons["connectClub"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        enter("YS20260018", in: card)
        enter("123456", in: app.secureTextFields["field.lock"])
        app.buttons["login"].tap()
        XCTAssertTrue(app.staticTexts["本机账号已注销，无法再次登录。"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
    }

    private func selectTab(_ title: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[title]
        if tab.exists {
            tab.tap()
        } else {
            let more = app.tabBars.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "更多", "More")).firstMatch
            XCTAssertTrue(more.waitForExistence(timeout: 5))
            more.tap()
            let destination = app.tables.cells.containing(.staticText, identifier: title).firstMatch
            XCTAssertTrue(destination.waitForExistence(timeout: 5))
            destination.tap()
        }
    }

    private func dismissKeyboard(in app: XCUIApplication) {
        let done = app.buttons["keyboardDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
    }

    private func enter(_ text: String, in field: XCUIElement) {
        field.tap()
        field.typeText(text)
    }

    private func replace(_ text: String, in field: XCUIElement) {
        let count = (field.value as? String)?.count ?? 0
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count) + text)
    }

    private func screenshot(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
