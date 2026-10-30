---
name: "叮咚聊 · 岩白与钴蓝 · 业务校正版"
description: "现有 iOS 视觉世界的静态业务细化"
colors:
  primary: "#2859BC"
  primary-soft: "#EAF0FA"
  canvas: "#FFFFFF"
  background: "#F3F5F9"
  ink: "#182536"
  secondary-text: "#647184"
  separator: "#E4E9F0"
  danger: "#B9413E"
  disabled: "#DCE2EB"
  outgoing-bubble: "#DCE7FD"
  media-background: "#101821"
  call-background: "#142239"
typography:
  brand-wordmark:
    fontFamily: "system-ui"
    fontSize: "29pt"
    fontWeight: 600
    letterSpacing: "1.3pt"
  page-title:
    fontFamily: "system-ui"
    fontSize: "29pt"
    fontWeight: 600
  navigation-title:
    fontFamily: "system-ui"
    fontSize: "17pt"
    fontWeight: 600
  row:
    fontFamily: "system-ui"
    fontSize: "17pt"
    fontWeight: 400
  body:
    fontFamily: "system-ui"
    fontSize: "16pt"
    fontWeight: 400
  metadata:
    fontFamily: "system-ui"
    fontSize: "13pt"
    fontWeight: 400
  button:
    fontFamily: "system-ui"
    fontSize: "16pt"
    fontWeight: 600
rounded:
  search: "10pt"
  control: "12pt"
  dialog: "15pt"
  sheet: "20pt"
spacing:
  page-inset: "20pt"
  field-inset: "15pt"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.canvas}"
    typography: "{typography.button}"
    rounded: "{rounded.control}"
    width: "350pt"
    height: "50pt"
  button-danger:
    backgroundColor: "{colors.danger}"
    textColor: "{colors.canvas}"
    typography: "{typography.button}"
    rounded: "{rounded.control}"
    width: "350pt"
    height: "50pt"
  button-disabled:
    backgroundColor: "{colors.disabled}"
    textColor: "{colors.secondary-text}"
    typography: "{typography.button}"
    rounded: "{rounded.control}"
    width: "350pt"
    height: "50pt"
  field:
    backgroundColor: "{colors.background}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.control}"
    width: "350pt"
    height: "52pt"
  search:
    backgroundColor: "{colors.background}"
    textColor: "{colors.secondary-text}"
    rounded: "{rounded.search}"
    width: "350pt"
    height: "42pt"
---

# Design System: 叮咚聊 · 岩白与钴蓝 · 业务校正版

## Overview

**Creative North Star: "岩白与钴蓝"**

沿用用户已批准的“岩白与钴蓝”。以白色内容面、深蓝灰文字和钴蓝操作建立稳定识别；用原生任务层级、信息密度和状态反馈组织页面，避免把聊天产品排成营销模板。

本次为现有视觉世界的业务细化，用户要求先看更新效果图，再继续应用实现。用户否定上一版双 D／错位口形标志后，已明确选择 D「笑着聊」，本轮将其统一到设计资产与效果图，沿用既定视觉世界与全部 token。文档记录本目录 render.swift 的实际静态表达；不是生产组件规范已经落地的声明。

**Key Characteristics:**
- 首页以日期与下一场活动组织注意力；消息页以会话、摘要和时间形成连续列表。
- 聊天保留气泡与输入栏的工作结构；表单让字段和提交状态形成顺序。
- 资料、群管理与群发按权限和任务分区；不把不同任务压成统一装饰卡片。

本次核对 `overview.png` 与 `flow-4.png`：首页的日期层级、会话平面列表、聊天气泡、资料分区及群发编辑/受理状态具有不同结构。独立审阅已对 057、074、099、092-attachment、流程板 4/5 及对应 JSON 状态完成五项修正复评，结论为 ship：该范围无剩余阻断项，菜单、表单、聊天和列表保持不同密度。此结论限于五项静态修正，不等于 146 项逐屏运行或辅助功能验收。

## Colors

Primary 使用钴蓝表达交互、选中及重点日期；浅钴蓝承载公告和录音等局部状态。Neutral 使用白色画布、灰蓝底色、深蓝灰正文和次级文字，细分隔线组织列表。危险红用于删除、失败或不可逆操作；禁用状态降低对比并保留明确文字。发出的消息气泡另用浅蓝。媒体和通话分别采用深色背景，以服务沉浸内容。

以上 frontmatter 是共享颜色的规范值，来源为 `render.swift`。头像示例的多种中性色、媒体占位色和展板背景不提升为品牌色。渲染器中变量 `green` 实际指向钴蓝，不能按变量名推断颜色。

## Typography

