# 2026-10-15 最新交接：聊天输入、群发送与默认游戏表情

本文件整合10月15日后续聊天工作。先完整阅读`PROJECT_HANDOFF.md`及本文，再按需查看[凌晨统一交接](SESSION_HANDOFF_2026-10-15_OVERNIGHT_MESSAGES_CONTACTS.md)和[116项验收台账](CONTACTS_MESSAGES_PARITY_QA_2026-10-14.md)。源码、实时Git及用户最新要求优先于历史快照。

## 1. 接手基线与授权

- 工作目录`/Users/taobotaobo/Desktop/ddlNew`，实时整理基线`feature-message-4 / ecf1b89`。本轮没有暂存、提交或推送；工作区有本轮及此前多个阶段的修改，接手必须再次检查Git，不以此快照覆盖新改动。
- 用户明确暂停Mobile MCP，当前仍暂停；没有改用其它工具操作设备。仅曾只读查询现有Mac进程系统日志，未取到权限业务字段。没有执行新的真实投诉、黑名单、群成员操作或游戏消息收发。
- `/Users/taobotaobo/Desktop/xgd`只读作为行为和资源参考，旧仓库保持干净。沿用首页/我的森林绿、UIAdapter、中文业务注释及现有SDK/登录所有权。
- 用户批准系统投诉，不含邀请码/IP域名；批准聊天整体布局、原生toolbar、键入@、工具四等分；最新明确追加默认石头剪刀布和骰子发送，覆盖此前CHAT-014“新游戏暂缓”中这两个默认游戏的子范围。商城、其它新游戏、位置发送、通话、收藏/翻译等既有暂缓不自动恢复。
- 同期工作区另有聊天头像回退修正及`run-avatar-checks.sh`，保留其实现与专项证据，见PROJECT_HANDOFF对应章节；本轮统一检查也会覆盖这个当前脚本，不将该工作冒称为本聊天输入修正。

## 2. 当前代码状态

| 项目 | 实现与边界 |
| --- | --- |
| 原生导航栏 | 四个实际Tab根页和活动相关重复标题使用`.toolbar {}`；群申请顶部安全区仍是业务筛选，底部输入/提交条保留职责；未接入的Original原型不作为实际页面改造。详见[导航迁移记录](NAVIGATION_TOOLBAR_MIGRATION_2026-10-15.md) |
| 聊天布局 | 输入框内表情、语音/发送切换、引用单独取消、多选独立底栏、群公告及紧凑消息行。工具固定相册/拍摄/文件/更多四等分居中，没有底部@成员按钮 |
| 基础表情 | 157个旧图片资源，默认面板可用，插入/复制/发送保留`[微笑]`等旧文本标记；Unicode及未知方括号文字保留。贴纸仍独立走真实SDK type12。最近使用仅当前面板实例7项，不声明跨启动持久化 |
| 群提及 | 仅键入单个@调当前群真实完整成员，可搜索/所有人-1，在光标处替换并绑定真实UID；取消留普通@。昵称含@、重复文本使用明确范围平移；迟到请求不能覆盖子页、草稿、输入面板或焦点 |
| 输入后收键盘 | UIKit富文本输入已改成`@State Bool → Binding<Bool> → UITextView`手动焦点；移除这条链上的无`.focused`目标FocusState。正文更新不以未注册的SwiftUI焦点值收键盘；其它原生表单FocusState不改 |
| 群输入全灰 | 已获得用户真实字段证据并修正缺省个人禁言解析，详见第3节；显式禁言/离群/停用等仍控制发送 |
| 默认游戏 | 基础表情面板增加石头剪刀布和骰子两个入口，使用旧资源、type21及SDK游戏字段。3秒动画后定格已发送结果，实际可见且前台才播放，减少动态效果时直接定格；细节见第4节 |
| 举报/拉黑及资料路由 | 已有真实接口、投诉图标、聊天设置查看好友资料及媒体取消修正全部保留；具体真实服务器待验见此前记录 |

## 3. 群发送被误禁用的证据与修正

用户实际表现：群聊键盘、相册、拍摄等全部置灰；正文顶部“正在确认群发送权限”；Toast“消息响应无效，请重试”。最初只有加密帧/请求返回日志，无法据此判断业务值；只读Mac系统日志也没有这三个字段。

