# ddlNew 项目交接文档

2026-10-15 01:17收尾：当前feature-message-4 / 6252ab8，后续改动保留工作区，未自动commit/push。xgd旧Mac已实际启动、核对同服务器及真实身份，完成角色徽标、成员行直达、独立移除入口和公告只读界面对照；旧App已Stop，临时Per-User DerivedData恢复Default，旧仓库干净。最终62/62组离线（311.43秒）与签名build通过，真机保数据覆盖安装成功；完整116项逐项状态见[验收台账](CONTACTS_MESSAGES_PARITY_QA_2026-10-14.md)。

删除持久化修正已真机闭环：AUTH latest写回前保护真实SDK库status0/2，删除必须确认SDK写入成功；新条实际删除→终止重启→AUTH→会话仍无原文→搜索空通过，未删对照仍在。A此前复活的自建DELETE_2230也已主动重新删除，B保留原条。

群公告删除后返回公告列表已在最终无诊断包真机通过；服务器失败仍留当前页。备注即时同步、双端Unicode/换行实收及双方1/1已读、B主动撤回只有一个占位均通过。A23:08标记仍是普通文本，最后Mac主动撤回菜单未打开，未冒充第二方向主动撤回通过。

文件联调补修已真实闭环：STS成功回执的data.credentials按真实合同映射，临时凭据不缓存/序列化；137字节QA文件A真实发送、B下载/系统预览与字节SHA一致。文件wire补稳定前缀，最后01:12新消息两端保留完整原名；Mac和真机只读详情关闭均回聊天。仅手动未读/已读接受SDK明确空成功回执，明确false及未知非空仍拒绝，最终真机标记/筛选/清除不再误报Toast。合并转发2条真实实收、作者/原时间/正文通过。完整建群人数、实际移除/转让/解散及三角色矩阵未验，需可恢复测试群及第三个可控身份；媒体全类型/供应商、弱网重连/同账号多端仍有未完成分支。首页/我的森林绿保持，临时诊断已移除。以下早期历史快照不代替最新验收台账。

更新时间：2026-10-15

本次消息 / 通讯录 / 群聊 UI 对话的最新交接入口：[会话交接文档](SESSION_HANDOFF_2026-10-14_MESSAGES_CONTACTS_UI.md)。包含最终用户要求、工作区边界、验证证据和真机待验收项；以下早期阶段快照需结合最新追加记录理解。

本文供新的 Codex 对话接手项目。先执行“接手检查”，再根据任务读取对应源码；不要只凭本文修改代码，因为分支和工作区可能已经变化。

## 接手检查

1. 使用 `/Users/taobotaobo/Desktop/ddlNew/ddlNew.xcworkspace`，不要用 `ddlNew.xcodeproj` 单独构建。
2. 执行 `git branch --show-current`、`git status --short` 和 `git log -5 --oneline`，保护用户已有改动。
3. 阅读根目录 `README.md`，它记录当前目录职责和通讯录边界。
4. 涉及旧逻辑对照时，只读参考旧项目 `/Users/taobotaobo/Desktop/ddl`，不要把旧项目文件直接复制回新项目。
5. 修改完成后至少执行本文“验证命令”中的全量构建。通讯录测试脚本已在当前提交中删除；通讯录相关修改应先补回等价验证，再声明行为通过。

## Git 快照

记录时状态：

- 当前分支：`feature-message-4`
- 当前提交：`f975457 feat：修复警告`
- 远端：`origin` → `git@github-second:tbLibs/ddlNew.git`
- 工作区：干净
- 现有里程碑分支：
  - `feature-login-1`
  - `feature-IMSDK-2`
  - `feature-contacts-3`
  - `feature-message-4`

以上只是 2026-09-30 的快照，新对话必须重新检查。

## 当前完成度

已经跑通的主链路：

```text
邀请码
→ 五路 DNS 并发解析
→ 节点归一化
→ OSS Auth 竞速
→ Nav Protobuf 响应校验与解密
→ 保存导航、HTTP/TCP 节点和系统配置
→ SDK 配置
→ TCP/ECDH 节点竞速与正式连接
→ 获取 systemConfig
→ 登录页
→ 检查账号是否存在
→ 获取登录加密密钥并加密密码
→ 发送账号登录请求
→ 保存用户资料和凭据
→ SDK 用户配置与用户数据库就绪
→ 等待用户 AUTH ACK
→ 进入四栏主界面
```

应用重启时先显示与 LaunchScreen 一致的等待页并恢复邀请码连接。连接失败停止启动恢复并返回邀请码页，保留上次入口；连接成功后读取同一俱乐部的成对资料、Token 和设备凭据，AUTH 成功才进入主界面。没有缓存会话或用户认证失败时显示登录页；暂时超时保留凭据，明确失效才删除。AUTH 成功但根路由尚未接收结果的取消窗口会撤销运行时会话，避免下一次恢复被残留所有权阻塞。

## 启动与路由

入口文件：

- `ddlNew/App/ddlNewApp.swift`
- `ddlNew/App/Startup/AppStartupCoordinator.swift`
- `ddlNew/App/Routing/AppSessionRouter.swift`
- `ddlNew/App/Routing/RouterTool.swift`

根路由只有三种业务页面：邀请码、登录、主界面。缓存恢复期间 `hasRestoredLocalEntry == false`，继续展示 `LaunchWaitingView`，不提前创建登录页。

重要约束：

- 本地有用户资料或 token 不代表登录成功。
- 账号登录 HTTP/TCP 请求返回成功也不代表登录成功。
- 必须收到 SDK 用户 AUTH ACK，并确认连接轮次、用户 UID、数据库状态仍一致，才允许进入主界面和请求后续业务数据。
- 已登录后的临时断网保留凭据，由 SDK 重连；启动连接失败回邀请码页，启动 AUTH 超时回登录页，均不删除有效缓存。明确的账号失效才清理缓存。
- “更换俱乐部”清除启动入口和当前会话，再回到邀请码页。

## DNS、OSS 与导航

核心文件：

- `ddlNew/Network/DNS/HostNodeRaceManager.swift`
- `ddlNew/Network/DNS/DNSHostNormalizer.swift`
- `ddlNew/Network/DNS/DNSUDPResolver.swift`
- `ddlNew/Network/OSS/OSSNodeRaceCoordinator.swift`
- `ddlNew/Network/OSS/OSSAuthRequestBuilder.swift`
- `ddlNew/Network/OSS/OSSAuthTCPClient.swift`
- `ddlNew/Network/OSS/OSSAuthResponseDecoder.swift`
- `ddlNew/Network/OSS/OSSNavigationStore.swift`
- `ddlNew/Network/OSS/OSSConnectionBootstrap.swift`
- `ddlNew/Protocols/Nav/nav.proto`
- `ddlNew/Protocols/Nav/Nav.pb.swift`

五路 DNS 来源同时启动：

1. 阿里 HTTPDNS SDK AAAA：`ALIDNS`
2. 腾讯 DoH AAAA：`TENCENT_AAAA`
3. Cloudflare DoH TXT：`CF_TXT`
4. Cloudflare DoH AAAA：`CF_AAAA`
5. 阿里 DoH TXT：`ALI_DOH_TXT`

每一路先解析并归一化候选节点，再按该路候选顺序尝试 OSS Auth。第一个通过请求、响应校验和解密的节点获胜，其他任务取消。DNS 最先返回不等于最终获胜。

域名归一化优先使用 `CocoaAsyncSocket` 的 UDP DNS 实现；DoH/系统结果和已是 IP 的节点走统一去重、Host/Port 规范化逻辑。

`Nav.pb.swift` 是由 `nav.proto`、`protoc` 和 `protoc-gen-swift` 生成的文件。协议变化时修改 `.proto` 后重新生成，不手工改生成代码。

## SDK、TCP/ECDH 与系统配置

核心文件：

- `ddlNew/Network/IM/IMConnectionCoordinator.swift`
- `ddlNew/Network/IM/IMSDKConnectionAdapter.swift`
- `ddlNew/Network/IM/IMHandshakeWaiter.swift`
- `ddlNew/Network/SystemConfig/SystemConfigService.swift`
- `ddlNew/Network/SystemConfig/SystemConfigRecord.swift`
- `ddlNew/Network/SystemConfig/SystemConfigStore.swift`
- `ddlNew/Network/NetworkPath.swift`

