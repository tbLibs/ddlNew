# 147 个设计状态的源码覆盖审计（SOURCE-ONLY）

> 此为第一轮映射与有限补漏记录。用户指出遗漏后已重新全量核对，最新状态见 [第二轮布局核对](round2-layout-audit.md)。不要把本文件早期SHARED-STYLE分类当作页面已完成。

审计时间：2026-10-30T14:11:34+08:00。分支 `feature-newUI-5`，HEAD `a55a32f`，存在此前 UI 工作区改动。此报告是补漏前审计快照；同会话其他执行者随后修改文件时，需要另外复核并记录关闭结果，不把本表自动改成通过。

## 结论与证据边界

已将 `pages.json` 的 **147/147** 个状态映射到 **67 个 source 标签 / 67 个主入口文件**。其中 `065 ContactDetailSheet` 仅在旧演示链路可达，排除后是 **146 个生产设计状态 / 66 个主来源**，不是146条独立页面或路由。私有子 View（如公告详情/编辑、群名称编辑、昵称编辑）另在对应行指明。实际 App 是否跑到这些状态由主执行者运行台账负责。

**本报告所有147行都是 SOURCE-ONLY，运行截图数为0。** 我没有构建、启动App、触发账号操作，也没有编辑生产源码。只读源码、当前diff、批准稿和其图像。手工查看的设计PNG为 `007, 029, 037, 056, 058, 059, 060, 061, 066, 067, 073, 090, 091, 092, 093` 共15张。其它条目完成来源定位与组件消费核对，未逐张视觉比较，不能把它们的状态读成视觉合格。

`DIRECT-EDIT` 只表示该主来源有工作区diff；`SHARED-STYLE` 只表示消费已修改的主题/组件；`SYSTEM/EXISTING` 表示第三方网页/媒体等既有容器；`INCOMPLETE` 为源码与已查看稿存在具体结构缺口；`DEMO-EXCLUDED` 不应为了凑147页而重新接入产品。所有类别都不代表运行通过。INCOMPLETE 按主来源归类：34个是关联设计状态，包含同源菜单/确认态，不代表已经逐屏证实34项独立视觉缺陷；具体证实范围以 F1-F8 和15张已查看稿为准。

|分类|设计状态数|主来源数|
|---|---:|---:|
|INCOMPLETE|34|12|
|DIRECT-EDIT|56|25|
|SHARED-STYLE|51|27|
|SYSTEM/EXISTING|5|2|
|DEMO-EXCLUDED|1|1|

## 可执行的补漏项

以下是本次只读观察时的行号；后续补丁会移动行号。补漏仅改变展示结构，保持原 binding、资格判断、发送/保存请求、确认框、导航所有权和回执规则。

|编号|优先级|设计ID|源码证据与缺口|建议|
|---|---|---|---|---|
|F1|P1|091、091-accepted|`MassMessageView.swift:43` 的 List 与 `:101` insetGrouped；记录标题是小号tag、状态在正文之后，接收对象各占一系统行。批准稿是白色连续任务列表，标题+状态先行，正文和操作分区。|换平面任务列表与文本层级，保留分页、全部对象、失败对象、再发与删除确认。|
|F2|P1|092、095、092-error、092-attachment|`MassMessageComposerView.swift:41` Form、Section；标签计数同表单块，正文编辑与附件入口仍旧布局，未落实批准表单节奏。|独立对象摘要/标签/正文区域，输入面用灰蓝，字数外置；保留再发对象/标签锁定、单附件、失败保稿。|
|F3|P1|056、056-stranger、056-blocked；057菜单依附其上|`ContactRecordDetailView.swift:70` 硬编码圆角身份块；`:75-76` 再列账号昵称；`:229` 左右同行值；`:96` 主动作随正文。批准稿为平面身份+两行备注/描述+底部动作。|重排展示层级；保留实际账号/昵称/在线/角色等真实字段及原资格，不因静态样例省略字段而删业务。|
|F4|P2|007-009、058、058-error、118、060|`PasswordChangeView.swift:22`、`ContactRemarkEditor.swift:51`、`FriendGroupNameEditor.swift:33` 仍 Form/Section。PasswordChangeView 虽有diff，但仅增加表面/背景/tint三行。|统一独立字段面、标签和计数；保留密码安全强制门禁、草稿限制、退出/稍后修改等现有动作；不能将换色计作布局完成。|
|F5|P2|059、061|`FriendGroupManagerView.swift:24` 与 `ContactGroupPicker.swift:22` 默认 List，未指定 plain。添加分组位于首个Section；设计是连续名单，添加入口分别在导航/名单底部。|显式平面名单并整理新增入口层级；拖动排序、默认组不可删、单点立即移动不变。|
|F6|P2|067-069|`GroupMemberPickerView.swift:127` 使用 segmented Picker，未消费新下划线 MessagingTabs；`:114-125` 已选头像放顶部，稿放底部。|沿同一filter/selection重排tab和已选摘要，防止选人后候选首屏被顶下；数量/锁定/提交不变。|
|F7|P2|037、090|`ChatMentionPickerView.swift:25-28` 仅姓名，缺稿中的真实角色副标题；两页均默认 List/searchable。`CallMemberSelectionView` 未接统一页面chrome，勾选圈在右侧。|补角色层级，统一平面列表/搜索；@仍单点立即插入，通话已在场成员仍锁定。搜索系统控件差异需运行确认。|
|F8|P2|050、066、066-member、066-owner、119（077/078、确认态为同源关联）|`ChatSettingsView.swift:39` 外层spacing12、`:97` padding16；共享 MessagingCard 虽已去圆角，各段仍以灰蓝间隔分开，标题/值左右并列。批准稿是白色连续分隔行、群名/成员主层级。|按任务层级整理设置表面/行。真实成员预览、加减号、权限入口必须保留，不能为复刻简图删除它们。|

较低优先级差异：093 的“完成”仍是底部主按钮，稿是导航动作；073 群管理已经通过共享卡实现平面表面，但组标题、图标、开关行密度尚未逐屏运行比较。029 搜索现有分类平面列表已接近稿，不能仅因文件没有diff就判断漏改，也不能仅凭继承主题就判定完成。

## 旧品牌与装饰核对

- `HomeTheme.forest` 当前值为浅色 `#2859BC` / 深色 `#9EBDFF`，旧属性名不是绿色残留。MessagingTheme.online 绿色是在线语义，应保留。
- `HomeLandscape` 的绿山色与 `HomeHubCard` 仍在源文件，但未找到实例调用；不把未使用组件算当前可达漏页。
- 生产邀请码/登录/启动使用 DingDongMark；俱乐部页的山形 SF Symbol 表达俱乐部，不应无依据替换成应用LOGO。
- JXPhotoBrowser 顶部黑色渐变用于媒体控件可读性；通话视频、扫码取景和系统裁剪不按白色表单模板强行改造。
- 065 路径只有 `OriginalContactsView/OriginalMessagesView → ChatScreen → ContactDetailSheet`，不要求把它接入真实导航。

## 逐状态映射

所有行的验证等级均为 SOURCE-ONLY。对应源码链接用于定位；“直接编辑”并不保证该状态分支被本轮改到。

