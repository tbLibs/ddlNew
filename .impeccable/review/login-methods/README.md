# 登录注册 UI 验证记录

2026-11-10，任务：按xgd扩展账号、手机、邮箱登录注册；用户指定 Impeccable 与 ui-ux-pro-max。

沿用已有 `HomeTheme`（森林绿、系统字体、浅深色），没有创建新的全局视觉系统。SwiftUI原生页面不运行HTML/CSS detector。生产应用目标为iPhone、竖屏；截图来自 iPhone SE3 375×667pt、iOS26.5 模拟器，750×1334px。

## 截图

- `account.png`、`email.png`：账号／邮箱密码登录。
- `phone-code.png`、`phone-code-dark.png`：手机验证码登录，浅深色。
- `phone-register.png`：手机注册首屏。
- `email-register-bottom.png`、`email-register-bottom-dark.png`：邮箱注册滚动到底，浅深色。
- `phone-code-ax.png`、`phone-code-ax-bottom.png`：accessibility3字号首屏和底部。
- `phone-captcha.png`、`phone-captcha-dark.png`：匿名图片验证码浅深色，DEMO为宿主生成的测试图。
- `phone-countdown.png`：匿名发码成功后的60秒倒计时。

截图通过 simctl 直接捕获，无后期修改。表单中的手机号为合成输入，未请求真实服务；“连接已就绪”和验证码结果来自替身。预览宿主位于临时目录 `/tmp/ddlNew-auth-preview/`，未给生产代码添加预览开关。

## 实际验证与限制

宿主编译生产 LoginView、AccountRegistrationView、AuthenticationFields、LegalConsentRow、LoginVerificationSheet、验证码协调器与发码ViewModel。替身隔离SDK、登录／注册主要ViewModel、会话及Toast。实际操作手机输入与完成键、安全验证输入并提交、倒计时、区号搜索44并选择英国、从登录页进入注册页后再次弹出安全验证并取消；大字号与注册表单实际滚动到底。

UI自动化元素确认方式选项为109×48pt、同意按钮44×44pt、法律链接至少44pt高、主按钮52pt高。未以这些结果宣称真实发短信／邮件、真实登录注册、AUTH、Keychain、错误Toast或VoiceOver通过；真实服务联调仍需在App中验证。

六组离线检查：`Tests/Login/run-checks.sh`、`Tests/Login/run-code-checks.sh`、`Tests/LoginConsent/run-checks.sh`、`Tests/AccountLifecycle/run-checks.sh`、`Tests/Verification/run-checks.sh`、`Tests/SessionRestore/run-checks.sh`。最终iOS构建日志 `/tmp/ddlNew-login-methods-final-build.log`。

## 独立复核

当前工具未暴露 Impeccable 专用代理角色，使用全新上下文的通用审查代理代行 finish reviewer。首轮 disposition: fix，唯一事项为安全验证占位文字太浅；图片验证码与安全码均显式采用 `LoginPalette.secondary`，重新构建并补拍浅深色。

复核 verdict: resolved，remaining: clear，disposition: ship。该结论只覆盖这项提示色修复评分，未发现修复引入的可见回归；不扩大为真实后端或全部辅助功能验收。

独立文档检查由通用代理代行 documenter，结论 No changes：LoginPalette 与 HomeTheme 一致，460pt表单宽度及12/16pt圆角仅属认证页局部实现，不提升为全局规范；实施计划、此记录和交接文档一致。

## 后续原生 XCTest 对照自测

本轮停用 Mobile MCP 后，改用 `Tests/LoginUI/` 原生宿主，编译真实 LoginViewModel 与 AccountRegistrationViewModel；服务、会话、Keychain、路由、Toast 保持隔离。最终7项用例通过，xcodebuild exit0、TEST SUCCEEDED，完整xcresult summary为Passed；原始附件位于 `audit/`，文件与用例名称对应关系见 `audit/manifest.json`。已目视检查坏图刷新恢复、注册后AUTH失败布局。

完整测试仍记录一条注册页唤起键盘时的frame尺寸警告，来源待定位。上述通过不表示全部UI／线上服务验收通过；本轮修复、xgd剩余差异与完整证据见 `Docs/LOGIN_REGISTRATION_PARITY_AUDIT_2026-11-10.md`。

## 移除邮箱后的双方式页面

按用户最新要求移除邮箱，当前只保留账号与手机号。`account-phone/` 保存两页原始XCTest截图与manifest，已目视检查两项入口均分宽度。调整后的7项原生UI测试全部通过，xcodebuild exit0，报告Passed；6组逻辑脚本和App无签名构建通过。既有注册页键盘frame警告仍在，未宣称零警告。上面的三方式截图保留为历史记录。