App 名称为用户确认的“叮咚聊”；“远山户外”仅为当前稿的示例俱乐部名称。启动字标使用系统字体 semibold、29pt、字距 1.3pt，居中；连接和登录页顶栏采用 23pt semibold 名称。身份展示板字标放大到 48pt，不作为所有页面的统一标题。

系统字体：渲染器使用 `NSFont.systemFont`，图标使用 SF Symbols；这里的 `system-ui` 是跨工具名称。记录的是逻辑点，导出图每点对应两个像素。浏览器组件预览每逻辑点对应一个 CSS 像素，属于展示映射，不是 iOS 字体实现。

常规正文与字段为 body，列表主文为 row；带次级信息的行标题可使用 medium。页面大标题、居中导航标题与小号辅助信息承担不同任务，不统一放大。实际页面还有登录欢迎标题（34pt）、首页日期（48pt）、tab 标签（11pt）和通讯录索引（10pt）；这些是局部用途，不是普通正文最小字号承诺。

`text` 使用按尾截断的文本框，框高为字号乘 1.7；这不是行高 token。`paragraph` 按词换行、额外行间距为 7pt、绘制框高 150pt。动态字体、长文本滚动和屏幕阅读器尚未验证，实施时需以原生布局重新检验，不能机械复制静态坐标。

## Layout

单屏画布为 390×844pt，2× PNG 为 780×1688px。普通正文左右各 20pt，可用宽 350pt；多行输入内侧横向各约 15–16pt。顶部导航分隔线在 y=107；根 tab 从 y=760 开始，高 84pt；常用底部主按钮 y=754、高 50pt。首页主动作位于内容中部，不套用底部固定模板。以上坐标描述静态稿，不构成所有设备的安全区规则。

列表以分隔线和内容对齐建立节奏，行间距随场景改变：联系人选择约 79pt，会话约 99pt，资料快捷项约 60pt。表单使用独立字段标签、输入面和状态文本；群发保留对象、可选标签、正文/附件和提交区。媒体页让内容占据主区域。只有需要共同承载内容或状态的区域才使用容器。

页面清单共 121 个原页面与 26 个补充状态、10 张流程板。数量只说明材料覆盖范围，不代表每个运行分支均已验证。未建立其他尺寸、横屏、iPad 或响应式断点。

## Elevation & Depth

App 内容采用平面分层，不使用投影。分隔线为 0.7pt；背景色区分聊天、字段与内容面。确认弹窗使用黑色 25% 遮罩，底部操作 sheet 使用黑色 22% 遮罩。展板上的圆角设备裁切是展示边框，不是应用容器。

没有静态稿可证明的动画、触觉、hover 或焦点样式；这些不生成假 token。

## Shapes

品牌状态为 `selected_by_user`，`selected = D`，名称「笑着聊」：微笑对话框使用 primary 与 canvas，不增加品牌色。当前规范资产为 `brand/mark.svg`、`mark.png`、`app-icon.png` 和 `identity.png`；矢量与 `brand/alternatives/d-smile.svg` 字节一致。上一版双 D／错位口形标志已被用户否定，归档于 `brand/archive-dual-d/`。

四案保留在 `brand/alternatives/` 作为选型记录：A「一声叮」、B「响铃」、C「你来我往」、D「笑着聊」。D 用微笑气泡表达亲近感，图形相对常见；用户选择不构成商标独占性结论。手工矢量以对应几何导出 SVG 与 AppKit PNG，不是 imagegen 输出。

规范 SVG 的 viewBox 为 256×256，透明标志与不透明方形图标均为1024×1024。图标圆角仅用于展示板模拟系统裁切，不烘焙进独立图标。候选目录另保留每案512×512透明标志；`comparison.png` 和 `startup-comparison.png` 保留选型前文案，属于历史比较板。此前 **OPTIONS-READY** 只评价候选展示；本轮选定 D 后的静态复评另见 `review.md`，不在此预先声明通过。

输入框、主按钮和消息气泡沿用 control 圆角；搜索框使用更小的 search 圆角；确认弹窗与 sheet 分别使用自己的圆角。通用旧式表单仍有 10pt 圆角与不同底色的实际例外，尚未宣称所有页面都已统一。头像按边长一半绘圆；通话接听/拒绝控件采用胶囊形。避免将局部圆角规则扩张成每行一个卡片。

## Components

### Brand and startup

系统启动稿与业务等待稿均使用白色背景，标志绘制框为 (125, 285, 128, 128)pt，字标在 (20, 438)pt 起、宽 350pt，位置保持一致。等待稿仅在下方增加 iOS 风格、不定进度 spinner 的静态帧与“正在打开…”；不增加倒计时、广告或人为等待时长。单张 PNG 不能证明 spinner 已播放动画。

