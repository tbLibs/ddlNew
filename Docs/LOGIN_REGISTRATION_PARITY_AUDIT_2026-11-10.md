# 登录注册自测与 xgd 对照

> 历史自测快照：用户随后要求移除邮箱登录与注册，现仅支持账号、手机号，本地方式改为5。下文邮箱测试仅记录此前结果，当前实现和本轮验证以 PROJECT_HANDOFF.md 顶部移除邮箱章节为准。

2026-11-10，分支 `feature-all-5`。结论：账号、手机、邮箱的主要请求合同和流程已对齐；发现并修复验证码链路差异，但不是全部行为完全一致。xgd 只读。用户要求停用 Mobile MCP 后，后续交互验证全部通过原生 XCTest／xcodebuild 完成。

## 请求参数与逻辑

| 项目 | 当前实现及对照结论 |
| --- | --- |
| 身份枚举 | 账号1、邮箱2、手机3；界面顺序为账号、手机、邮箱。 |
| 密码登录 | 三种身份均检查 userExit，领取新 encryptKey，以现有加密方法4处理 encryptKey + password；登录 type=2。pwdExit 在 xgd 也没有参与业务判断。 |
| 验证码登录 | 手机／邮箱提交6位 code，encryptKey、userPw 为空；不写入记住密码。 |
| 注册 | 账号提交前检查存在性；手机／邮箱在获取验证码时检查已注册。提交 registerType=1、type=1，加密密码，手机／邮箱附带验证码。 |
| 区号 | 登录、注册、存在性预检只有手机携带带 `+` 区号，账号／邮箱为空。短信／邮箱发码携带当前带 `+` 区号，默认 `+86`；目录中的连字符区号保留。 |
| 发码 | 手机按本地渠道先图形验证；邮箱直接发码。成功才开始60秒倒计时；失败／取消不倒计时。 |
| 图片验证码用途 | 注册发码1、登录发码2；手机密码登录2、账号／邮箱密码登录0。 |
| 会话保护 | 切换方式清除密码／验证码，旧连接回包拒收；注册成功后 AUTH 失败只能返回登录，不能重复注册。 |
| 协议确认 | 默认未同意；点击链接不代表同意，取消保留表单，明确确认才提交。这是本项目保留的用户要求。 |

对照源码入口：xgd `NoaChatKit/CandyTalk/Auth/Model/LoginAccount/NoaLoginAccountDataHandle.m`、`Auth/Model/Register/`、`Auth/Views/Register/NoaRegisterView.m`、`Auth/Views/ImageVerCode/NoaGetImgVerCodeBlurView.m`；新项目 `Features/Login/Services/` 与 `Network/IM/SDK/SDKAccount*Client.swift`。以上是源码合同和替身捕获参数验证，不是线上抓包结论。

## 本轮修复

1. 手机密码登录收到图片验证要求时，原先沿用 type=0；已按 xgd `getImageCodeType` 改为2，账号／邮箱保持0。新增回归覆盖首次请求和刷新。
2. 第三方验证码加载／执行失败，原先停留在重试界面；改为通知服务层重新领取图片，并用渠道2提交。主动取消继续取消，不能将失败当作验证成功。
3. 图片验证码原先没有换图入口；新增“换一张”，清除旧答案，刷新期间禁止提交，失败可重试，拒收取消或旧连接结果。初始图片损坏时也能换图恢复。

测试先复现缺失能力，再修改实现；修复后经过独立源码复核。图片损坏恢复同时有原生 UI 用例。

## 仍存在的差异与待查项

- **封禁处理尚未完整迁移**：xgd 在账号密码登录被封禁时查询封禁详情，并进入其封禁提示／解封相关 UI；新项目 `LoginSecurityNotice.swift` 仍显示固定提示。不能声称这类异常流程完全一致。
- **验证码尝试上限不同**：新项目登录挑战／发码流程保留客户端3轮限制，xgd 对照路径未找到相同的客户端限制。此处不是永久锁定账号，但本轮流程会提前结束。
- **登录页配置为有意差异**：按用户先前要求，仅用本地默认启用三种方式，不恢复 getSystemConfig 或 userSettings 的登录控制字段。
- **UI 为有意差异**：采用用户指定的 Impeccable／ui-ux-pro-max 和本项目森林绿样式，不复制 xgd 像素布局。
- **布局警告待定位**：完整 XCTest 报告记录一次 `Invalid frame dimension (negative or non-finite).`，发生在注册页身份输入框唤起键盘时。检查该页和共享字段未发现显式负尺寸计算；截图未见重叠或截断，但尚未定位警告来源，不能宣称运行时零警告。

## 验证证据

- 六组离线入口全部通过：`Tests/Login/run-checks.sh`（32/32）、`Tests/Login/run-code-checks.sh`（19项）、LoginConsent、AccountLifecycle、Verification、SessionRestore。日志 `/tmp/ddlNew-auth-audit-final-*-run-*.sh.log`。
- 主 App workspace 的 generic iOS Debug 无签名构建通过，日志 `/tmp/ddlNew-auth-audit-final-build.log`，`BUILD SUCCEEDED`。构建 PATH 排除 sentry-cli。
- iPhone SE3、iOS26.5、375×667pt：7项 XCTest 全部通过，0失败、0跳过；xcodebuild exit0、`TEST SUCCEEDED`，xcresult summary `Passed`。用例覆盖身份／密码切换、协议取消保留输入与继续、邮箱直接发码、手机验证取消与提交、注册后 AUTH 失败防重复、换图清空输入、初始坏图恢复。
- 完整结果：`/tmp/ddlNew-auth-audit-ui/DerivedData/Logs/Test/Test-AuthAudit-2026.11.10_10-41-59-+0800.xcresult`；日志 `/tmp/ddlNew-auth-audit-ui/all-final-test.log`。早期显式 resultBundlePath 导致结果收尾异常，最终使用默认结果目录正常完成，不以早期不完整报告作为验收证据。
- 7张原始 XCTest 截图和 manifest 保留在 `.impeccable/review/login-methods/audit/`；已目视检查换图恢复与注册后 AUTH 失败布局。前轮浅深色／大字号截图仍在上级目录。
- 可复现宿主位于 `Tests/LoginUI/`，生成脚本已实际运行成功。宿主编译真实 SwiftUI 页面、LoginViewModel、AccountRegistrationViewModel、验证码协调器；外部账号服务、会话、Keychain、路由、Toast 使用替身。

未验证真实短信／邮件、真实第三方验证码服务、线上注册与登录、设备 Keychain、真实 AUTH 或 VoiceOver；未操作实体设备、提交或推送代码。自测通过不替代这些联调验收。
