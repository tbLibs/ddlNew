# Contacts and Message Migration Implementation Plan

> **For agentic workers:** 使用 `superpowers:subagent-driven-development` 按文件责任开发、审查与修复；每批使用 `superpowers:test-driven-development`，交付使用 `superpowers:verification-before-completion`。SwiftUI 同时遵循 `swiftui-pro`，保持现有最低系统与工具链配置。

**Goal:** 按产品需求迁入明确建议的通讯录、消息、真实聊天与群能力，补齐既有UI并严格测试。

**Architecture:** Feature模型、可注入客户端、状态编排、页面分别放置；SDK及同步代理在 Network/IM，各用户异步结果绑定UID、邀请码和会话轮次。各Tab继续保留自己的NavigationStack，稳定ID路由进入真实聊天，原演示ChatScreen不接真实入口。

**Tech Stack:** 当前 Swift/SwiftUI、Combine、ObjectMapper、NoaChatCore、Kingfisher、现有文件/图片SDK，无新增第三方依赖。

**Spec:** Docs/CONTACTS_MESSAGE_MIGRATION_REQUIREMENTS.md、Docs/CONTACTS_MIGRATION_REQUIREMENTS.md、Docs/MESSAGE_MIGRATION_REQUIREMENTS.md。

## Global Constraints

- 用户已授权开发并补UI；已确认先完成明确建议迁移项，需取舍及独立待审阅能力暂缓。
- 继续当前 `feature-message-4` 工作区，保护用户未提交的需求文档，不擅自切分支、提交、推送或部署。
- iOS 16 最低目标及现有 Swift5 集成保持；版本特定API按可用性处理，禁止盲升系统或Swift版本。
- 每个新增或修改涉及的方法必须有中文注释；各主类型独立文件，目录与功能职责一致，禁止堆成巨型文件。
- 真实好友/群/消息基于SDK；成功以服务端回执与SDK回读为准，禁止恢复演示消息或假好友操作。
- 邀请码、登录、认证、凭据与网络质量规则保持；业务二维码与暂缓的导航扫码分离。
- 不修改生成Protobuf/第三方checkout/Pod锁定版本，不处理用户明确保留的umbrella警告。
- 测试报告区分离线、模拟器UI、单端真机与双端服务验收；用户稍后登录两端专用测试账号，不以编译代替联调。

## Review Focus

- 同UID重新登录、退出/换俱乐部、分页/上传迟到回调不能写入另一会话。
- 发送回执重排、双ID去重、失败重发、引用/编辑原消息须保留正确身份。
- 群禁言/角色权限/配置在页面打开后改变，显示与提交均守卫，失去权限不得重放操作。
- 删除好友、会话删除、消息删除、清空、退群解散各自范围及受理态不可混淆。
- SDK方法存在与真实UI可达/已验收分开，缺口必须进入逐需求验收台账。

## Task 1: UI与路由合同

**Files:** Docs/CONTACTS_MESSAGE_UI_DESIGN.md；Features/Chat/Models/ChatRoute.swift；Features/Tabbar/Views/TabbarView.swift。

**Interfaces:** `ChatRoute(id: String, kind: ConversationKind, title: String, avatarURL: String)` 为 Identifiable/Hashable/Sendable；`ChatRoomView(route: ChatRoute)`；Tabbar每个NavigationStack注册一次ChatRoute destination。

- [ ] UI设计师说明原UI上新增的列表切换/新朋友/操作菜单/输入/设置、状态和可访问性。
- [ ] iOS开发按设计接实际界面，已有组件复用，导航不携带可变快照。
- [ ] 测试导航、返回、sheet取消、长字和错误状态；确认没有假聊天路径。

## Task 2: 通讯录好友关系与资料

**Files:** Features/Contacts/{Models,Services,ViewModels,Views,Components}；Network/IM/Contacts；Tests/Contacts与新增 ContactsBusiness。

**Interfaces:** 复用 ContactsStore/ContactsClient；新关系操作客户端可注入；好友聊天使用ChatRoute单聊UID。