连接顺序固定为：

1. 清理并等待旧 Socket 完成释放。
2. 配置 API、邀请码、SSO 信息和组织标识。
3. 并发探测 TCP 候选，首个完成真实 ECDH 的节点获胜。
4. 对获胜节点建立正式 Socket 并再次完成 ECDH。
5. 获取并解析 `systemConfig`。
6. 应用 tenantCode、captchaChannel 等 SDK 配置。
7. 整条链路成功后才把 `lastLiceseId` 标记为可恢复入口。

所有服务器业务 Path 放在 `ddlNew/Network/NetworkPath.swift`。`systemConfig` 当前路径为 `/biz/system/v2/getSystemConfig`。

系统配置兼容旧服务端混合类型：字符串、数字和布尔值可能互相混用，解析层负责归一化，ViewModel 不直接猜类型。

## 登录、用户会话与 AUTH

核心文件：

- `ddlNew/Features/Login/ViewModels/LoginViewModel.swift`
- `ddlNew/Features/Login/Services/AccountLoginService.swift`
- `ddlNew/Features/Login/Services/LoginSessionService.swift`
- `ddlNew/Network/IM/SDK/SDKAccountLoginClient.swift`
- `ddlNew/Network/IM/IMUserAuthenticationService.swift`
- `ddlNew/Network/IM/IMUserAuthenticationDelegate.swift`
- `ddlNew/Common/User/UserSessionStore.swift`
- `ddlNew/Common/User/UserCredentialStore.swift`
- `ddlNew/Common/Database/UserDatabaseManager.swift`

登录请求复用 SDK 已有的验签、解密和 HTTP 转 TCP 通道：

1. 检查账号是否存在，不存在时返回对应业务提示，再获取一次性 `encryptKey`。
2. 使用 `LXChatEncrypt.method4(encryptKey + password)` 加密密码。
3. 发送账号登录请求。
4. 用 ObjectMapper 映射响应。
5. 保存用户资料、token、deviceSecret 和登录上下文。
6. 配置 SDK 用户并初始化用户数据库。
7. 注册连接和用户代理，发送 AUTH。
8. 等待 AUTH ACK 成功回调。

登录页“记住密码”默认开启。密码和会话凭据分别保存在不同 Keychain 项中；用户资料和非敏感状态存 AppStorage。缓存启动不会重新发送账号密码请求，而是使用保存的用户资料、token 和设备凭据恢复 AUTH。

不要在项目文档或提交信息中记录测试密码、token、deviceSecret、Sentry token 或其他运行时认证数据。

## 本地持久化

固定 key 定义在 `ddlNew/Configuration/Const.swift`，当前策略是每类数据只有一份，不按邀请码拼接 key：

- `ddlNew.ossNavigation.v1`：ObjectMapper JSON，结构与旧项目 `NoaSsoInfoModel` 的用途对齐，包含导航节点、配置和 `lastLiceseId`。
- `ddlNew.selectedHTTPHost.v1`：当前选中的 HTTP Host。
- `ddlNew.systemConfig.v1`：最新系统配置 ObjectMapper JSON。
- `ddlNew.userInfo.v1`：用户资料，不含密码和 token。
- 用户会话凭据：Keychain `ddlNew.userSession/currentSession.v1`。
- 记住的登录表单：Keychain `ddlNew.rememberedLogin/loginForm.v1`。

读取唯一导航和系统配置时不再按邀请码核对；用户会话凭据仍需核对其所属 `lastLiceseId`，避免跨俱乐部认证。

`Const.swift` 当前还承载旧协议所需的 DNS/OSS 常量。不要在日志、文档或回答中展开这些值。若以后治理密钥，应设计安全注入和迁移方案，不要只移动明文位置。

## 主界面与功能状态

主界面：`ddlNew/Features/Tabbar/Views/TabbarView.swift`

四个 Tab：

| Tab | 当前状态 |
| --- | --- |
| 首页 | 已重新设计；活动和俱乐部入口在首页；主要展示数据仍是本地演示数据 |
| 消息 | P0 真实会话只读列表已接 SDK 数据库与同步代理：本地搜索、未读筛选、置顶/免打扰/草稿/预览/未读、Tab 角标；真实聊天与列表操作尚未接入 |
| 通讯录 | 已接 SDK 好友数据库、同步代理、排序搜索、资料详情和真实头像 |
| 我的 | UI 已迁移；退出登录、更换俱乐部和基础设置可用，业务接口仍需逐项接入 |

活动导航统一由 `ActivityNavigationScope` 注入，避免二级页面缺失 `ActivityNavigation` 环境对象。旧的 `Main` 和 `OldVersion` 目录保持删除；演示页面以 `OriginalHomeView`、`OriginalInvitationCodeView`、`OriginalLoginView`、`OriginalMessagesView`、`OriginalContactsView` 保留在各功能目录中，不接真实主入口。用户确认保留的演示注册存储放在 `Features/Login/Services/LocalCredentialStore.swift`。演示拉黑与举报已按用户最新要求删除，包括入口、页面、本地状态和模型。真实会话和通讯录仍使用各自的 SDK Store。

网络图片使用 Kingfisher。通讯录和消息页头像统一通过 `RemoteAvatarURL` 处理完整 HTTP(S) 地址、OSS 相对路径和中文路径；相对路径使用当前文件 Host。SDK 的 `cimUserUpdateHttpNode` 回调会同步更新 API／文件／上传 Host，主界面观察 Host 变化以重新生成图片 URL。图片仅对当前文件 Host 使用项目现有的临时证书策略，其他 Host 仍按系统规则校验。

## 通讯录实现边界

核心文件：

- `ddlNew/Features/Contacts/Services/ContactsStore.swift`
- `ddlNew/Network/IM/Contacts/SDKContactsClient.swift`
- `ddlNew/Network/IM/Contacts/SDKContactsDelegate.swift`
- `ddlNew/Features/Contacts/Views/ContactsView.swift`

AUTH 前注册 SDK 用户代理，AUTH 后读取 SDK 本地好友数据库。SDK 同步完成、好友变化和备注变化会触发刷新；迟到回调通过用户 UID 与 generation 隔离。排序规则沿用旧项目：系统账号过滤、备注优先、拼音首字母分组、已注销账号置后。

头像取 SDK 好友记录 `friend.avatar`；已注销账号不请求远端图片。通讯录列表和资料页共用当前文件 Host 与同一个头像组件。

尚未完成：好友申请、修改备注 UI、从好友详情发起真实聊天。

## 消息会话实现边界

核心文件：`ddlNew/Features/Message/Models/ConversationRecord.swift`、`Services/ConversationsStore.swift`、`Views/MessageView.swift`，以及 `ddlNew/Network/IM/Conversations/SDKConversationsClient.swift`、`SDKConversationsDelegate.swift`。

AUTH 前注册会话代理，AUTH 后读取 SDK 本地会话库；SDK 分页代理先于数据库写入，因此同步完成后才做完整重读。首轮同步中的最新消息按旧项目做法写入 SDK 消息表，使预览可从缓存恢复；实时会话变化触发合并刷新。只显示 `sessionStatus == 1` 且属于已知类型的会话，置顶优先、组内按最新消息时间倒序，按会话 ID 去重。Tab 角标来自真实可见会话未读数，免打扰不计入，手动标记未读计 1。登出或切换账号时通过 UID 与 generation 清空并隔离状态。

单聊头像按旧项目优先读取好友库最新 `friend.avatar`，好友记录缺失时使用 `sessionAvatar`；群聊与其他会话使用 `sessionAvatar`。好友列表变化后重新读取会话快照，避免先同步会话时继续显示旧头像。

消息页已移除 `ClubCommunity` 演示会话、假全部已读和跳往演示 `ChatScreen` 的入口。当前 P0 只读：列表行尚不能打开真实聊天；搜索只匹配已加载的会话名称和预览，不是消息历史全文搜索。当前 P0 已按角色 isShowFileAssistant 过滤系统单聊账号 100002，权限变化同步重算列表和角标，允许后从保留快照恢复；通知类会话按 SDK 类型显示，具体入口待后续实现。

