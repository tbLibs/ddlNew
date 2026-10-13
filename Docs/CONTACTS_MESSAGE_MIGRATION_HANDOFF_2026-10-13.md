# 通讯录与消息迁移交接文档

日期：2026-10-13。**状态：用户要求暂停，开发与联调已停止。**

仓库：`/Users/taobotaobo/Desktop/ddlNew`；分支：`feature-message-4`；HEAD：`4c8f593`（`feat：开发通讯录和消息的功能`）；本轮开发起点：`78876ca`。
整理期间检测到仓库新增提交 `4c8f593`，已包含本轮开发与测试文件；该提交不是本次整理动作创建的。当前剩余修改为交接文档及相关记录；远端是否收到该提交未联网核验。接手时重新检查Git状态，不要整体回退、清理未跟踪文件或覆盖用户工程配置。

## 新窗口接手顺序

1. 完整阅读根 `AGENTS.md`、[PROJECT_HANDOFF.md](PROJECT_HANDOFF.md)及本文，再检查当前分支、`git status`、暂存区和未跟踪文件。源码与现场状态优先于历史文档。
2. 阅读[批准范围](CONTACTS_MESSAGE_DEVELOPMENT_SCOPE.md)、[实施计划](superpowers/plans/2026-10-13-contacts-message-development.md)和[测试报告](CONTACTS_MESSAGE_TEST_REPORT.md)。计划中的早期未勾选项不代表全部尚未实现，以本文和实际代码为准。
3. 用户在新窗口要求继续后，先接手最新三项修正的复核，再恢复两端联调。确保同一时刻只有一位测试人员操作设备，避免并行构建共用 DerivedData。
4. 核对两端版本、真实账号及“有魄力”群的权限。优先完成最新版本 My Mac → iPhone 的发送与接收，再检查 ACK、已读和前后台恢复。
5. 按测试报告逐项完成正式需求及公共验收，记录每项的证据和未通过原因；只有源码、隔离测试或本端气泡时，不标记真实业务验收通过。

## 一、范围与约定

- 正式需求116项：通讯录38项、消息29项、关联聊天49项；批准纳入103项，整体暂缓13项，另有部分子能力暂缓。
- 专项验收232条，另有公共验收21条。**本轮尚未完成全部验收，不能作为发布通过结论。**
- 继续使用 Superpowers 和 `swiftui-pro`；保持项目 iOS 16 / Swift 5 设置，代码按 Feature 与 SDK 适配层归类，每个新增或修改方法添加中文注释。
- 用户工程中的 Mac、沙盒等配置已保留；未升级生产依赖，未修改 Pods 或生成的协议代码。
- 实际服务端行为对照老项目 `/Users/taobotaobo/Desktop/xgd`，不恢复演示拉黑、举报或假登录。

## 二、已完成的实现

以下为源码实现进度，真实后端验收情况见后文。

| 模块 | 已完成内容 | 主要位置 |
| --- | --- | --- |
| 好友与新朋友 | 真实好友列表、查找与资料、申请/接受/重新申请、本地隐藏、20条分页、未读、关系同步；资料请求乱序与损坏数据防护 | `ddlNew/Features/Contacts/`、`ddlNew/Network/IM/Contacts/` |
| 备注与业务分组 | 备注/描述长度约束、未修改禁保存、脏数据取消确认；分组新增/修改/删除/排序、默认组与移动好友 | 同上 |
| 群列表与选人 | 真实群列表、2～200位好友选人约束、去重/过滤、建群与邀请入口；业务二维码展示、扫码及分享 | `ddlNew/Features/Groups/`、Contacts组件、`Network/IM/Groups/` |
| 会话与搜索 | 置顶、免打扰、未读、删除会话保留历史；文件助手仅置顶/删除；稳定聊天路由、本地好友/群/消息搜索及消息定位 | `Features/Message/`、`Features/Search/`、对应SDK适配层 |
| 群申请与通知 | 10条分页、逐条批量结果、权限守卫；系统会话chatType 5的已读边界快照，保留等待期间新通知未读 | `Features/GroupApplications/`、`Network/IM/GroupApplications/` |
| 聊天核心 | 100条历史分页、真实收发与ACK去重、失败/重试、批量已读、草稿、引用、@；迟到历史与身份切换隔离 | `Features/Chat/Services/`、`Models/`、`Network/IM/Chat/` |
| 消息操作 | 复制、回复、删除范围、撤回、编辑、最多100条选择、转发/逐目标结果、合并记录、置顶与聊天历史搜索 | `Features/Chat/`、`Network/IM/Chat/` |
| 群详情与管理 | 群名/头像/本人群昵称、成员角色预览、邀请/移除、禁言状态与名单、审批、管理员/转让、群开关/公告、退出/解散 | Chat设置页面和SDK设置适配层 |
| 群事件同步 | 禁言221与删成员历史204/通知失效；群昵称sync2/15/1透明代理、排队刷新与已加载作者重映射，保留正文/ACK/墓碑 | `SDKChatDelegate`、`SDKChatNicknameObserver`、`SDKChatMessageForwarder`等 |
| 媒体与旧格式 | 语音、图片、视频、文件入口与传输/预览；四供应商签名与STS、Minio分块、旧XOR/AES解码、头像101与旧目录、GIF保留播放 | `Features/Chat/Media/`、`Common/Media/`、[云传输说明](CHAT_CLOUD_TRANSPORT.md) |
| 会话生命周期 | AUTH统一绑定UID/邀请码/轮次；登出、账号失效或租户切换关闭各业务Store与ChatRuntime，拒绝迟到回调 | `Features/Login/Services/LoginSessionService.swift` |

