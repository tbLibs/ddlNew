# 通讯录与消息 UI 只读审查

日期：2026-10-13。分支：`feature-message-4` 当前工作树，开发持续进行中。首轮审查与聚焦复核仅写本文件；随后追加授权仅修改下文列明的4个聊天UI文件，不改工程、SDK，不构建、不连接后端、不提交。

## 结论与证据边界

结论（最终聚焦源码复核与授权UI补齐）：**首轮9项均已确认源码修复，尚不能认定全部 UI 或可访问性验收通过。** 本文先记录只读复核，随后按用户已授权范围补齐UI-09键盘收起和已有GIF/贴纸动画；运行、VoiceOver、深浅色与真实收发仍由独立QA确认。下节是最新状态，后面的首轮详细问题保留为历史依据。

授权以[本轮范围](CONTACTS_MESSAGE_DEVELOPMENT_SCOPE.md)为准；布局参照[UI设计](CONTACTS_MESSAGE_UI_DESIGN.md)。沿用森林绿、卡片和真实头像；不要求逐像素复制旧UIKit，不以个人样式偏好新增功能。真实拉黑/举报、主动全读、双击Tab定位、自动删除配置、支付、通话等暂缓项不算缺陷。

检查实际目录 `Features/Contacts`、`Groups`、`Message`、`Search`、`GroupApplications`、`Chat` 及根路由/公用配色。应用目标仍为 iOS16 / Swift5；按已安装swiftui-pro的views/data/navigation/design/accessibility/resizability检查。新代码使用NavigationStack、TextField(axis:)、LabeledContent、PhotosPicker、ShareLink、safeAreaInset等iOS16可用API，本轮未发现必须提高部署版本的UI调用；这不替代完整编译结果。

已查看独立QA截图：

- [/tmp/ddlNew-qa-chat-maxfont-green.png](/tmp/ddlNew-qa-chat-maxfont-green.png)：最大字号首屏末条正文可见、媒体操作两列文字完整。
- [/tmp/ddlNew-qa-chat-landscape-green.png](/tmp/ddlNew-qa-chat-landscape-green.png)：横屏附件和输入操作可见。
- [/tmp/ddlNew-qa-remark-discard-retest.png](/tmp/ddlNew-qa-remark-discard-retest.png)：备注脏输入取消出现放弃确认，键盘仍可见。

以上是**隔离宿主的局部布局证据**，宿主替换SDK、图片网络和部分目的页面；不是本轮完整生产登录后的UI、真实收发或成员管理证据。沿用[独立QA报告](CONTACTS_MESSAGE_TEST_REPORT.md)的谨慎口径：VoiceOver真实朗读、Reduce Motion、iPad与真实双端仍未执行。以下“源码确认”表示具体接线能推出的缺口；没有截图的场景不伪称已现场复现。

## 最终聚焦复核（当前源码，非设备操作）

本次按父任务要求只复核UI-01～09，未操作iPhone/MyMac、不与QA并行控制设备，未运行构建或后端请求。父任务报告两端已登录并在专用测试群联调，此为新的执行进展，取代首轮“无真机/未进入登录”的历史阻塞；当前真实业务是否完成由独立QA报告确认，本次不从登录推断收发或管理验收通过。

