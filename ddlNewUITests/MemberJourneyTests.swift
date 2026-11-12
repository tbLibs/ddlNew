import XCTest

@MainActor
final class MemberJourneyTests: XCTestCase {
    func testLoginRequiresLegalConfirmation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["CLUB_UI_TEST_DATABASE_ID"] = UUID().uuidString
        app.launch()
        let invite = app.textFields["field.shield"]
        XCTAssertTrue(invite.waitForExistence(timeout: 10))
        enter("100001", in: invite)
        app.buttons["connectClub"].tap()
        let account = app.textFields["field.person"]
        XCTAssertTrue(account.waitForExistence(timeout: 5))
        let loginButton = app.buttons["login"]
        let agreement = app.buttons["acceptLegalDocuments"]
        XCTAssertTrue(loginButton.isEnabled)
        loginButton.tap()
        XCTAssertTrue(app.alerts["请先勾选协议"].waitForExistence(timeout: 5))
        app.alerts.buttons["取消"].firstMatch.tap()
        XCTAssertEqual(agreement.value as? String, "未勾选")
        agreement.tap()
        loginButton.tap()
        XCTAssertTrue(app.alerts["请输入账号和密码"].waitForExistence(timeout: 5))
        app.alerts.buttons["知道了"].firstMatch.tap()
        agreement.tap()
        enter("YS20260018", in: account)
        enter("123456", in: app.secureTextFields["field.lock"])
        dismissKeyboard(in: app)

        let registerButton = app.buttons["registerAccount"]
        XCTAssertTrue(loginButton.isEnabled)
        XCTAssertTrue(registerButton.isEnabled)
        loginButton.tap()
        XCTAssertTrue(app.alerts["请先勾选协议"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        app.alerts.buttons["取消"].firstMatch.tap()
        app.buttons["openPrivacyPolicy"].tap()
        XCTAssertTrue(app.webViews.staticTexts["1. 处理的信息"].waitForExistence(timeout: 20))
        app.navigationBars.buttons["完成"].tap()
        app.buttons["openSupport"].tap()
        XCTAssertTrue(app.webViews.staticTexts["常见问题"].waitForExistence(timeout: 20))
        app.navigationBars.buttons["完成"].tap()
        XCTAssertEqual(agreement.value as? String, "未勾选")

        agreement.tap()
        XCTAssertTrue(loginButton.isEnabled)
        XCTAssertTrue(registerButton.isEnabled)
        agreement.tap()
        XCTAssertTrue(loginButton.isEnabled)
        XCTAssertTrue(registerButton.isEnabled)
        loginButton.tap()
        XCTAssertTrue(app.alerts["请先勾选协议"].waitForExistence(timeout: 5))
        app.alerts.buttons["勾选"].firstMatch.tap()
        XCTAssertEqual(agreement.value as? String, "已勾选")
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        loginButton.tap()
        assertMainTabs(in: app)
    }

    func testRegisterAccountCanSignOutLogInAndRestoreSession() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["CLUB_UI_TEST_DATABASE_ID"] = UUID().uuidString
        app.launch()

        let invite = app.textFields["field.shield"]
        XCTAssertTrue(invite.waitForExistence(timeout: 10))
        enter("100001", in: invite)
        app.buttons["connectClub"].tap()
        let register = app.buttons["registerAccount"]
        XCTAssertTrue(register.waitForExistence(timeout: 5))
        XCTAssertTrue(register.isEnabled)
        register.tap()
        let account = app.textFields["registerAccountField"]
        XCTAssertTrue(account.waitForExistence(timeout: 5))
        enter("trailuser", in: account)
        app.buttons["registerPasswordField.visibility"].tap()
        app.buttons["registerConfirmationField.visibility"].tap()
        enter("trailpass", in: app.textFields["registerPasswordField"])
        enter("trailpass", in: app.textFields["registerConfirmationField"])
        let submit = app.buttons["submitRegistration"]
        XCTAssertTrue(submit.isEnabled)
        submit.tap()
        let registrationLoginAccount = app.textFields["field.person"]
        XCTAssertTrue(registrationLoginAccount.waitForExistence(timeout: 8))
        XCTAssertEqual(registrationLoginAccount.value as? String, "trailuser")
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        app.buttons["login"].tap()
        XCTAssertTrue(app.alerts["请先勾选协议"].waitForExistence(timeout: 5))
        app.alerts.buttons["取消"].firstMatch.tap()
        XCTAssertEqual(app.buttons["acceptLegalDocuments"].value as? String, "未勾选")

        app.terminate()
        app.launch()
        XCTAssertTrue(registrationLoginAccount.waitForExistence(timeout: 8))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        replace("trailuser", in: registrationLoginAccount)
        enter("trailpass", in: app.secureTextFields["field.lock"])
        login(in: app)
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        assertMainTabs(in: app)

        selectTab("我的", in: app)
        XCTAssertTrue(app.staticTexts["trailuser"].waitForExistence(timeout: 5))
        app.buttons["打开设置"].tap()
        app.buttons["退出登录"].tap()
        app.alerts.buttons["退出登录"].tap()
        let loginAccount = app.textFields["field.person"]
        XCTAssertTrue(loginAccount.waitForExistence(timeout: 5))
        enter("trailuser", in: loginAccount)
        enter("wrong", in: app.secureTextFields["field.lock"])
        login(in: app)
        XCTAssertTrue(app.staticTexts["账号或密码不正确，请重新输入。"].waitForExistence(timeout: 5))
        enter("trailpass", in: app.secureTextFields["field.lock"])
        login(in: app)
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        assertMainTabs(in: app)
    }

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
        login(in: app)
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        selectTab("我的", in: app)

        app.buttons["打开设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.navigationBars.count, 1, app.navigationBars.debugDescription)
        app.buttons["deleteAccountEntry"].tap()
        screenshot("注销账号-导航栏", app)
        XCTAssertTrue(app.navigationBars["注销账号"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.navigationBars.count, 1, app.navigationBars.debugDescription)
        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons["完成"].tap()

        assertMainTabs(in: app)
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
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 20))
        XCTAssertTrue(app.webViews.staticTexts["1. 处理的信息"].waitForExistence(timeout: 20))
        app.navigationBars.buttons["完成"].tap()
        app.buttons["openSupport"].tap()
        XCTAssertTrue(app.webViews.staticTexts["常见问题"].waitForExistence(timeout: 20))
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
        login(in: app)
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
        login(in: app)
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
        login(in: app)
        XCTAssertTrue(app.staticTexts["账号已注销，无法再次登录。"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
    }

    private func acceptLegalDocuments(in app: XCUIApplication) {
        let agreement = app.buttons["acceptLegalDocuments"]
        XCTAssertTrue(agreement.waitForExistence(timeout: 5))
        if agreement.value as? String != "已勾选" {
            if app.keyboards.firstMatch.exists { app.buttons["keyboardDone"].tap() }
            agreement.tap()
        }
        XCTAssertEqual(agreement.value as? String, "已勾选")
    }

    private func login(in app: XCUIApplication) {
        acceptLegalDocuments(in: app)
        app.buttons["login"].tap()
    }

    private func assertMainTabs(in app: XCUIApplication) {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        XCTAssertEqual(app.tabBars.buttons.count, 4)
        for title in ["消息", "通讯录", "事项", "我的"] { XCTAssertTrue(app.tabBars.buttons[title].exists) }
        XCTAssertFalse(app.tabBars.buttons["首页"].exists)
    }

    private func selectTab(_ title: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[title]
        if tab.exists {
            tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: tab)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
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
