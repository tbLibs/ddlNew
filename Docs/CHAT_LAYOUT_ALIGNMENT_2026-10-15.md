# 2026-10-15 聊天页交互布局继续对齐

## 授权与边界

用户要求聊天页按旧xgd交互布局调整，明确选择“按此方案整体对齐”；随后补报“聊天页—右上三个点—查看好友资料”路由错乱，本轮一并窄修。基线`feature-message-4 / ecf1b89`，工作区已有真实举报/黑名单、图标及媒体取消改动，全部保留，不提交/推送。Mobile MCP继续暂停，未用替代工具操作设备。

只读参考`/Users/taobotaobo/Desktop/xgd`。本轮调整现有SwiftUI展示和局部模式，不改变登录、SDK消息发送、ACK、已读、媒体存储协议与权限归属，不恢复暂缓的通话/收藏/翻译/位置发送或表情商城。森林绿、UIAdapter、中文业务注释沿用。

## 旧端依据与具体调整

旧端路径相对`NoaChatKit/CandyTalk`：

| 旧端源码 | 行为与新端调整 |
| --- | --- |
| Base/Base/Views/NoaInputView/NoaChatInputFunctionView.m | 圆角文字框内置表情入口，右侧语音/发送随编辑状态切换，下方常驻横向快捷工具；新端保留已接通的相册、拍摄、文件、群@及更多输入选项，原图设置进入更多菜单 |
| Base/Base/Views/NoaInputView/NoaChatInputView.m、NoaChatInputVoiceView.m | 表情和语音在输入区展开；新端仅一个模式，可关闭、切回键盘或点消息区收起，文字/引用保持；录音仍显式开始、停止、确认发送和取消 |
| Base/Base/Views/NoaInputView/NoaChatInputReferenceView.m | 引用单独显示作者/摘要与取消；取消不清正文 |
| Modules/ChatModule/Views/ZMsgMultiSelectBottomView/NoaMessageMultiBottomView.m | 多选独立底栏合并转发、逐条转发、删除；新端沿既有转发确认流程携带初始模式，取消最后一条仍保留多选及导航栏取消出口 |
| Modules/ChatModule/Views/ZChatTopNavView/NoaChatTopView.m | 消息、群公告及设置；新端群消息顶部提供公告入口，单聊查找记录沿设置入口，不增旧链接收藏标签 |
| Modules/ChatModule/Views/MessageCell/ BaseView/NoaMessageContentBaseCell.m、NoaMessageTextCell.m | 紧凑头像/气泡/时间与发送状态；新端仅群聊显示对方昵称，媒体去文字气泡留白，失败图标可重试，语音时长和文件名/大小可辨识，撤回仍仅单个居中占位 |

UI使用用户指定`ui-ux-pro-max`：查询SwiftUI输入焦点及紧凑工具栏触点规范，保留FocusState、至少44pt点击范围与可见图文工具，大字号工具栏横向滚动；不采用检索中的通用配色或更换现有主题。

## 好友资料路由窄修

`ChatRoomView`的聊天设置使用`navigationDestination(isPresented:)`推入，设置页原“查看好友资料”却采用外层`NavigationLink(value: ContactsRoute)`；该路径没有设置页局部子导航状态，`presentingChild`也未计入，离开时可能提前关闭设置Store。改成与既有成员资料相同的`selectedMemberProfile`目标：按钮设置真实UID及原`sourceGroupID`，本页现有destination创建`ContactRecordDetailView`，`presentingChild`保持Store。未增加第二个NavigationStack或改根路径，返回仍沿当前层级。

这属于源码定位与修正，不能声称真机点击、实际目标资料和返回已验收；Mobile MCP暂停期间保留该运行验证项。

## 所有权与输入安全

- 新`ChatComposerMode`仅持有文字/表情/语音/多选四种互斥模式，不复制正文、引用、成员UID或选择集合；原ChatStore仍拥有业务数据。
- `ChatMediaComposer`始终挂在同一输入位置；多选只隐藏其控件，不通过if移除整个媒体组件，避免切换模式取消正在上传的附件。进入多选会取消未发送录音；退出保留文字和引用。
- 面板收起、键盘编辑、后台、权限撤销和页面退出取消录音/授权等待；取消不会发送录音。用户确认发送才调用原上传/发送路径，不把录音结束当发送成功。
- 表情内嵌与独立页面共用`ChatStickersView`、同一真实加载/发送合同；面板关闭撤销其读取资格，不新增本地假表情或发新游戏。
- 消息行仍用稳定ID、真实可见区域和原滚动跟随规则；多选覆盖消息点击，不能误开媒体/头像。所有删除仍走原逐条权限与服务器回执，失败保选。

## 验证与待验