| ID | 最新状态 | 当前实际源码依据 | 仍需执行的证据 |
| --- | --- | --- | --- |
| UI-01 | 源码修复确认 | MessageView:82～91观察GroupsStore并传async onSubmit/submissionError；ChatSettingsView:78～91邀请与成群同样仅真实完成返回true，失败留sheet | 三入口失败/待审核/成功/重复请求在完整页面复测；不因通讯录Picker旧宿主通过替代 |
| UI-02 | 源码修复确认 | ChatRoomView.messageRow:169～190触摸/命名accessibilityAction共用activateMessage；ForwardRecord:21～32记录内附件/位置同一open合同 | 真实VoiceOver执行打开、返回、引用/重试，默认双击与动作菜单的实际可发现性；当前源码是命名动作，不额外宣称默认Button语义已实现 |
| UI-03 | 源码修复确认 | ChatGroupMembersView:24当前页显示Store错误与刷新；移除sheet:51～52失败留错误和目标，busy禁重 | 当前成员页失败/降权/转让与禁言结果实际朗读；精确确认文案见下方待复核 |
| UI-04 | 源码修复确认 | AddFriend主按钮及资料发消息/申请tint改HomeTheme.forest；ContactsRecipientPicker姓名.primary、选择value/trait已接；最终再读GroupMemberPicker:98已改.primary，原低对比姓名缺口关闭 | 深浅色实际取样对比、最大字号；主按钮/姓名源码改善不能替代整页AA验收 |
| UI-05 | 源码修复确认 | ContactsBusinessStore.search:141～155已有独立isSearching，AddFriend:38～40加载/error/空结果分离；NewFriends:21要求error==nil。最终再读ContactsView:97～103/112～115/132～135三类空态已按各自Store loading/error条件分离，缓存ForEach仍保留 | 首次读失败、延迟回执、真实空、有缓存失败的互斥反馈实际UI复测，确认页面错误仍可发现并有有效重读 |
| UI-06 | 源码修复确认 | MessageEditor:32～36dirty取消确认及busy/dirty防拖动；Notices:58～62公告正文label、dirty确认、busy阻关闭；Settings:48/51有群昵称/群名VO标签 | 两editor真实取消/拖动/忙/失败/键盘；仍建议有值时视觉字段名常驻，但不扩大为另一个阻塞项 |
| UI-07 | 源码修复确认 | ChatForwardRecipient:37～38装饰勾选隐藏、姓名label、已选value和selected trait | VoiceOver选中→搜索→清查询→取消与真实目标数一致 |
| UI-08 | 源码修复确认 | FriendGroupManager:45转FriendGroupNameEditor；新editor:29～50有草稿/错误/加载/非空与dirty校验，perform成功才dismiss | 新建/改名真实失败保草稿、重试、取消、成功回读 |
| UI-09 | 源码修复与语法解析确认 | 后续授权补齐ChatRoomView中的private FocusState、TextField.focused、ScrollView.scrollDismissesKeyboard(.interactively)，keyboard toolbar“收起键盘”44pt，identifier chatDismissKeyboard；收起只改变焦点 | 中文/emoji/多行/横屏/外接键盘实际复测；确认正文/引用/@片段与浏览位置保留，语法解析不等于构建或运行 |

UI-01～09源码缺口已关闭，实际行为仍由QA复测。UI-04/05由根补完后本次独立重读源码确认；UI-09在本次追加授权中实际补齐。未添加镜像实现的测试，不以源码关闭替代实际页面复测。

### 追加授权：键盘与GIF实现记录

用户已授权补齐缺失UI；后续根任务将UI-09与已批准GIF能力交给本设计代理实施，以下产品改动属于该追加授权，不属于前面的只读审查。仅拥有并改动：

- `Features/Chat/Views/ChatRoomView.swift`：焦点与键盘收起；原Store、草稿、引用、@UID片段未修改。
- `Features/Chat/Components/ChatMessageBubble.swift`：type12无后缀贴纸和明确.gif照片资源使用动画原资源；照片/视频封面保留legacy decode→downsample。
- `Features/Chat/Views/ChatStickersView.swift`：已用贴纸列表复用动画组件、观察当前文件Host；不新增商城/游戏/机器人。
- 新增 `Features/Chat/Components/ChatAnimatedRemoteImage.swift`：一个独立主要类型复用消息/贴纸动画。

已应用ios-dev、swiftui-pro及Superpowers实施检查，保持iOS16/Swift5。实际Kingfisher本地源码确认`KFImage.HoldingView`为SwiftUI.Image，无法承担GIF逐帧动画；`KFAnimatedImage`为iOS14起可用AnimatedImageView representer。动画分支采用实际API `configure`（framePreloadCount=3、needsPrescaling=true、contentMode=scaleAspectFit）、`purgeFramesOnBackground(true)`、`loadDiskFileSynchronously(false)`、`cancelOnDisappear(true)`、`serialize(by:LegacyRemoteImageCacheSerializer())`；**不调用动画类型不存在的resizable，也不先Downsampling导致仅剩首帧**。共享serializer由根任务实现，保留旧XOR/AES包装GIF的磁盘动画数据。