## 下一步建议

1. P1：接真实单聊/群聊聊天页，先完成历史消息分页、实时收消息、发送文本与发送状态，再加入已读回执、失败重试和撤回。聊天入口可用后再开放列表行点击及标记已读。
2. P1：接会话置顶、免打扰、标记未读/已读、删除等列表操作；服务端请求成功后以 SDK 缓存回读为准。
3. P2：迁移旧项目全局搜索、文件助手权限控制、群发/系统/签到等特殊会话入口，再接好友申请、群资料、活动服务端数据和“我的”业务接口。

## 代码与依赖约定

- Swift/SwiftUI 代码按功能分目录，一个主要类型一个文件。
- 新 Swift 文件顶部使用项目现有四行文件头，`Created by taobo on` 日期用创建当天日期。
- 需要解释业务原因和异步边界时使用中文注释；明显代码不添加无意义注释。
- Moya 响应映射使用 ObjectMapper 和项目已有扩展，不使用 HandyJSON。
- 服务器 Path 放 `NetworkPath.swift`，固定 key 和全局服务常量放 `Const.swift`。
- 应用状态持久化使用 `@AppStorage`；结构化 JSON 使用 ObjectMapper；密码、token 和设备凭据使用 Keychain。
- 网络图片使用 Kingfisher。
- 项目包含 SwiftProtobuf；旧 SDK 的 Objective-C Protobuf 仍由 CocoaPods 提供，两者服务不同代码路径。
- `CandyTalkPro.xcodeproj` 是 `ddlNew` 的显式依赖，模块名为 `NoaChatCore`。
- `libLXChatEncrypt.a` 同时存在于应用和 SDK 各自需要的位置，避免随意删除或移动。
- CocoaPods、SPM 依赖和 vendored SDK 警告优先通过升级依赖解决，不直接改生成文件或 checkout。

## 警告处理现状

提交 `f975457` 已清理项目自身可安全修复的警告，包括：

- SwiftUI 弃用导航 API。
- 无效库／框架搜索路径。
- Sentry 脚本阶段依赖分析提示。
- SDK 内格式字符串、枚举转换、未使用变量、数组常量和缺失方法实现。
- 旧归档 API。

明确保留：

- `umbrella header for module 'NoaChatCore' does not include header ...`，用户要求不要处理此类警告。
- WCDB 的同类 umbrella header 警告。
- `UICKeyChainStore` 的旧安全 API 警告；替换会改变认证 UI 和 Keychain 可访问级别，需要单独设计迁移。
- LiveKit、WebRTC、Zego、Protobuf、ObjectMapper 等第三方依赖警告。
- 预编译静态产物携带的旧机器 ModuleCache 调试路径警告；需用源代码重新构建对应产物才能根治。

不要通过修改 `NoaChatCore.h` 或批量调整 Public Headers 来消除 umbrella 警告。

## 验证命令

全量真机构建，不需要签名：

```bash
xcodebuild \
  -workspace ddlNew.xcworkspace \
  -scheme ddlNew \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /Users/taobotaobo/Library/Developer/Xcode/DerivedData/ddlNew-gouvoiamsobqkuevngdfnxdlbzay \
  -disableAutomaticPackageResolution \
  CODE_SIGNING_ALLOWED=NO \
  clean build
```

2026-09-30 最近一次结果：

- 全量 clean build：`BUILD SUCCEEDED`
- `git diff --check`：通过
- 消息 P0 离线校验：`sh Tests/Conversations/run-checks.sh`，置顶排序、去重、免打扰角标口径和切账号后的 Store 状态隔离通过。新增会话代码的无签名真机目标构建通过；真实账号同步仍需真机验收。
- 头像链路修正后再次执行无签名真机目标 `clean build` 和最终增量 `build`，均为 `BUILD SUCCEEDED`；`git diff --check` 通过。

通讯录离线脚本已从 `feature-contacts-3` 恢复，并增加 OSS 路径、中文编码与无文件 Host 的头像用例。当前可执行 `sh Tests/Contacts/run-checks.sh`；生产逻辑 43 项、SDK 分页 19 项通过。真实 OSS 图片下载、节点切换和证书行为仍需真机登录验收。

模拟器不能完成依赖 `LXChatEncrypt` 的真实系统配置签名和完整登录链路；端到端 DNS、OSS、TCP/ECDH、登录和 AUTH 验证应使用真机。

## 本次会话完成的阶段

本会话从网络层迁移开始，依次完成或确认了：

1. Moya、RxSwift 与 ObjectMapper 响应映射。
2. 五路 DNS、UDP 归一化和 OSS 并发竞速。
3. Nav Protobuf、OSS Auth TCP 客户端、响应校验解密和导航缓存。
4. SDK 配置、TCP/ECDH 正式连接、系统配置获取和证书策略。
5. 登录请求加密、用户会话保存、数据库初始化和 AUTH ACK 判定。
6. AUTH 成功进入主界面及缓存启动自动恢复。
7. 首页重设计、四栏结构、登录记住密码和基础路由修复。
8. SDK 真实通讯录接入、Kingfisher 头像和离线验证。
9. 项目结构整理、依赖迁移与本轮安全警告清理。

新对话应以当前源码和 Git 历史为准，把本文当作导航和决策记录，而不是替代代码检查。

## 2026-10-12 分支合并记录

本次将 `feature-IMSDK-2`（`6b7c653`）合入 `feature-message-4`（合并前 `0c25315`）。用户确认：

- Sentry 使用 `feature-IMSDK-2` 配置；文档不记录 DSN 或认证信息。
- 合并时保留旧演示注册、拉黑和举报逻辑，按现有目录拆分迁入；其后用户要求删除演示拉黑与举报，见下节。
- 隐私政策与使用支持采用在线页面，删除本地 HTML 与开源许可入口。

合并后的登录增强包括账号预检查、验证码、安全码、真实账号注册和缓存 AUTH 恢复；手机号/邮箱登录、验证码登录和找回密码暂缓。注册成功后复用会话编排，AUTH 前订阅通讯录和消息，AUTH 后读 SDK 数据库，并再次核对会话所有权。

登录后断线竞速、导航兜底和网络质量检测统一管理。巡检受导航 `enableNetworkDetect` 控制，仅在已 AUTH 且前台运行，30 秒巡检，使用临时 TCP/ECDH 完整握手 RTT 比较节点，切换有 60 秒冷却；退出、后台和 SDK 断线竞速会取消业务等待并隔离迟到回调。临时探测 Socket 无 SDK 取消句柄，最长约 10 秒自行回收。

验证入口增加 `Tests/Login`、`AccountLifecycle`、`SessionRestore`、`Network`、`NetworkQuality`、`Verification` 中的 `run-checks.sh`；合并仍应保留执行既有 `Tests/Contacts` 与 `Tests/Conversations`。离线检查和构建不代替真机账号注册、验证码、自动恢复、弱网切换与消息同步验收。

本次合并验证：无签名真机目标 `clean build` 为 `BUILD SUCCEEDED`；上述八组离线检查全部通过，通讯录生产逻辑 43 项、SDK 分页 19 项、登录 25 项通过。构建前执行 `pod install --deployment --no-repo-update` 同步本地安装记录，未升级锁定依赖；CocoaPods 对工程空数组的自动改写已还原。`git diff --check` 通过。合并提交与最终工作区状态以 `git log -1`、`git status` 为准。

## 2026-10-12 删除演示拉黑与举报

按用户最新要求，删除“我的”黑名单与举报记录入口、演示好友拉黑操作、聊天举报弹窗和相关模型、快照字段、Store 方法、消息/联系人过滤及发送限制。旧快照中多余字段由 Codable 解码时忽略，不影响账号与活动记录恢复。保留其他演示流程及真实 SDK 通讯录、消息和登录逻辑。同步移除对应 UI 用例和注销说明；当前工作区的 `html/privacy.html`、`html/support.html` 已删除。在线页面未发布更新，现有在线文案需要后续独立更新。

本次删除验证：无签名真机目标全量 `clean build` 为 `BUILD SUCCEEDED`，通讯录离线逻辑 43 项与 SDK 分页 19 项通过，消息排序和 ConversationsStore 检查通过。应用源码与 UI 用例中已无演示拉黑/举报引用；`git diff --check` 通过。