- [ ] C-001～019、C-030～031、C-036～038：真实检索、新朋友、同意/重申/本地隐藏、资料/备注/名片/删除受理，保留旧流程限制。
- [ ] 先写业务状态、错误、取消、身份隔离失败测试，再实现真实SDK适配。
- [ ] 扩展原ContactsView与详情UI，不重复创建好友同步所有者；每方法中文注释。
- [ ] 验证成功/拒绝/受理/无权限/重复点击与多端事件，SDK回读后刷新。

## Task 3: 好友分组、群列表与建群

**Files:** Features/Contacts/{Models,Services,Views}/分组相关；Features/Groups/{Models,Services,ViewModels,Views}；Network/IM/Groups；Tests/Groups。

**Interfaces:** Contacts开发方拥有共享GroupRecord与SDKGroupsClient；Chat群设置读群服务可先使用自己的detail DTO，需分享字段合同，不能重复更改共享GroupRecord。

- [ ] C-022～029、C-032：分组CRUD/排序/移动、群列表与搜索、选人建群、业务群二维码。
- [ ] 验证默认组、最低/最高选人、已有成员排除、权限变化、群返回、取消与群创建真实返回。
- [ ] 分组/群标签沿用当前卡片，系统sheet支持编辑/选人，稳定选择ID。

## Task 4: 真实单群聊基本闭环

**Files:** Features/Chat/{Models,Services,ViewModels,Views,Components}；Network/IM/Chat；Tests/Chat。

**Interfaces:** ChatRoute与ChatRoomView；注入ChatClient/ChatStore，真实SDK消息代理、历史、发送/ACK/失败/已读，根会话层负责关闭所有运行时服务。

- [ ] CHAT-001～009、CHAT-018：进入、数据库历史/服务补页100、实时收发、双ID去重、ACK重排、已读、文本、失败重发、禁言与配置守卫。
- [ ] 先以可暂停/错序客户端写失败测试，再实现SDK边界与状态机；复用已有SDK重试，不新增无限循环。
- [ ] UI显示日期、头像、正文、发送中/失败、重试、加载更多和新消息；从消息/好友进入同一真实路由。

## Task 5: 消息列表操作与全局搜索

**Files:** Features/Message；Features/Search；Network/IM/Conversations、Search；Tests/Conversations、Search。

**Interfaces:** 已有ConversationsStore公开只读快照；新增会话写操作可注入，成功后重新读库，MessageView以ChatRoute进入。

- [ ] M-001～018、M-024（仅已批准入口）、M-026～028：置顶、免打扰、标记未读已读、删除会话保留历史、草稿、全局好友/群/消息搜索与定位。
- [ ] M-014只保留已见同步，不新增待确认的全部已读入口；手动未读与真实未读冲突保留明确台账。
- [ ] 检查特殊会话权限/操作矩阵，真实列表与角标同步，无假成功。

## Task 6: 语音、图片视频、文件和消息操作

**Files:** Features/Chat/{Media,Models,Services,Views,Components}；Network/IM/Chat/媒体适配；Tests/ChatMedia、ChatActions。

- [ ] CHAT-010～017（贴纸非商城；位置仅历史显示）、CHAT-019～025、CHAT-028、CHAT-031～032。
- [ ] @、引用、复制、删除/撤回/编辑、多选≤100、逐条/合并转发、已读与消息置顶使用角色/单位/类型矩阵。
- [ ] 真实录制/拍摄选图/视频/文件上传下载，取消、资源过期、权限/磁盘错误、失败重试与退出回调隔离。
- [ ] 新输入工具及预览UI复用现有品牌；业务发送与SDK字节/回执由专用适配层处理。

## Task 7: 单群设置与群管理

**Files:** Features/Chat/Views/设置相关；Features/Groups/{Models,Services,Views}/详情与管理；Network/IM/Groups；Tests/GroupManagement。