减少动态效果、非前台、离页状态切静态KFImage legacy→downsample分支，避免动画缓冲继续运行；本地库后台通知还会停止并清帧。动画固定展示边界220×200、列表64×64，预缩放+仅三帧预取；这说明实现策略，不是已测内存峰值。网络资源失败给占位，不改变发送状态。

验证实际执行：`xcrun swiftc -frontend -parse`四个文件exit0；`git diff --check`exit0。本地Kingfisher `Tests/KingfisherTests/dancing-banana.gif`用ImageIO确认为8帧365×360，首尾帧均可解码；**此证据仅说明真实多帧样本可用，不证明本次SwiftUI界面动画已经播放**。未运行xcodebuild、后端或设备操作；完整真实Kingfisher构建、cold disk cache、GIF前后台/Reduce Motion与连续滚动由根/QA执行。四个产品文件已冻结交还根任务。

### 首轮待复核项的源码进展

- 群二维码：ChatSettingsView:44已增加真实groupID入口，C-032不再记为入口缺失；实际禁码/过期/入群审批待QA。
- 群头像：ChatSettingsView:42/70已有子页；ChatGroupAvatarView:23～49真实头像、1/2编辑、上传错误和进度，上传后保存回读。Settings:68调用leaveSettingsView(presentingChild:)包含showAvatar，父Store不会因进头像子页提前close；子页失败/返回与跨账号尚需独立验证。
- 移除并删发言：ChatGroupMembersView:50～52已接默认关闭Toggle和真实deleteMessages提交；多选删除：ChatRoomView:113～116/130已有授权范围入口。关闭首轮“未接入口”的源码结论，实际部分失败/范围同步待QA。
- 成员普通角色预览、成员列表层级与禁言名单（CHAT-035/040）父任务明确仍在收尾，**待复核，不判终版失败**。当前成员confirm:55～57仍通用“确认群操作”与转让提示，未见按期限/解除/管理员/转让精确标题；已告知开发，按收尾项复核。
- 未发现新增本轮暂缓的真实拉黑/举报/群发/签到发起/主动自动删除/独立翻译/商城/音视频入口。历史类型兼容展示和既有模型不算恢复功能。

构建边界：父任务已报告一次clean build通过，但发生于部分晚期聊天修复之前；本审查没有独立运行，不据此称当前全部晚期UI代码已构建。最终构建日志与测试由根统一提供。

## 首轮详细问题记录（历史快照）

以下位置/描述为首次审查快照，**当前状态以前面最终聚焦表为准**。保留影响与复测方法，避免修复后删除问题追踪依据。

优先级：P1＝会阻断/掩盖日常操作或等价可访问操作；P2＝反馈、输入保护、可读性或可识别状态缺口。开发正在收尾，修复后以新源码和对应场景复测关闭，不把本报告旧快照当最终状态。

### UI-01 / P1：部分入口提交后立即关闭选择器，失败丢选择

**位置与方法**：[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:81) `body` 创建群sheet；[ChatSettingsView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Chat/Views/ChatSettingsView.swift:72) 邀请与单聊成群sheet；[GroupMemberPickerView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Groups/Views/GroupMemberPickerView.swift:69) `confirm()`。

**场景/影响**：选两名好友→确定→服务器超时/拒绝。调用方只有同步`onConfirm`内创建Task，选择器无`onSubmit`时立即`dismiss()`，网络尚未返回；本次selectedIDs随sheet销毁，用户无法在原页看到失败并重试。通讯录群入口已经采用async onSubmit和submissionError，不能把该入口的QA通过推广到消息菜单/聊天设置。

**最小补救**：三个调用点改同一async onSubmit合同，传当前业务错误，只在真实创建/邀请已确认（或明确需审已受理）时返回true；失败返回false保留候选与选择。期间禁重复和关闭。不要用“关闭sheet”当成功。

**复核**：在消息更多、单聊成群、群邀请分别注入失败和待审核，确认错误与选择留在sheet；重试仅一次请求，成功才关。关联C-028/029、CHAT-030/037。