## 2026-10-12 导航弃用 API 修复

`OriginalContactsView` 和 `OriginalMessagesView` 的隐藏 `NavigationLink(isActive:)` 改为 `navigationDestination(isPresented:)`，沿用所在 `NavigationStack` 及已有选中会话状态。弹出聊天后由系统重置呈现绑定，支持再次打开聊天。其他有效的 `NavigationLink(value:)` 与直接指定目标页面的写法继续使用。

本轮全量无签名真机目标 `clean build` 为 `BUILD SUCCEEDED`，构建日志中的两处 `NavigationLink(isActive:)` 弃用警告已消除，`git diff --check` 通过。


## 2026-10-13 网络与登录维护补齐

需求见 `Docs/NETWORK_LOGIN_REQUIREMENTS.md`；实施与验收计划见 `Docs/superpowers/plans/2026-10-13-network-login-maintenance.md`。开发使用 Superpowers，安全页面和状态接线同时按 swiftui-pro 复核，保留 iOS 16 最低版本和现有 ObservableObject 架构。

- 前台恢复：在同一登录会话从后台返回时调用 SDK `verifyConnectionOnForeground`；由 SDK 的现有 PING、超时和重连处理断链，普通断线保留用户凭据。
- 会话维护：首次 AUTH 后立即刷新系统配置、本人资料和角色权限；前台随机 180～480 秒执行，访客只刷新系统配置。前台恢复、HTTP Host 切换及 AUTH 恢复可触发合并刷新；后台暂停。应用配置只更新 SDK 租户/验证码，避免重建用户、数据库或 Socket。
- 资料与权限：部分资料合并到当前 UID 快照，保留 Token/deviceSecret；主页观察资料变化。角色配置独立缓存，绑定 UID 和邀请码；兼容数字/字符串布尔值，保留 configData/authorityKey。缺失图片视频上传权限默认开启、其他一般权限关闭、翻译空值默认开启；条目结构/值非法关闭，不能误用缺省允许。
- 主动退出：复用真实 `authUserLogoutWith`，当前 UID/Token 快照最多等 2 秒，失败仍清理本地。Swift 并发退出去重，旧会话回调不得清理新用户；SDK `clearMyUserInfo` 同时撤销排队请求会话归属并清队列，旧 logout/Token 刷新请求不能随下一 AUTH 重发。
- 特殊错误：账号、设备、IP 封禁、白名单、密码错误等待、注销和强制下线使用明确文案，原因保留到登录页。维护接口明确封禁同样按当前会话轮次撤销身份；普通网络失败保持会话。白名单仅展示验证过的服务端真实 IP，日志不输出密码、Token 或密钥。
- HTTP 独立优选：旧 JSON 导航保留 `is_merge_version` 和 `ping_interval_second`，默认 300 秒；Protobuf 导航无该旧开关时不擅自启用。真实 GET `/zlcpig`，2 秒超时；成功次数和平均 RTT 排序，仅选择本轮成功节点，60 秒冷却。同步 SDK API/SSO 和 API/文件/上传 Host；账号/邀请码/导航版本及递增 Host revision 隔离旧结果，包括 A→B→A 交错。
- 密码安全：复用真实强度检查、原密码检查和本人密码重置。手动登录密码短暂用于密钥加密，缓存 AUTH 仅 UID 检查；临时失败前台/周期重试。强制状态只能改密成功或明确退出解除，后续非强制检查不降级；最小 UID/邀请码要求以 ObjectMapper + AppStorage 持久化，重启和暂时恢复失败保持阻断。修改成功清除记住的旧密码并退出重新登录，不假设新 Token。已提交重置在后台保留有界回执等待，成功后前台退出；输入和明文立即释放。

任务在停止、进入后台、退出、换账号和同邀请码重新导航时通过会话轮次/Host/导航版本使迟到结果失效；明确封禁回调另按 UID/邀请码/会话轮次核对，即使后台也能撤销原会话。固定品牌展示和动态 Sentry/Logan 配置未纳入；手机号/邮箱登录、验证码登录、找回密码、直连/扫码/代理仍暂缓。

本轮验证：11 组离线脚本全部通过；登录 26 项、安全 69 项、维护 17 项、角色/资料 19 项、SDK 请求会话隔离 7 项，通讯录 43 项和 SDK 分页 19 项通过；消息补充文件助手开关及角标恢复验证。独立审查发现的五类问题已修复并复核关闭。最终无签名真机目标 `clean build` 为 `BUILD SUCCEEDED`，`git diff --check` 通过；现有 SDK/导航并发与 ObjectMapper 警告仍存在。完整日志 `/tmp/ddlNew-session-maintenance-final-clean.log`。

真实服务器响应、前台半开连接、强制改密 UI、退出请求与节点优选尚未真机联调，按需求文档清单验收。变更保留在 `feature-message-4` 工作区，未提交/推送；本轮不更改在线服务配置。


## 2026-10-13 通讯录与消息需求盘点（仅文档）

用户要求先对照旧项目 `xgd` 整理详细移植需求，本轮不开发。旧代码基线为 `xgd / 5e45f3f` 当前工作树，新代码基线为 `feature-message-4 / 78876ca` 当前工作树；源码可达与 SDK 方法存在不等于旧 App 运行或服务端支持已验证。

- [需求总纲](CONTACTS_MESSAGE_MIGRATION_REQUIREMENTS.md)：范围、现状差距、需求与验收索引、依赖、建议优先级以及待取舍／联调问题。
- [通讯录详细需求](CONTACTS_MIGRATION_REQUIREMENTS.md)：好友、业务分组、群聊、搜索、新朋友、资料与关系操作、业务二维码和关联助手入口。
- [消息与关联聊天详细需求](MESSAGE_MIGRATION_REQUIREMENTS.md)：会话列表、会话操作、历史／收发／消息操作、单群聊详情、群管理与特殊会话，以及旧新 SDK 接口差异。

需求中的建议优先级、扩展功能和验收案例等待用户审阅，不能据此自动开发、恢复演示逻辑或声称真机验收通过。原有主链路和代码完成度不变；后续开发另按用户确认的需求 ID 划定范围。

文档收尾核对：正式需求共116项（C38/M29/CHAT49），专项232项与公共21项合计253项验收设计，15项待确认。三份文档823处本地链接、文件存在、行号、锚点与代码块校验通过，需求ID唯一且总纲索引完整；`git diff --check` 通过。任务开始以来非文档文件摘要比对无变化。本轮未构建、未执行业务测试或真实后端请求，验收设计尚未执行。


## 2026-10-13 通讯录与消息迁移开发（继续验收）

**用户已在新窗口授权继续并要求自主收尾，当前进度以[迁移交接文档](CONTACTS_MESSAGE_MIGRATION_HANDOFF_2026-10-13.md)及测试报告“继续验收记录”为准。** 接手HEAD为`a3233e6`（`4c8f593`之后仅文档），工作区当时干净。最新三项修正已独立复核，补修媒体失效提示、真实成员分页items解析、前台/页面恢复已读及清历史读批次隔离；成员9项、Chat32项、Viewport7项通过；UI/日志快照41/41及签名clean build通过；后续新增精确搜索旧userUID兼容、只传userName及坏页报错窄修，最新42/42入口exit0，127.88秒及签名增量build通过。固定yield的登录安全测试曾偶发失败，仅改测试等可观察退出状态后全量通过，生产登录未改。两端同包最新群文本已实收，原始ACK身份字段取得；真实已读计数、其它业务/媒体及公共严格验收未齐条件已逐项记录，不作发布GO。运行中Mac已锁屏，工具不能继续该端UI；没有绕过锁屏。SDK诊断日志泄漏已在13文件日志边界修复，180匿名可执行检查及独立反向回归通过，非日志业务保持一致；终版iPhone覆盖安装/冷启动/账号B核验完成，Mac因锁屏未运行后续UI/日志版本，不能将此前群正文子证据冒报为终版双端完整验收。终版B搜索ceshi001已真实返回A cs123，检索缺陷闭环。最后发现单聊SDK好友status不持久化导致正常DB行默认0被禁发，仅数据库缓存资格适配0/1，缺行/注销/未知状态与来源群仍拒绝，6项及独立复核通过；最终43/43入口exit0（110秒）及签名build成功；真实单聊Unicode/换行已入列表并在首屏时序修正版返页实见1份，手机终版b4562836…已安装冷启动，详见测试报告RES-19/20。21项公共严格台账已补齐；指定iPad默认字号键盘布局宿主局部Passed，完整宽窗/VoiceOver仍未齐。仍只使用A/B和“有魄力”，不清既有历史、不自动提交/推送，第三身份和同账号双设备等缺前提项不能伪报通过。

