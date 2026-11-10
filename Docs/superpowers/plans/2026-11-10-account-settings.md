# Account Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox syntax for tracking.

**Goal:** 已认证账号通过 userInfo.userSettings 驱动消息、通话、上传及群活跃积分同步。
**Architecture:** UserSettings 保存字段存在性，UserProfileCache 标记新缓存格式；AccountSettingsSnapshot 纯值解释，AccountSettingsStore 按完整认证身份发布。SessionMaintenanceCoordinator 复用现有串行资料刷新，不请求 getSystemConfig。
**Tech Stack:** Swift 6、ObjectMapper、Combine、现有 NoaChatCore。
**Spec:** Docs/superpowers/specs/2026-11-09-user-settings-runtime-design.md

## Global Constraints

- 用户已明确要求实施；在当前 feature-all-5 工作区直接完成，不额外请求流程确认、不提交推送。
- 登录前本地默认；tenantCode、密码规则及已删除35字段不恢复。
- 用户明确新增群成员活跃积分同步，版本检查及日志上传不新增。
- xgd只读；不操作真实设备或真实账号。
- 列表展示、断线点击和消息页恢复合同不变。

## Review Focus

- 旧缓存把省略字段存成空字符串：不得误关功能或混用供应商。
- 切换供应商只返回type：不得把旧桶用于新供应商。
- 同UID重新认证后旧资料／积分回调：不得写入新会话。
- 开始通话后配置变更：新请求拒收旧配置结果，已接通通话维持快照。
- 上传主文件与封面之间刷新配置：二者使用同一份开始时快照。

### Task 1: 字段存在性、缓存与有效配置
**Files:** UserSettings.swift、UserProfileCache.swift、AccountSettingsSnapshot.swift、AccountSettingsStore.swift、UserSessionStore.swift；Tests/SessionMaintenance/SettingsChecks.swift 与脚本。
**Interfaces:** UserSettings.providedKeys；UserProfileCache.encode/decode；AccountSettingsSnapshot.init(settings:)；AccountSettingsStore.activate(userUID:tenantID:sessionID:settings:), update(settings:userUID:tenantID:sessionID:), reset()；current published快照。
- [x] 先检查稀疏字段往返／旧缓存，运行确认失败。
- [x] 实现稀疏映射与版本化缓存；纯值解析群间隔0→2000ms、撤回0关闭、保守坏值及通话／存储组验证。
- [x] 实现账号身份隔离Store，配置不变不重复发布；供应商切换清除不适用旧字段。
- [x] 测试缓存、分组、身份、缺失／null／空值及供应商切换；运行专项并记录结果，不提交。

### Task 2: 生命周期与聊天／通话／上传接线
**Files:** SessionMaintenanceCoordinator.swift、SDKChatClient.swift、ChatSettingsView.swift、CallConfigurationStore.swift、CallCoordinator.swift、SDKChatMediaClient.swift、SDKCloudChatMediaClient.swift。
**Interfaces:** 消费Task1快照；AccountSettingsStore.current配置供同步校验，上传捕获不可变Media值，权限变化通知现有eventHandler。
- [x] 在现有AUTH后、业务激活前prepareSettings激活缓存，资料合并成功后更新，stop重置；沿用现有回包资格。
- [x] 替换消息本地常量、群人数视图订阅、刷新菜单权限；通话Store更新及建房完整配置比较。
- [x] 上传在第一次await前捕获快照，云上传及封面使用同一快照；本地tenant参数保持。
- [x] 运行相关聊天／通话／生命周期／媒体回归，补配置变化的实际行为断言，不提交。

### Task 3: 群活跃积分同步
**Files:** GroupActivitySyncPolicy.swift、SDKGroupActivitySyncCoordinator.swift、群成员同步接线处；Tests专项。
**Interfaces:** 按tenant/uid/session/group去重；group.lastSyncActiviteScoreime毫秒与interval秒比较；现有SDK积分同步及成员库复用。
- [x] 检查SDK异步数据库写入是否验证账号轮次，必要时补齐边界；按xgd在群成员同步后触发。
- [x] 测试间隔、重复请求、失败重试及退出／同UID新轮次迟到隔离；积分失败不挡成员展示。
- [x] 实现积分刷新配置生效后的当前群检查，不新增后台全群轮询，不提交。

### Task 4: 验证与独立复核
- [x] 跑SessionMaintenance、Calls、Chat、Groups、Media、Login/SessionRestore涉及入口；generic iOS无签名构建且PATH排除sentry-cli。
- [x] 独立只读review当前任务变更，修复具体问题；更新交接文档，报告源码／离线／构建与未验收设备范围。

## Execution ledger

Ruling: 使用当前分支、直接实施，不重复请求计划执行方式确认；用户已要求配置功能。业务积分同步按最新答复纳入，版本与日志排除。原设计中的tenant动态切换已按先前删字段要求移除。

Task 1: complete — 稀疏字段回归先RED后GREEN；最终14项账号快照检查通过，覆盖旧缓存及供应商切换。
Task 2: complete — AUTH后prepare、资料刷新、clear、消息／通话／媒体接线；Calls56项与SessionRestore通过，实际群权限方法15项通过。
Task 3: complete — SDK旧积分封装缺少身份写库守卫，改用同一SDK请求接口加Swift分页及锁内提交；积分策略13项、完整生产协调器边界9项通过，不修改SDK公共行为。
Task 4: complete — 独立复核发现并修复成员短页提前终止，生产协调器测试先RED后GREEN，复核无剩余重要问题。9组相关入口通过，最终generic iOS无签名构建exit0/BUILD SUCCEEDED。交接已更新。
Ruling: 最终userInfo配置使用稀疏UserSettings及缓存顶层版本标记；只旧缓存剥离设置，资料与消息继续展示。
Ruling: 发现xgd AppSign和WebSocket配置只是赋值，实际Zego引擎仅用AppID和房间token；本项目维持同一鉴权模式。
Evidence: /tmp/ddlNew-account-settings-maintenance-reviewed.log、/tmp/ddlNew-account-settings-calls-final.log、/tmp/ddlNew-account-settings-regressions.json、/tmp/ddlNew-account-settings-reviewed-build.log。
Limit: SDK／会话边界替身验证与编译不等于真实服务、数据库或设备验收；未操作设备、账号、xgd或提交推送。
