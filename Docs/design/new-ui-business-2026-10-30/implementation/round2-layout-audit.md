# 第二轮全量布局核对与补齐（2026-10-30）

分支 `feature-newUI-5`。用户指出“还有很多页面没有改完”后重新核对：上一轮主要完成来源映射和共享主题，确实遗漏独立页面结构与私有编辑/确认面板。本轮不以有diff或用了主题作为完成依据。

## 实际修改

本轮相对于上一轮运行包又修改39个UI源码文件。全量66个生产设计来源均有代表设计PNG与对应源码的比较记录（147设计状态排除旧演示065后146状态）。这仍不是146个状态逐个运行通过。

- 账号注册、验证码、添加好友、编辑消息、个人昵称、群名/群昵称、报名、签到：补标签、灰蓝字段和稿件指定的底部操作；群发选人完成移导航，底部保留已选摘要。
- 群管理、群头像、公告列表/详情/编辑、移除确认、二维码、置顶、转发记录、文件/语音详情：按任务重新组织信息及操作，不再只继承主题；成员/申请列表保留真实权限。
- 活动详情改纵向事实行与全宽动作，报名/签到结果改独立结果构图；俱乐部和信息页改阅读层级。
- 通话保留真实视频与状态，重排身份、网格及底部操作；输入扩展区改附件优先四列，录音改整面状态反馈，保留原按住/滑出取消行为。
- 设置退出、注销动作移底部；投诉原因先于证据，白画布与灰蓝输入面区分。

## 独立复核及修正

独立源码/设计审阅发现并关闭：视频小窗进入顶部不安全区域、公告详情操作仍跟随长正文、签到漏交互收键盘、录音可见麦克风与100×100实际触区错位、投诉画布/输入同色。整合者进一步核对真实token值，将签到/报名字段从白色ClubTheme.background改为灰蓝ClubTheme.wash；实际Mac截图显示信息页完成按钮对比不足，已用明确品牌色plain文字修正信息/设置完成。原权限、禁用条件、确认、草稿及提交回调保留。

9组首批受影响专项及后续通话/公告/设置/群发/录音/投诉/账户生命周期专项均按变更范围通过；语法解析和diff检查通过。107组全套是上轮证据，本轮不重复冒领。整合构建、运行包hash与最终截图见下方最终验证记录。

## 明确保留的差异

真实数据、群角色、候补/已参加状态、服务端类别与原生地图/网页验证/相机相册/媒体浏览/菜单确认保持。未增加模拟数据、虚构发送成功、页面图中不存在于产品的筛选能力。聊天扩展工具保留原可见性及typing/stickers/voice模式，没有为了画面上的加号引入新的展开状态。群名称仍沿原校验，未因稿件示例“30字”新增业务限制；昵称的原30限制保留。

## 全来源登记

下表是代表PNG/源码核对登记，不代表全部分支运行验收。私人编辑器按其所属来源列出；共享组件更新的具体原生消费者见上方说明。

|来源|设计状态ID|本轮处理|
|---|---|---|
|LaunchScreen.storyboard|001|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|InvitationCodeView|002|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|LoginView|003, 010, 011, 003-empty, 003-busy|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|AccountRegistrationView|004|本轮调整布局/私有子视图|
|LoginVerificationSheet|005, 005-failed, 006-code|本轮调整布局/私有子视图|
|LoginCaptchaWebView|006, 006-failed|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|PasswordChangeView|007, 008, 009|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|ClubHomeView|012|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|ActivitiesScreen|013, 121|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|ActivityDetailScreen|014, 025, 014-wait, 014-joined|本轮调整布局/私有子视图|
|RegistrationScreen|015|本轮调整布局/私有子视图|
|RegistrationResultScreen|016, 017|本轮调整布局/私有子视图|
|RecordsScreen|018, 019, 020, 021|本轮调整布局/私有子视图|
|CheckInSelectionScreen|022|本轮调整布局/私有子视图|
|CheckInScreen|023, 024, 023-error|本轮调整布局/私有子视图|
|ClubScreen|026|本轮调整布局/私有子视图|
|InformationSheet|027|本轮调整布局/私有子视图|
|MessageView|028|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|GlobalSearchView|029, 111|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|ChatRoomView|030, 031, 034, 035, 115, 030-failed|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|ChatMediaComposer|032|本轮调整布局/私有子视图|
|ChatVoiceRecordingMeter|033, 033-cancel|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|ChatMessageEditorView|036|本轮调整布局/私有子视图|
|ChatMentionPickerView|037|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|ChatHistorySearchView|038|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|ChatForwardRecipientView|039, 040|本轮调整布局/私有子视图|
|ChatForwardRecordView|041|本轮调整布局/私有子视图|
|ChatPinnedMessagesView|042|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|ChatPinActionView|043|本轮调整布局/私有子视图|
|ChatStickersView|044|本轮调整布局/私有子视图|
|ChatPhotoBrowserView|045, 046, 114|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|ChatMediaDetailView|047, 048|本轮调整布局/私有子视图|
|ChatLocationDetailView|049|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|ChatSettingsView|050, 066, 077, 078, 084, 085, 116, 119, 066-member, 066-owner|本轮调整布局/私有子视图|
|ContactsView|051, 052|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|AddFriendView|053, 054|本轮调整布局/私有子视图|
|NewFriendsView|055|本轮调整布局/私有子视图|
|ContactRecordDetailView|056, 057, 056-stranger, 056-blocked|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|ContactRemarkEditor|058, 118, 058-error|本轮正向确认工具栏样式调整|
|FriendGroupManagerView|059|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|FriendGroupNameEditor|060|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|ContactGroupPicker|061|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|BusinessQRCodeView|062, 079|本轮调整布局/私有子视图|
|BusinessQRScannerView|063|本轮调整布局/私有子视图|
|ContactsRecipientPickerView|064|本轮正向确认工具栏样式调整|
|GroupMemberPickerView|067, 068, 069|本轮正向确认工具栏样式调整|
|ChatGroupMembersView|070, 074, 075|本轮调整布局/私有子视图|
|ChatGroupRemovalView|071, 072|本轮调整布局/私有子视图|
|ChatGroupManagementView|073, 113, 120|本轮调整布局/私有子视图|
|ChatGroupAvatarView|076|本轮调整布局/私有子视图|
|ChatGroupNoticesView|080, 081, 082|本轮调整布局/私有子视图|
|GroupApplicationsView|083, 083-pending|本轮调整布局/私有子视图|
|CallRoomView|086, 087, 088, 089, 087-wait|本轮调整布局/私有子视图|
|CallMemberSelectionView|090|本轮正向确认工具栏样式调整|
|MassMessageView|091, 091-accepted|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|MassMessageComposerView|092, 095, 092-error, 092-attachment|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|MassMessageRecipientPicker|093|本轮调整布局/私有子视图|
|MassMessageRecipientsView|094, 094-failed|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|MineView|096, 108|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|MineProfileView|097, 098, 099, 100|本轮调整布局/私有子视图|
|SettingsScreen|101, 107|本轮调整布局/私有子视图|
|BlacklistView|102, 112, 117|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|ComplaintView|103, 104, 103-ready, 103-busy, 103-error|本轮调整布局/私有子视图|
|DeleteAccountScreen|105, 106, 105-ready|本轮调整布局/私有子视图|
|LegalDocumentScreen / RemoteLegalPage|109, 110|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|
|LaunchWaitingView|001-wait|图/源码复核后保留结构（原生容器、既有布局或已修改组件）|