以下为较早开发过程快照，28个入口、正在修复等描述不能代替上述最新交接状态。

用户已授权按产品需求开发，范围见 `Docs/CONTACTS_MESSAGE_DEVELOPMENT_SCOPE.md`：116项正式需求中103项明确建议纳入、13项整体暂缓，贴纸、位置、全读及加密等按批准子范围执行。实施计划 `Docs/superpowers/plans/2026-10-13-contacts-message-development.md`。本节取代上一节“仅文档”的当前进度描述，历史记录保留。

- 使用 Superpowers 分工、失败测试与独立审查，SwiftUI 配合 swiftui-pro；iOS16与Swift5保持，每个新增/修改方法中文注释。基线 `feature-message-4 / 78876ca`，不自动提交或推送。用户单独调整的工程Mac/沙盒配置保留。
- 好友业务、分组、群列表和选人、二维码放在各Feature；SDK请求和代理在 `Network/IM`，根 `LoginSessionService` 统一绑定UID、邀请码和认证轮次，退出关闭业务Store及ChatRuntime。根Tab用稳定ID路由进入真实聊天。
- 会话列表接真实置顶/免打扰/未读/删除，删除会话保留历史；文件助手仅置顶与删除。全局搜索读真实好友、群和消息库并按目标消息ID定位。群申请10条分页、批量逐结果，群通知用系统会话最新serviceMsgID上报chatType5已读；等待期间新通知保留未读。
- Chat核心、媒体、消息操作、群设置正在收尾；ACK以ackMsgId绑定发送消息，Socket sessionId不能当聊天UID。云媒体沿用旧STS和对象目录，凭据只留内存，上传HTTP回执与聊天ACK分离；旧XOR/AES媒体格式兼容、四供应商签名离线对抗验证，细节见 `Docs/CHAT_CLOUD_TRANSPORT.md`。
- 独立审查发现申请加载事件丢失、迟到未读快照、好友关系同步、损坏资料写库、群内昵称、选人失败及UI反馈问题，正在逐项修复复测。设计复核见 `Docs/CONTACTS_MESSAGE_UI_REVIEW.md`，逐需求验收见 `Docs/CONTACTS_MESSAGE_TEST_REPORT.md`。

验证当前只确认离线及隔离宿主的局部证据；最近QA汇总28个离线入口通过，云媒体86项对抗断言通过。本轮有签名真机目标clean build已通过，日志`/tmp/ddlNew-contacts-message-final-clean.log`；独立聊天审查随后发现7项缺陷与3项已批准子能力遗漏，修复后的重新构建和复测仍在进行。用户已提供两端专用测试身份，源码/文档/脚本/日志不保存真实密码。最初mobile只发现模拟器，随后devicectl确认两台手机连接并安装签名App。用户明确实际已登录端为名叫iPhone的真机及My Mac，另一台手机仅安装不能记为登录。真机UI改用隔离的本地go-ios/WDA端口8101，避免与模拟器8100混用；My Mac辅助功能由用户开启。独立QA正在核对身份及专用群内实际行为，登录的用户确认不等于收发/群管理验收。


## 2026-10-14 消息与通讯录 UI / 交互对齐 xgd

用户要求消息、通讯录及全部关联页面按 xgd 老项目风格调整，并明确要求交互对照旧项目、使用既有 UIAdapter 做屏幕适配。覆盖30个在用页面文件及通用/专属组件；页面清单、旧源码参考和验证边界见 [UI对齐记录](MESSAGING_UI_ALIGNMENT_2026-10-14.md)。

- 主界面改中性白灰、圆形头像、紧凑标题和平铺列表；品牌色按用户后续要求与首页／我的底栏保持一致，统一复用 `HomeTheme.forest`。通讯录保留权限控制的新朋友/文件助手/群助手卡片、好友/分组/群聊点击分类、字母定位和真实搜索。深色配色独立定义，UIAdapter几何缩放与系统DynamicType分开处理。
- 所有真实二级页面统一导航、资料与表单、确认与失败反馈；账号行点二维码/长按复制、备注整行编辑、可见分组删除/排序、群成员网格/独立名称编辑、公告管理与审核、转发确认及筛选保留选择、文件主动下载/取消等按旧项目交互调整。
- 聊天输入区常驻工具并可收拢、表情/资料入口明确；辅助字号时工具独立一行，键盘收起保留草稿。消息、资料与群来源仍使用真实身份/权限边界，不移动SDK、启动或登录所有权。
- 公告详情编辑已修正为使用当前展示的最新正文/置顶，并以item sheet携带公告身份和独立草稿，避免首次误进发布模式；子页/弹窗返回保留已加载名单和详情。

全量无签名真机目标clean build与六组相关离线入口通过；匿名宿主已验证主列表/聊天的窄屏、最大辅助字号、深色与iPad局部布局，以及分类/未读/返回/键盘草稿和公告编辑快照。全部二级页面尚未逐页VoiceOver/最大字号真机走查，真实相机、媒体与后端操作仍需联调，不将宿主截图记为消息送达或真实群操作通过。补修后的最终增量build成功，日志`/tmp/ddlNew-legacy-ui-final-rechecked-build.log`；公告匿名回归确认ID/新正文/置顶传参、失败保稿及取消返回详情。收尾结果见UI对齐记录。变更留在 feature-message-4 工作区，未提交/推送；用户已有未跟踪评审文档未改。


### 后续主题色修正

用户明确要求保留首页／我的主题色。接手 `feature-message-4 / 89cc7a4`，工作区干净；消息与通讯录的强调、实色按钮、发送气泡统一直接复用 `HomeTheme.forest`，底栏统一森林绿，不再随Tab切换成紫蓝色。头像衬底与边框复用首页主题；深色浅绿按钮／气泡使用深绿前景保证对比。布局、UIAdapter适配及业务交互保持现有实现。

本次无签名真机目标全量 `clean build` 成功，日志 `/tmp/ddlNew-theme-alignment-clean-build.log`；匿名浅色通讯录与深色聊天预览检查通过，主按钮／气泡文字对比浅色7.87:1、深色7.71:1；`git diff --check` 通过。最新图片见UI对齐记录，首轮紫蓝图片已标注为历史预览。主题色修正未提交／推送。

### 通讯录默认分组与资料交互修正

- 对照 xgd 的 `NoaFriendGroupSectionHeaderView`、`NoaFriendGroupManagerCell` 和 `NoaFriendManageVC`，空分组名显示“默认分组”。新客户端此前直接显示SDK空名称；现在统一使用 `FriendBusinessGroup.displayName`，通讯录分组、管理／重命名初值、移动分组和选人页面均复用。空名与纯空白名有兜底，非空名称和默认组重命名保留；原始名称、分组ID、成员及不可删除限制不变。
- 新朋友加载、好友备注保存使用既有 AlertToast loading浮层，移除列表／表单内ProgressView；保存按钮固定显示“保存”。Toast直接观察Store的加载／提交状态，请求结束自动关闭；重复提交禁用和失败保留草稿沿用现有行为。
- 资料页备注、描述两行均带右箭头，打开同一份“备注与描述”编辑页；箭头与内容间距统一为6.zoom，移除嵌套行内边距造成的额外空白。资料底部不再展示“账号已复制”或操作成功文案，复制功能与错误提示保留。

默认分组回归先复现空名失败，修复后 `Tests/Contacts/run-business-checks.sh` 通过；`Tests/Contacts/run-checks.sh` 全部通过（43项生产逻辑、19项SDK分页、25项字段合并）。全量无签名真机目标clean build通过，日志 `/tmp/ddlNew-default-group-name-clean-build.log`。匿名宿主实际确认空名称显示“默认分组”、新朋友Toast出现／请求结束消失，以及备注保存Toast、禁重复提交、模拟失败关闭Toast并保留输入；宿主不访问真实后端。改动未提交／推送，森林绿主题修正保留。

