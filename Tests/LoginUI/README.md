# 登录注册原生 UI 自测

使用 XCTest／xcodebuild，不使用 Mobile MCP。`Host.swift` 隔离网络、账号服务、Keychain、AUTH与路由；编译真实 LoginView、AccountRegistrationView、两者 ViewModel、验证码协调器和组件。测试数据为合成输入，服务成功／失败由替身控制。Toast 被替换，不能据此宣称真实请求、Toast、Keychain或设备认证通过。

`AuthUITests.swift` 覆盖7个场景：身份切换与密码清除、协议取消保留输入／确认后继续、登录／注册均仅显示账号与手机号、手机验证码取消／提交、注册成功但AUTH失败时禁止再次注册、图片刷新清输入、初始坏图刷新恢复。

已有 XcodeGen 和已启动的 iPhone 模拟器时，可生成独立临时工程：

```sh
python3 Tests/LoginUI/generate.py /tmp/ddlNew-auth-ui-check
xcodebuild -project /tmp/ddlNew-auth-ui-check/AuthAudit.xcodeproj -scheme AuthAudit -destination 'platform=iOS Simulator,id=<模拟器UDID>' -derivedDataPath /tmp/ddlNew-auth-ui-check/DerivedData CODE_SIGNING_ALLOWED=NO test
```

2026-11-10在iPhone SE3／iOS26.5执行，最终7项全部通过、0失败、0跳过，xcodebuild exit0／TEST SUCCEEDED，默认目录xcresult summary为Passed。早期显式resultBundlePath导致收尾异常，最终使用上述默认目录命令解决。报告仍记录一条注册页唤起键盘时的负数／非有限frame尺寸警告，来源待定位。

最终结果：`/tmp/ddlNew-auth-audit-ui/DerivedData/Logs/Test/Test-AuthAudit-2026.11.10_10-41-59-+0800.xcresult`；截图保存到 `.impeccable/review/login-methods/audit/`。主App的generic iOS无签名构建与6组离线入口独立通过。完整对照、剩余差异及验证限制见 `Docs/LOGIN_REGISTRATION_PARITY_AUDIT_2026-11-10.md`。

本日随后按用户要求删除邮箱，宿主与用例改为账号／手机号；原7项中的邮箱直接发码替换为两页入口检查。最终7/7通过、xcodebuild exit0，报告 `/tmp/ddlNew-remove-email-ui/DerivedData/Logs/Test/Test-AuthAudit-2026.11.10_10-47-49-+0800.xcresult`。既有frame警告仍出现。两页最新截图位于 `.impeccable/review/login-methods/account-phone/`。