## 运行证据与限制

最新页面在Mac Designed for iPhone实际App检查，非静态设计网页。截图目录 `/tmp/ddlNew-newUI-5-round2-runtime/`：053添加好友、062二维码、097个人资料、098昵称、026俱乐部、027信息页。前六张来自首批整合包，027显示的完成按钮对比问题已在后续修正，不能把该旧图当修正后证据。

iPhone本轮返回黑屏/自动化连接失效，用户解锁后仍无法获取可用快照；不能把上一轮iPhone截图当本轮验收。完整最大字号、深色、键盘、实时视频、录音发送、验证码及所有服务端提交未运行穷尽；未主动发送、邀请、报名、注销或改密来制造设计状态。


## 最终验证记录

- 最终签名Debug构建exit0、`BUILD SUCCEEDED`：`/tmp/ddlNew-newUI-5-round2-final-acceptance-build.log`。
- 最终`ddlNew.debug.dylib` SHA256：`1c84cdf487ab9ae24d8e38333becb88c5cdf7cc3c22fd9062f1fea42b2b09b12`。Mobile MCP回执确认此包覆盖安装并启动到既有iPhone；截图通道仍黑屏，安装/启动回执不等于真机视觉通过。
- Mac实际运行包先后为`685c5c33…`及`18fc66b9…`。后者确认信息/设置完成按钮改普通右侧位置后的可读性，`101-settings-final.png`为实际最终设置画面。随后相同正向工具栏修正扩展6文件，已独立源码复核、parse、整合构建通过；这6处未再次逐个运行。
- 独立视觉复核直接看7张Mac实际截图：053添加、097资料、098昵称、026俱乐部、103投诉、105注销、101设置，所见区域无确认阻断。另实际看062二维码及027信息页；旧027、101-settings-verified是问题过程图，不是修正后证据。
- 投诉邮箱由AX聚焦后实际滚入可见，截图`103-complaint-email-focus.png`；未输入或提交。滚轮/拖动未观察到变化，不据此冒报所有滚动手势通过。
- 最终39源增量由快照与当前源码核对，业务Stores/Services/Models/ViewModels/Network/SDK与App根部启动无净修改，`git diff --check`通过；未commit/push。
- 详细核对见[设计审计](round2-design-review.md)、[源码复核](round2-code-review.md)、[逐源改动与测试](round2-changes.md)、[实际视觉复核](round2-runtime-visual-review.md)。这些记录分别保留证据边界，不以单一“完成”混写。


### 聊天底部工具区补正

用户实测指出工具区布局不正确：附件常驻两排并叠加在语音/表情上，先前作为保留差异的判断不成立。现按设计补“＋”收起/展开，并按用户最新要求放在左侧；语音/发送在右侧。仅 `ChatMediaComposer.swift` 的展示状态和布局变化，业务处理与权限保留。最终构建通过、三组既有专项通过、Mac实际面板切换验证通过；最终包已装到iPhone，手机键盘与安全区仍需人工验收。详细证据见 PROJECT_HANDOFF 的同日聊天底部工具区修复条目。
