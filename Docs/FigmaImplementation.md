# 活动空间 · Figma 实现

设计来源：https://www.figma.com/design/43NO42xeEVZFJXzdKBBuQJ/Untitled?node-id=3-757

## 页面与流程

1. 启动闪屏 → 恢复会员状态。
2. 邀请码输入、验证中、错误状态 → 会员登录。
3. 会员登录与密码错误状态 → 首页。
4. 首页、活动列表、消息、通讯录、俱乐部、我的：使用系统 TabView 的六个页面，超出容量时由系统收纳到“更多”。
5. 活动详情 → 报名确认 → 报名结果；无名额时加入候补。
6. 已报名活动 → 输入签到码 → 签到结果。
7. 报名、候补、签到记录会随操作同步，支持取消参与。
8. 设置内提供退出登录、更换俱乐部、隐私说明和演示使用说明。

## 演示数据

设计稿标记全部数据为 Mock。本实现不连接真实俱乐部接口、不发送报名请求，日期沿用设计样例；不以设备当前日期限制演示签到。

- 邀请码：`100001`（其他邀请码显示邀请码错误；输入不限制位数）
- 会员卡号：`YS20260018`
- 密码：`123456`（其他密码显示登录错误）
- 签到码：`6812`（必须先报名，候补不能签到）

初始示例：轻徒步可报名，城市夜骑已报名，森林观鸟在候补。个人中心计数来自实际本地记录，不采用稿中与三张活动卡不一致的固定统计。

## 依赖复用

- SwiftUIX：Keyboard 管理登录与连接时的键盘收起。输入框使用原生 TextField / SecureField；实测 CocoaTextField 在当前模拟器快速连续输入时偶有丢字符，未用于会员凭证输入。
- AlertToast：连接中的加载提示与操作反馈。
- SwiftUI Introspect：滚动容器的交互式键盘收起。
- WCDBSwiftDynamic：以 actor 串行保存登录状态、报名和签到；密码不落库。
- UIAdapter、TBBasicLib、SwiftSocket 保留项目现有接入，当前页面不强行调用不相关功能。

## 素材与布局

图片资源全部提供显式 2x / 3x PNG，并在 Contents.json 中配置对应倍率。21 个 imageset 包含图标、logo 和启动页背景；同一资源两种倍率的逻辑尺寸一致。可编辑 SVG 原稿保存在 Docs/FigmaAssets 中，图标原稿位于 Icons 子目录。资源随 App 打包，不依赖临时 Figma URL。活动卡的青绿占位图本身就是原稿中的渐变矩形。

忽略稿中的设备外框、假状态栏与 Home Indicator，使用系统安全区。系统 TabView 提供标签栏、未读角标与无障碍语义，NavigationView 提供原生返回手势；iOS 26+ 使用系统玻璃外观，兼容 iOS 15。

## 验证

已添加共享 `ddlNew` Scheme 和 `ddlNewUITests` 测试 Target。UI 测试每次生成独立的 WCDB 测试目录，正常数据不受影响；同一次测试重启 App 时复用该目录以验证持久化。

```sh
xcodebuild -workspace ddlNew.xcworkspace -scheme ddlNew \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test
```

测试覆盖邀请码错误与成功、密码错误与成功、未确认须知时禁止报名、筛选列表内报名、错误与正确签到码、重启后恢复登录和签到记录、取消候补与重新候补，以及四个主标签页面。截图作为测试附件保存在 xcresult 中。

活动详情的导航入口独立于列表筛选与报名状态；签到完成、报名后卡片移出筛选结果时，不会因此丢失当前页面。

验证结果：2026-09-18，iPhone 18 Pro / iOS 27 模拟器编译与 UI 测试通过，1 条端到端用例、0 失败。已用 `otool -L` 确认 App 链接 `WCDBSwiftDynamic.framework`。该轮页面验收未进行真机测试。

最终运行截图位于 `Docs/Screenshots/`，包含邀请码、登录、四个主页面、活动详情、报名确认及成功、签到及成功等 12 张截图。

## 真机动态库打包修复（2026-09-18）

真机启动日志报告 `Library not loaded: @rpath/WCDBSwiftDynamic.framework/WCDBSwiftDynamic`。原项目只在 Frameworks 阶段链接该 SPM 产品，未把动态库复制进 App。模拟器可以从 Mac 上的构建目录加载动态库，因此前面的模拟器测试没有暴露漏嵌入问题。