### UI-02 / P1：附件、位置和合并记录仅触摸打开，缺VoiceOver等价动作

**位置与方法**：[ChatRoomView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Chat/Views/ChatRoomView.swift:148) `messageRow(_:)`；[ChatForwardRecordView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Chat/Views/ChatForwardRecordView.swift:18) `body`。气泡自身[ChatMessageBubble.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Chat/Components/ChatMessageBubble.swift:48)只contain子元素。

**场景/影响**：屏幕阅读器用户焦点到历史语音/文件/图片/位置/合并聊天记录。打开由`onTapGesture`执行，没有Button语义或对应打开accessibilityAction；父消息唯一显式动作是“选择消息”，菜单也不提供附件/位置/记录打开项。用户可能读到资源摘要，却缺少可靠可发现的打开/播放方式；记录内附件同样受影响。

**最小补救**：可打开类型共用一个当前消息ID的`openContent`动作，以Button或默认accessibilityAction暴露“查看图片/查看视频/播放语音/查看文件/查看位置/查看聊天记录”。选择消息动作仅对当前允许多选类型提供；保留失败重试和引用子按钮，避免父`.ignore`吞掉子控件。

**复核**：VoiceOver实际执行每个类型的打开→返回→重试/引用，不仅观察accessibilityIdentifier。关联CHAT-011/013/016/017/032。

### UI-03 / P1：成员管理失败只写父Store，当前成员页看不到结果

**位置与方法**：[ChatGroupMembersView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Chat/Views/ChatGroupMembersView.swift:22) `body` / 确认回调；[ChatSettingsStore.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Chat/Services/ChatSettingsStore.swift:56) `groupAction`、`operate`。错误显示目前仅在[ChatSettingsView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Chat/Views/ChatSettingsView.swift:30)。

**场景/影响**：成员页提交禁言、移除、管理员调整、转让→服务端失败/降权。确认框消失，Store有errorMessage但成员页没有错误/处理中/结果栏；用户只看到原成员，不能区分请求失败和仍处理中，需要退回父页才见错误。

**最小补救**：在成员页当前内容上方显示同一Store的错误、busy和可执行“刷新/重试”；成功按回读更新身份/列表，未知回执不显示成功。保留目标与具体动作，让重试重新校验权限，避免无限自动重发。

**复核**：对移除、期限禁言、转让分别注入失败/权限收回，当前页面能朗读准确原因；退出返回后不残留别的操作错误。关联CHAT-038/040/042。

### UI-04 / P2：新控件使用固定青绿色，小字对比与深色名单可读性不足

**位置**：[ClubTheme.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Common/Design/ClubTheme.swift:14)固定ink/secondary/darkTeal；[AddFriendView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/AddFriendView.swift:31)和[ContactRecordDetailView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/ContactRecordDetailView.swift:66)显式主按钮tint；[GroupMemberPickerView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Groups/Views/GroupMemberPickerView.swift:98)和[ContactsRecipientPickerView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/ContactsRecipientPickerView.swift:53)系统List中固定ink姓名。

**场景/影响**：浅色“查找”等默认body小字白色配#008C86，对比度计算4.12:1，低于正文4.5:1。深色系统List底色变化而固定#173D3B姓名不变：以常见#1C1C1E背景计算仅1.43:1；实际设备背景应进一步取样。新列表选择时主要姓名可能难以辨认。该问题不是要求重做原卡片配色。

**最小补救**：新增控件主按钮用HomeTheme.forest适配色；系统List姓名使用`.primary`或HomeTheme.text，辅助用`.secondary`/HomeTheme.secondaryText。避免全局改ClubTheme影响未纳入页面。实际渲染后检查opacity和禁用状态；浅色森林绿#285B43/白字已计算7.87:1。

**复核**：新联系人/分享/建群列表和小字主按钮在浅深色正常及最大字号可读；截图颜色取样与Contrast检查。默认大字按钮按3:1规则单独评估，不把所有按钮误报。关联C-037/M-028。

### UI-05 / P2：查询中或读取失败仍出现业务空结果

**位置与方法**：[AddFriendView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/AddFriendView.swift:37) `body` 与`search()`；[ContactsBusinessStore.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Services/ContactsBusinessStore.swift:113) `search`；[NewFriendsView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/NewFriendsView.swift:21)；[ContactsView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/ContactsView.swift:97)。

