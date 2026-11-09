# 消息页连接恢复 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 冷启动本地路由零联网，消息页恢复认证并显示真实连接状态。
**Architecture:** 本地待恢复身份与 AUTH 资格分离。可注入的恢复协调器持有任务，页面只触发；状态监控适配系统网络与SDK，已有SDK仍独占已登录重连。
**Tech Stack:** Swift、SwiftUI、Combine、Network、NoaChatCore。
**Spec:** Docs/superpowers/specs/2026-11-09-message-connection-design.md

## Global Constraints
- 首次登录／注册保持原AUTH合同；xgd只读；无真实设备操作、提交或推送。
- 20秒当前节点探测、3秒超时；五种状态无固定次数上限。
- 保留当前工作区其它修改，使用现有feature-all-5 checkout。

## Review Focus
- 退出与挂起AUTH竞争：旧任务不能复活身份。
- 同UID重登：旧探测失败不能断开新连接。
- 本地存储错误：停止重试并保留凭据。
- 冷启动未读未知：不显示确定空态或清系统角标。
- 首次进入登录页：没有启动连接后仍能准备登录。

### Task 1: 本地路由与恢复协调器
**Files:** 新增 Features/Message/Services/MessageSessionRecovery.swift、Network/IM/MessageSessionRecovery+Live.swift；修改 AppStartupCoordinator、AppSessionRouter、ddlNewApp、LoginSessionService、LoginView；Tests/SessionRestore。
**Interfaces:** MessageSessionRecovery.prepare(userUID:license:)、ensureRecovery()、cancel()、setAvailable(_:)；hasPendingIdentity、failureMessage；生产闭包复用restoreCachedSession。
- [x] 修改启动断言，验证网络失败仍进入消息页且零连接/AUTH，运行看到失败。
- [x] 新增真实恢复协调器测试，验证幂等、取消、临时失败重试、终态失败、离线暂停、存储错误停止。
- [x] 实现协调器与本地入口接线，保留真实AUTH业务激活顺序。
- [x] 运行 SessionRestore 与新协调器检查，预计全部PASS。

### Task 2: 连接状态与探测
**Files:** 新增 MessageConnectionStatus.swift、MessageConnectionMonitor.swift、MessageConnectionStatusView.swift；修改 MessageView、IMUserAuthenticationDelegate/Service、IMLoggedInReconnectCoordinator。
**Interfaces:** 状态resolve使用网络可用、认证、恢复失败、连接阶段及SDK事件；monitor的setVisible、setForeground负责探测资格。
- [x] 添加状态优先级和迟到探测失效检查，旧实现应失败。
- [x] 实现固定状态行、五类文案、真实AUTH门禁，消息页出现触发恢复；20秒/3秒探测复用SDK并隔离轮次。
- [x] 验证后台/离页/换号取消、连接质量互斥及失败交回SDK重连。

### Task 3: 集成验收与交接
**Files:** 相关测试夹具、Docs/PROJECT_HANDOFF.md、README.md。
- [x] 运行相关离线脚本与无签名workspace构建；检查编译错误并修复。
- [x] 独立源码复核并处理重要发现，新增有意义的回归。
- [x] 记录验证结果、真机待验与最终实现边界；不提交推送。

## 执行记录
- 用户已批准设计并明确“开始实施”；直接在本会话实施，不重复请求计划批准。
- 现有工作区有未提交网络检测改动，保留并复用当前分支；不创建隔离后遗漏既有功能。

- Task 1/2/3 complete：14个最终专项入口exit0，无签名workspace构建exit0，diff检查通过；日志与真机待验见PROJECT_HANDOFF。
- Ruling: 使用现有功能分支和工作区，不按技能默认创建worktree/commit，避免遗漏用户同期改动并遵循仓库不自动提交约定。
- Review fixes: AUTH取消与主动退出争抢清理、首次超时清Push两项均真实回归RED/GREEN；复核已确认解决。
- 生产状态组件已匿名静态渲染；未操作设备，系统手势／VoiceOver和端到端网络仍待验。


## 追加实施：消息列表不等待连接（2026-11-09）

- 消息页触发后先异步读 SDK 本地会话，离线也执行，保持启动路由零连接。
- 增加非破坏性已有数据库打开和临时身份清理，禁止快照读取建库／修复／删除或表迁移。
- 同账号 AUTH／重试保留 Store 快照，成功同步更新；退出和换号隔离迟到结果。
- 本地读取失败支持离线重试，与正式 AUTH 串行。
- 增补 Store、恢复时序、生产 SDK 本地读库方法回归，复核后无签名构建并更新交接。
