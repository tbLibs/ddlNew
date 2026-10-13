# Network and Login Maintenance Implementation Plan

> **For agentic workers:** 使用 `superpowers:subagent-driven-development` 按责任范围实现，使用 `superpowers:test-driven-development` 验证剩余缺陷修复，最终使用 `superpowers:verification-before-completion` 核对结果。

**Goal:** 接入产品经理确认的七项网络与登录维护能力。

**Architecture:** 保留现有访客连接 → 真实登录 → SDK AUTH 编排。独立 HTTP 择优、安全改密和会话维护服务通过会话生命周期协作；前台恢复、身份及导航版本校验负责撤销迟到结果。

**Tech Stack:** Swift、SwiftUI、ObjectMapper、NoaChatCore；离线 Swift 检查脚本与 Xcode 真机目标构建。

**Spec:** `Docs/NETWORK_LOGIN_REQUIREMENTS.md`

## Global Constraints

- iOS 16 导航 API；必要注释使用中文，新文件作者 taobo、日期 2026/10/13。
- 入口继续使用邀请码；手机号／邮箱登录、验证码登录及找回密码暂缓。
- 固定品牌展示与静态 Sentry／Logan 配置保持现有行为。
- 使用真实 SDK 方法；保留 Token、deviceSecret、记住密码的 Keychain 边界。
- 系统配置、资料、角色权限每 180～480 秒刷新；进入后台暂停。
- 弱密码临时检查失败允许继续并重试；明确强制改密只能完成修改或退出。
- 本轮在 `feature-message-4` 用户工作区继续，保留变更供用户审阅。

## Review Focus

- 同一邀请码重新导航时，旧请求不能覆盖新 Host 或配置。
- 主动退出与强制下线并发时，旧退出任务不能清理下一用户。
- 弱密码检查和手动密码补充交错时，强制策略不得丢失。
- 修改密码的服务端响应丢失时，不得绕过已确认的强制改密。
- 权限字段缺失或数值／字符串混用时，遵循旧端默认值并隔离账号缓存。

## Task 1: 前台探活和 HTTP 独立优选

**Files:**
- Modify: `ddlNew/Network/IM/IMLoggedInReconnectCoordinator.swift`
- Create: `ddlNew/Network/IM/IMHTTPNodePreferenceEngine.swift`、`IMHTTPNodePreferenceProbe.swift`
- Modify: `ddlNew/Network/OSS/` 导航解码与缓存传递路径、`ddlNew/Network/NetworkPath.swift`
- Test: `Tests/HTTPNodePreference/run-checks.sh`

**Interfaces:**
- Consumes: `SessionMaintenanceCoordinator.shared.refreshConfigurationAfterNodeChange()`。
- Produces: 同会话前台探活；真实 API／文件／上传 Host 更新。

- [x] 核对 SDK `verifyConnectionOnForeground` 与旧 `is_merge_version`、`ping_interval_second`。
- [x] 独立 GET `/zlcpig`，默认 300 秒，单次 2 秒，失败保留当前节点。
- [x] 按成功次数、平均成功 RTT 排序；60 秒切换冷却。
- [x] 按 UID／邀请码／导航保存版本隔离，后台和断线竞速取消。
- [x] 复核离线 HTTP、Network、NetworkQuality 脚本和集成构建。

## Task 2: 特殊错误与弱密码强制修改

**Files:**
- Create: `ddlNew/Features/Login/Models/LoginSecurityNotice.swift`、`PasswordSecurity*.swift`
- Create: `ddlNew/Features/Login/Services/LoginSecurityCoordinator.swift`、`PasswordSecurityService.swift`
- Create: `ddlNew/Features/Login/Views/PasswordChangeView.swift`
- Create: `ddlNew/Network/IM/SDK/SDKPasswordSecurityClient.swift`
- Modify: 登录错误、登录页、LoginViewModel、`ddlNew/App/ddlNewApp.swift`
- Test: `Tests/LoginSecurity/run-checks.sh`

