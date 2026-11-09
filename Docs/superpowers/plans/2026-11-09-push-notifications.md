# Push Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在 ddlNew 完整迁移 xgd 推送，xgd 文件保持只读。
**Architecture:** Swift 通知协调器持有系统通知、Token绑定和偏好生命周期；SDK薄适配提供真实数据；导航接入现有ActivityNavigationScope。
**Tech Stack:** SwiftUI, UserNotifications, Noa SDK, Combine。
**Spec:** Docs/superpowers/specs/2026-11-09-push-notifications-design.md（用户已确认完整迁移）

## Global Constraints
- 只修改 ddlNew；保留所有既有工作区修改；不提交或推送。
- UID、租户、登录轮次隔离；不恢复远程systemConfig；不更改pushMsg补发。
- 本地/前台提醒遵循总开关及免打扰；前台同会话静默；系统后台声音受iOS控制。
- 真实APNs送达另验，不将无签名构建当作真机验收。

## Review Focus
- Token先到/后到、请求期间换号：最后绑定必须属于当前身份。
- 冷启动无归属payload及相同UID重登：不误入旧会话。
- 偏好请求失败或乱序：保留已确认值，不覆盖新身份。
- SDK已有自动声音：普通消息只由一个所有者提醒，不抢通话音频。
- 初始未读未知：不将默认零写入系统角标。

### Task 1: 纯模型及策略
**Files:** Features/Notifications/PushModels.swift; Tests/Push/PushPolicyChecks.swift; Tests/Push/run-checks.sh。
**Interfaces:** PushIdentity、PushPreferences、PushDestination.parse、PushEvent、PushDeliveryPolicy。
- [x] 先编写身份/过滤/payload/@命中/去重回归并确认缺失实现失败。
- [x] 实现类型和纯策略，再运行swiftc离线回归通过。

### Task 2: 系统及SDK适配、协调器
**Files:** Features/Notifications/PushCoordinator.swift、PushSystemClient.swift；Network/IM/Notifications/SDKPushClient.swift；AppDelegate.swift；LoginSessionService.swift；ddlNewApp.swift。
**Interfaces:** PushCoordinator.shared.activate(identity:), close(), prepareSignOut(), receivedToken(_:), setForeground(_:), preferences, pendingNavigation。
- [x] 编写协调器假系统/假运输回归，覆盖先后顺序、退出换号及失败回退；确认失败。
- [x] 接入SDK注册/删除、偏好读取保存及实时消息快照；协调器校验轮次，系统delegate在启动绑定。
- [x] SDK普通消息自动声音增加独立应用接管开关（默认保持旧行为），仅ddlNew接管，不影响通话。
- [x] 运行策略和协调器回归通过。

### Task 3: 导航、设置、角标
**Files:** TabbarView.swift、ActivityNavigationScope.swift、ChatRoomView.swift、SettingsScreen.swift；Features/Notifications/PushSettingsView.swift；相关Store快照就绪属性。
**Interfaces:** 每Tab注册当前ActivityNavigation；待点击仅主界面就绪后消费；设置绑定协调器。
- [x] 验证导航待就绪/重复点击及偏好切换状态。
- [x] 设置页通知入口，授权状态/系统设置、三个真实开关及失败重试。
- [x] 就绪角标和可见聊天抑制接线，现有已读行为不变。

### Task 4: 验证与交接
- [x] 运行Push专项、SessionRestore、SessionMaintenance、Chat及相关导航回归；修正新增依赖夹具。
- [x] 无签名generic iOS workspace build通过；独立代码复核后解决重要问题。
- [x] 更新PROJECT_HANDOFF、设计状态及验收清单；核对xgd diff摘要未变。

## Execution ledger
- 用户已批准完整设计并明确xgd不可修改；依据主指令持续执行，不重复请求计划批准。
- 使用现有feature-all-5工作区，不创建新worktree；已有未提交功能需一并保持可编译。
- Task 1: complete：Push模型回归26项通过，覆盖非法payload、同进程旧登录轮次、跨进程冷恢复、@文案和群通知开关。
- Task 2/3: implemented：真实SDK/系统通知、设置、导航、角标已接线；首次完整build通过，最终修正后构建进行中。
- Review fixed：移除写操作3秒Swift等待超时，PushRequestLane等待SDK真实终态；取消等待不代表底层取消，串行专项2项通过。读取偏好先等待旧写结束。底层运输超时后服务端仍可能延迟执行的极端情况需要服务端版本/幂等协议，客户端不作绝对顺序保证。
- Review fixed：普通@其他人恢复正文；群公告检查groupInformStatus；本地payload加入process/session并严格验证。
- Ruling：后台系统通知的声音/震动由iOS管理，独立震动设置用于前台；APNs服务端设置仍需服务器配合，客户端不读取或上传cer私钥。
- Ruling：保留当前feature-all-5及未提交改动，不按技能默认步骤创建worktree/提交；所有xgd访问只读，git status+diff SHA256与开工一致。

- Final: Push专项29+13+2=44项通过；最终workspace无签名build exit0，/tmp/ddlNew-push-build-verified.log。
- Final: 全量离线112/113通过；旧日志脱敏夹具缺少Socket诊断替身而编译失败（Tests/MigrationAcceptance/run-log-redaction-checks.sh），不是推送改动导致，未修改其生产代码。证据 /tmp/ddlNew-push-full-qa/summary.json。
- Final: xgd工作区status与diff SHA256保持不变；交接已更新，真机/APNs外部配置仍按验收清单另验。
