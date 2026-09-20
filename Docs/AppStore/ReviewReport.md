# App Store 上架检查报告

检查日期：2026-09-18。结论：**HIGH RISK / 尚不具备可确认的提交条件**。

## 项目概况

- SwiftUI 原生 iPhone App，最低 iOS 15，Bundle ID `com.sigua.ddlNew`，版本 1.0 (1)。桌面名称 DDL，页面品牌活动空间；提交元数据时需统一。
- 保留本地 Mock 数据和现有俱乐部、聊天功能，这是当前产品要求。没有业务后端，不能将界面完成或构建成功等同于业务服务完成。
- 本轮使用 `appstore-review` skill。该 skill 引用的本地 guidelines-summary.md 缺失，已改为查阅 Apple 官方最新页面。检查覆盖 skill 步骤 0–7；未登录 App Store Connect、未上传二进制、未提交审核。

## 已修复

1. 登录前即可打开隐私政策与使用支持，设置内增加政策、支持和完整开源许可入口。网页有 App 内离线副本，无需登录或网络才能阅读。
2. 增加 App 隐私清单；SwiftUIX 0.3.2 的 Package.swift 未打包其清单，因此附带独立的 SDK 隐私资源 bundle，说明 UserDefaults 包装 API 的 C56D.1 用途。
3. WCDB 2.1.16 / SQLCipher 1.4.7 的本机数据库文件元数据用途声明为 C617.1，在框架嵌入及签名前复制入动态框架。磁盘 API 的未解决事项见下文，不能把清单视为已完全合规。
4. 保留 WCDBSwiftDynamic 的 Embed Frameworks 和 CodeSignOnCopy，避免动态库缺失导致真机启动崩溃。
5. 数据库目录及历史数据库文件添加 iOS 文件保护，目录排除常规备份；不持久保存密码。读取失败时保留原数据、提供重试，不再进入新账号流程覆盖损坏记录。
6. 注销流程先保存删除状态，成功后才退出并清理聊天会话；取消操作不删数据，写入失败不显示成功。保留本机注销标记。此功能仅对本机数据有效。
7. 移除未被业务代码调用的 TBBasicLib 的 App target 链接，其 SPM 包引用仍保留。其 UserDefaults 系统键读取等代码不再随 App 链接。
8. 主开发语言改为简体中文，使系统控件与中文界面语言一致。保留浅色模式、系统 TabView、启动页和不透明 1024×1024 AppIcon。
9. 按要求移除消息、通讯录、成员资料和设置页中的体验提示。没有引入审核专用开关、远程隐藏行为或虚假的服务器成功状态。隐私政策仍描述实际本机处理方式。

## 必须处理的风险

### [CRITICAL] 2.1 / 2.2 / 4.2 — 业务完整性

位置：`ddlNew/Models/ClubStore.swift:128`，`ddlNew/Models/ClubCommunity.swift`。

邀请码、账号校验、活动、联系人及聊天数据仍为预置内容。聊天文字只进入进程内存，报名/候补/签到只更新本机状态。没有真实人员收发消息、真实俱乐部连接、实时活动管理或独立创建个人活动的能力。更改文案不能补齐这些功能。当前仅能继续开发/内部验证；面向公众提交前需实现与产品承诺一致的业务，或经产品确认改造成独立可用的离线工具。

### [CRITICAL] 1.5 / 5.1.1(i) / 5.6.2 — 真实运营联系信息

位置：`ddlNew/Legal/support.html`、`ddlNew/Legal/privacy.html`。

静态支持页已有操作说明，但没有真实客服邮箱/联系方式和运营主体。不得虚构联系方式。需要实际负责人提供可接收并回复请求的渠道及正式主体信息，并同步 App、网站、App Store Connect。

### [CRITICAL] Required Reason API — WCDB / SQLCipher 的磁盘 API 理由未闭环

证据：WCDBSwiftDynamic 二进制导入 `_stat`、`_fstat`、`_lstat`、`_statfs`、`_fstatfs`。SQLCipher `src/os_unix.c` 5667、6374、7783 行的磁盘 API 主要读取文件系统类型、只读状态、锁机制标志，不能据此直接声称“检测剩余空间以决定是否写文件”。

目前仅声明已验证的 FileTimestamp C617.1。没有随意添加 DiskSpace E174.1。需由 SDK 维护者提供符合用途的声明/实现，或维护经过验证的 SDK 补丁并使用匹配的批准理由，再对最终 Archive 生成隐私报告并执行 App Store Connect 验证。不要只修改 DerivedData 缓存来掩盖问题。

Apple 文档要求声明位于使用相关 API 的可执行文件/动态库所属 bundle；SDK 不能依赖另一 SDK 或 App 的声明代替自己的说明。[Required Reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)

## 条件性风险与人工检查