**Interfaces:**
- Produces: `LoginSecurityCoordinator.start(userUID:lastLiceseId:)`、`stop()`、`refreshIfNeeded()`。
- Produces: `LoginSecurityNoticeStore.record(message:)`。
- Consumes: `AppSessionRouter.signOut(changeClub:) async throws`。

- [x] 核实业务码和 SDK 下线类型，保留 2036／40019 与验证码、安全码原流程。
- [x] 接真实密码强度检查；手动密码只用于单次加密，恢复会话以 UID 检查。
- [x] 原密码验证 → 新密钥 → 重置密码；强制页面不能关闭或绕过。
- [x] 修改成功清除记住的旧密码并退出；退出清理失败提供重试。
- [x] 先复现安全码白名单消息丢失，再修复并跑安全与登录离线检查。

## Task 3: 系统配置、资料与角色权限维护

**Files:**
- Create: `ddlNew/Network/Session/SessionMaintenanceEngine.swift`、`SessionMaintenanceCoordinator.swift`
- Create: `ddlNew/Network/IM/SDK/SDKSessionMaintenanceClient.swift`
- Create: `ddlNew/Common/User/UserRoleAuthority.swift`、`UserRoleAuthorityStore.swift`
- Modify: `UserSessionStore.swift`、`IMConnectionCoordinator.swift`、`LoginSessionService.swift`、`TabbarView.swift`
- Test: `Tests/SessionMaintenance/run-checks.sh`、`Tests/SessionRestore/run-checks.sh`

**Interfaces:**
- Produces: `startGuest(lastLiceseId:)`、`start(userUID:lastLiceseId:)`、`stop()`。
- Produces: `setForegroundActive(_:)`、`setAuthenticated(_:)`、`refreshNow()`。
- Consumes: SDK 系统配置／资料／角色权限方法和既有连接、导航、资料缓存。

- [x] 首次 AUTH 后立即刷新；访客仅刷新配置，登录后增加资料、权限。
- [x] 180～480 秒串行周期，主动刷新唤醒等待，失败保留原资料和配置。
- [x] 请求提交前后核对身份、Host、导航版本；后台／下线取消。
- [x] 合并部分资料响应，不覆盖 Token 或 deviceSecret；主页观察用户资料。
- [x] 离线验证暂停、主动唤醒、迟到结果、权限默认值和身份隔离。

## Task 4: 服务端退出与统一生命周期

**Files:**
- Modify: `ddlNew/Features/Login/Services/LoginSessionService.swift`、`ddlNew/App/Routing/AppSessionRouter.swift`
- Modify: `ddlNew/App/ddlNewApp.swift` 与安全改密退出回调。
- Test: `Tests/SessionRestore/SessionRestoreChecks.swift`

**Interfaces:**
- Produces: `LoginSessionService.signOut() async throws`，原同步 `clearSession()` 仍用于直接撤销。
- Consumes: SDK `authUserLogout(with:onSuccess:onFailure:)`，显式当前 UID／Token。

- [x] 主动退出发送服务端请求，最多等待 2 秒，失败继续本地清理。
- [x] 取消维护、安全任务及旧会话回调，再清理 SDK、数据库和本地凭据。
- [x] 验证并发退出去重、强制下线与旧退出结果隔离、退出时请求身份。

## Task 5: 审查与验收记录

**Files:** `Docs/PROJECT_HANDOFF.md`，上述新增与修改文件。

- [x] 独立审查需求覆盖、行为与代码质量；修复明确缺陷。
- [x] 全部离线检查和 `git diff --check` 通过。
- [x] 使用 `ddlNew.xcworkspace`、真机目标、无签名 `clean build`，检查退出码和错误日志。
- [x] 更新交接文档；明确真实服务器与真机行为尚需联调。


## 验证结果

11 组离线检查均通过，最终真机目标无签名 `clean build` 成功，独立审查确认修复关闭。真机／服务端联调未执行，保留需求文档验收清单。

用户在初步实现已开始后指定 Superpowers，本计划复用已有实现；剩余边界通过失败用例 → 修复 → 回归和独立审查完成，同时以 swiftui-pro 检查新安全页面及数据接线。