新增`Tests/Chat/run-composer-mode-checks.sh`执行生产模式模型：表情/语音互斥、再次点击关闭、键盘替换面板、多选取代输入、零选择不退出、多选时迟到焦点不恢复编辑、文字/空白/中文的语音发送按钮切换。先运行确认缺实现失败，再实现并通过。既有Settings14项通过，Swift语法及diff空白检查通过。

本轮统一离线入口66/66组exit0，逐脚本耗时合计300.47秒，`/tmp/ddlNew-20261015-chat-layout-offline/summary.json`；无签名generic iOS workspace第一轮`BUILD SUCCEEDED`，日志`/tmp/ddlNew-20261015-chat-layout-build.log`。独立只读复核发现视频去气泡后的标记对比不足，已将透明媒体的前景改为正常正文色；多选另补权限禁用、辅助功能去重与表情切回键盘焦点。复核确认无其他已知重要问题。最终增量构建exit0、`BUILD SUCCEEDED`，日志`/tmp/ddlNew-20261015-chat-layout-final-build.log`；最终输入模式、Settings14项、Viewport7项和ReviewAction9项均复跑通过，`git diff --check`通过。既有预编译SDK警告保留，未宣称零警告。匿名模式检查只证明状态规则，不能替代键盘、麦克风、相册或系统导航运行。

恢复设备操作后重点验证：单聊/群聊/文件助手，右上设置到好友资料及返回，来源群禁私聊限制，键盘与两个输入面板切换、草稿/引用恢复，录音授权取消/后台/发送，逐条/合并转发确认，删除部分失败保选，长消息与媒体预览，窄屏/最大字号/iPad/明暗/VoiceOver。服务器收发和投诉/黑名单的待验矩阵仍按原文档保留。

## 后续追加：基础表情与键入@（2026-10-15）

用户指出表情按钮没有emoji，并要求移除群聊底部@成员按钮，改成输入@时弹出群成员。该要求覆盖上文工具栏“群@”历史描述；当前相册、拍摄、文件和更多保持常驻，@不再占底部按钮。

### 旧端依据

- `Base/Base/Views/NoaInputView/NoaEmoji/NoaChatInputEmoji.plist`及`EmojiResource.xcassets/emoji`：157个基础图片表情，使用`zhCN`的`[微笑]`等文本标记，不作为独立贴纸消息上传。资源原名与字节复制到新端`ChatEmojiCatalog.plist`及Assets，旧xgd保持只读且Git干净。
- `NoaImageEmojiView/NoaChatInputEmojiView.m`：基础表情、最近使用、明确删除；`NoaChatEmojiContentCell.m`区分基础表情和贴纸。新端默认基础表情，另有真实SDK贴纸标签。最近使用目前为本页面面板实例的7项，不声明旧端跨启动持久化已迁移。
- `NoaChatInputFunctionView.m`键入单个`@`触发成员选择；`NoaChatViewController.m`约束普通成员禁私聊，取消保留普通@；`Modules/ChatModule/Views/AtUserView/NoaMsgAtListViewController.m`提供搜索及所有人`-1`。

### 当前实现

`ChatEmojiCatalog`统一旧标记、附件与UTF16选区映射；`ChatComposerTextInput`用原生UITextView保留输入法、选区和复制粘贴，已知表情显示为一个图片附件，复制/发送恢复原标记。输入面板可在光标插入表情并整格删除；普通Unicode emoji保留系统字素行为。`ChatEmojiText`在正文气泡显示相同旧资源，未知方括号文字原样显示。贴纸继续走现有SDK type12，基础表情沿原文本/type10发送，不额外上传。

群聊键入单个@时保存正文、范围和登录/会话上下文，收起键盘并经既有SDK完整成员同步加载选择列表，支持搜索；有成员时加入所有人UID`-1`。选中只替换本次@并保留后文，`ChatStore`持有真实UID，原协议转换不变。普通成员禁私聊时保留普通@且不弹选择；取消不添加UID。失效会话、加载取消、已变化草稿和关闭后的迟到结果不发布选择或覆盖输入。头像长按原提及入口保留。

新增表情模型检查先确认缺实现失败再通过；成员光标插入检查同样先失败再通过。最终离线、构建及独立复核结果见本节后续记录。Mobile MCP仍暂停，未执行实际键盘/输入法、弹层、VoiceOver或服务器双端验证。

### 等分工具栏与独立复核

用户最新要求底部工具栏等分布局，`ChatMediaComposer.tools`已改为四项`maxWidth: .infinity`的HStack，图标/文字与触点居中；本节替代上文横向滚动工具的历史描述。保留四项真实业务入口和至少44pt点击高度，不恢复@按钮。

