# ddlNew

使用 `ddlNew.xcworkspace` 打开、构建和运行项目。应用源码按业务功能和基础设施分目录；目录移动不改变模块名或调用接口。

最新续接入口：[2026-10-15聊天输入、群发送与默认游戏交接](Docs/SESSION_HANDOFF_2026-10-15_CHAT_INPUT_GAMES.md)。实时Git优先，Mobile MCP仍暂停，不自动提交/推送；构建和离线检查不代替设备及双端服务器验收。

2026-10-15新增真实SDK黑名单与系统投诉（好友资料/群设置/我的），仅系统投诉、不含邀请码/IP域名。历史演示拉黑/举报仍已删除，当前为独立真实接口实现；离线/构建通过，服务器及设备待验，详见[迁移记录](Docs/SAFETY_REPORT_BLOCK_MIGRATION_2026-10-15.md)。

## 目录职责

| 目录 | 职责 |
| --- | --- |
| `ddlNew/App` | 应用入口、生命周期、启动流程、路由和桥接头 |
| `ddlNew/Features` | 各功能的页面、ViewModel、模型、服务和专用 UI 组件 |
| `ddlNew/Features/Tabbar` | 主界面唯一的四栏容器：首页、消息、通讯录、我的 |
| `ddlNew/Features/Home` | 当前首页及其专用组件、样式和活动／俱乐部入口 |
| `ddlNew/Features/Message`、`Contacts`、`Mine` | 消息、通讯录、个人中心及各自的二级页面 |
| `ddlNew/Features/Chat`、`Groups`、`GroupApplications`、`Search` | 真实聊天、群列表与建群、群申请通知、SDK本地全局搜索 |
| `ddlNew/Features/Activities`、`Club` | 活动列表、报名签到、参与记录，以及俱乐部介绍和信息页面 |
| `ddlNew/Common/Club`、`Community` | 跨页面共享的本地俱乐部和社区展示状态 |
| `ddlNew/Common/Components`、`Design`、`Legal` | 通用 UI 组件、共用配色和在线法律文档展示 |
| `ddlNew/Common/User` | 用户资料与会话凭据存储 |
| `ddlNew/Common/Database` | 用户数据库生命周期管理和俱乐部本地快照数据库 |
| `ddlNew/Common/Crypto` | 通用加解密工具 |
| `ddlNew/Common/Media` | 旧媒体格式编解码、云上传及共用网络图片处理 |
| `ddlNew/Network/Core` | Moya 请求封装、公共请求头、ObjectMapper 扩展 |
| `ddlNew/Network/DNS1` | 当前 APP t 域解析、BIN 降级、原生 TCP/ECDH 竞速 |
| `ddlNew/Network/DNS` | 保留的旧五路 DNS 查询、数据解码、域名规范化 |
| `ddlNew/Network/OSS` | OSS 节点竞速、导航响应、导航缓存和连接准备 |
| `ddlNew/Network/IM` | SDK 连接、TCP/ECDH、用户 AUTH 与 SDK 适配 |
| `ddlNew/Network/SystemConfig` | 系统配置请求、解析和存储 |
| `ddlNew/Configuration` | 常量、固定缓存 key、服务地址 |
| `ddlNew/Protocols/Nav` | Nav 协议定义与生成的 Swift Protobuf 代码 |
| `ddlNew/Resources` | 图片、启动屏和隐私清单 |

## 放置新代码

- 功能专用的页面、组件、模型和业务编排放在对应 `Features/<功能>`，不把所有服务塞进 `Common`。
- 网络传输及 SDK 适配放在 `Network`；登录业务编排放在 `Features/Login/Services`。
- 跨功能复用且职责明确的代码再放入 `Common`，一个主要类型一个文件。
- 服务器业务 path 统一放在 `Network/NetworkPath.swift`；固定存储 key 和服务常量放在 `Configuration/Const.swift`。
- `Nav.pb.swift` 是生成代码，协议变更时修改 `nav.proto` 后重新生成。

## 当前边界

应用页面已经按功能迁入 `Features`，不再保留 `Main` 和 `OldVersion` 目录。主界面路径为 `ddlNewApp → TabbarView → ClubHomeView / MessageView / ContactsView / MineView`。原版首页、邀请码页、登录页、演示消息和演示通讯录分别以 `OriginalHomeView`、`OriginalInvitationCodeView`、`OriginalLoginView`、`OriginalMessagesView`、`OriginalContactsView` 保留在对应功能目录中，不接入当前真实业务入口。旧演示注册逻辑保留在对应功能及共享状态目录中；演示拉黑和举报已删除。

通讯录使用 SDK 好友数据库：登录前注册用户代理，AUTH 后读取缓存，同步完成及好友变化时刷新。沿用老项目的系统账号过滤、备注优先、拼音首字母分组和已注销账号置后规则。真实资料、好友申请、备注、业务分组、群列表、选人建群与业务二维码已接入。通讯录展示状态在退出、账号失效和更换账号时清空，好友持久化仍由 SDK 管理。

活动仍使用原有本地演示数据；消息 Tab 接 SDK 会话列表、未读角标及真实列表操作，进入统一 `ChatRoomView`。聊天支持历史、文本及媒体收发、消息操作、单群设置与群申请。范围见 `Docs/CONTACTS_MESSAGE_DEVELOPMENT_SCOPE.md`，已明确暂缓的能力保持暂缓。实现、离线通过和实际两端验收分开记录在 `Docs/CONTACTS_MESSAGE_TEST_REPORT.md`；当前不据此声明全部业务通过。隐私与支持通过在线法律页面展示，地址从 `Resources/Legal/LegalLinks.json` 读取；本地 HTML 和开源许可入口已移除。

`NoaChatSDKCore`、`NetWorkStatus`、Pods 和静态库不属于本次应用目录整理范围。`ddlNew/Basic/LXChatEncrypt` 保持原位，以保留静态库链接和头文件路径。

启动连接当前使用 APP DNS1：t 域主备/BIN 给出原生 TCP，ECDH 竞速后建立正式连接，再经 TCP 获取系统配置；HTTP 为可选文件地址。DNS1来源全部耗尽后继续旧五路/OSS导航兜底，冷启动与已登录重连共用该顺序；两种导航按实际来源准备连接，细节见 `Docs/PROJECT_HANDOFF.md` 的 2026-10-22 章节。账号密码请求成功还不代表 IM 登录就绪：必须收到 SDK 的用户 AUTH ACK 成功回调，才完成登录并允许后续业务流程。目录整理不改变该判定。

## 通讯录验证

执行 `bash Tests/Contacts/run-checks.sh`，离线验证生产模型与状态层的排序、完整拼音搜索、系统好友过滤、同步事件、错误恢复、异步账号隔离、备注请求版本，以及 SDK 分页校验和在线 UID 合并。测试复用 Xcode 已检出的 ObjectMapper（也可设置 `CONTACTS_OBJECTMAPPER_SOURCES`），不访问服务器或真实用户数据库。真机登录后打开通讯录，可查看 SDK 的好友列表及资料；没有好友时显示真实空列表。

通讯录头像使用 Kingfisher 缓存、请求去重和尺寸处理。图片仅对导航文件 Host 沿用业务接口的临时无效证书策略，其他图片 Host 仍按系统规则校验；服务端证书修复后应移除此例外。