当前生产 `LaunchWaitingView` 仍直接复用 `LaunchScreen.storyboard`。新增等待提示是效果图提案，尚未接入应用；原有连接、认证和路由顺序不变。连接俱乐部与登录页的品牌标志使用 42pt 绘制框，位置为 (14, 54)pt；示例俱乐部放在当前俱乐部信息中，不取代 App 名称。

资产来源：内建 imagegen 尝试一次后连接失败，没有采用生成位图；随后以手工指定矢量路径制作 SVG，并用 `render.swift` 的对应路径绘制 PNG 和展示板。`brand/identity.png` 展示标志、应用图标与 60/40/24pt 小尺寸对照；`flow-10.png` 展示系统启动、业务等待、连接、登录。这里只记录静态审视，没有将图标导入生产资产目录，也没有完成商店图标或真机启动验收。`brand/identity.png`、`flow-10.png` 及147个页面/状态与流程板已重新渲染，品牌位置统一采用 D；`flow-10.png` 已不是旧标志占位。此前旧标志的 ship 不作为本轮复评结论，最新静态审视以 `review.md` 为准。本轮没有替换生产 Assets 或 storyboard，也没有运行验收；应用实现继续暂停。

### Buttons

主按钮宽、高与圆角取 frontmatter，白字居中；禁用使用灰蓝面和次级文字，危险按钮用红色。页内文字动作、导航动作与底部主操作按任务选用；不为所有页面补一个统一主按钮。提交中的文案与禁用由对应业务状态决定。静态预览不提供真实点击或网络行为。

### Inputs / Fields

字段标签位于输入面上方（13pt medium）；单行输入高 52pt，通用多行字段高 116pt，群发正文区域实际高 166pt。字段和错误信息保持上下关联；失败稿保留之前输入。字段的聚焦、键盘和光标尚未在本轮验收。

### Navigation

根页面没有返回箭头；推入页面使用返回，模态验证按现有流程显示取消或完成。四个根 tab 依次为首页、消息、通讯录、我的。选中项用钴蓝图标/文字及短横线表达。普通导航标题 17pt semibold，业务根标题存在 23pt 的局部变体。

### Lists, selectors and chat

会话行展示摘要、时间和真实状态位；通讯录沿字母与入口分段。选择器仅在业务允许多选时展示选择/确认；点选 @ 成员立即插入、分组点选即提交、贴纸点按即发送。群权限决定入口与只读表达，不能从“展示了资料”推导“可编辑”。

聊天以发送/接收气泡、语音、已读或失败标记表达状态；禁言替换输入区的可操作表达。图片/视频沿全屏浏览器及允许的更多菜单动作，不添加假页码或常驻底部主按钮。群发新建可改对象，再发锁定对象与标签；已受理、接收对象和失败结果分别表达，不以已受理暗示全员送达。

## Do's and Don'ts

### Do:
- Do 让标题、现状和下一步操作在首屏可辨认，动作名称说明具体结果。
- Do 按页面任务调整密度：会话连续排列，表单留出输入空间，媒体优先展示内容。
- Do 在失败时保留已有输入，并在相关操作附近给出恢复路径。
- Do 将示例身份、数量与媒体的性质写在图外说明中，实际产品使用真实数据。
- Do 用真实权限决定编辑入口、只读文案和可执行动作。

### Don't:
- Don't 用统一大卡片、重复圆角容器或装饰图标替代页面自身结构。
- Don't 添加口号、营销副标题、虚构功能、虚构统计或没有业务结果的蓝色按钮。
- Don't 给点按立即生效的选择器追加统一的完成按钮。
- Don't 将群发已受理、静态成功态或演示报名写成实际送达与服务器业务验收。
- Don't 将此单尺寸效果图当作动态字体、辅助功能或真机适配证据。


人工审阅标准：页面能否凭内容辨认任务；每个显眼控件是否有源码支持的结果；密度是否随任务变化；是否存在装饰性重复卡片、口号或无依据数据。不能用“像原生”或“去 AI 化”的结论代替这些检查。

## IMPLEMENTATION — 2026-10-30 原生实现与证据

用户已批准业务校正版并授权继续实现；`feature-newUI-5` 上的 UI/UX 实施已恢复并完成本轮源码调整。上方 frontmatter、静态组件预览及“尚未接入／保持暂停”等段落保留为效果图阶段快照，**当前实施状态以本节为准**。静态稿 token 继续作为批准的视觉规格；以下记录实际原生实现差异，不改写或重新生成原规格。

### 原生来源与实际差异