包含最后的资料箭头和底部文案修正的增量build成功，日志 `/tmp/ddlNew-default-group-toast-final-build.log`；`git diff --check` 通过。

### 群聊返回列表顺序稳定

用户反馈通讯录群聊列表进入聊天后返回，该群自动移到末尾。旧版 `NoaGroupListVC` 直接展示SDK群名单；新聊天进入时刷新群详情，`SDKChatClient.updateGroupCache` 调用SDK的替换写入，而群表查询没有显式排序，因此下一次读取数据库行顺序变化。`GroupsStore.reload` 现在按稳定群ID合并：已有群沿用当前列表位置但更新为最新资料，已退出群移除，新群按本轮SDK顺序追加；账号／俱乐部切换或退出清空顺序，不增加第二份持久化群库，也不冻结权限或成员数据。

`Tests/Groups/run-checks.sh` 回归先复现A/B/C在打开A后变成B/C/A，修复后通过；同时验证名称／头像／角色／人数更新、增删和去重，以及切账号后采用新账号列表顺序。日志 `/tmp/ddlNew-group-order-red.log`、`/tmp/ddlNew-group-order-green.log`。

最终无签名真机目标build成功，日志 `/tmp/ddlNew-contacts-final-group-order-build.log`；`git diff --check` 通过。真实账号的反复进入／返回仍需真机走查，当前结论为生产Store离线回归和构建通过。

### 创建群聊分组标签间距

选人页的分组名称改用紧凑普通标题行，移除原生Section标题的额外顶部留白，分组标签下方padding从16.zoom缩为8.zoom；“选择本组好友”使用整行按钮和显式行内边距，保留至少44pt点击区域及原有UID选择、数量限制和预选保护。默认分组名称继续显示，不用空标题占位。匿名生产视图对比确认标签下方到分组标题的空白从37pt缩为7pt；不涉及真实建群请求。

匿名选人宿主确认分组全选7人、取消恢复0人，最终build通过，日志 `/tmp/ddlNew-contacts-final-picker-build.log`；`git diff --check` 通过。

### 用户资料复制账号Toast

用户后续要求复制账号给Toast反馈。`ContactRecordDetailView` 在写入剪贴板后显示既有AlertToast的居中短提示“账号已复制”，2秒自动关闭；顶部HUD因反馈看不到改为居中，资料底部继续不追加成功文案。

无签名真机目标build成功，日志 `/tmp/ddlNew-profile-copy-toast-build.log`；`git diff --check` 通过，改动未提交／推送。

### Toast对比与移动／添加分组

复制提示、新朋友加载、备注保存、移动分组和分组名称保存统一使用 `MessagingTheme.toastBackground`／`toastText`，复用首页文字／表面色反转浮层明暗：浅色页面深绿底浅色字，深色页面浅色底深绿字，避免白色Toast融入白色页面。移动分组加载和移动提交不再插入列表ProgressView；打开添加分组子sheet时父页暂停自己的Toast，防止双重提示。

添加／重命名分组的保存按钮始终显示，使用清晰的禁用背景和文字色，名称为空／纯空白、未更改或提交中禁用；有效名称后启用。提交改用Toast，失败保留输入；sheet最小高度和键盘出现时按钮仍可见。匿名生产视图已确认居中复制Toast、移动页加载Toast、添加页空名称与空格禁用／有效名称启用，以及提交时只有一个Toast。

浅／深色复制Toast已截图确认可辨，添加分组模拟失败关闭Toast、保留名称并恢复保存。无签名真机目标build成功，日志 `/tmp/ddlNew-contacts-toast-contrast-build.log`；`git diff --check` 通过。匿名宿主不访问真实后端，改动未提交／推送。

### 按导航路径控制Tab底栏

按用户指定的 `.toolbar(path.isEmpty ? .visible : .hidden, for: .tabBar)` 方式，`ActivityNavigationScope` 现在使用实际绑定NavigationStack的 `navigation.path` 统一控制底栏，四个Tab继续独立持有路径。移除聊天页、MessagingPageChrome以及旧ClubDetailChrome的固定隐藏指令；ClubDetailChrome已无职责，移除文件及使用点。

消息行点击、消息／通讯录建群后的跳转改用 `ActivityNavigation.open` 将ChatRoute追加到实际路径，首页签到入口使用ActivityRoute值路由，避免根页面布尔／直接目标push未计入路径、底栏误显。二级页仍沿已有栈跳转，SDK与聊天Store所有权保持原实现；没有启用RouterTool内未接当前主界面的历史路径，也没有增加第二份导航状态。

无签名真机目标build通过，日志 `/tmp/ddlNew-tabbar-path-build.log`。匿名宿主运行生产TabbarView、ActivityNavigationScope以及消息／通讯录／资料页面，SDK、首页／我的内容及聊天正文替换为夹具；已操作四个Tab根页面到二级页面再返回，确认根页面显示、push隐藏、返回恢复。消息点击的路径深度确认为1。此为导航验收，不代表真实聊天收发／建群通过；`git diff --check` 通过，未提交／推送。

### Toast柔和配色与新朋友行修正

使用ui-ux-pro-max的颜色对比建议，将共享Toast底色更新为低饱和灰绿：浅色#E1E9E3、深色#2F3C34，文字使用HomeTheme.text。覆盖复制、新朋友加载、备注保存、移动分组和分组名称保存；首页／我的品牌主题色继续保留。文字与底色对比约10.07:1和10.45:1，替代先前较突兀的反转配色。

新朋友页按用户最新要求移除业务成功和错误文案的列表行，也不以Toast提示这些文案；Store仍保存真实结果状态，页面保留加载Toast与cell内“已添加”“等待验证”等申请状态。NavigationLink包住整行，系统右箭头位于申请操作按钮之后的最右侧，大字体时操作按钮仍换至下一行。

### 添加好友、二维码、按钮与通讯录同步补充

- 添加好友进入／离开时清空搜索结果，进入时重置输入和提示；`clearSearch()`撤销搜索轮次，迟到请求不能恢复历史用户，资料缓存保留。精确搜索的服务器“用户不存在”作为无结果显示空态，其他网络／格式错误保留。
- 我的二维码移除右上角更多菜单，底部保存相册／聊天分享保留。新增`MessagingActionButtonStyle`控制整体最小高度48pt，替换二维码、资料操作、备注保存、新朋友申请、相册扫码、聊天附件／群公告／发送／头像／位置／转发以及注销页中叠加系统内边距的按钮；分组保存也统一48pt，大字体可自然增高。已有52pt登录／首页按钮没有同类叠加问题。
- 扫一扫直接在当前导航页创建相机，移除相机fullScreenCover及入口表单；相册选择保留在取景页底部，失败可重新扫描，退出销毁捕获会话。识别结果继续由真实SDK转换和原有用户／群流程处理。
- 备注保存成功后等待ContactsStore读取SDK缓存，再更新资料关系快照、关闭编辑器；保存及回读期间保持Toast和禁用。读取中遇到显式刷新追加一次读取，避免复用保存前旧快照，账号轮次隔离保留。
- 分组管理去掉成功文案和列表ProgressView，读取／更新改居中Toast，名称编辑sheet出现时父页暂停Toast。前后移动与拖动共用`moveGroup(id:toIndex:)`，提交目标分组真实ugOrder，移除首尾加减1；首尾菜单边界禁用，原位／非法位置不提交。

离线回归已复现保存回读复用旧快照并修复，Contacts检查44项、SDK分页19项、字段合并25项通过。Business检查涵盖搜索清空／迟到隔离／再次搜索、用户不存在空态与网络错误，以及非连续排序值10／30／70的前后和拖动目标及边界。最终无签名真机目标build通过，日志`/tmp/ddlNew-contacts-final-all-build.log`。

