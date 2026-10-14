# 消息与通讯录 UI / 交互对齐记录

日期：2026-10-14。基线：`feature-message-4 / ced0440`。当前变更留在工作区，未提交或推送。

## 设计与实现

按用户指定的 ui-ux-pro-max 对照只读 xgd 源码，覆盖30个在用页面文件及相关组件。主列表、二级资料、编辑表单、群管理、记录/媒体、转发和二维码沿同一视觉与交互体系调整。

- 中性浅灰背景、白色分区、紫蓝 `5966F2` 强调、圆形头像、紧凑标题、平铺名单、下划线分类。独立配置深色配色。
- 使用项目现有 UIAdapter `.zoom()` 适配头像、间距、圆角和行高。其锁定源码默认按 iPhone 屏幕短边/375 缩放，iPad保持原尺寸；布局宽度和辅助字号分支仍由SwiftUI响应。正文保留系统Dynamic Type，触点至少44pt。
- `MessagingPageChrome` 统一二级导航、安全区、返回与隐藏底栏；聊天和资料沿已有真实Store和SDK身份边界操作。
- 消息行点击、双侧滑动、长按菜单、草稿/未读/免打扰/置顶状态保留；聊天头像可看资料，群头像菜单可提及作者；输入区常驻工具、表情入口、附件收拢、明确收起键盘。
- 添加好友账号行点击二维码、长按复制；资料备注行点击编辑、右上好友管理；分组添加/改名/删除、拖动与菜单排序。
- 群设置按旧版重排成员网格与资料、独立名称/昵称编辑、公告管理、清空/退出；选人显示头像/已选状态、上限和审核理由。
- 转发选人分最近/好友/群，确认后提交；过滤隐藏的已选对象仍参与发送。逐对象回执和失败保留延续真实接口。
- 文件显示名称/大小，由用户发起下载，可取消、重试、系统打开；播放器清理及原消息失效逻辑保留。
- 公告详情编辑使用正在显示的最新快照；编辑sheet携带稳定公告身份并独立持有草稿，避免首次变成发布模式。返回保留已加载名单与详情。

## 页面覆盖

- [ChatForwardRecipientView](../ddlNew/Features/Chat/Views/ChatForwardRecipientView.swift)
- [ChatForwardRecordView](../ddlNew/Features/Chat/Views/ChatForwardRecordView.swift)
- [ChatGroupAvatarView](../ddlNew/Features/Chat/Views/ChatGroupAvatarView.swift)
- [ChatGroupManagementView](../ddlNew/Features/Chat/Views/ChatGroupManagementView.swift)
- [ChatGroupMembersView](../ddlNew/Features/Chat/Views/ChatGroupMembersView.swift)
- [ChatGroupNoticesView](../ddlNew/Features/Chat/Views/ChatGroupNoticesView.swift)
- [ChatHistorySearchView](../ddlNew/Features/Chat/Views/ChatHistorySearchView.swift)
- [ChatLocationDetailView](../ddlNew/Features/Chat/Views/ChatLocationDetailView.swift)
- [ChatMediaDetailView](../ddlNew/Features/Chat/Views/ChatMediaDetailView.swift)
- [ChatMessageEditorView](../ddlNew/Features/Chat/Views/ChatMessageEditorView.swift)
- [ChatPinActionView](../ddlNew/Features/Chat/Views/ChatPinActionView.swift)
- [ChatPinnedMessagesView](../ddlNew/Features/Chat/Views/ChatPinnedMessagesView.swift)
- [ChatRoomView](../ddlNew/Features/Chat/Views/ChatRoomView.swift)
- [ChatSettingsView](../ddlNew/Features/Chat/Views/ChatSettingsView.swift)
- [ChatStickersView](../ddlNew/Features/Chat/Views/ChatStickersView.swift)
- [AddFriendView](../ddlNew/Features/Contacts/Views/AddFriendView.swift)
- [BusinessQRCodeView](../ddlNew/Features/Contacts/Views/BusinessQRCodeView.swift)
- [BusinessQRScannerView](../ddlNew/Features/Contacts/Views/BusinessQRScannerView.swift)
- [ContactGroupPicker](../ddlNew/Features/Contacts/Views/ContactGroupPicker.swift)
- [ContactRecordDetailView](../ddlNew/Features/Contacts/Views/ContactRecordDetailView.swift)
- [ContactRemarkEditor](../ddlNew/Features/Contacts/Views/ContactRemarkEditor.swift)
- [ContactsRecipientPickerView](../ddlNew/Features/Contacts/Views/ContactsRecipientPickerView.swift)
- [ContactsView](../ddlNew/Features/Contacts/Views/ContactsView.swift)
- [FriendGroupManagerView](../ddlNew/Features/Contacts/Views/FriendGroupManagerView.swift)
- [FriendGroupNameEditor](../ddlNew/Features/Contacts/Views/FriendGroupNameEditor.swift)
- [NewFriendsView](../ddlNew/Features/Contacts/Views/NewFriendsView.swift)
- [GroupApplicationsView](../ddlNew/Features/GroupApplications/Views/GroupApplicationsView.swift)
- [GroupMemberPickerView](../ddlNew/Features/Groups/Views/GroupMemberPickerView.swift)
- [MessageView](../ddlNew/Features/Message/Views/MessageView.swift)
- [GlobalSearchView](../ddlNew/Features/Search/Views/GlobalSearchView.swift)