临时DEBUG诊断仅输出固定三字段的归一化形状，不输出群资料、账号、Token或完整请求/响应。用户重新Run后提供：

```text
[ChatGroupPermission] detail.userInGroup=true mute.isGroupForbid=missing mute.isGroupChat=false
```

旧端`NoaChatViewController.getUserNotalkState`对缺省个人禁言字段用`integerValue`解释为0；新端原`verified`却强制要求该键存在，导致整个快照不发布，输入永久停留在确认状态。现`ChatGroupPermissionPayload.personalMuted`仅对**键缺省**解释为false，明确null/非法值仍不确认；在群状态、全群禁言仍必须明确。`SDKChatClient.permissions`复用同一规则，避免校验通过而实际发送再被另一套默认值拒绝。

独立复核同时确认另一问题：详情/本地群表的旧全群禁言与随后返回的最新禁言接口做OR，会阻止已解除禁言的普通成员。现沿旧端采用最新禁言接口的明确值，真实全群禁言、个人禁言及管理员豁免规则保持。

回归包含真实字段形状、null/非法、缺全禁字段、最新值与旧群表冲突、个人/全群禁言、管理者、离群/缺资料等；先RED后GREEN。用户提供的字段只证明读取形状，不能代替修正版实际发送、对端接收和服务器ACK。DEBUG固定字段日志暂保留，后续复验可只提供此行，不粘贴完整认证/业务响应。

## 4. 默认石头剪刀布与骰子

旧端依据：

- `NoaChatGitImgCollectionView.defaultGameStickersData`：两个默认入口。
- `NoaChatViewController.chatInputViewPlayGameStickerAction`：客户端随机生成1–3或1–6。
- `NoaMessageSendHander.ZMessageGameStickersSendResultContent`及重试分支：type21、type1石头剪刀布/type2骰子、字符串结果、空ext；失败重试重新生成结果。
- `NoaMessageGameStickersCell`：旧帧动画3秒后定格；完成后标记并写回SDK。
- SDK`LingIMModelTool`使用`gameSticekersType/gameStickersResut/gameStickersExt`生成真实GameStickersMessage；当前历史转换链已继承SDK库`isGameAnimationed`，没有再建一份游戏数据库。

新端从只读旧资源复制15组图：两个入口、3个手势结果、6个骰子结果及4个骰子动画帧；手势1石头、2剪刀、3布。发送结果一次生成，作为原消息正文/游戏字段提交，不把客户端随机当作服务器裁决，也不把动画结束当发送成功。没有数字选择器或手动指定结果的UI。

`ChatStore.sendGame`复用现有发送权限、普通成员频控、SDK保存和ACK链路；不清正在编辑的文字、引用或提及。失败按钮沿旧端重新掷结果，保留原消息身份；正常或发送中不能人工重发。游戏仍沿既有策略禁止多选/转发，未扩展其它消息操作。

`ChatGameStickerBubble`按实际视口与前台资格播放，取消或后台不提交动画完成；Reduce Motion直接显示最终图。完成回调核对当前消息、结果、类型与时间，SDK同样核对后写标记，旧页/旧动画不能恢复已删除消息或标记重试后的新结果。ACK/历史合并保留已播放状态，新重试允许重播。

## 5. 源码与验证入口

主要源码：

- `Features/Chat/Components/ChatComposerTextInput.swift`、`ChatMediaComposer.swift`、`Views/ChatRoomView.swift`：手动焦点、输入与@生命周期。
- `Features/Chat/Models/ChatGroupPermissionPayload.swift`、`Network/IM/Chat/SDKChatClient.swift`：严格字段、个人禁言缺省及最新全禁判断。
- `Features/Chat/Models/ChatGameSticker.swift`、`ChatMessageRecord.swift`、`ChatMessageMerge.swift`：类型、结果、动画状态。
- `Features/Chat/Services/ChatStore.swift`、`Models/ChatClient.swift`：游戏发送、失败重试和动画完成。
- `Features/Chat/Components/ChatEmojiPanel.swift`、`ChatGameStickerBubble.swift`、`ChatMessageBubble.swift`：两个默认入口及旧图片动画。
- `Network/IM/Chat/SDKChatMessageMapper.swift`：SDK游戏结果/播放标记回读；SDKChatClient同处填写真实发送字段。

针对性命令：