匿名宿主运行生产页面已确认：二维码导航没有更多按钮，底部保存／分享实测48pt，大字体改纵向排列；新朋友按钮48pt、系统箭头在整行最右侧、按钮点击独立提交；添加好友首次进入不显示夹具旧搜索，无结果展示空态；分组管理加载只呈现居中灰绿Toast，添加分组行缩小；扫码直接取景而不呈现入口表单。浅／深色Toast均已截图检查。宿主使用模拟数据，未验证真机相机识别及服务端修改／排序最终结果；改动未提交／推送。

### 消息默认Tab、统一保存样式与二维码Toast

ClubStore首次创建及登录准备／退出／注销后的Tab默认统一为消息。分组名称保存按钮与备注保存复用MessagingActionButtonStyle，可提交为首页森林绿／对应前景，禁用统一降低透明度；消息编辑、群名称／群昵称和公告编辑的保存入口也复用此样式，保留各自校验和禁用条件。

二维码保存过程与结果均改居中Toast，移除图片下面的保存文案和进度行；匿名模拟器实际保存夹具二维码后确认“已保存到相册”Toast。扫码读取／业务结果改Toast，删除页面内错误／业务结果以及所有“重新扫描”入口；相机解析失败的Toast结束后自动恢复捕获，相机权限／设备错误不反复重启。相册入口保留在取景页底部。

### 备注保存确认直接更新SDK缓存

用户再次反馈刷新后仍显示旧值。离线客户端复现：服务器保存确认返回新资料，原perform紧接着读取profile时仍返回旧资料，会覆盖新值；单纯补读本地缓存不能解决这一覆盖路径。

SDKContactsBusinessClient在备注保存成功回执后、当前身份验证及SDK共用锁内更新真实好友模型的remarks／descRemark／remarksPinyin／showName，调用toolUpdateMyFriend触发已有好友与分组代理，并返回已更新缓存快照。ContactProfileRequestGate撤销保存前读取的写入资格。ContactsBusinessStore使用该确认快照，不再立即发送可能返回旧值的profile读取，同时撤销保存前的Store资料轮次；缓存写入失败返回错误并保留编辑稿。随后仍读取通讯录缓存、更新资料关系并关闭编辑页，未另建好友数据源。

Business回归新增保存确认后旧资料不能覆盖以及失败不能修改资料，修复前已复现失败、修复后通过。Contacts44项、SDK分页19项、字段合并25项继续通过。全量无签名真机目标build通过，日志`/tmp/ddlNew-remark-confirmed-cache-build.log`；真机当前账号修改结果尚未再次核对。

匿名生产视图进一步确认分组保存空输入禁用／有效名称启用，颜色与备注保存共用同一样式，键盘出现仍可操作；二维码保存结果Toast实际出现，扫码通过相册读取夹具二维码后模拟业务失败仅显示Toast且无重新扫描按钮。主Tab匿名预览初始选中消息。预览Store和SDK为夹具，不代表真机备注同步或相机业务识别已通过。


### 群人数、群成员导航与全局操作Toast收尾

- 新建群先合并服务器确认记录，reload保留已知正数，0缓存不覆盖有效人数，后续真实正数仍更新。SDKChatClient将群详情memberCount写回群表，并且仅人数变化且写库成功时发群更新代理，让通讯录刷新；相同人数不通知，避免权限刷新回查循环。没有用选择人数推算服务端人数。
- xgd群设置成员预览和查看成员先到名单，名单再到资料；同步未就绪、私聊限制、注销和机器人限制保留，自己的资料可按权限查看。名单资料沿当前栈直接push，修正布尔导航目标内混入值路径导致父目标重排。整行系统箭头在管理菜单之后最右侧，管理独立响应。移除sheet与确认dialog的状态清理互不干扰。
- 群二维码右上角更多菜单删除。群名称与公告的导航栏保存恢复紧凑文字样式、44pt触点和启用 / 禁用色；保存Toast、失败草稿保留。群设置查找聊天记录右侧放大镜删除。
- MessagingStatusToast复用AlertToast与灰绿配色，loading观察真实请求，短反馈独立3秒计时、默认不重播旧结果。群设置、管理、成员、头像、公告、选人、二维码、入群审核及相关聊天 / 搜索 / 媒体 / 转发操作统一接入。其它既有注册、改密、邀请码和注销等操作结果同步移出正文。新朋友页继续遵循单独要求，不弹全局业务结果Toast；分组管理不显示普通成功提示。内容、连接 / 权限状态、校验说明、失败标记、重试和确认入口保留。
- 聊天实时发送失败进入ChatStore.errorMessage，由聊天页Toast显示，气泡下不再追加业务错误正文；保留失败图标和重试。历史失败和成功ACK之后的迟到失败不会弹提示；发送 / 重试清旧错允许重复提示。验证码loading仅网页验证显示，不遮住图片 / 安全码输入。

收尾验证：Groups、Group policy14项、Settings7项、Member page9项、ContactsBusiness通过；Contacts44项、SDK分页19项、字段合并25项、Chat33项及LoginSecurity69项通过。最终无签名真机目标build为BUILD SUCCEEDED，日志`/tmp/ddlNew-final-ui-handoff-build.log`；git diff --check通过。匿名生产成员视图确认预览进名单、资料正确push与返回、箭头最右侧及管理菜单独立；群名称加载 / 失败Toast均实际出现，消失后保留输入。全部代码保留工作区未提交 / 推送，用户另行改动LocalCredentialStore保留。真实群人数、备注缓存与服务端、角色导航和二维码相机仍需真机验收，不能将匿名夹具当作完成证据。完整需求与交接见上方会话文档。

### 群设置成员头像直接打开资料（后续用户要求）

2026-10-14接手实时分支为 `feature-message-4`、HEAD `39bfae9`，工作区干净；此前交接的未提交修正已包含在该后续提交中，本助手未提交或推送。

用户要求点击群成员直接进入详情，不再经过一遍成员列表。当前完整名单已直接跳资料，问题入口为群设置成员预览绑定了打开名单动作。预览现传递所点成员 UID 和来源群 ID，直接打开 `ContactRecordDetailView`；返回回到群设置。设置 Store 将资料导航计为子页，避免 push 时关闭快照与观察。“查看群成员”继续打开完整名单，同步、私聊权限、注销及机器人限制保留。此要求取代上节关于“预览先到名单”的历史行为。

群策略14项、设置7项、成员分页9项离线检查通过；全量无签名真机目标 clean build 为 `BUILD SUCCEEDED`，日志 `/tmp/ddlNew-member-direct-profile-clean-build.log`，`git diff --check` 通过。用户明确暂不使用 Mobile MCP，后续未再调用；本轮未安装新包，真机实际跳转、备注同步、新建群人数与 Toast 服务器结果仍待验收。改动保留工作区，不自动提交或推送。

### 群设置移除成员与角色标签补齐

按用户要求只读对照xgd独立移除页，修正减号入口仍打开普通名单的问题。新增 `ChatGroupRemovalView`：搜索、UID多选、完成人数、确认sheet中的删除所选成员全部已发消息选项；失败保留选择，真实受理后返回群设置Toast。共用现有Settings Store和SDK `.remove`，没有新增接口、群库或推算人数；进入子页保留设置Store。候选与提交共用当前权限，过滤本人 / 群主 / 注销 / 机器人和非下级角色；同步未完成、重复UID和超500人不能提交，权限变化撤销失效选择，SDK提交前再次拉取服务器权限。

预览、完整名单、移除和确认名单统一显示 `ChatGroupMemberRoleBadge`，真实role2为群主、role1为管理员，保留首页森林绿和既有UIAdapter。前一轮头像直达资料改动保留，普通名单管理菜单仍可单个移除。

群策略17项、多选12项、设置10项、成员分页9项、Chat33项及Groups检查通过；测试覆盖移除失败保留、批量UID / 删除消息选项、成功回读名单 / 人数和降权 / 上限。无签名真机目标全量clean build成功（`/tmp/ddlNew-group-removal-clean-build.log`），最终增量build成功（`/tmp/ddlNew-group-removal-final-build.log`），`git diff --check`通过。未调用Mobile MCP、未在真实服务器群中执行移除；工作区改动未提交 / 推送，真实成功 / 失败Toast和不同角色权限仍待真机验收。

### 群公告正文与置顶字段修复