### 已完成的审查修正

通讯录及根集成的具体审查问题已修复。聊天审查发现的7项缺陷和3项已批准子能力遗漏已补齐，复核未再发现确定的新问题。包括群QR参数 `isShowQrCode`、本人转发已读状态、管理员撤回窗口、缓存版本比较、禁言/删除事件及群昵称同步。详见[聊天覆盖记录](../Tests/Chat/CHAT_IMPLEMENTATION_COVERAGE.md)。

### 独立审查之后的最新修正

这三项由根接手完成；已有离线/构建或布局证据，**尚未再经过新的独立人员完整复核**。

1. **聊天键盘遮挡**：`ChatRoomView.swift`移除重叠的系统键盘工具栏，在输入区增加44pt收起键盘行；发送按钮可点击区域44×44。隔离宿主实测输入与发送位于键盘上方，收起后正文保留。
2. **已打开附件被删除后仍可播放/重载**：`ChatMediaPreviewStore`保存绑定消息身份，删除/撤回/清历史后取消下载、停播并禁止重试；后台close仍保留失效识别。`ChatStore`与`ChatRuntime`已接失效回调；真实音视频及跨端删除场景仍待验收。
3. **邀请码1000初始化失败**：现场日志确认ECDH成功，随后系统配置HTTP请求超时；旧项目SDK配置接口在已有Socket Host/Port时优先TCP。`SystemConfigService.swift`改复用 `SDKSessionMaintenanceClient.configuration(host:loggedIn:false)`，保留配置映射、取消、租户及请求轮次守卫。用户已反馈最新版本1000登录成功，真实UI也核对了两端身份。

## 三、已经执行的验证

| 验证 | 结果 | 证据与边界 |
| --- | --- | --- |
| 最新完整离线脚本 | **38/38入口exit 0** | `/tmp/ddlNew-migration-qa-final-transport/summary.json`；总151.07秒，由根执行，含最新键盘/媒体阶段后的逻辑及系统配置测试。入口数不是需求完成数 |
| 独立QA此前完整回归 | 36/36入口exit 0 | `/tmp/ddlNew-migration-qa-postreview/summary.json`；106.59秒，早于最后三项根修正 |
| 最新媒体失效回归 | 9项通过 | `Tests/Chat/run-preview-invalidation-checks.sh`，使用生产方法及系统对象替身，未使用真实播放器/服务端 |
| 最新Chat核心回归 | 23项通过 | `Tests/Chat/run-checks.sh`，包含撤回/清历史通知与昵称/墓碑等场景 |
| 系统配置传输回归 | 3项通过 | `Tests/Network/run-system-config-transport-checks.sh`，覆盖HTTP不可用、SDK可用、旧轮次及取消；传输和磁盘为测试替身 |
| 整个workspace签名构建 | 成功 | 最新 `/tmp/ddlNew-contacts-message-system-config-transport-build.log`；此前媒体/键盘 `/tmp/ddlNew-contacts-message-final-media-keyboard-build2.log` |
| 整个workspace clean build | 成功，较早快照 | `/tmp/ddlNew-contacts-message-final-clean.log`；不能代替最新增量签名构建 |
| 键盘布局复测 | 默认字号局部通过 | `/tmp/ddlNew-qa-keyboard-final-green.png`；隔离宿主，不代表生产Mac输入、最终最大字号/VoiceOver全部通过 |
| 最新两端登录 | 已确认 | 手机与My Mac实际“添加好友→我的账号”确认身份；邀请码1000用户反馈可登录 |
| 最新iPhone→My Mac群消息 | 已观察真实接收 | “有魄力”群 `QA_20261013_1600_B2A`，接收端精确1条；尚未核对ACK字段与已读计数 |
| 较早版本双向文本 | 已观察 | `QA_20261013_1405_B2A`和`QA_20261013_1403_A2B`两端各1条；更新重启后仍可见，只作历史恢复子证据 |