生产语义色来源为 `ddlNew/Features/Home/Design/HomeTheme.swift`、`ddlNew/Common/Design/MessagingTheme.swift` 和 `ClubTheme.swift`。旧属性名 `forest / teal / darkTeal` 为调用兼容保留，当前表达钴蓝；LoginPalette 与 InvitationCodePalette 消费相同语义主题。

| 项目 | 已批准静态稿 | 当前原生实现 |
| --- | --- | --- |
| 主操作及前景 | primary + canvas | `primaryAction / onPrimaryAction`；浅色钴蓝＋白字，深色浅蓝 `#9EBDFF`＋深字 `#142239` |
| 内容／背景 | canvas / background | 内容 `#FFFFFF / #192432`、背景 `#F3F5F9 / #111923`（浅／深） |
| 正文／次级 | ink / secondary-text | 浅色沿规格；深色 `#EDF2FA / #ACB9CC` |
| 局部浅蓝面 | primary-soft `#EAF0FA` | HomeTheme.mintSurface 为 `#EAF0FC / #253754` |
| 分隔／描边 | separator `#E4E9F0`、0.7pt | MessagingTheme.divider `#E8EDF4 / #303E50`；HomeTheme.border `#DFE5EE / #354459`；现有行按组件使用0.5或1pt |
| 危险操作及前景 | danger + canvas | `error / onError`：`#B9413E / #FF9B95` 背景配 `#FFFFFF / #142239` 前景 |
| 发出消息 | outgoing-bubble | `outgoingBubble / onOutgoingBubble`：浅色沿浅蓝面与深正文，深色 `#2B4165 / #EDF2FA` |
| 字体 | 静态固定pt | 原生主要使用动态 `.body / .subheadline / .title*`，局部 `@ScaledMetric`；不能将macOS夹具字号当成iOS字号验收 |
| 主按钮 | 50pt高、12pt角 | 登录／邀请码最小50pt；通用ClubButtonStyle最小52pt；现有组件保持各自禁用表达 |
| 启动构图 | 固定390×844坐标、字距1.3pt | 同一storyboard，128pt标志水平居中，top按视图高度比例定位，字标距标志25pt、29pt semibold；原生storyboard未单设1.3pt字距 |

源码复核已将登录／邀请码及注销的前景改为对应语义色，避免深色浅蓝／浅红面仍使用白字。上述差异为源码事实，不是对全页面逐像素还原的声明。界面沿原数据绑定、动作、校验和权限所有权调整；未改业务Store、Services、Models、ViewModels或SDK边界。

### 品牌与启动

批准的 D「笑着聊」`brand/mark.png` 与 `brand/app-icon.png` 已原样复制到生产 `DingDongMark.imageset` 和 `AppIcon.appiconset/AppIcon.png`。`LaunchScreen.storyboard`、登录及邀请码采用新品牌；系统启动与业务等待共用构图。`LaunchWaitingView` 仅在实际等待期间增加原生不定进度指示器与“正在打开…”；没有人为延时、百分比、广告或路由时序修改。该源码和资产落地不等于系统启动快照或真机启动验收。

### 本轮检查与边界

整合者记录统一离线入口 **107/107通过**，generic iOS workspace 无签名整合构建已 `BUILD SUCCEEDED`。后续录音前景微调后的最终增量构建亦已 `BUILD SUCCEEDED`，日志 `/tmp/ddlNew-newUI-5-build-final.log`。构建与离线检查不证明真实服务器和设备行为。

原生组件视觉证据见仓库根 `.superpowers/sdd/2026-10-30-new-ui/visual-report.md`，临时产物 `/tmp/ddlNew-newUI-5-visuals/`。实际生产组件源码体经仅移除平台import并提供macOS颜色／zoom兼容层，生成24张PNG：HomeFeaturedActivity、HomeActivityRow、ClubButtonStyle、MessagingTabs、MinePageContent、SettingsPageContent；覆盖390／320长文本／768宽与浅深色，直接查看12张代表图。已查看图未见遮挡或裁切；这是特定组件布局与颜色的证据，不能扩展为整个页面、全部组件或设计稿保真度验收。独立复评见仓库根 `.superpowers/sdd/2026-10-30-new-ui/visual-review.md`：七张指定macOS组件夹具为 **SHIP**，仅覆盖该报告列出的画面，不能扩展为整应用发布结论。

macOS夹具仅证明显式辅助字号纵向布局分支与窄宽长文本换行；accessibility3／5产物尺寸相同，**没有验证iOS最大动态字体缩放**。实际iOS页面的键盘、安全区、导航／底栏、弹层、启动快照、验证码网页、图片权限及真实账号／服务器验收仍未完成。147个静态页面／状态仅代表设计材料覆盖，不代表147屏逐一运行检查。此次未通过模拟器或真机冒充这些证据。