- **账号注销（5.1.1(v)）：**当前没有在线开户，已实现本机清理。未来开放真实账号创建时，必须接入服务器删除、会话撤销及相关数据删除/保留规则。不能把退出登录作为注销。
- **UGC（1.2）：**当前没有对外传输用户内容；未来开放真实聊天时，需提供内容处理、举报、屏蔽、响应流程与有效联系渠道。单加“举报成功”按钮不能替代处理系统。
- **隐私标签：**目前 App 不上传会员数据，无广告/分析/跟踪 SDK。在线文档访问会产生托管服务的常规网络请求；政策已区分 App 本机处理与网站访问。接入后端后必须重新盘点，不能沿用“不收集数据”的判断。
- **加密出口声明：**SQLCipher 使用系统 CommonCrypto，业务未调用数据库加密配置。仍需基于最终分发二进制确认 App Store Connect 出口合规问题，没有直接写入未经确认的 `ITSAppUsesNonExemptEncryption=NO`。
- **权限：**代码没有申请相机、照片、系统通讯录、定位或麦克风权限。签到用手动码；无需为依赖库“可能提供”的功能添加无用途的权限描述。未来启用时再配置。
- **SDK 清单：**UIAdapter 隐私资源随包提供；SwiftUIX/WCDB 有本项目补充声明。SDK 升级后必须复核并移除过时补丁。TBBasicLib 保留为可解析包，不随 App 链接。
- **名称与素材（2.3、5.2）：**确认 DDL / 活动空间的最终名称，确认 Figma 素材及品牌的商业使用权。开源许可不代表已取得设计素材授权。
- **设备与系统：**iPhone 是目标设备，并非强制改为 iPad 原生 App；仍需在 iPad 兼容运行、最低支持系统和实际分发 SDK 上复测。完整 Dynamic Type / VoiceOver 审计未在本轮穷尽。
- **提交资料：**填写真实年龄分级、分类、支持网址、隐私网址、审核账号和功能说明，提供实际使用截图。按发行地区核实适用资质、备案和主体要求。

## 排查结果

| 检查项 | 状态 |
|---|---|
| 基础 Bundle 元数据、启动资源、图标 | 已检查 |
| ATS 任意加载、HTTP 业务 URL、硬编码 IPv4 | 未发现 |
| 敏感权限使用、未用后台模式 | 未发现 |
| App 源码强制解包、try!、fatalError、真实 API 密钥 | 未发现 |
| 私有系统 API、远程脚本下载执行 | App 业务代码未发现；SQLCipher 禁用 load extension |
| 第三方登录 / Sign in with Apple | 当前不适用，只有本机账号校验 |
| 数字内容支付 / IAP / 恢复购买 / 订阅 | 当前不适用，无交易入口 |
| 广告、ATT、儿童服务、HealthKit、VPN、MDM | 当前不适用 |
| 应用外数据收集/用户画像/设备指纹 | App 业务代码未发现 |
| 真实业务、人工支持、完整 SDK API 声明 | 未解决，不能提交为已就绪 |

## 官方依据

[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) · [Required Reason API 分类与理由](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype) · [第三方 SDK 要求](https://developer.apple.com/support/third-party-SDK-requirements/)

本报告是代码及归档检查，不是 Apple 审核结论，也不承诺通过审核。

## 已发布静态网址

- [隐私政策](https://huodong-space-help.longhaoran682.chatgpt.site/privacy.html)
- [使用支持](https://huodong-space-help.longhaoran682.chatgpt.site/support.html)

Sites 已返回发布成功，访问权限为公开，源版本 2。网址已接入 App；政策和支持页仍需补真实运营主体及客服渠道。

## 验证记录

- Release 构建及最终 Archive 均通过。最终包中的隐私政策、支持页、网址配置与源文件逐字节一致，App / WCDBSwiftDynamic 的 codesign --verify --deep --strict 均通过。App、SwiftUIX、UIAdapter、WCDB 四份隐私清单均已进入归档。归档路径：`/tmp/ddlNew-AppStore-Audit-Final.xcarchive`。
- iPhone 18 Pro / iOS 27：`testLegalDocumentsBeforeLogin`、`testAccountDeletionAndRestart` 两项通过（2026-09-18，结果 `/tmp/ddlNew-appstore-final-tests.xcresult`）。覆盖未登录阅读离线文档、注销取消/确认、重启后拒绝旧账号登录；测试使用独立数据库。
- iPhone 12 / iOS 26.5：`testContactChatAndMessages` 通过。先前同一次运行中的注销测试曾因 UI 自动化按钮查询重复而失败，改为唯一匹配后在上述设备复测通过；没有把那次混合结果标为全通过。
- 静态页本地返回 HTTP 200；HTML 本地链接全部存在。Sites 版本 2 文案更新已发布成功且保持公开。
- 图标 1024×1024、无 alpha；App 源码无“演示”“示例”“仅供体验”“Mock”界面字符串。法律许可原文和开发检查文档不属于界面提示。
- 编译工具 Xcode 27.0 (27A266a)，SDK iPhoneOS 27.0。当前归档使用开发签名进行本地验证，没有执行 App Store 分发导出、上传或 Apple 自动验证；正式提交需使用当时被 App Store 接受的 Xcode / SDK。

- 最终归档已安装到 iPhone 12。自动启动因设备锁屏被系统拒绝（CoreDevice Locked），本轮没有宣称真机启动测试通过。设备解锁后可直接打开已安装版本。

- 最终网页发布：Sites 版本 2 返回 succeeded，地址 https://huodong-space-help.longhaoran682.chatgpt.site ，与 App 内文档内容一致。

- 最终 Debug 真机构建也通过，WCDB 隐私清单打包存在且签名通过；普通构建和 Archive 两条路径均已验证。
