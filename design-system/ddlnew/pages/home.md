# 会员首页设计规范

> **PROJECT:** ddlNew
> **Generated:** 2026-09-29 10:46:00
> **Page Type:** 原生 SwiftUI 会员首页（非营销落地页）

> ⚠️ **IMPORTANT:** Rules in this file **override** the Master file (`../MASTER.md`).
> Only deviations from the Master are documented here. For all other rules, refer to the Master.

---

## Page-Specific Rules

### Layout Overrides

- 内容最大宽度 640pt，手机左右留白 20pt，区块间距 24pt。
- 底部导航只保留首页、消息、通讯录、我的；活动与俱乐部作为首页二级入口。
- 首屏顺序：会员问候、活动/俱乐部入口、下一场活动。下方是报名/候补/签到、活动推荐与公告。
- 保留原首页代码与业务页面；首页只改变展示和导航，不改登录 AUTH、数据存储或报名协议。

### Spacing Overrides

- 卡片内边距 16–20pt，卡片间距 12pt，圆角 20–24pt。
- 可点击区域至少 44pt；放大字体时入口和快捷操作改成纵排。

### Typography Overrides

- 使用 iOS 系统字体与 Dynamic Type，不引入 Web Fonts。
- 标题使用 title/title2/headline，说明使用 subheadline，次要计数使用 caption。

### Color Overrides

- 以 `HomeTheme.swift` 为实际色值来源：暖白底、森林绿主色、薄荷绿与浅沙色入口。
- 首页支持深浅两套颜色；活动卡固定深绿底与浅色前景，保证插画图层一致。
- 普通文字对比度至少 4.5:1；图标控件需要 3:1，装饰插画不承载状态。

### Component Overrides

- 使用原生 SF Symbols，不使用 emoji 图标或新增第三方图标依赖。
- 导航使用 NavigationStack；活动和俱乐部由类型化 destination 跳转，保留返回与 Tab 状态。
- 按压仅改变透明度，不缩放布局；无轮播、视差或持续动画，降低动态效果时无需额外运动。

---

## Page-Specific Components

- `ClubHomeView`：首页结构、页面内导航与公告弹窗。
- `HomeHubCard`：活动与俱乐部入口。
- `HomeFeaturedActivity` / `HomeLandscape`：下一场活动与纯装饰矢量山景。
- `HomeQuickEntry` / `HomeActivityRow`：会员日程与推荐列表。
- 昵称由外层传入，记录继续使用现有 ClubStore；当前活动与俱乐部仍为本机演示内容，不宣称已连接业务后端。

---

## Recommendations

- 验证小屏、横向、大字体、深色和减少动态效果；检查从首页和个人中心进入俱乐部，以及空记录中的发现活动入口。