|ID|设计状态|主来源（对应子视图）|等级 /覆盖类型|审计说明|
|---|---|---|---|---|
|001|系统启动页|[LaunchScreen.storyboard](../../../../ddlNew/Resources/LaunchScreen.storyboard#L1)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|品牌资产/布局已直接改；系统缓存启动快照未在本审计验证。|
|002|连接俱乐部|[InvitationCodeView](../../../../ddlNew/Features/InvitationCode/Views/InvitationCodeView.swift#L12)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|品牌/标题/字段/按钮直接改；真实连接状态未运行。|
|003|会员登录|[LoginView](../../../../ddlNew/Features/Login/Views/LoginView.swift#L11)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|品牌/欢迎标题/表单直接改；协议系统 alert 与业务 Toast 沿原链路。|
|004|账号注册|[AccountRegistrationView](../../../../ddlNew/Features/Login/Views/AccountRegistrationView.swift#L3)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|字段背景/语义色直接编辑；正常、键盘与校验态仍待运行。|
|005|图片验证码|[LoginVerificationSheet](../../../../ddlNew/Features/Login/Views/LoginVerificationSheet.swift#L5)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|输入面/按钮直接改；验证码坏图和安全码状态未运行。|
|006|交互验证|[LoginCaptchaWebView](../../../../ddlNew/Features/Login/Views/LoginCaptchaWebView.swift#L17)|SOURCE-ONLY · SYSTEM/EXISTING · 系统/既有容器|第三方 WKWebView 宿主；周边样式由 LoginVerificationSheet，网页非静态稿实现责任。|
|007|密码安全|[PasswordChangeView](../../../../ddlNew/Features/Login/Views/PasswordChangeView.swift#L11)|SOURCE-ONLY · INCOMPLETE · 直接编辑|F4：直接 diff 仅3行表面/tint；主体 Form、字段和提交行仍旧版。|
|008|密码安全|[PasswordChangeView](../../../../ddlNew/Features/Login/Views/PasswordChangeView.swift#L11)|SOURCE-ONLY · INCOMPLETE · 直接编辑|F4：直接 diff 仅3行表面/tint；主体 Form、字段和提交行仍旧版。|
|009|密码修改成功|[PasswordChangeView](../../../../ddlNew/Features/Login/Views/PasswordChangeView.swift#L11)|SOURCE-ONLY · INCOMPLETE · 直接编辑|F4：直接 diff 仅3行表面/tint；主体 Form、字段和提交行仍旧版。|
|010|协议确认|[LoginView](../../../../ddlNew/Features/Login/Views/LoginView.swift#L11)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|品牌/欢迎标题/表单直接改；协议系统 alert 与业务 Toast 沿原链路。|
|011|连接失败|[LoginView](../../../../ddlNew/Features/Login/Views/LoginView.swift#L11)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|品牌/欢迎标题/表单直接改；协议系统 alert 与业务 Toast 沿原链路。 设计清单 source 写 LoginView；连接俱乐部失败实际 Toast 同时可来自 InvitationCodeView，不是独立错误路由。|
|012|首页|[ClubHomeView](../../../../ddlNew/Features/Home/Views/ClubHomeView.swift#L11)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|日期/入口/活动层级直接改造；组件夹具不等同整个首页运行。|
|013|活动|[ActivitiesScreen](../../../../ddlNew/Features/Activities/Views/ActivitiesScreen.swift#L10)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|直接使用 MessagingTabs；活动列表组件已改，筛选行为待运行。|
|014|活动详情|[ActivityDetailScreen](../../../../ddlNew/Features/Activities/Views/ActivityDetailScreen.swift#L10)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|标题/元数据/动作分层已直接编辑；不同报名状态仍待运行。|
|015|确认报名|[RegistrationScreen](../../../../ddlNew/Features/Activities/Views/RegistrationScreen.swift#L10)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|直接改表单/分隔；沿用本地报名状态，不新增业务。|
|016|报名成功|[RegistrationResultScreen](../../../../ddlNew/Features/Activities/Views/RegistrationResultScreen.swift#L10)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|结果符号/背景/动作直接改；本地活动结果不等于服务器受理。|
|017|候补成功|[RegistrationResultScreen](../../../../ddlNew/Features/Activities/Views/RegistrationResultScreen.swift#L10)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|结果符号/背景/动作直接改；本地活动结果不等于服务器受理。|
|018|我的报名|[RecordsScreen](../../../../ddlNew/Features/Activities/Views/RecordsScreen.swift#L10)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|页面无 diff，子 ActivityCard/空态/按钮已改；四状态共享一个页面。|
|019|候补记录|[RecordsScreen](../../../../ddlNew/Features/Activities/Views/RecordsScreen.swift#L10)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|页面无 diff，子 ActivityCard/空态/按钮已改；四状态共享一个页面。|
|020|签到记录|[RecordsScreen](../../../../ddlNew/Features/Activities/Views/RecordsScreen.swift#L10)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|页面无 diff，子 ActivityCard/空态/按钮已改；四状态共享一个页面。|
|021|已参加活动|[RecordsScreen](../../../../ddlNew/Features/Activities/Views/RecordsScreen.swift#L10)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|页面无 diff，子 ActivityCard/空态/按钮已改；四状态共享一个页面。|
|022|选择签到活动|[CheckInSelectionScreen](../../../../ddlNew/Features/Activities/Views/CheckInSelectionScreen.swift#L10)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|页面无 diff，继承 ClubCard/Badge/主题；未逐屏验收。|
|023|个人签到|[CheckInScreen](../../../../ddlNew/Features/Activities/Views/CheckInScreen.swift#L10)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|直接改字段/层级；成功/错误态仅映射。|
|024|签到成功|[CheckInScreen](../../../../ddlNew/Features/Activities/Views/CheckInScreen.swift#L10)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|直接改字段/层级；成功/错误态仅映射。|
|025|取消参与|[ActivityDetailScreen](../../../../ddlNew/Features/Activities/Views/ActivityDetailScreen.swift#L10)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|标题/元数据/动作分层已直接编辑；不同报名状态仍待运行。|
|026|俱乐部|[ClubScreen](../../../../ddlNew/Features/Club/Views/ClubScreen.swift#L10)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|直接改标题/俱乐部信息；山形 SF Symbol 表达俱乐部，不是旧 App LOGO。|
|027|俱乐部公告|[InformationSheet](../../../../ddlNew/Features/Club/Views/InformationSheet.swift#L10)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|直接调整正文/间距；实际长公告未运行。|
|028|消息|[MessageView](../../../../ddlNew/Features/Message/Views/MessageView.swift#L13)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|背景/系统助手标识直接改；共享 tabs/search，列表主体为既有 plain。|
|029|全局搜索|[GlobalSearchView](../../../../ddlNew/Features/Search/Views/GlobalSearchView.swift#L12)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|已看029：既有分类平面结果结构接近稿；共享搜索/主题，不能据此宣布保真通过。|
|030|单人聊天|[ChatRoomView](../../../../ddlNew/Features/Chat/Views/ChatRoomView.swift#L13)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|根 View 无直接改；ChatMessageBubble/Voice/MediaComposer 已直接改色；不可算整屏确认。|
|031|群聊|[ChatRoomView](../../../../ddlNew/Features/Chat/Views/ChatRoomView.swift#L13)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|根 View 无直接改；ChatMessageBubble/Voice/MediaComposer 已直接改色；不可算整屏确认。|
|032|聊天扩展面板|[ChatMediaComposer](../../../../ddlNew/Features/Chat/Components/ChatMediaComposer.swift#L14)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|前景/背景直接调整；原录音阴影仍有 offset，未据此泛化为装饰禁令。|
|033|语音录制|[ChatVoiceRecordingMeter](../../../../ddlNew/Features/Chat/Components/ChatVoiceRecordingMeter.swift#L11)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|meter 一处柱色修改，状态卡来自 ChatMediaComposer；动画/触摸未运行。|
|034|消息多选|[ChatRoomView](../../../../ddlNew/Features/Chat/Views/ChatRoomView.swift#L13)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|根 View 无直接改；ChatMessageBubble/Voice/MediaComposer 已直接改色；不可算整屏确认。|
|035|消息操作|[ChatRoomView](../../../../ddlNew/Features/Chat/Views/ChatRoomView.swift#L13)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|根 View 无直接改；ChatMessageBubble/Voice/MediaComposer 已直接改色；不可算整屏确认。|
|036|编辑消息|[ChatMessageEditorView](../../../../ddlNew/Features/Chat/Views/ChatMessageEditorView.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|共享平面卡/按钮，正文编辑仍需实际字号与键盘验证。|
|037|选择@成员|[ChatMentionPickerView](../../../../ddlNew/Features/Chat/Views/ChatMentionPickerView.swift#L10)|SOURCE-ONLY · INCOMPLETE · 共享组件/主题|F7：只有姓名，未呈现稿中角色副标题；默认 List/searchable。|
|038|查找聊天记录|[ChatHistorySearchView](../../../../ddlNew/Features/Chat/Views/ChatHistorySearchView.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|共享搜索/tab 与平面结果行；成员筛选/定位未运行。|
|039|选择转发对象|[ChatForwardRecipientView](../../../../ddlNew/Features/Chat/Views/ChatForwardRecipientView.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|共享搜索/tab/行与确认摘要；现有发送/确认语义保留，未运行。|
|040|确认转发|[ChatForwardRecipientView](../../../../ddlNew/Features/Chat/Views/ChatForwardRecipientView.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|共享搜索/tab/行与确认摘要；现有发送/确认语义保留，未运行。|
|041|聊天记录|[ChatForwardRecordView](../../../../ddlNew/Features/Chat/Views/ChatForwardRecordView.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|共享消息摘要行/分隔线；合并记录媒体预览未运行。|
|042|置顶消息|[ChatPinnedMessagesView](../../../../ddlNew/Features/Chat/Views/ChatPinnedMessagesView.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|既有平面列表与摘要行继承主题；定位行为未运行。|
|043|消息置顶|[ChatPinActionView](../../../../ddlNew/Features/Chat/Views/ChatPinActionView.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|共享平面摘要/置顶范围；只按真实权限展示，未运行。|
|044|贴纸与表情|[ChatStickersView](../../../../ddlNew/Features/Chat/Views/ChatStickersView.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|共享背景/行；贴纸图本身及点击发送规则保留。|
|045|照片预览|[ChatPhotoBrowserView](../../../../ddlNew/Features/Chat/Views/ChatPhotoBrowserView.swift#L14)|SOURCE-ONLY · SYSTEM/EXISTING · 系统/既有容器|保留现有透明全屏 JXPhotoBrowser；黑色媒体/顶部可读性渐变有功能用途。|
|046|视频预览|[ChatPhotoBrowserView](../../../../ddlNew/Features/Chat/Views/ChatPhotoBrowserView.swift#L14)|SOURCE-ONLY · SYSTEM/EXISTING · 系统/既有容器|保留现有透明全屏 JXPhotoBrowser；黑色媒体/顶部可读性渐变有功能用途。|
|047|文件详情|[ChatMediaDetailView](../../../../ddlNew/Features/Chat/Views/ChatMediaDetailView.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|共享媒体详情、文件操作/权限；下载与系统预览未运行。|
|048|语音详情|[ChatMediaDetailView](../../../../ddlNew/Features/Chat/Views/ChatMediaDetailView.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|共享媒体详情、文件操作/权限；下载与系统预览未运行。|
|049|位置详情|[ChatLocationDetailView](../../../../ddlNew/Features/Chat/Views/ChatLocationDetailView.swift#L12)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|MapKit 内容和共享动作；地图本身不是主题补漏。|
|050|聊天设置|[ChatSettingsView](../../../../ddlNew/Features/Chat/Views/ChatSettingsView.swift#L11)|SOURCE-ONLY · INCOMPLETE · 共享组件/主题|F8：共享卡已去圆角，但外层16pt内缩+12pt间隔仍为旧分区节奏；保留真实成员预览。|
|051|通讯录|[ContactsView](../../../../ddlNew/Features/Contacts/Views/ContactsView.swift#L12)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|根页仅一处底面直接改；tab/search/shortcut由共享组件变更。|
|052|群聊列表|[ContactsView](../../../../ddlNew/Features/Contacts/Views/ContactsView.swift#L12)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|根页仅一处底面直接改；tab/search/shortcut由共享组件变更。|
|053|添加好友|[AddFriendView](../../../../ddlNew/Features/Contacts/Views/AddFriendView.swift#L12)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|继承搜索/行/主题；结果仍有局部 clipShape，未逐像素判为通过。|
|054|查找结果|[AddFriendView](../../../../ddlNew/Features/Contacts/Views/AddFriendView.swift#L12)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|继承搜索/行/主题；结果仍有局部 clipShape，未逐像素判为通过。|
|055|新朋友|[NewFriendsView](../../../../ddlNew/Features/Contacts/Views/NewFriendsView.swift#L13)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|既有 plain 申请行共享色与按钮；不改变本页独立 Toast 约束。|
|056|用户资料|[ContactRecordDetailView](../../../../ddlNew/Features/Contacts/Views/ContactRecordDetailView.swift#L14)|SOURCE-ONLY · INCOMPLETE · 直接编辑|F3：硬编码头部圆角、左右字段、重复身份区；主操作仍随正文滚动。|
|057|好友管理|[ContactRecordDetailView](../../../../ddlNew/Features/Contacts/Views/ContactRecordDetailView.swift#L14)|SOURCE-ONLY · INCOMPLETE · 直接编辑|F3：硬编码头部圆角、左右字段、重复身份区；主操作仍随正文滚动。|
|058|备注与描述|[ContactRemarkEditor](../../../../ddlNew/Features/Contacts/Views/ContactRemarkEditor.swift#L13)|SOURCE-ONLY · INCOMPLETE · 直接编辑|F4：原生 Form/Section 未换独立灰蓝输入面；失败保稿逻辑保持。|
|059|分组管理|[FriendGroupManagerView](../../../../ddlNew/Features/Contacts/Views/FriendGroupManagerView.swift#L13)|SOURCE-ONLY · INCOMPLETE · 直接编辑|F5：默认 List 分组、首行添加；稿为平面列表和导航添加。|
|060|编辑分组|[FriendGroupNameEditor](../../../../ddlNew/Features/Contacts/Views/FriendGroupNameEditor.swift#L13)|SOURCE-ONLY · INCOMPLETE · 直接编辑|F4：Form 单字段未换独立灰蓝输入面；底部保存保留。|
|061|移动分组|[ContactGroupPicker](../../../../ddlNew/Features/Contacts/Views/ContactGroupPicker.swift#L13)|SOURCE-ONLY · INCOMPLETE · 直接编辑|F5：默认 List 分组，添加分组在顶部；稿为平面名单与底部添加。|
|062|我的二维码|[BusinessQRCodeView](../../../../ddlNew/Features/Contacts/Views/BusinessQRCodeView.swift#L15)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|继承平面 MessagingCard 与主按钮；二维码/权限与有效期待运行。|
|063|扫一扫|[BusinessQRScannerView](../../../../ddlNew/Features/Contacts/Views/BusinessQRScannerView.swift#L15)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|相机和白色取景线为业务媒体容器；照片/相机权限待运行。|
|064|分享名片|[ContactsRecipientPickerView](../../../../ddlNew/Features/Contacts/Views/ContactsRecipientPickerView.swift#L12)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|plain 名单/共享搜索/按钮；多选与确认未运行。|
|065|成员资料（旧演示页）|[ContactDetailSheet](../../../../ddlNew/Features/Contacts/Views/ContactDetailSheet.swift#L11)|SOURCE-ONLY · DEMO-EXCLUDED · 共享组件/主题|仅 Original 页面→ChatScreen 可达，当前真实产品不接此页；排除漏页计数。|
|066|群聊设置|[ChatSettingsView](../../../../ddlNew/Features/Chat/Views/ChatSettingsView.swift#L11)|SOURCE-ONLY · INCOMPLETE · 共享组件/主题|F8：共享卡已去圆角，但外层16pt内缩+12pt间隔仍为旧分区节奏；保留真实成员预览。|
|067|创建群聊|[GroupMemberPickerView](../../../../ddlNew/Features/Groups/Views/GroupMemberPickerView.swift#L12)|SOURCE-ONLY · INCOMPLETE · 共享组件/主题|F6：分段 Picker 未接下划线 tab；已选头像在顶部，稿位于底部。|
|068|邀请群成员|[GroupMemberPickerView](../../../../ddlNew/Features/Groups/Views/GroupMemberPickerView.swift#L12)|SOURCE-ONLY · INCOMPLETE · 共享组件/主题|F6：分段 Picker 未接下划线 tab；已选头像在顶部，稿位于底部。|
|069|邀请审核说明|[GroupMemberPickerView](../../../../ddlNew/Features/Groups/Views/GroupMemberPickerView.swift#L12)|SOURCE-ONLY · INCOMPLETE · 共享组件/主题|F6：分段 Picker 未接下划线 tab；已选头像在顶部，稿位于底部。|
|070|群成员|[ChatGroupMembersView](../../../../ddlNew/Features/Chat/Views/ChatGroupMembersView.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|plain 名单/角色徽标；管理 Menu、转让确认仍是系统控件。|
|071|移除群成员|[ChatGroupRemovalView](../../../../ddlNew/Features/Chat/Views/ChatGroupRemovalView.swift#L12)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|plain 多选名单；确认用原生 Form，整页未运行比较。|
|072|移除成员确认|[ChatGroupRemovalView](../../../../ddlNew/Features/Chat/Views/ChatGroupRemovalView.swift#L12)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|plain 多选名单；确认用原生 Form，整页未运行比较。|
|073|群管理|[ChatGroupManagementView](../../../../ddlNew/Features/Chat/Views/ChatGroupManagementView.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|共享平面分区已生效；标题/图标/开关密度与稿仍需运行比较。|
|074|成员权限操作|[ChatGroupMembersView](../../../../ddlNew/Features/Chat/Views/ChatGroupMembersView.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|plain 名单/角色徽标；管理 Menu、转让确认仍是系统控件。|
|075|转让群主|[ChatGroupMembersView](../../../../ddlNew/Features/Chat/Views/ChatGroupMembersView.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|plain 名单/角色徽标；管理 Menu、转让确认仍是系统控件。|
|076|群头像|[ChatGroupAvatarView](../../../../ddlNew/Features/Chat/Views/ChatGroupAvatarView.swift#L12)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|共享主按钮/表面；真实选图与上传未运行。|
|077|修改群名称|[ChatSettingsView](../../../../ddlNew/Features/Chat/Views/ChatSettingsView.swift#L177)|SOURCE-ONLY · INCOMPLETE · 共享组件/主题|F8：共享卡已去圆角，但外层16pt内缩+12pt间隔仍为旧分区节奏；保留真实成员预览。|
|078|我的群昵称|[ChatSettingsView](../../../../ddlNew/Features/Chat/Views/ChatSettingsView.swift#L177)|SOURCE-ONLY · INCOMPLETE · 共享组件/主题|F8：共享卡已去圆角，但外层16pt内缩+12pt间隔仍为旧分区节奏；保留真实成员预览。|
|079|群二维码|[BusinessQRCodeView](../../../../ddlNew/Features/Contacts/Views/BusinessQRCodeView.swift#L15)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|继承平面 MessagingCard 与主按钮；二维码/权限与有效期待运行。|
|080|群公告|[ChatGroupNoticesView](../../../../ddlNew/Features/Chat/Views/ChatGroupNoticesView.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|plain 列表，详情/编辑为同文件私有 View；正文输入仍共享旧 MessagingCard。|
|081|公告详情|[ChatGroupNoticesView](../../../../ddlNew/Features/Chat/Views/ChatGroupNoticesView.swift#L128)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|plain 列表，详情/编辑为同文件私有 View；正文输入仍共享旧 MessagingCard。|
|082|编辑群公告|[ChatGroupNoticesView](../../../../ddlNew/Features/Chat/Views/ChatGroupNoticesView.swift#L176)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|plain 列表，详情/编辑为同文件私有 View；正文输入仍共享旧 MessagingCard。|
|083|群助手|[GroupApplicationsView](../../../../ddlNew/Features/GroupApplications/Views/GroupApplicationsView.swift#L12)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|plain 列表/共享 tab；审批选择和真实状态不变，未运行。|
|084|退出群聊|[ChatSettingsView](../../../../ddlNew/Features/Chat/Views/ChatSettingsView.swift#L11)|SOURCE-ONLY · INCOMPLETE · 共享组件/主题|F8：共享卡已去圆角，但外层16pt内缩+12pt间隔仍为旧分区节奏；保留真实成员预览。|
|085|解散群聊|[ChatSettingsView](../../../../ddlNew/Features/Chat/Views/ChatSettingsView.swift#L11)|SOURCE-ONLY · INCOMPLETE · 共享组件/主题|F8：共享卡已去圆角，但外层16pt内缩+12pt间隔仍为旧分区节奏；保留真实成员预览。|
|086|语音来电|[CallRoomView](../../../../ddlNew/Features/Calls/Views/CallRoomView.swift#L11)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|本轮仅两处通话背景/接听色直接编辑；布局并未重做或运行验收。|
|087|语音通话|[CallRoomView](../../../../ddlNew/Features/Calls/Views/CallRoomView.swift#L11)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|本轮仅两处通话背景/接听色直接编辑；布局并未重做或运行验收。|
|088|视频通话|[CallRoomView](../../../../ddlNew/Features/Calls/Views/CallRoomView.swift#L11)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|本轮仅两处通话背景/接听色直接编辑；布局并未重做或运行验收。|
|089|群通话|[CallRoomView](../../../../ddlNew/Features/Calls/Views/CallRoomView.swift#L11)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|本轮仅两处通话背景/接听色直接编辑；布局并未重做或运行验收。|
|090|选择通话成员|[CallMemberSelectionView](../../../../ddlNew/Features/Calls/Views/CallMemberSelectionView.swift#L4)|SOURCE-ONLY · INCOMPLETE · 共享组件/主题|F7：默认 List/searchable，未接 MessagingPageChrome；选择圈与稿位置不同。|
|091|群发助手|[MassMessageView](../../../../ddlNew/Features/MassMessage/Views/MassMessageView.swift#L11)|SOURCE-ONLY · INCOMPLETE · 共享组件/主题|F1：insetGrouped 每条多行卡，任务标题/状态/正文顺序尚未对齐。|
|092|新建群发|[MassMessageComposerView](../../../../ddlNew/Features/MassMessage/Views/MassMessageComposerView.swift#L14)|SOURCE-ONLY · INCOMPLETE · 共享组件/主题|F2：主体 Form/Section，未落实对象摘要→独立标签/正文输入面；再发锁定规则保留。|
|093|群发接收对象|[MassMessageRecipientPicker](../../../../ddlNew/Features/MassMessage/Views/MassMessageRecipientPicker.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|共享 tab/plain 列表；完成仍底部而稿在导航栏，P3差异。|
|094|发送结果|[MassMessageRecipientsView](../../../../ddlNew/Features/MassMessage/Views/MassMessageRecipientsView.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|既有 plain 接收名单/失败原因，继承主题；不能虚构逐个成功。|
|095|再次群发|[MassMessageComposerView](../../../../ddlNew/Features/MassMessage/Views/MassMessageComposerView.swift#L14)|SOURCE-ONLY · INCOMPLETE · 共享组件/主题|F2：主体 Form/Section，未落实对象摘要→独立标签/正文输入面；再发锁定规则保留。|
|096|我的|[MineView](../../../../ddlNew/Features/Mine/Views/MineView.swift#L14)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|MinePageContent 分区/身份层级直接改；实际账号长度与弹窗待运行。|
|097|编辑个人资料|[MineProfileView](../../../../ddlNew/Features/Mine/Views/MineProfileView.swift#L13)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|身份行/昵称输入面直接改；头像来源与裁剪是系统 UIImagePickerController。|
|098|修改昵称|[MineProfileView](../../../../ddlNew/Features/Mine/Views/MineProfileView.swift#L145)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|身份行/昵称输入面直接改；头像来源与裁剪是系统 UIImagePickerController。|
|099|修改头像|[MineProfileView](../../../../ddlNew/Features/Mine/Views/MineProfileView.swift#L13)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|身份行/昵称输入面直接改；头像来源与裁剪是系统 UIImagePickerController。|
|100|头像裁剪|[MineProfileView](../../../../ddlNew/Features/Mine/Views/MineProfileView.swift#L13)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|MineProfileView.fullScreenCover → MineAvatarPicker；方形裁剪来自系统 picker，不新建自定义裁剪业务。|
|101|设置|[SettingsScreen](../../../../ddlNew/Features/Mine/Views/SettingsScreen.swift#L10)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|SettingsPageContent 直接改；确认仍系统 alert，未执行退出。|
|102|黑名单|[BlacklistView](../../../../ddlNew/Features/Safety/Views/BlacklistView.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|已有 plain 列表，语义色/Toast 继承；失败/处理中未运行。|
|103|投诉与支持|[ComplaintView](../../../../ddlNew/Features/Safety/Views/ComplaintView.swift#L12)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|字段/表面直接改；提交/失败通过原 Toast，未实际上传证据。|
|104|投诉提交后的反馈|[ComplaintView](../../../../ddlNew/Features/Safety/Views/ComplaintView.swift#L12)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|字段/表面直接改；提交/失败通过原 Toast，未实际上传证据。|
|105|注销账号|[DeleteAccountScreen](../../../../ddlNew/Features/Mine/Views/DeleteAccountScreen.swift#L10)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|后果说明/主按钮直接改；二次确认仍系统 alert，不执行真实注销。|
|106|注销确认|[DeleteAccountScreen](../../../../ddlNew/Features/Mine/Views/DeleteAccountScreen.swift#L10)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|后果说明/主按钮直接改；二次确认仍系统 alert，不执行真实注销。|
|107|退出登录|[SettingsScreen](../../../../ddlNew/Features/Mine/Views/SettingsScreen.swift#L10)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|SettingsPageContent 直接改；确认仍系统 alert，未执行退出。|
|108|更换俱乐部|[MineView](../../../../ddlNew/Features/Mine/Views/MineView.swift#L14)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|MinePageContent 分区/身份层级直接改；实际账号长度与弹窗待运行。|
|109|隐私政策|[LegalDocumentScreen / RemoteLegalPage](../../../../ddlNew/Common/Legal/Views/LegalDocumentScreen.swift#L12)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|宿主状态直接改；线上正文/Safari由系统与服务端提供。|
|110|使用支持|[LegalDocumentScreen / RemoteLegalPage](../../../../ddlNew/Common/Legal/Views/LegalDocumentScreen.swift#L12)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|宿主状态直接改；线上正文/Safari由系统与服务端提供。|
|111|搜索无结果|[GlobalSearchView](../../../../ddlNew/Features/Search/Views/GlobalSearchView.swift#L12)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|已看029：既有分类平面结果结构接近稿；共享搜索/主题，不能据此宣布保真通过。|
|112|网络加载失败|[BlacklistView](../../../../ddlNew/Features/Safety/Views/BlacklistView.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|已有 plain 列表，语义色/Toast 继承；失败/处理中未运行。|
|113|权限发生变化|[ChatGroupManagementView](../../../../ddlNew/Features/Chat/Views/ChatGroupManagementView.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|共享平面分区已生效；标题/图标/开关密度与稿仍需运行比较。|
|114|原消息失效|[ChatPhotoBrowserView](../../../../ddlNew/Features/Chat/Views/ChatPhotoBrowserView.swift#L14)|SOURCE-ONLY · SYSTEM/EXISTING · 系统/既有容器|保留现有透明全屏 JXPhotoBrowser；黑色媒体/顶部可读性渐变有功能用途。|
|115|群聊禁言|[ChatRoomView](../../../../ddlNew/Features/Chat/Views/ChatRoomView.swift#L13)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|根 View 无直接改；ChatMessageBubble/Voice/MediaComposer 已直接改色；不可算整屏确认。|
|116|清空记录确认|[ChatSettingsView](../../../../ddlNew/Features/Chat/Views/ChatSettingsView.swift#L11)|SOURCE-ONLY · INCOMPLETE · 共享组件/主题|F8：共享卡已去圆角，但外层16pt内缩+12pt间隔仍为旧分区节奏；保留真实成员预览。|
|117|移出黑名单 · 处理中|[BlacklistView](../../../../ddlNew/Features/Safety/Views/BlacklistView.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|已有 plain 列表，语义色/Toast 继承；失败/处理中未运行。|
|118|放弃编辑|[ContactRemarkEditor](../../../../ddlNew/Features/Contacts/Views/ContactRemarkEditor.swift#L13)|SOURCE-ONLY · INCOMPLETE · 直接编辑|F4：原生 Form/Section 未换独立灰蓝输入面；失败保稿逻辑保持。|
|119|群聊设置 · 下半页|[ChatSettingsView](../../../../ddlNew/Features/Chat/Views/ChatSettingsView.swift#L11)|SOURCE-ONLY · INCOMPLETE · 共享组件/主题|F8：共享卡已去圆角，但外层16pt内缩+12pt间隔仍为旧分区节奏；保留真实成员预览。|
|120|群管理 · 下半页|[ChatGroupManagementView](../../../../ddlNew/Features/Chat/Views/ChatGroupManagementView.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|共享平面分区已生效；标题/图标/开关密度与稿仍需运行比较。|
|121|活动 · 筛选|[ActivitiesScreen](../../../../ddlNew/Features/Activities/Views/ActivitiesScreen.swift#L10)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|直接使用 MessagingTabs；活动列表组件已改，筛选行为待运行。|
|003-empty|登录 · 空输入|[LoginView](../../../../ddlNew/Features/Login/Views/LoginView.swift#L11)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|品牌/欢迎标题/表单直接改；协议系统 alert 与业务 Toast 沿原链路。|
|003-busy|登录 · 正在提交|[LoginView](../../../../ddlNew/Features/Login/Views/LoginView.swift#L11)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|品牌/欢迎标题/表单直接改；协议系统 alert 与业务 Toast 沿原链路。|
|005-failed|验证码 · 图片失败|[LoginVerificationSheet](../../../../ddlNew/Features/Login/Views/LoginVerificationSheet.swift#L5)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|输入面/按钮直接改；验证码坏图和安全码状态未运行。|
|006-failed|交互验证 · 失败|[LoginCaptchaWebView](../../../../ddlNew/Features/Login/Views/LoginCaptchaWebView.swift#L17)|SOURCE-ONLY · SYSTEM/EXISTING · 系统/既有容器|第三方 WKWebView 宿主；周边样式由 LoginVerificationSheet，网页非静态稿实现责任。|
|006-code|安全码验证|[LoginVerificationSheet](../../../../ddlNew/Features/Login/Views/LoginVerificationSheet.swift#L5)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|输入面/按钮直接改；验证码坏图和安全码状态未运行。|
|014-wait|活动 · 名额已满|[ActivityDetailScreen](../../../../ddlNew/Features/Activities/Views/ActivityDetailScreen.swift#L10)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|标题/元数据/动作分层已直接编辑；不同报名状态仍待运行。|
|014-joined|活动 · 已报名|[ActivityDetailScreen](../../../../ddlNew/Features/Activities/Views/ActivityDetailScreen.swift#L10)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|标题/元数据/动作分层已直接编辑；不同报名状态仍待运行。|
|023-error|签到 · 输入错误|[CheckInScreen](../../../../ddlNew/Features/Activities/Views/CheckInScreen.swift#L10)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|直接改字段/层级；成功/错误态仅映射。|
|030-failed|单聊 · 发送失败|[ChatRoomView](../../../../ddlNew/Features/Chat/Views/ChatRoomView.swift#L13)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|根 View 无直接改；ChatMessageBubble/Voice/MediaComposer 已直接改色；不可算整屏确认。|
|033-cancel|录音 · 松开取消|[ChatVoiceRecordingMeter](../../../../ddlNew/Features/Chat/Components/ChatVoiceRecordingMeter.swift#L11)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|meter 一处柱色修改，状态卡来自 ChatMediaComposer；动画/触摸未运行。|
|056-stranger|资料 · 非好友|[ContactRecordDetailView](../../../../ddlNew/Features/Contacts/Views/ContactRecordDetailView.swift#L14)|SOURCE-ONLY · INCOMPLETE · 直接编辑|F3：硬编码头部圆角、左右字段、重复身份区；主操作仍随正文滚动。|
|056-blocked|资料 · 已拉黑|[ContactRecordDetailView](../../../../ddlNew/Features/Contacts/Views/ContactRecordDetailView.swift#L14)|SOURCE-ONLY · INCOMPLETE · 直接编辑|F3：硬编码头部圆角、左右字段、重复身份区；主操作仍随正文滚动。|
|058-error|备注 · 保存失败|[ContactRemarkEditor](../../../../ddlNew/Features/Contacts/Views/ContactRemarkEditor.swift#L13)|SOURCE-ONLY · INCOMPLETE · 直接编辑|F4：原生 Form/Section 未换独立灰蓝输入面；失败保稿逻辑保持。|
|066-member|群设置 · 普通成员|[ChatSettingsView](../../../../ddlNew/Features/Chat/Views/ChatSettingsView.swift#L11)|SOURCE-ONLY · INCOMPLETE · 共享组件/主题|F8：共享卡已去圆角，但外层16pt内缩+12pt间隔仍为旧分区节奏；保留真实成员预览。|
|066-owner|群设置 · 群主|[ChatSettingsView](../../../../ddlNew/Features/Chat/Views/ChatSettingsView.swift#L11)|SOURCE-ONLY · INCOMPLETE · 共享组件/主题|F8：共享卡已去圆角，但外层16pt内缩+12pt间隔仍为旧分区节奏；保留真实成员预览。|
|083-pending|群助手 · 待审核|[GroupApplicationsView](../../../../ddlNew/Features/GroupApplications/Views/GroupApplicationsView.swift#L12)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|plain 列表/共享 tab；审批选择和真实状态不变，未运行。|
|087-wait|语音 · 等待接听|[CallRoomView](../../../../ddlNew/Features/Calls/Views/CallRoomView.swift#L11)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|本轮仅两处通话背景/接听色直接编辑；布局并未重做或运行验收。|
|092-error|群发 · 提交失败|[MassMessageComposerView](../../../../ddlNew/Features/MassMessage/Views/MassMessageComposerView.swift#L14)|SOURCE-ONLY · INCOMPLETE · 共享组件/主题|F2：主体 Form/Section，未落实对象摘要→独立标签/正文输入面；再发锁定规则保留。|
|092-attachment|群发 · 附件|[MassMessageComposerView](../../../../ddlNew/Features/MassMessage/Views/MassMessageComposerView.swift#L14)|SOURCE-ONLY · INCOMPLETE · 共享组件/主题|F2：主体 Form/Section，未落实对象摘要→独立标签/正文输入面；再发锁定规则保留。|
|091-accepted|群发 · 已受理|[MassMessageView](../../../../ddlNew/Features/MassMessage/Views/MassMessageView.swift#L11)|SOURCE-ONLY · INCOMPLETE · 共享组件/主题|F1：insetGrouped 每条多行卡，任务标题/状态/正文顺序尚未对齐。|
|094-failed|群发 · 失败对象|[MassMessageRecipientsView](../../../../ddlNew/Features/MassMessage/Views/MassMessageRecipientsView.swift#L11)|SOURCE-ONLY · SHARED-STYLE · 共享组件/主题|既有 plain 接收名单/失败原因，继承主题；不能虚构逐个成功。|
|103-ready|投诉 · 填写完成|[ComplaintView](../../../../ddlNew/Features/Safety/Views/ComplaintView.swift#L12)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|字段/表面直接改；提交/失败通过原 Toast，未实际上传证据。|
|103-busy|投诉 · 正在提交|[ComplaintView](../../../../ddlNew/Features/Safety/Views/ComplaintView.swift#L12)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|字段/表面直接改；提交/失败通过原 Toast，未实际上传证据。|
|103-error|投诉 · 失败保留|[ComplaintView](../../../../ddlNew/Features/Safety/Views/ComplaintView.swift#L12)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|字段/表面直接改；提交/失败通过原 Toast，未实际上传证据。|
|105-ready|注销 · 已确认后果|[DeleteAccountScreen](../../../../ddlNew/Features/Mine/Views/DeleteAccountScreen.swift#L10)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|后果说明/主按钮直接改；二次确认仍系统 alert，不执行真实注销。|
|001-wait|启动等待|[LaunchWaitingView](../../../../ddlNew/App/Startup/LaunchWaitingView.swift#L12)|SOURCE-ONLY · DIRECT-EDIT · 直接编辑|直接复用 storyboard 并加真实等待 spinner；实际转场未验证。|

## 尚不能确认

本次没有147个实际页面截图，也未验证键盘遮挡、iOS最大辅助字号、VoiceOver、深色整屏、iPad、安全区、系统启动缓存、菜单与sheet转场。源码映射不证明相机/相册/验证码/上传/消息/群管理或其它服务端业务成功。不要为制造设计状态而修改真实联系人、群成员、消息或账号。

主执行者补漏后，应对本报告列出的 F1-F8 各代表页补运行截图与实际源码复核，再单独追加关闭记录；没有被运行的状态继续保留 SOURCE-ONLY。

## 12文件补漏后的只读闭环复核

复核时间：2026-10-30T14:16:30+08:00。范围为本报告 F1-F8 对应的12个 UI 文件；以当前工作树对 HEAD 的diff、当前源码、前述15张已查看批准稿进行复核。没有构建或运行App，本节不接收其他执行者正在进行的测试作为本人的测试结论。初始147行保留为补漏前快照；本节覆盖其源码缺口状态，所有运行等级仍为 **SOURCE-ONLY**。

### 关闭状态

|项|源码复核状态|当前证据与保留条件|
|---|---|---|
|F1 群发历史|CLOSED-SOURCE|已改 ScrollView/LazyVStack 白色连续列表；标题/状态/对象数/时间先于正文，操作集中排列。全部接收对象、失败对象、再发、删除确认、分页及刷新仍在。|
|F2 群发编辑|CLOSED-SOURCE|已改独立对象摘要、标签字段与外置计数、正文/附件区；灰蓝字段面与底部发送。原 original 分支、标签禁用、canSubmit/busy/allowed、附件二选一、确认发送和失败保稿闭包未变。|
|F3 联系人资料|CLOSED-SOURCE|去身份圆角，改大标题/复制账号、双行详情，主动作移底部。只移除重复账号行与和显示名称相同的昵称行；真实账号仍在头部可复制，差异昵称/群昵称/备注/描述/在线/角色仍保留。访问、好友、自身、注销、权限和黑名单资格与原动作保留。|
|F4 备注/分组名/密码表单|CLOSED-SOURCE|三页均改白底和独立灰蓝输入面。备注保存移到导航，原 disabled 条件与 save 完整保留。密码原/新/成功三阶段及强制/可延后/退出分支仍在，新增成功层级仅由已有 passwordChanged 决定。|
|F5 分组管理/移动|CLOSED-SOURCE|两页显式 plain/白底。添加入口分别移导航与名单底部。删除移入更多菜单但仍受 !isDefault 控制、仍打开原确认；onMove、前后移、改名、移动分组即提交和失败保留均在。|
|F6 建群/邀请选择器|CLOSED-SOURCE|segmented 改同一 filter binding 的 MessagingTabs；已选区移底部。原 chosen、preselectedIDs、minimum/maximum、toggle/selectGroup/confirm 与 onSubmit 保留；提交中tab和取消选择仍禁用。|
|F7 @/通话成员选择|CLOSED-SOURCE|均显式 plain/白底；@补真实角色/普通成员副标题、chevron，仍直接调用 onSelect；通话选择圈移左，已有成员说明位于副标题，alreadyInCall/busy/selected/requestID与原确认不变。searchable 保留原生实现，实际导航/键盘还需运行。|
|F8 聊天设置|CLOSED-SOURCE|已去外层16pt内缩和12pt灰蓝间隔，改连续白底；最终 row(_:value:icon:) 改左对齐标题→值双行，值允许垂直增长，图标/chevron 保留。成员预览/加减号/完整名单/权限/开关/清空/退出/解散均保留；群头仍用“群资料”标识其原有资料入口，属于保留实际功能的展示差异，不计未实现双行布局。|

本轮结论：**F1-F8 中 8项源码关闭、0项未关闭源码缺口；运行通过0项。** 另有2类待验：①本报告全部146个生产设计状态仍未由本审计运行，特别是系统搜索/菜单、键盘、安全区、大字号和深色整屏；②原低优先级093“完成”仍在底部，与静态稿导航位置有差异，未纳入这12文件补丁。不得将“源码关闭”改写为页面视觉通过或业务验收完成。

### 业务与SwiftUI语义核对

逐段人工复核了移动的按钮、内联闭包、条件分支、disabled、sheet/alert/confirmationDialog。12文件的既有具名方法正文按去空白对照HEAD：仅联系人 detail 展示方法变化；群发新增 recipients 展示方法，原 save/prepare/close/confirm/toggle/selectGroup/moveGroup/权限方法保持。该文字比较只是辅助证据，不代替编译与运行。

- 没有发现新增请求、Store/Services/ViewModels/Models/Network 变更；没有把服务端未确认状态改为成功。群发 statusText 继续来自原记录，全部对象不被改成全部送达。
- Form→ScrollView 后禁用作用域仍覆盖原字段和按钮；密码页的外层 disabled 仍覆盖 safeAreaInset，群发正文 VStack 仍 disabled(busy)。
- 联系人底部操作搬移保留 groupAccessAllowed、contact 存在、未注销、非本人、isFriend、allowAddFriend和黑名单判断。删除/拉黑、投诉和推荐菜单没有删掉。
- 使用动态语义字号和可增长字段；触点保持至少44pt。主操作/错误/正文采用现有自适应语义色，没有新增写死白字配浅色按钮的问题。
- 静态计算：次级字对白面4.96:1、对浅灰蓝字段4.54:1；深色对白面对应7.89:1、字段8.90:1；浅/深主按钮前景6.47:1、8.48:1；浅色错误字对白面5.40:1、字段4.95:1，深色错误字对表面7.74:1。此计算针对启用态明确token；系统placeholder、禁用alpha、系统Menu和真实合成画面未验证。
- 尚未发现可确认的源码级阻断。长昵称/超大字号导致的底部已选区高度、固定按钮与键盘交互、List内菜单与拖动手势，需要运行实测，不能靠源码断言通过。

复核文件快照（SHA-256前12位，后续编辑需重核）：

|文件|摘要|
|---|---|
|ContactRecordDetailView.swift|`6ca63b9148f9`|
|ContactRemarkEditor.swift|`0632a6770dd6`|
|ContactGroupPicker.swift|`b46eb2dc8baf`|
|FriendGroupManagerView.swift|`74f3160951a8`|
|FriendGroupNameEditor.swift|`413ae44eafd1`|
|GroupMemberPickerView.swift|`b3dcf11eea84`|
|MassMessageComposerView.swift|`7b3601276969`|
|MassMessageView.swift|`f2b8b20a5e2e`|
|PasswordChangeView.swift|`92ce8b1cb813`|
|ChatMentionPickerView.swift|`9a59a3b4f425`|
|CallMemberSelectionView.swift|`a6df784d74d4`|
|ChatSettingsView.swift|`c189b6d67ca3`|

### F8 最终增量复核

2026-10-30T14:18:23+08:00：仅重核 ChatSettingsView.swift 最后新增的 row 双行布局。变化限于展示函数：标题和非空 value 放入 leading VStack，value 保持 subheadline/secondaryText，并使用 fixedSize(horizontal: false, vertical: true) 支持换行；原 icon、chevron、16pt内距和至少44pt触点保留。所有调用点、Button动作、NavigationLink目的、Toggle binding、权限判断与disabled条件未改。未发现此增量引入的源码级阻断。F8 更新为 CLOSED-SOURCE，以上合计更新为8关闭/0缺口；运行验证仍为0通过，原2类待验不变。

## 实际截图独立视觉复核（有限覆盖）

2026-10-30：本审计读取主执行者提供的11张实际截图，对照11张对应批准PNG，没有亲自操作设备或执行提交动作。4张文件名为iphone的截图为主执行者提供的iPhone画面，其余7张为其Mac运行捕获。以下只判断截图可见区域，不把初始147行整体升级为运行通过。首页最终截图尚未提供。实际截图位于 `/tmp/ddlNew-newUI-5-runtime/`。

|设计参考|实际截图文件|观察|
|---|---|---|
|028|iphone-028-messages-final.png|消息标题可见；搜索/加号、正文搜索、分类、会话和底栏均在。系统导航外观不同于静态稿，未见功能遮挡。|
|051|iphone-051-contacts-final.png|标题、顶部全局搜索/添加工具栏、快捷入口、分类、正文搜索、字母索引和联系人均可见。|
|056|056-profile.png|平面身份头、账号复制、双行备注/描述、底部发送消息可见；在线状态是既有业务保留。|
|058|058-remark.png|灰蓝字段、独立字数、导航取消/保存可见；实际是未填写或未改动状态，不能证明有变更后保存成功。|
|059|059-groups.png|连续名单、默认分组、更多菜单、拖动柄和添加入口可见；未验证菜单或排序提交。|
|060新增分支|060-group-name.png|实际为添加分组半屏sheet，标题/字段/底部禁用保存可见；批准稿060是有值编辑分组，不作状态一对一通过。|
|066-owner|066-group-settings.png|群资料、成员预览和加减入口可见；成员数/群名称已经双行显示。下方开关/退出未在此截图显示。|
|068选1人|068-member-picker-selected.png|分类、勾选、底部已选头像/数量、顶部完成(1)均可见。完成为系统灰底白字，未点击，不凭外观判定禁用。|
|101|101-settings.png|账号、隐私/支持、注销、退出与完成可见；完成为系统灰底白字。未执行注销或退出。|
|013|iphone-013-activities.png|搜索、四分类、连续列表和已有活动状态完整，未见关键文字裁切或入口遮挡。|
|014-wait候补中分支|iphone-014-activity-waiting.png|活动信息、候补状态、须知、取消候补和底部等待中可见；批准014-wait是尚未加入候补，不为追齐静态按钮改变业务状态。|

### 复核结论与更正

重新单独读取完整 iphone-051-contacts-final.png 后，已确认右上钴蓝色搜索与加号位于白色工具栏内。先前“工具栏缺失”的观察不成立，撤销该问题；无需因此修改源码。主执行者另反馈移动端可访问性树包含“全局搜索/添加好友”，该反馈不是本审计亲自操作所得。

11张截图所见区域未发现足以阻断使用的明确遮挡、主操作缺失或内容裁切。通讯录快捷入口排列、系统导航材质、账号样本、066成员预览等差异不扩展为新外观重做范围。058/068/101原生确认按钮的白字浅灰面随实际启用态和设备继续观察，本次不误判为业务禁用。

复查最新标题修正源码：MessageView、ContactsView通过正文大标题与inline principal占位展示标题；搜索/添加路由、权限、数据过滤与操作闭包保留。ClubHomeView展示调整仍用原活动路由、store.status和公告动作，没有引入请求或新业务状态；这不代替首页最终运行检查。

本次新增11张实际画面观察证据，所见区域没有确认的UI阻断；051工具栏已复核可见。F1-F8仍按8项源码关闭计数，不能称8项均完成实际验收。F1/F2/F4密码、F5移动分组、F7等本轮没有对应实际图；最大字号、深色、键盘、VoiceOver、滚动末端、菜单动作与服务端提交均未由本审计验证。临时截图可能被后续捕获覆盖。

### 最终增量：iPhone首页与启动等待层

2026-10-30T15:20:07+08:00：补看 `iphone-012-home-final.png`（SHA-256前12位 `13bd4ea95b77`）并对照批准012。实际首页标题、俱乐部名、下一场活动日期/标题/状态、查看参与信息主按钮、三项快捷入口、近期活动和底栏均可见，所见区域未发现新的使用阻断。底部更多内容仍需滚动才能检查，不据此判完整长页通过。现在本审计实际图观察覆盖为12张（5张iPhone、7张Mac运行捕获），取代上节“首页最终截图尚未提供”的临时状态。

标题修复应用在共享的 MessageView、ContactsView、ClubHomeView 源码，不能描述为仅Mac修复。最新iPhone截图已经分别显示“消息”“通讯录”“首页”正文标题；主执行者报告Mac亦已检查，本审计不把iPhone截图当成所有系统版本验证。未更改搜索/添加/公告/活动等既有路由和状态条件。

启动等待层：当前 LaunchWaitingView 只实例化原 LaunchScreen storyboard，没有再新增 UIActivityIndicatorView；storyboard中也无独立进度控件。ddlNewApp.swift:49-68 原有底部 ProgressView 与 authentication.state/connection.phase 动态文案仍完整保留，且该文件当前无diff。因而删除重复指示器未移除真实恢复反馈，也未改变启动/登录状态机。早先001-wait行所述“新增spinner”属于当时快照，当前以本增量为准。

本增量仅做源码和已提供首页截图核对；删除重复spinner后的启动实际画面与正在进行的最终构建尚未由本审计验证。没有新增源码阻断或外观改造要求，F1-F8继续为8项源码关闭，12张截图仍是有限可见区域观察，147设计状态未整体验收。