**场景/影响**：第一次查找点击后立即searched=true，Store没有该搜索isSearching，结果未回先出现“没有找到用户”；请求失败时此空态与错误并列。同样申请空数组+读取失败仍“暂无好友申请”；好友首次缓存读取失败仍“暂无好友”。用户会把未取得数据误认为关系确实为空。

**最小补救**：查找单独isSearching并显示“正在查找…”，成功回执且无error才展示零结果；空业务列表状态要求!loading且error==nil，否则“暂时无法读取/查找”+正确重试。保留已有缓存；不要用通用isSubmitting冒充搜索阶段。联系人缓存重试已有Store.reload可复用。

**复核**：延迟首次回执、真实空数组、网络失败、有效缓存+失败四种状态文案互斥；自己账号提示不同时“未找到”。关联C-005/009/013/037。

### UI-06 / P2：消息/公告编辑仍可无确认丢未保存输入，公告输入缺标签

**位置与方法**：[ChatMessageEditorView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Chat/Views/ChatMessageEditorView.swift:31)取消/interactiveDismissDisabled；[ChatGroupNoticesView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Chat/Views/ChatGroupNoticesView.swift:54)公告sheet。

**场景/影响**：编辑长消息或公告后按取消/滑下sheet，输入立即销毁；发送中的公告取消与sheet拖动也未按busy关闭。公告TextEditor无可访问label，VoiceOver无法准确获知它是公告正文。备注编辑已实现dirty确认，截图只能证明备注，不包含这两页。

**最小补救**：采用备注编辑相同原始值/dirty/确认放弃模式；忙时阻关闭，失败原输入保留；公告TextEditor增加始终可见“公告正文”与accessibilityLabel。消息原文未变禁保存可减少无效请求。群名/群昵称inline输入同样加显式标签（ChatSettingsView:43/46）以区分预填值。

**复核**：两个editor取消、拖动关闭、busy期间关闭、失败重试、VoiceOver字段标签及键盘均逐页测试。关联CHAT-023/044。

### UI-07 / P2：转发收件人的选中状态只由装饰图标表示

**位置与方法**：[ChatForwardRecipientView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Chat/Views/ChatForwardRecipientView.swift:35)收件行 `body`。

**场景/影响**：转发选多位收件人，用checkmark.circle.fill与circle表示已选/未选，却没有明确accessibilityValue或isSelected trait；不能依赖SF Symbol默认名字正确朗读业务选择状态。其他选人页面已经使用“姓名，已选/未选”标签，本页不一致。

**最小补救**：隐藏勾选装饰图的朗读，行accessibilityLabel是合法目标姓名，value“已选择/未选择”，加selected trait；为禁用/失效候选同步状态。保持现有kind+ID的选择key。

**复核**：选择→搜索隐藏→清查询→取消选择，VoiceOver每步读出最新状态，发送按钮数量与真实有效集合一致。关联CHAT-025。

### UI-08 / P2：分组创建/改名失败后输入框自动关闭

**位置与方法**：[FriendGroupManagerView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/FriendGroupManagerView.swift:44)名称alert的保存回调。

**场景/影响**：输入名称→保存→服务端重名/断网。alert的按钮触发Task后系统立即关闭；再次点击新建清name，改名回填group.name，失败草稿没有可见恢复入口。虽State短暂保留name，也无法原表单直接重试。

**最小补救**：换系统sheet/Form编辑副本；在真实成功后dismiss，失败留输入+错误。至少非空/纯空格时禁保存；取消不发请求。无证据的长度/数量不造上限。

**复核**：新建与改名失败、取消、成功回读分别观察输入与组列表，不吞失败名称。关联C-023。

### UI-09 / P2：聊天键盘没有明确收起入口

**位置与方法**：[ChatRoomView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Chat/Views/ChatRoomView.swift:49)ScrollView与`composer`，TextField在:128。