构建仍有既有SDK/OSS/ObjectMapper/PCM等警告，不宣称零警告。离线回归与匿名UI宿主没有访问真实云账户，不能证明所有上传供应商、实际播放或SDK二进制回执正确。

## 四、未完成任务（继续时的优先级）

### P0：最新版本双端消息闭环

- **My Mac→iPhone尚未在最新版本发送成功。** 自动输入 `QA_20261013_1600_A2B`后核对输入值不匹配，未点击发送；不能记为发送失败或已送达。先修复测试操作方式或由用户手动输入，然后确认另一端只收1条。
- 核对真实ACK字段、发送中/失败/重试、已读计数与他端已读；验证前后台、断网重连、冷启动自动恢复及迟到回调。
- 补单聊测试；现有跨端证据主要来自专用群。
- 验证他端禁言、删除成员历史、群昵称更新在打开页面和后台预览中的实际回流。

### P1：通讯录、群管理与媒体验收

- 好友申请/接受/拒绝或隐藏/删除/重加、真实备注更新、业务分组增删改移动、二维码扫码与相机权限。
- 确认“有魄力”中账号A/B的群主/管理员角色，再按权限测试邀请、移除、禁言、审批、转让、开关、公告等；只操作已授权对象。
- 建群至少需要群主外另选两位好友；目前仅两组测试身份，建群验收仍缺第三个经授权身份。
- 编辑、撤回、删除、置顶、单条/合并转发及部分失败，尤其本人转发未读数与管理员撤回他人消息。
- 真语音录制、照片/视频/文件上传下载、四供应商实际配置、旧XOR/AES与GIF显示、播放前后台恢复、删除后停播/禁止重载、弱网取消和账号切换隔离。

### P1/P2：最终复核与测试收尾

- 独立复核最后三项根修正，重点为系统配置TCP接入与轮次、媒体失效回调、输入区布局。
- 最终输入区最大字号/横屏、真实VoiceOver操作、iPad布局尚未完成；测试报告M-028整体仍Blocked。
- 深历史连续补页采用VStack后的真实设备渲染成本尚未评估，不能据此直接认定性能缺陷。
- 完成新增/修改方法中文注释和文件归类的最终检查，尤其新增测试辅助方法尚未全面检查。
- 按116个ID、232条专项及公共21条逐项收尾，更新测试报告与计划完成状态；全部批准能力完成严格验收后再决定提交/合并。

## 五、明确暂缓的内容

整体暂缓：C-020拉黑、C-021举报、C-035团队；M-020群发、M-022签到、M-023支付、M-025双击未读、M-029推送深链；CHAT-026收藏/链接、CHAT-027翻译、CHAT-029自动删除、CHAT-046发起通话、CHAT-047机器人/活跃等级。

子范围：CHAT-014只兼容既有贴纸/历史游戏，暂缓商城与新游戏；CHAT-016只展示历史位置，暂缓发送；C-038只聊天不通话；M-014只兼容已有全读同步、不新增全读按钮；CHAT-049只兼容历史加密/阅后消息、不新增发起。CHAT-043群禁止通话设置仍属于本轮批准范围。

此前暂缓的手机号/邮箱登录、短信/邮箱验证码登录、找回密码、IP/域名直连、扫码导入导航、应用内SOCKS5，以及动态品牌展示和动态诊断配置，均不因本轮迁移自动恢复。业务联系人/群二维码与导航扫码不同。

