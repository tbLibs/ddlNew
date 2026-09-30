# ddlNew

使用 `ddlNew.xcworkspace` 打开、构建和运行项目。应用源码按业务功能和基础设施分目录；目录移动不改变模块名或调用接口。

## 目录职责

| 目录 | 职责 |
| --- | --- |
| `ddlNew/App` | 应用入口、生命周期、启动流程、路由和桥接头 |
| `ddlNew/Features` | 各功能的页面、ViewModel、模型、服务和专用 UI 组件 |
| `ddlNew/Features/Tabbar` | 主界面唯一的四栏容器：首页、消息、通讯录、我的 |
| `ddlNew/Features/Home` | 当前首页及其专用组件、样式和活动／俱乐部入口 |
| `ddlNew/Features/Message`、`Contacts`、`Mine` | 消息、通讯录、个人中心及各自的二级页面 |
| `ddlNew/Features/Activities`、`Club` | 活动列表、报名签到、参与记录，以及俱乐部介绍和信息页面 |
| `ddlNew/Common/Club`、`Community` | 跨页面共享的本地俱乐部和社区展示状态 |
| `ddlNew/Common/Components`、`Design`、`Legal` | 通用 UI 组件、共用配色和本地法律文档展示 |
| `ddlNew/Common/User` | 用户资料与会话凭据存储 |
| `ddlNew/Common/Database` | 用户数据库生命周期管理和俱乐部本地快照数据库 |
| `ddlNew/Common/Crypto` | 通用加解密工具 |
| `ddlNew/Network/Core` | Moya 请求封装、公共请求头、ObjectMapper 扩展 |
| `ddlNew/Network/DNS` | 五路 DNS 查询、数据解码、域名规范化 |
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

应用页面已经按功能迁入 `Features`，不再保留 `Main` 和 `OldVersion` 目录。主界面路径为 `ddlNewApp → TabbarView → ClubHomeView / MessageView / ContactsView / MineView`。原版首页、邀请码页和登录页分别以 `OriginalHomeView`、`OriginalInvitationCodeView`、`OriginalLoginView` 保留在对应功能目录中，不接入当前应用入口。

活动、消息和通讯录仍使用原有本地演示数据；目录迁移不代表已经接通 SDK 的消息、联系人或服务端活动接口。本地法律文档资源统一放在 `Resources/Legal`，按原有资源名称读取。

`NoaChatSDKCore`、`NetWorkStatus`、Pods 和静态库不属于本次应用目录整理范围。`ddlNew/Basic/LXChatEncrypt` 保持原位，以保留静态库链接和头文件路径。

启动连接流程保留 DNS/OSS、SDK 配置、TCP/ECDH、系统配置的现有顺序。账号密码请求成功还不代表 IM 登录就绪：必须收到 SDK 的用户 AUTH ACK 成功回调，才完成登录并允许后续业务流程。目录整理不改变该判定。