**场景/影响**：多行正文聚焦后想收起键盘看历史/附件。当前没有FocusState、键盘“完成”工具、scrollDismissesKeyboard；Return用于多行编辑，页面唯一其他路径可能是切页或点击另一业务按钮。截图只能证明输入栏在键盘上方，不能证明易于收起。

**最小补救**：TextField增加FocusState，提供“收起键盘”工具或明确按钮；ScrollView增加iOS16 `.scrollDismissesKeyboard(.interactively)`；保留换行语义，显式发送，取消引用/工具不能清正文。外接键盘Escape收起焦点，Command+Return发送需单独可验证接入。

**复核**：中文/emoji/多行、横屏最大字、外接键盘能收起/恢复；草稿和浏览锚点保留。关联CHAT-003/009、M-028。

## 首轮收尾子能力记录（历史快照）

下表是首次审查的接入/质量缺口历史记录，当前源码进展见前面“首轮待复核项的源码进展”；已接二维码、头像等不得继续按此历史表称入口缺失。其余开发仍可能追加，不称终版已验收失败，也不因有模型或SDK方法称完整。

| 子能力 | 当前观察 | 最小后续接入/复核 |
| --- | --- | --- |
| 群二维码 C-032 | BusinessQRCodeView已支持groupID，但实际调用仅个人二维码groupID:nil；群设置没有群二维码行 | group.qrVisible允许时用ContactsPageRoute.qrCode真实groupID进入；禁码/过期/审批实测 |
| 群头像 CHAT-034 | ChatGroupDetail含avatar，群设置暂无群头像显示/可编辑入口 | 1/2可编辑真实上传+保存、0只读，上传成功接口失败保旧图 |
| 移除成员并清其发言 CHAT-038 | ChatGroupMembersView的deleteMessages状态未使用，remove固定false | 确认页增加默认关闭范围开关，并接真实delMemberMsg及部分失败 |
| 多选批量删除 CHAT-021/024 | composer已选栏仅转发/取消；逐条菜单已有删除 | 获授权矩阵下新增明确范围的批量删除动作、部分失败留条目 |
| 消息置顶/历史搜索/富消息 | 页面与SDK接线已新增，独立宿主部分用替代目的页 | 正式页面往返、目标ID定位、消息删除/撤回失效、加载/错误/取消逐页测 |
| 暴露群操作范围 | 成员确认统一“确认对姓名的群操作”，正文同时提转让并不区分禁言/管理员/移除 | 按动作显示精确标题、期限、目标和真实影响；非破坏的解除动作不套全部destructive |
| 小触区与最大文字 | 新朋友/助手裸链接、二维码三按钮HStack、已选chip未明确最小44 | 完整宿主测辅助树bounds；小于44再补frame；最大字号按钮改纵向，不能仅由源码32pt行内容推断系统List实际触区不足 |
| iPad/宽窗与字体 | ClubScroll保持600宽，消息List与聊天无统一最大宽；手机QA截图无法证明iPad | 使用实际可变窗口测宽窄重排，选择/path/草稿不重置；若整行跨宽屏难读，再加居中内容约束 |
| Value routes统一 | 根对ChatRoute/ContactsRoute/ContactsPageRoute各注册一次；群管理/公告子页仍用destination型NavigationLink | 后续统一群子页value route或验证混用层的连续push/pop，避免根据风格差异臆造已观测崩溃 |
| 返回后标题实时 | ChatRoomView.navigationTitle仍取route.title初始化文本 | 备注/群名变化从实时Store标题刷新；两端名称同步最终UI复核 |
| 屏幕阅读器结果反馈 | 多数error/notice为Text，未见统一主动结果公告 | 真实VO测试焦点/通知：失败不能只能靠用户重新遍历整页发现；公告不重复播报 |

## 首轮分维度验收状态（历史快照）

