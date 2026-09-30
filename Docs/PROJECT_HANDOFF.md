# ddlNew 项目交接文档

更新时间：2026-09-30

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
→ 获取登录加密密钥并加密密码
→ 发送账号登录请求
→ 保存用户资料和凭据
→ SDK 用户配置与用户数据库就绪
→ 等待用户 AUTH ACK
→ 进入四栏主界面
```

应用重启时，如果存在可用入口和会话凭据，会一直显示与 LaunchScreen 一致的等待页，在后台完成连接恢复和用户 AUTH；只有 AUTH 成功后才进入主界面。没有可用入口时显示邀请码页；有入口但没有有效用户会话时显示登录页。

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
- 临时断网时保留凭据并退避重试；明确的账号失效才清理缓存。
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

1. 获取一次性 `encryptKey`。
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

活动导航统一由 `ActivityNavigationScope` 注入，避免二级页面缺失 `ActivityNavigation` 环境对象。旧的 `Main` 和 `OldVersion` 目录已经删除；保留的原版演示页面以 `OriginalHomeView`、`OriginalInvitationCodeView`、`OriginalLoginView` 命名，不接当前入口。

网络图片使用 Kingfisher。通讯录头像对导航下发的文件 Host 使用项目现有的临时证书策略，其他 Host 仍按系统规则校验。

## 通讯录实现边界

核心文件：

- `ddlNew/Features/Contacts/Services/ContactsStore.swift`
- `ddlNew/Network/IM/Contacts/SDKContactsClient.swift`
- `ddlNew/Network/IM/Contacts/SDKContactsDelegate.swift`
- `ddlNew/Features/Contacts/Views/ContactsView.swift`

AUTH 前注册 SDK 用户代理，AUTH 后读取 SDK 本地好友数据库。SDK 同步完成、好友变化和备注变化会触发刷新；迟到回调通过用户 UID 与 generation 隔离。排序规则沿用旧项目：系统账号过滤、备注优先、拼音首字母分组、已注销账号置后。

尚未完成：好友申请、修改备注 UI、从好友详情发起真实聊天。

## 消息会话实现边界

核心文件：`ddlNew/Features/Message/Models/ConversationRecord.swift`、`Services/ConversationsStore.swift`、`Views/MessageView.swift`，以及 `ddlNew/Network/IM/Conversations/SDKConversationsClient.swift`、`SDKConversationsDelegate.swift`。

AUTH 前注册会话代理，AUTH 后读取 SDK 本地会话库；SDK 分页代理先于数据库写入，因此同步完成后才做完整重读。首轮同步中的最新消息按旧项目做法写入 SDK 消息表，使预览可从缓存恢复；实时会话变化触发合并刷新。只显示 `sessionStatus == 1` 且属于已知类型的会话，置顶优先、组内按最新消息时间倒序，按会话 ID 去重。Tab 角标来自真实可见会话未读数，免打扰不计入，手动标记未读计 1。登出或切换账号时通过 UID 与 generation 清空并隔离状态。

消息页已移除 `ClubCommunity` 演示会话、假全部已读和跳往演示 `ChatScreen` 的入口。当前 P0 只读：列表行尚不能打开真实聊天；搜索只匹配已加载的会话名称和预览，不是消息历史全文搜索。当前 P0 未处理旧项目文件助手权限开关，需在接入服务端角色权限时补齐；通知类会话按 SDK 类型显示，具体入口待后续实现。

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

历史通讯录验证在 `feature-contacts-3` 的 `Tests/Contacts/run-checks.sh` 中完成过：生产逻辑 39 项、SDK 分页 19 项均通过。当前提交 `f975457` 已删除整个 `Tests/Contacts` 目录，因此当前分支不能再执行该命令；根目录 `README.md` 中的通讯录验证命令也已过期。需要继续修改通讯录时，应先从 Git 历史理解并恢复或重建等价测试，不要把历史结果当作当前改动的验证证据。

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