用户反馈发布后没有正文且关闭置顶仍显示置顶。只读核对xgd的 `NoaGroupNoteModel`、列表数据Handle、公告编辑和详情页：写入字段为 `noticeContent / isTop / isSendMsg`，响应字段为 `content / topStatus / noticeCreateNickname / createTime`；`status`是正常/删除状态。新客户端之前误将写入字段当读取字段，并用正常status1兜底置顶。请求的isTop开关原本已正确，不据此声称服务器把普通公告实际改成了置顶。

新增共用 `ChatGroupNoticePayload` 修正列表、详情及聊天顶部的响应映射，兼容原有别名但以xgd响应字段为准，不再以status判断置顶；正文保留Unicode/换行，大整数ID和毫秒时间兼容数字/字符串，坏页报错而非空白或静默吞行。发布/编辑仍独立提交isTop与isSendMsg，删除只提交身份与公告ID。

公告Store通过 `ChatNoticesClient` 注入现有SDK，保持Runtime会话所有权。保存受理后回读首屏，回读失败保留现有列表并提示下拉重试，不重复发布；详情成功同步列表，编辑/删除使用当前正文和置顶值，保存或退出后旧详情请求失效。页面增加下拉/重新加载入口，保存Toast在编辑sheet关闭后展示，写操作仅群主/管理员可见；聊天从公告sheet或群设置返回会主动重读真实置顶公告。

离线公告响应15项、公告Store12项通过；回归先复现content读错和保存后刷新失败清空列表，再修复。Chat33项、Settings10项及群策略17项/移除选择12项继续通过。无签名真机目标clean build成功（`/tmp/ddlNew-notice-contract-clean-build.log`）；增量第一次遇到build.db锁，未终止其他构建，重试成功（`/tmp/ddlNew-notice-contract-final-retry-build.log`）。随后窄修新增的Optional公告Equatable隔离警告，公告响应15项再次通过，终版增量build成功（`/tmp/ddlNew-notice-contract-warning-fixed-build.log`），`git diff --check`通过。未调用Mobile MCP、未创建/编辑真实服务器公告，既有群移除和头像资料路由改动保留，未提交/推送。

### 公告详情删除确认不再延迟到返回列表

用户反馈详情点击删除没反应，返回列表才弹确认框。原因是详情回调只设置父列表的confirmDelete，而confirmationDialog挂在不可见的列表页。详情现在持有自己的删除快照和确认框，点击即在当前详情确认；取消或离开清理该页状态，确认后与列表长按共用deleteNotice和既有真实Store/SDK删除、失败反馈及成功返回。详情不再设置列表的弹框状态，避免返回后二次提示。

公告响应15项和Store12项离线检查通过；本次无签名真机目标clean build为BUILD SUCCEEDED（`/tmp/ddlNew-notice-delete-dialog-clean-build.log`），`git diff --check`通过。保留已有字段、置顶、成员移除和路由修正，未使用Mobile MCP、未执行真实服务器删除，未提交/推送；弹框与取消/确认的真机表现仍待复验。

收尾实时检查发现HEAD已前进至 `6252ab8`（`fix：修改通讯录模块的bug`），上述生产修正保留在当前源码，工作区只余两份交接文档修改。本助手没有执行commit/push；此前未提交状态为过程快照。


## 2026-10-14 晚间：全模块对齐继续执行

用户授权恢复 Mobile MCP，在 Mac Designed for iPhone 与真机使用 A/B 测试账号对照 xgd，自行决定常规测试问题，不自动提交/推送。已完整阅读两份交接文档，当前分支 feature-message-4，开工 HEAD 6252ab8；用户既有修改保留。

本轮代码进度：公告删除受理即发布返回事件，详情导航不再依附被删除的列表行；编辑页当前确认删除，先关 sheet 再返回列表，失败保稿留页。公告时间与 xgd 一致 yyyy/MM/dd HH:mm；管理角色读取只依赖群 info，写前核权保留，角色回执乱序隔离。资料好友申请成功 Toast 和本认证轮次等待状态；等待以申请稳定版本识别终态，展示昵称/头像变动不能解除等待。入群申请展示邀请双方真实 UID、头像、角色及群名，严格混合类型页解析，坏页保留旧列表及通知未读。业务二维码已验证结果直接导航资料/已加入群；返回重建相机。

消息修正：全局搜索过滤删除/撤回原文及非法会话身份；名片点击直接资料；转发专用编码保留合并原时间、清引用、@转普通可见文本，回执缓存保留媒体/贴纸/坐标尺寸；预检后重读原消息状态。系统展示摘要与旧通知开关/静默/定向对象策略共用；刷新型不插空气泡，置顶独立revision回读。可见正文只扣实际成功转读的身份，计数写失败保留待补扣状态。**打开会话仅清本机手动 readTag，不自动发 conversationReadedStatus：SDK对应服务端事件会整会话清零且没有消息边界字段，不能把该API当只清提醒。跨端自动手动标记清除仍未验收。** 禁言结束时间只安排真实权限重查；失败不本地解禁，身份轮次/截止任务取消隔离。

退出/解散使用现有公开 NoaIMHttpManager 运输接口，服务端受理后在 SDK 锁和身份守卫内清群/历史/会话，避免 SDK包装先自行处理迟到旧账号回执。Runtime 发布带完整认证上下文的关闭事件，先退设置再退聊天，防动画中重open。后续服务端会话清理失败提示“群操作已受理…”而不误报退出失败；尚未对既有群执行退出/解散测试。

验证记录持续写入 [全量对齐验收台账](CONTACTS_MESSAGES_PARITY_QA_2026-10-14.md)，覆盖116项原需求及13项既有暂缓项。脚本曾有旧备注验收fake无限等待，已按确认保存合同修复并加5秒截止；更新fixture过程中全套抓到一项编译失败，后续需最终稳定复跑，不计全部通过。聚焦匿名检查不能代替真实SDK/服务器。

Mac当前真实App已收到真机B发来的 QA_20261014_B2A_1840 中文/emoji/第二行，并发出A2B1850；双向接收、已读及最终代码复验继续。真机18:58覆盖安装签名build成功（/tmp/ddlNew-parity-final-device-build.log），保留数据，install回执保存在 /tmp/ddlNew-parity-device-install.json；debug dylib SHA256 ae33417a430ce59d6782b68180d9ba652f32a1e3eea29b9e4891073d0cd400a2。交叉复核后仍在窄修，不把此过程构建当最终全部验收。真机普通公告1856已发布，正文和第二行可读，未自动置顶；最新删除返回/Toast待覆盖版本复验。既有公告未改动/删除，原备注Affff临时改为QA1014_A_备注🙂用于同步检查，验收后须恢复。


晚间19:14实际复验补充：54/54稳定离线脚本通过（260.56秒）与签名build/覆盖安装成功只是过程证据。真机确认A2B1850完整实收；1840发送条已读人数仍0/1，继续检查。公告编辑页确认删除后仍停留，Toast直到手动返回列表出现；列表摘要字面省略号会覆盖保存后的详情和再次编辑草稿。已继续修可见页受理callback返回和真实完整详情准备；19:13 QA1856条仍显示在列表，正在核对ID/版本，不宣称服务器消失。详见全量验收台账，不自动commit/push。


19:35真机公告删除返回已闭环：编辑真实14后confirm即自动回列表，服务器首屏只有原11/7，自建QA消失。诊断另证实编辑13回执新14；按xgd保存回公告列表避免旧ID操作。保留全文/真实详情编辑已复验。临时身份日志将移除，过滤证据见 /tmp/ddlNew-parity-evidence/notice-id-lifecycle.log。另补type13真实三段已读协议，51项离线通过，最终新marker实读人数继续。

21:xx补充：公告最新无诊断包普通发布→置顶→取消置顶→编辑删除已真机闭环，保存和删除均自动回列表；全文中文/emoji/换行保留，QA项回查消失，原公告保留。读计数新增AUTH范围SDK观察和成员epoch，保留未知初始正数/进程结束/SDK506无边界全清限制；最终59/59离线与签名build通过。真机又确认备注恢复时排序新而好友行视觉旧，最小展示identity修正构建通过，即时同步仍待末包复验。详情以全量验收台账最新章节为准，工作区保留、不提交推送。
