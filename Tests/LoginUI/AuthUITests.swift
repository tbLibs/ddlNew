import XCTest
final class AuthUITests: XCTestCase {
    let app = XCUIApplication()
    override func setUp() { super.setUp(); continueAfterFailure = false }
    func launch(_ mode: String) { app.launchArguments = [mode]; app.launch(); XCTAssertTrue(app.buttons["authMethod.1"].waitForExistence(timeout: 8)) }
    func field(_ key: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: "authField.\(key)").firstMatch }
    func show(_ e: XCUIElement) { for _ in 0..<5 { if e.isHittable { return }; app.swipeUp() }; XCTAssertTrue(e.isHittable) }
    func enter(_ key: String, _ value: String) { let e = field(key); show(e); e.tap(); e.typeText(value); if app.buttons["完成"].firstMatch.isHittable { app.buttons["完成"].firstMatch.tap() } }
    func shot(_ name: String) { let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a) }
    func testIdentityAndPasswordSwitch() {
        launch("account")
        enter("identity", "test001"); enter("password", "Ab1234")
        app.buttons["显示密码"].tap(); XCTAssertEqual(field("password").value as? String, "Ab1234")
        app.buttons["authMethod.3"].tap()
        XCTAssertFalse((field("password").value as? String ?? "").contains("Ab1234"))
        enter("identity", "13800000000")
        show(app.buttons["toggleCodeLogin"]); app.buttons["toggleCodeLogin"].tap()
        XCTAssertTrue(field("code").exists); XCTAssertFalse(app.switches["rememberPassword"].exists)
        app.swipeDown(); app.buttons["authMethod.1"].tap()
        XCTAssertEqual(field("identity").value as? String, "test001"); shot("method-switch")
    }
    func testLoginConsentCancelPreservesInputs() {
        launch("account"); enter("identity", "test001"); enter("password", "Ab1234")
        show(app.buttons["login"]); app.buttons["login"].tap()
        XCTAssertTrue(app.alerts["提示"].waitForExistence(timeout: 3))
        app.alerts.buttons["取消"].tap(); XCTAssertEqual(field("identity").value as? String, "test001")
        show(app.buttons["显示密码"]); app.buttons["显示密码"].tap(); XCTAssertEqual(field("password").value as? String, "Ab1234")
        show(app.buttons["login"]); app.buttons["login"].tap(); app.alerts.buttons["同意并继续"].tap()
        XCTAssertTrue(app.buttons["login"].waitForExistence(timeout: 3))
        let done = NSPredicate(format: "label == %@", "已登录")
        expectation(for: done, evaluatedWith: app.buttons["login"]); waitForExpectations(timeout: 4)
        shot("login-consent-success")
    }
    func testOnlyAccountAndPhoneOnBothForms() {
        for mode in ["account", "phone-register"] {
            launch(mode)
            XCTAssertTrue(app.buttons["authMethod.1"].exists)
            XCTAssertTrue(app.buttons["authMethod.3"].exists)
            XCTAssertFalse(app.buttons["authMethod.2"].exists)
            shot("two-methods-\(mode)")
        }
    }
    func testRegisterAuthFailureCannotRegisterTwice() {
        launch("phone-register-auth-fail")
        enter("identity", "13800000000"); enter("code", "123456"); enter("password", "Ab1234"); enter("confirmation", "Ab1234")
        show(app.buttons["submitAccountRegistration"]); app.buttons["submitAccountRegistration"].tap()
        XCTAssertTrue(app.alerts["提示"].waitForExistence(timeout: 3)); app.alerts.buttons["取消"].tap()
        show(field("confirmation")); XCTAssertFalse((field("confirmation").value as? String ?? "").isEmpty)
        show(app.buttons["submitAccountRegistration"]); app.buttons["submitAccountRegistration"].tap(); app.alerts.buttons["同意并继续"].tap()
        let back = NSPredicate(format: "label == %@", "返回登录")
        expectation(for: back, evaluatedWith: app.buttons["submitAccountRegistration"]); waitForExpectations(timeout: 4)
        XCTAssertFalse(field("confirmation").isEnabled); shot("register-auth-failure")
    }
    func testInvalidCaptchaImageCanRefresh() {
        launch("phone-code-bad-image"); enter("identity", "13800000000"); show(app.buttons["sendVerificationCode"]); app.buttons["sendVerificationCode"].tap()
        let refresh = app.buttons["refreshLoginImageCode"]; XCTAssertTrue(refresh.waitForExistence(timeout: 3)); XCTAssertTrue(refresh.isEnabled)
        XCTAssertFalse(app.textFields["loginImageCode"].isEnabled); refresh.tap()
        let ready = NSPredicate(format: "enabled == true")
        expectation(for: ready, evaluatedWith: app.textFields["loginImageCode"]); waitForExpectations(timeout: 3); shot("bad-image-recovered")
    }
    func testCaptchaRefreshClearsAnswer() {
        launch("phone-code"); enter("identity", "13800000000"); show(app.buttons["sendVerificationCode"]); app.buttons["sendVerificationCode"].tap()
        let code = app.textFields["loginImageCode"]; XCTAssertTrue(code.waitForExistence(timeout: 3)); code.tap(); code.typeText("OLD")
        app.buttons["refreshLoginImageCode"].tap()
        let clear = NSPredicate(format: "value != %@", "OLD")
        expectation(for: clear, evaluatedWith: code); waitForExpectations(timeout: 3)
        XCTAssertFalse(app.buttons["submitLoginVerification"].isEnabled)
        XCTAssertTrue(app.buttons["refreshLoginImageCode"].isEnabled); shot("captcha-refresh")
        code.tap(); code.typeText("DEMO"); app.buttons["submitLoginVerification"].tap()
        let sent = NSPredicate(format: "label CONTAINS %@", "秒后重新获取")
        expectation(for: sent, evaluatedWith: app.buttons["sendVerificationCode"]); waitForExpectations(timeout: 4)
    }
    func testPhoneCaptchaCancelAndSend() {
        launch("phone-code"); enter("identity", "13800000000"); show(app.buttons["sendVerificationCode"]); app.buttons["sendVerificationCode"].tap()
        XCTAssertTrue(app.buttons["cancelLoginVerification"].waitForExistence(timeout: 3)); app.buttons["cancelLoginVerification"].tap()
        XCTAssertTrue(app.buttons["sendVerificationCode"].waitForExistence(timeout: 3)); XCTAssertTrue(app.buttons["sendVerificationCode"].isEnabled)
        app.buttons["sendVerificationCode"].tap(); let code = app.textFields["loginImageCode"]; XCTAssertTrue(code.waitForExistence(timeout: 3)); code.tap(); code.typeText("DEMO")
        app.buttons["submitLoginVerification"].tap()
        let sent = NSPredicate(format: "label CONTAINS %@", "秒后重新获取")
        expectation(for: sent, evaluatedWith: app.buttons["sendVerificationCode"]); waitForExpectations(timeout: 4); shot("phone-countdown")
    }
}