| 维度 | 证据状态 | 已见依据 / 尚缺 |
| --- | --- | --- |
| iOS16/Swift5目标 | 静态检查通过范围内 | 应用目标保持；没发现必需提高版本API；完整build由根统一 |
| 根Value routes | 静态已接 | TabbarView:43三类各注册一次；真实启动入口返回/连点待测 |
| 头像与原卡片 | 静态已接 | Contacts/Message仍用真实URL与Kingfisher、卡片圆角；真实Host切换UI待测 |
| 原生消息侧滑 | 静态已接 | MessageView为List，allowsFullSwipe:false并共用contextMenu/accessibilityActions；完整宿主待测 |
| Dynamic Type聊天 | 截图局部通过 | 最新green纵横屏末正文/媒体可见；其他新页长名/标签未验证 |
| 备注dirty取消 | 截图+QA局部通过 | retest确认已出现；新消息/公告editor未覆盖 |
| 键盘安全区 | QA局部通过 | ChatRoomView.safeAreaInset与输入截图；收起/外接键盘为UI-09 |
| 选择状态 | 部分已接、存在缺口 | 通讯录入口与独立Picker失败保留QA通过；消息/设置接线UI-01，转发VO UI-07 |
| 加载/空/错误 | 部分已接、存在缺口 | 全局搜索error/empty分离；添加/列表空态UI-05，成员错误UI-03 |
| 触区 | 部分静态可确认 | 两根搜索/添加44、chat搜索/发送44、MediaComposer按钮44；裸链接/chip需辅助树 |
| 深浅色/对比 | 未全通过 | 聊天系统色适配；固定色新列表与小字主按钮UI-04 |
| VoiceOver | 未执行完整验收 | 语义源码审查；附件打开UI-02、收件选择UI-07，需实际朗读 |
| Reduce Motion | 待实际复核 | 当前无明显新增大弹簧动画；定位/历史滚动和GIF播放仍需设置实测 |
| iPad/窗口/导航连续性 | 待实际复核 | 手机截图不覆盖；不能以单列代码/尺寸假定通过 |
| 真实两端行为 | Blocked于独立QA层 | 依QA报告未完成真实AUTH/业务，不从本次设计审查推断后端通过 |

## 建议收尾顺序

当前复核新增键盘/GIF与正在收尾的角色预览/禁言名单。UI-01～09源码修复的实际场景仍由QA执行，真实VoiceOver/iPad/深浅色与错误取消不被源码关闭代替。每次复测保留局部与完整、离线与真实边界；根同步交接文档实际功能进度，本设计审查文件不代表上线验收完成。

## 本次继续验收UI修正（2026-10-13）

- 新复测确认：默认字号开键盘后末条不跟随，AXXXL开键盘时附件区占满正文。旧通过截图只证明无键盘场景，不能覆盖此失败。
- ChatRoomView改用末尾锚点实际几何；视口改变时仅先前末尾跟随，用户拖历史取消待跟随，搜索目标不强跳。Viewport7离线检查与独立SwiftUI复核通过。
- 键盘时媒体工具收拢到44×44展开入口，收起键盘也是44×44独立按钮；ChatMediaComposer自身与StateObject保持原身份，上传进度/错误和录音控制仍显示，不因切焦点取消资源。只限制AXXXL输入可见行数，完整草稿未截断。
- 隔离宿主最新默认字号正文4在键盘之上可见（/tmp/ddlNew-ui-viewport-default-green.png），AXXXL正文4恢复可见（/tmp/ddlNew-ui-viewport-max-green.png）；收起保留QA_LARGE并恢复附件工具。滚向正文2再打开键盘仍停旧历史，无强跳。
- 隔离宿主并非真实网络/上传验收；最大字号+引用、多选、媒体进度叠加、VoiceOver真实朗读与完整横屏/宽窗仍保留Blocked。不将辅助树等同屏幕阅读器通过。

指定iPad Pro13(M5)iOS26.5隔离宿主默认字号键盘实测：正文与QA_IPAD_CURRENT输入、发送及44×44收起可见（/tmp/ddlNew-ui-ipad-default-keyboard.png），仅此布局子场景Passed；真实后端、最大字号、多窗口和VoiceOver未通过。

单聊真实长历史补证：Unicode发送已入列表预览，但返页仍停旧消息，最初一次async滚动不能证明已落锚点。ChatRoomView首屏改等稳定布局再滚latest，其余只末尾跟随，拖动取消、搜索target不强跳；最终物理iPhone返A单聊实见原Unicode/换行标记1份，稳定再次读取1份，未重发，RES-20局部Passed；不是对端A收消息或所有分页锚点Passed。