- [ ] CHAT-030、CHAT-033～045：单聊设置/清空、群详情/成员、名称头像、昵称30、邀请移除、禁言、审核、管理员/转让、群开关、公告、退群解散。
- [ ] 请求仅用旧项目已证实参数；所有破坏性动作说明范围并确认，服务端受理态与完成态区分。
- [ ] 角色0/1/2、禁言、群私聊保护、权限临时收回、逐成员部分失败和多端变更严格测试。

## Task 8: 文件助手与群系统通知

**Files:** Features/Chat/文件助手支持；Features/SystemMessages；Network/IM/SystemMessages；Tests/SystemMessages。

- [ ] M-019/021、C-033/034、CHAT-041：文件助手100002与专门操作限制、全局/单群申请通知、10条分页、同意拒绝及批量逐结果。
- [ ] 客户端无真实拒绝好友协议，不误用群申请status；助手角标、权限隐藏与恢复保持一致。

## Task 9: 独立测试、审查与交付

**Files:** Docs/CONTACTS_MESSAGE_ACCEPTANCE.md；Tests各模块；Docs/PROJECT_HANDOFF.md。

- [ ] 测试人员按需求ID建立通过/失败/待真机/暂缓台账，实际执行全部新增与既有离线检查。
- [ ] 检查所有新/修改文件的方法中文注释、职责/目录、SDK边界、SwiftUI数据/导航及可访问性。
- [ ] UI设计师复核实现，模拟器UI用隔离测试宿主验证，禁止给生产AUTH增加演示绕过。
- [ ] 全工程无签名真机目标clean build，修复自己的编译错误/警告，既有依赖警告如实保留。
- [ ] 专用两端测试账号就绪后验收真实收发、好友/群业务、多端/前后台/弱网；尚未具备证据的项不标通过。
- [ ] 独立审查并修复明确问题，更新交接、保持未提交工作供用户审阅。

## 2026-10-13继续执行的进度说明

上方任务勾选作为原计划历史快照；实现、离线合同与严格真实验收不混为完成。当前实现已落地，严格逐项结果以CONTACTS_MESSAGE_TEST_REPORT.md为准，不批量勾选受身份/历史/环境限制的整项。

- [x] 最新三修正独立复核；发现并修正媒体失效close提示回归，12项通过。
- [x] 实测群成员items契约并修复解析；9项、两端成员页与A群主标签通过。
- [x] 前台/页面返回重读、清空旧读队列与批次所有权修复；Chat32通过，真实人数计数仍受阻。
- [x] 最新成员/读状态版本Mac→iPhone完整文本、单条服务ACK及B前后台群角标子场景实证；后续UI/日志终版My Mac运行复验因锁屏受阻。
- [x] 键盘/AXXXL正文可见与历史不跳底局部修复，Viewport7、隔离UI及独立SwiftUI复核通过。
- [x] 精确账号搜索旧协议偏差补修，userName参数2项/旧userUID和坏页25项绿，独立复核通过；最新42入口通过，B查A终版真机结果cs123及资料ceshi001均已复核。
- [x] 单聊SDK缓存非持久化status适配，正常DB好友0/1可发，缺行/注销/未知及来源群仍守卫；6项、独立复核、最新43/43入口及增量签名build通过。
- [x] 真实单聊长历史首屏稳定滚动修复；终版物理返页原Unicode标记1份，未重发，最新43/43入口110秒及签名构建通过，手机已覆盖安装。
- [x] 13文件日志诊断脱敏，180可执行匿名检查及独立反向回归通过，非日志业务保持一致。
- [x] 最终签名workspace clean build成功；最后完整离线重跑结果由报告记录。
- [x] 补齐21项公共严格台账，四个暂缓子用例保留Deferred；保存未提交工作。
- [ ] 第三专用身份/同账号双端、三角色、建群及破坏动作成功范围：缺授权/前提，不选择未知成员、不清原历史。
- [ ] Mac锁屏后的终版收发UI、真实媒体/读人数/弱网全矩阵、VoiceOver和宽窗：未具备证据，保留Blocked，不自动提交推送。