已给 App Target 添加 `Embed Frameworks` 构建阶段，将同一 `WCDBSwiftDynamic` 产品复制到 `ddlNew.app/Frameworks/`，启用 `CodeSignOnCopy` 和 `RemoveHeadersOnCopy`；适用于 Debug 和 Release。保持动态库接入，未更改依赖版本或运行时搜索路径。

真机 Debug 签名构建通过，安装包中已确认包含 WCDB 动态库，App 及嵌入框架通过 `codesign --verify --deep --strict` 检查。

随后已将修复后的签名安装包安装到连接的 iPhone 12（iOS 26.3），启动成功，并确认 App 进程持续运行；本次验证针对启动闪退，未在真机重跑完整 UI 测试。

## 桌面 App 图标

`AppIcon.appiconset` 已接入现有 Figma 品牌标志，仅保留默认的 1024×1024 PNG；Xcode 生成设备需要的桌面图标尺寸。图标使用不透明背景，系统负责桌面圆角裁切。可编辑 SVG 源文件保存在 `Docs/FigmaAssets/AppIcon.svg`。

## 启动页、键盘与浅色模式

系统启动页使用 LaunchScreen.storyboard，显示品牌标志、“活动空间”和“一起发现，一起参与”，已移除底部恢复连接卡片。本地会话恢复期间复用同一 storyboard，不增加人为延时。

邀请码输入使用 FocusState：键盘上方的“完成”按钮和连接操作均可收起键盘，滚动容器支持交互式收起。输入会规范化数字，不限制位数、不截断，也不在输入第 6 位时自动收起键盘。非空邀请码即可提交；当前本地演示仍仅识别示例邀请码 100001。

App 的 Debug / Release 均配置 UIUserInterfaceStyle = Light，根视图同时指定 preferredColorScheme(.light)。系统启动页、App 页面和弹窗统一使用浅色。

本轮验证：iPhone 12 / iOS 26.5 模拟器的两条 UI 测试通过（0 失败），并在系统深色外观下检查 App 仍显示浅色。19 个 imageset 的文件与倍率尺寸校验通过。最终真机签名构建通过，已安装到连接的 iPhone 12 并成功启动。

取消邀请码位数限制后的专项 UI 测试通过：3 位邀请码能提交查询、10 位输入不截断且键盘保持显示，点击“完成”正常收起，示例邀请码仍可进入会员登录。

## 全部输入页的键盘收起

邀请码、会员卡号、密码、活动搜索和签到码统一接入 ClubKeyboardDismissal。输入框聚焦时在键盘上方显示“完成”，点击后取消焦点；文字键盘的完成/搜索键也会收起键盘。登录页与其他滚动输入页支持拖动收起，登录、连接和签到提交会主动收起键盘，登录帮助及更换俱乐部前也会结束输入。

消息与通讯录的页面设计和演示数据范围见 `Docs/Design/CommunityPages.md`。

通讯录点击人员直接进入一对一聊天，采用稳定的联系人会话 ID，与消息列表共用记录和草稿。重复打开同一人不会新增重复会话；成员资料和常用联系人操作移到聊天页右上角。

设置新增注销账号流程，与退出登录分开：说明影响、勾选确认、二次确认后执行。当前仅支持本机演示账号注销，尚无服务器注销接口。成功写入清空后的 WCDB 状态后才退出，并清除内存中的聊天记录、草稿、常用联系人；保留本机注销标记，重启后原演示账号仍无法登录。旧版本快照缺少注销字段时可正常解码。

消息行现在使用原生导航进入聊天页。聊天提供收发气泡、输入与本地发送、空白校验、自动滚动、键盘收起；本次会话内保留记录与草稿，发送后同步更新列表摘要。当前仍为本地演示，不向真实用户发送消息。

底部已恢复系统 TabView：原生玻璃标签栏与未读角标，由系统处理六个页面的“更多”入口。iPhone 12 / iOS 26.5 的三条系统导航回归测试全部通过；聊天专项测试随后通过，覆盖未读筛选下跳转、发送、返回、重新进入和通讯录操作。真机签名构建通过。

键盘修复验证：统一完成按钮已覆盖会员卡号、密码、活动搜索、签到码和邀请码。调整按钮容器后，两条 UI 测试完整通过（0 失败），包含再次输入、提交、签到和重启恢复。

本轮消息/通讯录完成后：iPhone 12 三条 UI 测试通过；iPhone 18 Pro 最大辅助功能字号下新增页面专项测试通过。真机签名构建通过，更新已安装到连接的 iPhone 12 并启动。新页面截图位于 Docs/Screenshots/13-消息列表.png、14-通讯录.png、15-成员资料.png。