## 六、现场与工具交接

| 项目 | 暂停时状态 |
| --- | --- |
| 手机 | 名为“iPhone”的真机，账号B `ceshi002`；设备ID `00008101-000100820E41001E` |
| 电脑端 | My Mac运行“叮咚聊”，账号A `ceshi001`，用户已开启辅助功能权限 |
| 测试入口/群 | 邀请码1000，既有专用群“有魄力”；群管理角色未核实 |
| 另一台已连接手机 | 仅有安装记录，不作为已认证测试端 |
| 自动化 | 本任务go-ios tunnel / runwda / forward已停止，无继续运行的子代理；没有退出用户账号或清空历史 |

密码、Token、密钥不写入交接文档。设备登录与进程状态会变化，新窗口恢复时重新核对现场。

- 本地真机工具位于 `/tmp/ddlNew-device-automation`，不属于生产依赖；配对记录保持私有，不复制到仓库。
- 真机WDA使用本地 **8101**，模拟器MCP使用 **8100**。mobile-mcp的UI控制固定8100，不能直接当真机控制使用，否则可能操作错端。
- 重启WDA后若转发监听还在但请求失败，先检查本任务forward是否需要重启，不要直接重建全部工具或终止其他进程。
- `Tests/MigrationAcceptance/PhoneUIBridge.cjs`与`MacUIBridge.js`已有辅助工具；Mac辅助树全量读取慢，键入命令返回成功不代表正文真的输入，必须核对值/截图后才发送。
- 临时原生Mac辅助工具 `/tmp/ddlNew-native-mac-qa.swift`及同名二进制仅验证过inspect，type/send尚未验证；临时目录可能被系统清理。
- My Mac通过Xcode的Designed for iPad/iPhone目标启动；直接open iOS产物可能报执行格式错误。恢复后核对运行包的debug dylib，不能只比较启动可执行文件。

需要重建时使用workspace：

```sh
PATH=/usr/bin:/bin:/usr/sbin:/sbin /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -workspace ddlNew.xcworkspace -scheme ddlNew -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /Users/taobotaobo/Library/Developer/Xcode/DerivedData/ddlNew-gouvoiamsobqkuevngdfnxdlbzay \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=YES build
```

离线脚本执行方式示例：`bash Tests/Chat/run-checks.sh`。完整38个入口以汇总JSON为清单；只有修改相关逻辑或最终验收需要时再复跑，避免无目标重复测试。

## 七、文档入口与新窗口提示词

- 产品：[总纲](CONTACTS_MESSAGE_MIGRATION_REQUIREMENTS.md)、[通讯录](CONTACTS_MIGRATION_REQUIREMENTS.md)、[消息](MESSAGE_MIGRATION_REQUIREMENTS.md)。
- 开发：[范围](CONTACTS_MESSAGE_DEVELOPMENT_SCOPE.md)、[计划](superpowers/plans/2026-10-13-contacts-message-development.md)、[云传输](CHAT_CLOUD_TRANSPORT.md)。
- UI：[设计](CONTACTS_MESSAGE_UI_DESIGN.md)、[复核](CONTACTS_MESSAGE_UI_REVIEW.md)。
- 验收：[测试报告](CONTACTS_MESSAGE_TEST_REPORT.md)、[Chat覆盖](../Tests/Chat/CHAT_IMPLEMENTATION_COVERAGE.md)。这些文件包含历史快照，当前暂停状态和最新增补以本文为准。

可复制到新窗口：

> 继续ddlNew通讯录与消息迁移。先完整阅读AGENTS.md、Docs/PROJECT_HANDOFF.md和Docs/CONTACTS_MESSAGE_MIGRATION_HANDOFF_2026-10-13.md。以feature-message-4当前提交4c8f593及工作区为起点，保留所有未提交修改，使用Superpowers和swiftui-pro，新增或修改方法添加中文注释。先复核最新三项修正，再完成最新版本My Mac→iPhone消息闭环和剩余严格验收，逐项更新测试报告。只操作已授权账号A/B及“有魄力”群，不保存密码，不清空既有历史，不实现暂缓范围，不自动提交或推送；缺少群角色或第三测试身份时先说明需要的授权。