## 旧项目参考

旧项目根目录 `/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk`：

- Tab：`CandyTalkHomeViewController.m`、`CandyTalkContactVC.m`；Session：`NoaSessionCell.m`、`NoaSessionTopView.m`。
- ContactsModule：`NoaContactHeaderView.m`、`NoaContactListTableCell.m`、`NoaAddFriendVC`、`NoaUserHomePageVC`、`NoaFriendManageVC`、`NoaFriendGroupManagerVC`、`NoaGlobalSearchVC`。
- ChatModule：`NoaChatInputFunctionView`、`NoaBubbleSendView`、`NoaChatGroupSetVC`、`NoaChatSetGroupInfoCell`、`NoaGroupManageVC`、`NoaGroupMemberListVC`、`NoaGroupInviteFriendVC`、`NoaGroupNoticeDetailVC`、`NoaSystemMessageVC`。
- 二级流程：`NoaChatHistoryVC`、`NoaChatFileDetailViewController`、`NoaMessageForwardTipView`、`ZGroupTopMessageListViewController`、`NoaMyQRCodeViewController`、`NoaQRcodeScanViewController`。

## 已验证

- 全量无签名真机目标 clean build成功，日志 `/tmp/ddlNew-legacy-ui-all-pages-clean-build.log`；补修后的最终增量build成功，日志 `/tmp/ddlNew-legacy-ui-final-rechecked-build.log`。
- 六组离线入口 Contacts / Conversations / Chat / Groups / Search / GroupApplications 全部通过。Contacts逻辑43项、分页19项、字段/部分资料合并25项；Chat32项。
- 独立只读复核关闭公告旧正文编辑问题，其余UI/交互差异未发现可确认的高/中严重业务回归。
- 匿名宿主运行生产消息/通讯录视图，以及生产ChatRoomView、ChatStore、ChatMessageBubble、ChatMediaComposer。只替换数据/SDK/图片下载和未测的导航目标，未修改生产认证。
- 主列表已检查375pt、普通/最大辅助字号、浅/深色、iPad纵向与横向；分类切换、未读筛选、点击会话/返回已操作。大字号聊天的正文、发送及收键盘按钮均在键盘上方，收键盘后草稿保留。
- 颜色计算：浅色次要文字5.21:1、深色次要文字7.49:1、主按钮/气泡白字浅色4.56:1/深色5.51:1、红色未读白字4.79:1。免打扰角标独立固定深灰，避免深色浅灰底白字失去对比。
- 公告回归宿主：列表旧A、详情新B且置顶；编辑实际显示“编辑公告”、正文B、置顶开启，保存可用。模拟保存调用已核验目标公告ID、正文B和置顶一致；模拟失败保留草稿，取消后仍回详情B。SDK仅为匿名校验，不访问服务端。

## 验证边界

截图使用匿名夹具和图片占位，不能作为真实头像下载、消息送达、群操作或二维码后端验收。全部二级页面已编译和源码复核，尚未逐页进行最大字号/VoiceOver真机走查。真实相机、相册、录音、上传、服务器排序及权限回收仍需真机联调；当前摄像头组件没有手电接口，保留既有能力边界。iOS16完整导航/键盘与后端验收仍按迁移测试报告执行。

本轮改动不扩展已暂缓的业务范围；旧演示页面仍不接真实入口。用户已有的 `Docs/CONTACTS_MESSAGE_TASK_RESULT_REVIEW_2026-10-14.md` 保持原样。

## 匿名布局预览

- [消息](/Users/taobotaobo/.codex/visualizations/2026/10/14/01a137f7-e88d-7cf2-abed-77fbe6ac0645/ddlNew-legacy-ui/messages.png)
- [通讯录](/Users/taobotaobo/.codex/visualizations/2026/10/14/01a137f7-e88d-7cf2-abed-77fbe6ac0645/ddlNew-legacy-ui/contacts.png)
- [聊天](/Users/taobotaobo/.codex/visualizations/2026/10/14/01a137f7-e88d-7cf2-abed-77fbe6ac0645/ddlNew-legacy-ui/chat.png)
- [通讯录深色最大辅助字号](/Users/taobotaobo/.codex/visualizations/2026/10/14/01a137f7-e88d-7cf2-abed-77fbe6ac0645/ddlNew-legacy-ui/contacts-dark-large.png)
- [聊天深色最大辅助字号与键盘](/Users/taobotaobo/.codex/visualizations/2026/10/14/01a137f7-e88d-7cf2-abed-77fbe6ac0645/ddlNew-legacy-ui/chat-dark-large-keyboard.png)
- [iPad横向](/Users/taobotaobo/.codex/visualizations/2026/10/14/01a137f7-e88d-7cf2-abed-77fbe6ac0645/ddlNew-legacy-ui/contacts-ipad-landscape.png)
- [公告最新正文编辑回归](/Users/taobotaobo/.codex/visualizations/2026/10/14/01a137f7-e88d-7cf2-abed-77fbe6ac0645/ddlNew-legacy-ui/notice-edit-latest.png)

- [公告编辑ID与保存失败回归](/Users/taobotaobo/.codex/visualizations/2026/10/14/01a137f7-e88d-7cf2-abed-77fbe6ac0645/ddlNew-legacy-ui/notice-save-identity.png)
