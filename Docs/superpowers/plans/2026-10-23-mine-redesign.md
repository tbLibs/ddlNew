# 我的页面重设计实施计划

> **For agentic workers:** 使用 superpowers:executing-plans 按步骤实现。用户已确认设计并要求执行，直接在当前会话落地，不提交或推送。

**Goal:** 将用户确认的自然留白方案落地到整个“我的”页。

**Architecture:** MineView 保持真实资料、文件Host和弹层状态所有权。MinePageContent 仅组合身份、活动、俱乐部与账户服务，沿用原值路由和 HomeTheme，不创建额外导航栈或业务Store。

**Tech Stack:** iOS16、SwiftUI、UIAdapter、Kingfisher。

**Spec:** Docs/design/mine-redesign-2026-10-23.md

## Global Constraints

- 保留真实昵称、账号、头像及UID隔离；不新增请求或缓存。
- 采用现有HomeTheme浅深色与UIAdapter几何适配，字号随Dynamic Type变化。
- 四类活动、俱乐部、隐私、黑名单、投诉、设置入口全部保留。
- 二维码使用ContactsPageRoute，复制账号使用现有居中Toast。
- Mobile MCP保持暂停，不操作设备；保留所有同期消息、群发、工程与依赖改动。

## Review Focus

- 长昵称与账号：可换行，复制按钮保持44pt。
- 辅助字号：身份纵向、活动单列，内容可滚动。
- 缺资料或退出：无旧账号头像、复制或二维码入口。
- 二维码push/返回：使用原路径控制底栏。
- 深色：所有表面和文字使用HomeTheme语义色。

## Task 1: 页面实现与验证

- [x] 更新 MineView.swift；新建 Components/MinePageContent.swift，组合身份、两列活动和两组菜单。
- [x] 复用现有二维码值路由、复制账号提示和所有弹层行为。
- [x] 用实际生产展示组件渲染匿名浅深色、窄屏及辅助布局静态预览；macOS宿主不代表iOS真实字号；不新增镜像实现的单元测试。
- [x] 执行相关既有回归和无签名workspace build；复核diff。
- [x] 请已参与的UI设计师复核生产布局，未发现明确阻断问题。
- [x] 更新设计稿状态与 PROJECT_HANDOFF.md，报告原生设备待验边界。
