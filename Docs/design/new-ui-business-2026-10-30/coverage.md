# 页面覆盖

基线：feature-newUI-5 / a55a32f。121个原有页面/状态与25个补充状态。不是146条独立路由。

|ID|设计状态|源页面|业务说明|
|---|---|---|---|
|001|系统启动页|LaunchScreen.storyboard|系统启动画面只展示品牌；不添加倒计时、广告或假进度。|
|002|连接俱乐部|InvitationCodeView||
|003|会员登录|LoginView|记住密码默认开启；注册入口按权限展示。|
|004|账号注册|AccountRegistrationView||
|005|图片验证码|LoginVerificationSheet|没有点击刷新图片。坏图需取消后重新登录。|
|006|交互验证|LoginCaptchaWebView|第三方验证容器；仅加载失败显示重试验证。|
|007|密码安全|PasswordChangeView||
|008|密码安全|PasswordChangeView||
|009|密码修改成功|PasswordChangeView||
|010|协议确认|LoginView||
|011|连接失败|LoginView||
|012|首页|ClubHomeView|活动为当前本地演示功能；不承诺服务端名额与通知。|
|013|活动|ActivitiesScreen||
|014|活动详情|ActivityDetailScreen||
|015|确认报名|RegistrationScreen||
|016|报名成功|RegistrationResultScreen||
|017|候补成功|RegistrationResultScreen||
|018|我的报名|RecordsScreen||
|019|候补记录|RecordsScreen||
|020|签到记录|RecordsScreen||
|021|已参加活动|RecordsScreen||
|022|选择签到活动|CheckInSelectionScreen||
|023|个人签到|CheckInScreen||
|024|签到成功|CheckInScreen||
|025|取消参与|ActivityDetailScreen||
|026|俱乐部|ClubScreen||
|027|俱乐部公告|InformationSheet||
|028|消息|MessageView|页内仅筛已加载会话名和预览；全局搜索为独立入口。|
|029|全局搜索|GlobalSearchView|好友、群聊、单聊消息、群聊消息分节；每类先3条。|
|030|单人聊天|ChatRoomView|单聊不展示发送者昵称；消息状态使用圆环、勾或失败重试。|
|031|群聊|ChatRoomView|群聊显示成员昵称；已读状态随权限展示。|
|032|聊天扩展面板|ChatMediaComposer|相册、拍摄、文件；音视频通话按能力显示。|
|033|语音录制|ChatVoiceRecordingMeter||
|034|消息多选|ChatRoomView|合并转发、逐条转发、允许时删除；零选中禁用。|
|035|消息操作|ChatRoomView||
|036|编辑消息|ChatMessageEditorView||
|037|选择@成员|ChatMentionPickerView|点击单个成员即插入@并关闭。没有所有人虚拟项。|
|038|查找聊天记录|ChatHistorySearchView|文字、图片视频、文件分类；群聊可额外选择成员。|
|039|选择转发对象|ChatForwardRecipientView||
|040|确认转发|ChatForwardRecipientView||
|041|聊天记录|ChatForwardRecordView||
|042|置顶消息|ChatPinnedMessagesView||
|043|消息置顶|ChatPinActionView|两项为独立操作；普通成员只显示个人置顶；单聊为双方置顶。|
|044|贴纸与表情|ChatStickersView|点击贴纸直接发送，无底部发送按钮。|
|045|照片预览|ChatPhotoBrowserView|全屏浏览、更多菜单；下拉或关闭回原入口，无页数及底部主按钮。|
|046|视频预览|ChatPhotoBrowserView|全屏浏览、更多菜单；下拉或关闭回原入口，无页数及底部主按钮。|
|047|文件详情|ChatMediaDetailView||
|048|语音详情|ChatMediaDetailView|正常聊天语音点击为原地播放，此处仅媒体详情入口。|
|049|位置详情|ChatLocationDetailView||
|050|聊天设置|ChatSettingsView||
|051|通讯录|ContactsView|按好友／分组／群聊当前分类搜索；全局搜索独立。|
|052|群聊列表|ContactsView||
|053|添加好友|AddFriendView||
|054|查找结果|AddFriendView||
|055|新朋友|NewFriendsView|独立通过验证和重新申请按钮；本机隐藏不拒绝申请。|
|056|用户资料|ContactRecordDetailView|备注与描述保留正文编辑；移动分组只在菜单。|
|057|好友管理|ContactRecordDetailView||
|058|备注与描述|ContactRemarkEditor|备注50、描述200 UTF-16；未改、超限或保存中禁用；失败保留草稿。|
|059|分组管理|FriendGroupManagerView|支持拖动排序、更多菜单；默认组不可删除。|
|060|编辑分组|FriendGroupNameEditor||
|061|移动分组|ContactGroupPicker||
|062|我的二维码|BusinessQRCodeView|有图片才显示保存相册与分享；失败可重新生成，示意码不可扫描。|
|063|扫一扫|BusinessQRScannerView||
|064|分享名片|ContactsRecipientPickerView||
|065|成员资料（旧演示页）|ContactDetailSheet|旧本地演示入口，非实时通讯录资料链路。|
|066|群聊设置|ChatSettingsView||
|067|创建群聊|GroupMemberPickerView||
|068|邀请群成员|GroupMemberPickerView||
|069|邀请审核说明|GroupMemberPickerView|邀请理由在成员选择器内；共用一次完成动作。|
|070|群成员|ChatGroupMembersView||
|071|移除群成员|ChatGroupRemovalView||
|072|移除成员确认|ChatGroupRemovalView||
|073|群管理|ChatGroupManagementView||
|074|成员权限操作|ChatGroupMembersView|按操作者与目标角色显示禁言、角色、移除或转让。|
|075|转让群主|ChatGroupMembersView||
|076|群头像|ChatGroupAvatarView||
|077|修改群名称|ChatSettingsView||
|078|我的群昵称|ChatSettingsView||
|079|群二维码|BusinessQRCodeView|有图片才显示保存相册与分享；失败可重新生成，示意码不可扫描。|
|080|群公告|ChatGroupNoticesView||
|081|公告详情|ChatGroupNoticesView||
|082|编辑群公告|ChatGroupNoticesView||
|083|群助手|GroupApplicationsView|全部页逐项同意/拒绝；待审核页可多选，操作前确认。|
|084|退出群聊|ChatSettingsView||
|085|解散群聊|ChatSettingsView||
|086|语音来电|CallRoomView||
|087|语音通话|CallRoomView||
|088|视频通话|CallRoomView||
|089|群通话|CallRoomView||
|090|选择通话成员|CallMemberSelectionView|已在通话成员锁定，不计入新增选择数。|
|091|群发助手|MassMessageView|已受理不等于已送达；允许时新建、再次发送。|
|092|新建群发|MassMessageComposerView|可选标签16 UTF-16；文字或单个附件二选一，失败保留草稿。 选择附件后仅发送附件；失败使用原页Toast。|
|093|群发接收对象|MassMessageRecipientPicker|最近聊天／好友／群聊；跨类保留选择，全选仅当前列表。|
|094|发送结果|MassMessageRecipientsView|全部接收对象不虚构逐个成功；失败分栏显示原因。|
|095|再次群发|MassMessageComposerView|再发时标签、接收对象均只读；仅编辑正文或附件。 选择附件后仅发送附件；失败使用原页Toast。|
|096|我的|MineView||
|097|编辑个人资料|MineProfileView|账号只读可复制；头像和昵称各自更新。|
|098|修改昵称|MineProfileView|30 UTF-16；清空、未改、超限、忙碌时不可保存。|
|099|修改头像|MineProfileView||
|100|头像裁剪|MineProfileView||
|101|设置|SettingsScreen||
|102|黑名单|BlacklistView||
|103|投诉与支持|ComplaintView|原因是菜单；证据必填。准备/提交中锁定，失败保留所有输入。|
|104|投诉提交后的反馈|ComplaintView||
|105|注销账号|DeleteAccountScreen|默认未确认注销后果；确认后才能进入二次确认。|
|106|注销确认|DeleteAccountScreen||
|107|退出登录|SettingsScreen||
|108|更换俱乐部|MineView||
|109|隐私政策|LegalDocumentScreen / RemoteLegalPage|在线文档宿主加载状态；正式正文不改写。|
|110|使用支持|LegalDocumentScreen / RemoteLegalPage|在线文档宿主加载状态；正式正文不改写。|
|111|搜索无结果|GlobalSearchView|仍在搜索原页，可直接修改关键词。|
|112|网络加载失败|BlacklistView|黑名单加载失败示例，原页提供重试。|
|113|权限发生变化|ChatGroupManagementView||
|114|原消息失效|ChatPhotoBrowserView|在全屏浏览器显示失效提示，关闭回来源。|
|115|群聊禁言|ChatRoomView||
|116|清空记录确认|ChatSettingsView||
|117|移出黑名单 · 处理中|BlacklistView||
|118|放弃编辑|ContactRemarkEditor||
|119|群聊设置 · 下半页|ChatSettingsView|长页的滚动续页|
|120|群管理 · 下半页|ChatGroupManagementView|长页的滚动续页|
|121|活动 · 筛选|ActivitiesScreen|全部、可报名、已报名、已结束；页内筛选，不是新路由。|
|003-empty|登录 · 空输入|LoginView|输入为空，登录不可用|
|003-busy|登录 · 正在提交|LoginView|同意协议后提交，避免重复登录|
|005-failed|验证码 · 图片失败|LoginVerificationSheet|取消后重新登录，不提供虚假刷新|
|006-failed|交互验证 · 失败|LoginCaptchaWebView|原验证容器内重试|
|006-code|安全码验证|LoginVerificationSheet|独立安全码分支|
|014-wait|活动 · 名额已满|ActivityDetailScreen|候补与报名分开表达|
|014-joined|活动 · 已报名|ActivityDetailScreen|主操作改为前往签到|
|023-error|签到 · 输入错误|CheckInScreen|原页保留签到码并提示|
|030-failed|单聊 · 发送失败|ChatRoomView|保留失败消息，可点重试|
|033-cancel|录音 · 松开取消|ChatVoiceRecordingMeter|滑回继续，松开取消|
|056-stranger|资料 · 非好友|ContactRecordDetailView|仅在条件允许时可申请好友|
|056-blocked|资料 · 已拉黑|ContactRecordDetailView|发消息禁用，菜单可移出黑名单|
|058-error|备注 · 保存失败|ContactRemarkEditor|草稿保留，可以重试|
|066-member|群设置 · 普通成员|ChatSettingsView|不展示群管理入口|
|066-owner|群设置 · 群主|ChatSettingsView|群主设置上半页，显示群管理入口|
|083-pending|群助手 · 待审核|GroupApplicationsView|勾选后才能批量同意或拒绝|
|087-wait|语音 · 等待接听|CallRoomView|无虚构已接通计时，可取消|
|092-error|群发 · 提交失败|MassMessageComposerView|标签、对象和正文保留 选择附件后仅发送附件；失败使用原页Toast。|
|092-attachment|群发 · 附件|MassMessageComposerView|正文与单附件互斥 选择附件后仅发送附件；失败使用原页Toast。|
|091-accepted|群发 · 已受理|MassMessageView|可刷新查询结果，不宣称送达|
|094-failed|群发 · 失败对象|MassMessageRecipientsView|仅失败列表展示服务端原因|
|103-ready|投诉 · 填写完成|ComplaintView|图片和邮箱齐全后可提交|
|103-busy|投诉 · 正在提交|ComplaintView|提交中锁定表单，避免重复|
|103-error|投诉 · 失败保留|ComplaintView|原页Toast反馈；图片、文本、邮箱均保留|
|105-ready|注销 · 已确认后果|DeleteAccountScreen|可继续二次确认，尚未注销|
|001-wait|启动等待|LaunchWaitingView|保留品牌位置，仅添加无百分比等待提示；连接及认证完成后按原逻辑跳转。|