```bash
sh Tests/Chat/run-composer-focus-checks.sh
sh Tests/Chat/run-read-permission-checks.sh
sh Tests/Chat/run-group-send-permission-checks.sh
sh Tests/Chat/run-game-sticker-checks.sh
sh Tests/Chat/run-checks.sh
sh Tests/Chat/run-file-name-contract-checks.sh
sh Tests/Chat/run-mention-request-checks.sh
```

焦点专项、权限59项、群发送11项、游戏模型/生产SDK字段往返、聊天Store及文件13项、成员请求15场景均已通过。测试执行生产方法/分支，UIKit、SDK等待或库边界用匿名形状；没有连接真实账号。独立只读复核确认本轮无已知阻塞问题。

最终统一离线**72/72组exit0**，逐脚本耗时合计347.34秒，逐项退出码/耗时/日志见`/tmp/ddlNew-20261015-game-permission-offline/summary.json`；包含同期头像专项。新游戏、群权限、焦点等均在该当前版本统一入口中执行，未借用前一版68/68结果。`git diff --check`与本文本地链接检查通过，15组游戏图片逐文件SHA与只读xgd一致；`assetutil`确认最终app的Assets.car包含全部15个游戏资源。

无签名generic iOS workspace首轮构建`/tmp/ddlNew-20261015-game-permission-build.log`已exit0、BUILD SUCCEEDED。最终复跑`/tmp/ddlNew-20261015-game-permission-final-build.log`遇同DerivedData的build.db锁（exit65，不能算通过），未终止其它构建；锁释放后`/tmp/ddlNew-20261015-game-permission-final-retry-build.log`重试exit0、**BUILD SUCCEEDED**，包含最新可见性收口。既有SDK/依赖警告保留，不宣称零警告；没有签名、安装、启动或真实发送验收。

## 6. 待验与优先级

1. 在用户恢复设备操作或自行Run后，验证连续中文/英文/Unicode输入、中文输入法候选、插入表情/移动光标/删除、切面板、@取消和返回。不能以焦点匿名形状声称实际系统键盘已通过。
2. 群聊正常成员重新进入后输入/附件可用，真实禁言/解除及管理员行为正确；确认真实文本和附件发送、ACK、对端收取。用户三字段行不是完整服务器验收。
3. 单聊/群聊默认游戏：两个入口、发送/动画/结果、对端一致、离页/后台/Reduce Motion、失败重试、重启历史不重复动画；只使用已有A/B和可恢复数据，不为测试制造真实业务副作用。
4. 同期头像修正的本人发送中/对方缓存空值/注销及远端头像下载待实际复验，沿该专项记录，不重复改其它线程已有实现。
5. 继续凌晨交接未完成项：媒体全类型/各供应商、大文件、弱网/后台与重连、同账号多端；真实投诉上传/受理/审核、黑名单阻断/解除；完整三角色群管理需要第三可控身份及可恢复测试群。缺条件记录事实，继续不依赖它们的检查。

此前已真实闭环的凌晨双端文本/已读、137字节文件下载SHA、公告流程等按原台账保留；本轮新输入/UI改动的对应回归仍需重新验，不扩大为所有历史问题重做。

## 7. 新会话续接文字

> 请先完整阅读`/Users/taobotaobo/Desktop/ddlNew/Docs/PROJECT_HANDOFF.md`和`/Users/taobotaobo/Desktop/ddlNew/Docs/SESSION_HANDOFF_2026-10-15_CHAT_INPUT_GAMES.md`，再检查实时分支、git status及相关源码，必要时查凌晨统一交接和116项台账。整理时为feature-message-4/ecf1b89，后续修正在工作区，以实时Git为准，保留全部已有改动，不自动提交或推送。Mobile MCP仍暂停，不用其它工具替代操作设备；只读参考xgd，保持森林绿、UIAdapter与中文业务注释。当前已补原生toolbar、四等分工具栏、157基础表情、光标@提及、UIKit手动焦点、真实响应缺省个人禁言以及默认石头剪刀布/骰子type21；商城和其它原暂缓能力不扩大。先核对本文最后验证和待验项，构建/离线形状/动画结束/发送方气泡均不能代替SDK服务器受理、ACK和对端实收。恢复设备验证需要用户后续明确授权，仅用既有A/B和可恢复数据；缺第三身份或测试群如实记录。