独立只读复核发现：昵称含@时，最长公共前后缀不能代表实际选区，旧UID片段会错位；成员加载期间进入设置或改草稿/切面板，迟到回执仍会弹页或恢复焦点。前者以`@@旧 `选择昵称`@旧`补生产模型回归，先RED exit133再GREEN；改为按已知范围平移并拒绝重叠。后者离页撤销请求，成功/失败/焦点恢复统一核对实际资格。新增`run-mention-request-checks.sh`提取页面实际加载/资格方法，在匿名SDK暂停点覆盖15种结果；当前专项通过。复核确认两项P2关闭，其余指定范围无新增阻塞问题。

本轮首轮统一67/67组exit0（228.84秒）覆盖导航/基础表情与初始@实现，日志`/tmp/ddlNew-20261015-toolbar-emoji-at-offline/summary.json`。该快照早于特殊昵称/迟到请求修正与等分工具栏；最终版本结果以下一条最终验证记录为准。157个资源目录逐文件SHA与只读旧xgd一致，构建app中确认157项索引。基础表情的最近使用目前仅页面实例内7项；VoiceOver、中文输入法及实际富文本交互仍待设备恢复后验证。

最终无签名generic iOS workspace构建exit0、`BUILD SUCCEEDED`，日志`/tmp/ddlNew-20261015-toolbar-emoji-at-final-build.log`，包含复核修正、系统toolbar、157基础表情、输入@和四等分工具栏。预编译SDK/依赖的既有警告保留，不宣称零警告；这不是签名、安装、启动或设备验收证据。

最终统一离线68/68组exit0（逐脚本耗时合计351.63秒），`/tmp/ddlNew-20261015-toolbar-emoji-at-final-offline/summary.json`，包含最新特殊昵称UID、15种成员请求资格场景及全部既有离线回归；最终`git diff --check`通过。上述离线成员方法使用暂停SDK形状，不读取真实群，也不能证明SDK实际网络返回、iOS输入法/键盘、选区展示、VoiceOver或双端服务器@通知。


## 后续回归：输入一字收键盘与群权限（2026-10-15）

用户报告输入一个字符键盘自动消失。UIKit输入器没有SwiftUI`.focused`目标，原FocusState不能再作为手动first responder的状态所有者；ChatRoom改用普通State，两个输入组件使用Binding传递。`run-composer-focus-checks.sh`提取实际绑定类型、同步和begin/end代理，旧类型RED后新实现GREEN，覆盖连续正文更新不resign、组合输入跳过重建、主动关闭/恢复、原生结束编辑、禁权不强开键盘。UITextView/富文本绘制为匿名形状，未运行设备系统键盘。

用户另报群聊输入全部置灰，明确顶部“正在确认群发送权限”、Toast“消息响应无效，请重试”。当前SDK群权限快照未通过三字段严格校验；旧端缺省0与新端严格校验存在差异，但日志没有真实字段，不能随意改为允许。仅追加DEBUG固定三字段形状诊断，`ReadPermissionChecks`新增原始数据不泄漏及missing断言，53项通过；`MentionRequestChecks`15场景通过。独立只读复核确认本轮窄改无新增阻塞问题。权限OR缓存与最新接口不一致的独立风险已记录，未将其当作当前“正在确认”故障的已证实原因。

无签名generic iOS workspace构建exit0、BUILD SUCCEEDED，`/tmp/ddlNew-20261015-composer-focus-permission-build.log`；专项日志为`/tmp/ddlNew-20261015-composer-focus-green.log`、`/tmp/ddlNew-20261015-group-permission-diagnostic-green.log`、`/tmp/ddlNew-20261015-composer-focus-mentions.log`。已请用户重新Run复验输入并提供`[ChatGroupPermission]`单行，群发送故障仍待该响应证据定位。Mobile MCP暂停，不操作设备/关系，不提交或推送。此前68/68属于前一版本，未冒充本次69组全量结果。


## 当前收尾：群权限已补证、默认游戏已批准

用户提供`userInGroup=true / isGroupForbid缺省 / isGroupChat=false`，已修复把合法缺省个人禁言判整份无效的问题，同时关闭最新全禁值被旧群缓存覆盖的复核问题；权限59项与实际发送判断11项RED/GREEN通过。前段“未获得字段/未修复”仅为当时诊断快照。

用户明确追加默认石头剪刀布/骰子，覆盖此前该子能力暂缓。两个默认入口、15组旧资源、type21真实SDK字段、客户端一次随机结果/失败重掷、3秒可见前台动画/减少动态效果、完成标记回写与ACK/历史保留均已实现，真实双端仍待验。本轮完整源码和当前验证/新会话提示统一转到[最新交接](SESSION_HANDOFF_2026-10-15_CHAT_INPUT_GAMES.md)。原本页导航/表情/@过程与历史验证继续作为阶段证据，不代替最新记录。

当前统一回归72/72组exit0（347.34秒），最终无签名workspace构建锁释放后重试exit0、BUILD SUCCEEDED，日志见新交接第5节；独立复核通过。Mobile MCP仍暂停、未提交/推送，真实输入/群发送/游戏双端未计通过。
