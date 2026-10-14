# 消息与通讯录 UI / 交互对齐记录

日期：2026-10-14。首轮基线：`feature-message-4 / ced0440`；主题色修正接手提交：`89cc7a4`，接手时工作区干净。后续修正未提交或推送。最新完整用户要求、代码边界和验收见 [本次会话交接](SESSION_HANDOFF_2026-10-14_MESSAGES_CONTACTS_UI.md)。

## 设计与实现

按用户指定的 ui-ux-pro-max 对照只读 xgd 源码，覆盖30个在用页面文件及相关组件。主列表、二级资料、编辑表单、群管理、记录/媒体、转发和二维码沿同一视觉与交互体系调整。

- 中性浅灰背景、白色分区、圆形头像、紧凑标题、平铺名单、下划线分类。按用户后续要求，品牌强调复用首页／我的底栏的 `HomeTheme.forest`（浅色 `285B43`／深色 `AED5B5`）；按钮、选中态、发送气泡及导航同步，头像衬底／边框复用 `HomeTheme.mintSurface`／`HomeTheme.border`，不再定义独立紫蓝品牌色。
- 使用项目现有 UIAdapter `.zoom()` 适配头像、间距、圆角和行高。其锁定源码默认按 iPhone 屏幕短边/375 缩放，iPad保持原尺寸；布局宽度和辅助字号分支仍由SwiftUI响应。正文保留系统Dynamic Type，触点至少44pt。
- `MessagingPageChrome` 统一二级导航、安全区与返回；底栏由每个Tab的 `ActivityNavigationScope` 根据实际path统一显隐。聊天和资料沿已有真实Store和SDK身份边界操作。
- 消息行点击、双侧滑动、长按菜单、草稿/未读/免打扰/置顶状态保留；聊天头像可看资料，群头像菜单可提及作者；输入区常驻工具、表情入口、附件收拢、明确收起键盘。
- 添加好友账号行点击二维码、长按复制；资料备注行点击编辑、右上好友管理；分组添加/改名/删除、拖动与菜单排序。
- 群设置按旧版重排成员网格与资料、独立名称/昵称编辑、公告管理、清空/退出；选人显示头像/已选状态、上限和审核理由。
- 转发选人分最近/好友/群，确认后提交；过滤隐藏的已选对象仍参与发送。逐对象回执和失败保留延续真实接口。
- 文件显示名称/大小，由用户发起下载，可取消、重试、系统打开；播放器清理及原消息失效逻辑保留。
- 公告详情编辑使用正在显示的最新快照；编辑sheet携带稳定公告身份并独立持有草稿，避免首次变成发布模式。返回保留已加载名单与详情。

## 页面覆盖

### 后续通讯录修正

- 启动与会话重置默认消息Tab；分组及消息／群资料／公告保存入口与备注保存统一可用／禁用样式。
- 二维码保存结果和进度使用Toast，扫码业务结果也用Toast；删除重新扫描入口，解析失败提示结束后自动恢复相机。
- 备注服务器确认后直接更新真实SDK好友缓存，撤销保存前资料轮次，避免即时旧profile回读覆盖新备注；随后刷新通讯录并关闭编辑页。
- 添加好友清空历史搜索和输入，离页使迟到结果失效；“用户不存在”作为无结果显示空态。
- 我的二维码移除右上更多菜单；二维码及同类过高操作按钮统一整体最小48pt，大字体自适应。
- 扫一扫直接显示相机取景，不再出现入口选择表单，相册选择保留在相机底部。
- 备注保存等待通讯录缓存刷新后关闭；读取中显式刷新补读，备注／描述与列表同步。
- 分组管理loading改Toast、移除成功状态行；前后和拖动提交真实目标ugOrder，首尾菜单边界禁用。
- 分组空名称沿用旧版“默认分组”兜底；分组管理、移动、选人同步，已重命名的默认组仍显示真实名称。
- 新朋友加载和备注保存改为AlertToast loading，不占用列表／表单内容行；备注保存失败关闭Toast、保留输入，保存期间禁止重复提交。
- 新朋友页按最新要求不在列表或Toast显示业务成功／错误文案，仅保留加载Toast和cell内申请状态；资料入口覆盖整行，系统右箭头置于操作按钮之后的cell最右侧。
- 用户资料的备注／描述都带紧贴内容的右箭头，点击打开“备注与描述”；删除底部“账号已复制”和操作成功文案，保留错误提示。
- 复制账号成功显示居中“账号已复制”Toast，2秒自动关闭，底部仍不追加状态文案。相关Toast统一使用低饱和灰绿底色：浅色为#E1E9E3、深色为#2F3C34，文字复用首页文字色，减少白色页面上的突兀感。
- 移动分组加载／提交和添加分组保存也使用Toast，父子sheet不重复展示；添加分组保存按钮始终可见，空名称／纯空格禁用，有效名称后启用。
- 群聊列表刷新按稳定ID保留已有位置，避免进入群聊更新资料后返回将该群移动至末尾；名称、头像、权限、人数仍更新，退出群移除，新群追加，切账号清空顺序。Groups离线回归已复现并修复返回排序变化。
- 创建群聊选人页分组分类移除原生Section额外顶部空白，改紧凑分组标题和整行选择按钮；标签下方留白缩小，保留默认组名、选择限制及至少44pt触点。
- 匿名实际预览：[默认分组](/Users/taobotaobo/.codex/visualizations/2026/10/14/01a137f7-e88d-7cf2-abed-77fbe6ac0645/ddlNew-legacy-ui/contacts-default-group.png)、[新朋友Toast](/Users/taobotaobo/.codex/visualizations/2026/10/14/01a137f7-e88d-7cf2-abed-77fbe6ac0645/ddlNew-legacy-ui/new-friends-toast-loading.png)、[备注保存Toast](/Users/taobotaobo/.codex/visualizations/2026/10/14/01a137f7-e88d-7cf2-abed-77fbe6ac0645/ddlNew-legacy-ui/remark-toast-saving.png)。截图使用模拟数据，失败保稿与Toast消失已在宿主操作核对。

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

- 后续主题色修正：无签名真机目标全量 `clean build` 成功，日志 `/tmp/ddlNew-theme-alignment-clean-build.log`；匿名宿主重新编译并检查浅色通讯录、深色聊天气泡；`git diff --check` 通过。本次只调整颜色，沿用前轮交互回归证据。

- 全量无签名真机目标 clean build成功，日志 `/tmp/ddlNew-legacy-ui-all-pages-clean-build.log`；补修后的最终增量build成功，日志 `/tmp/ddlNew-legacy-ui-final-rechecked-build.log`。
- 六组离线入口 Contacts / Conversations / Chat / Groups / Search / GroupApplications 全部通过。Contacts逻辑43项、分页19项、字段/部分资料合并25项；Chat32项。
- 独立只读复核关闭公告旧正文编辑问题，其余UI/交互差异未发现可确认的高/中严重业务回归。
- 匿名宿主运行生产消息/通讯录视图，以及生产ChatRoomView、ChatStore、ChatMessageBubble、ChatMediaComposer。只替换数据/SDK/图片下载和未测的导航目标，未修改生产认证。
- 主列表已检查375pt、普通/最大辅助字号、浅/深色、iPad纵向与横向；分类切换、未读筛选、点击会话/返回已操作。大字号聊天的正文、发送及收键盘按钮均在键盘上方，收键盘后草稿保留。
- 颜色计算：浅色次要文字5.21:1、深色次要文字7.49:1、修正后的森林绿主按钮/气泡浅色白字7.87:1、深色深绿文字7.71:1、红色未读白字4.79:1。免打扰角标独立固定深灰，避免深色浅灰底白字失去对比。
- 公告回归宿主：列表旧A、详情新B且置顶；编辑实际显示“编辑公告”、正文B、置顶开启，保存可用。模拟保存调用已核验目标公告ID、正文B和置顶一致；模拟失败保留草稿，取消后仍回详情B。SDK仅为匿名校验，不访问服务端。

## 验证边界

截图使用匿名夹具和图片占位，不能作为真实头像下载、消息送达、群操作或二维码后端验收。全部二级页面已编译和源码复核，尚未逐页进行最大字号/VoiceOver真机走查。真实相机、相册、录音、上传、服务器排序及权限回收仍需真机联调；当前摄像头组件没有手电接口，保留既有能力边界。iOS16完整导航/键盘与后端验收仍按迁移测试报告执行。

本轮改动不扩展已暂缓的业务范围；旧演示页面仍不接真实入口。用户已有的 `Docs/CONTACTS_MESSAGE_TASK_RESULT_REVIEW_2026-10-14.md` 保持原样。

## 主题色修正预览（当前）

- [通讯录森林绿](/Users/taobotaobo/.codex/visualizations/2026/10/14/01a137f7-e88d-7cf2-abed-77fbe6ac0645/ddlNew-legacy-ui/contacts-theme-green.png)
- [深色聊天浅绿气泡](/Users/taobotaobo/.codex/visualizations/2026/10/14/01a137f7-e88d-7cf2-abed-77fbe6ac0645/ddlNew-legacy-ui/chat-theme-green-dark.png)

## 首轮匿名布局预览（主题色修正前）

- [消息](/Users/taobotaobo/.codex/visualizations/2026/10/14/01a137f7-e88d-7cf2-abed-77fbe6ac0645/ddlNew-legacy-ui/messages.png)
- [通讯录](/Users/taobotaobo/.codex/visualizations/2026/10/14/01a137f7-e88d-7cf2-abed-77fbe6ac0645/ddlNew-legacy-ui/contacts.png)
- [聊天](/Users/taobotaobo/.codex/visualizations/2026/10/14/01a137f7-e88d-7cf2-abed-77fbe6ac0645/ddlNew-legacy-ui/chat.png)
- [通讯录深色最大辅助字号](/Users/taobotaobo/.codex/visualizations/2026/10/14/01a137f7-e88d-7cf2-abed-77fbe6ac0645/ddlNew-legacy-ui/contacts-dark-large.png)
- [聊天深色最大辅助字号与键盘](/Users/taobotaobo/.codex/visualizations/2026/10/14/01a137f7-e88d-7cf2-abed-77fbe6ac0645/ddlNew-legacy-ui/chat-dark-large-keyboard.png)
- [iPad横向](/Users/taobotaobo/.codex/visualizations/2026/10/14/01a137f7-e88d-7cf2-abed-77fbe6ac0645/ddlNew-legacy-ui/contacts-ipad-landscape.png)
- [公告最新正文编辑回归](/Users/taobotaobo/.codex/visualizations/2026/10/14/01a137f7-e88d-7cf2-abed-77fbe6ac0645/ddlNew-legacy-ui/notice-edit-latest.png)

- [公告编辑ID与保存失败回归](/Users/taobotaobo/.codex/visualizations/2026/10/14/01a137f7-e88d-7cf2-abed-77fbe6ac0645/ddlNew-legacy-ui/notice-save-identity.png)


## 最终群聊与Toast补充

群二维码更多菜单已删除；群名称 / 公告的导航栏保存使用紧凑文字按钮与启用 / 禁用色，操作加载Toast。群设置成员预览先进入成员名单，再按来源群权限push资料；成员最右箭头与管理菜单独立。资料直接沿当前栈push，避免布尔目标混入值路径重排。查找聊天记录的右侧放大镜删除。

群详情真实memberCount写回SDK群表后，仅人数变化发送群代理；创建回执合并和0缓存保护修复无需重启才显示人数的更新路径。Groups回归、Chat33项、Settings7项、Member page9项及Contacts相关检查通过；最新生产build日志`/tmp/ddlNew-final-ui-handoff-build.log`为BUILD SUCCEEDED。

新增MessagingStatusToast共享低饱和灰绿loading / 短反馈；群设置、成员、头像、管理、公告、二维码、审核及聊天 / 转发 / 查询等操作反馈移到Toast。新朋友继续不显示全局业务结果，也不弹这类提示。匿名群名称视图已实见加载与失败Toast，消失后保留草稿；成员生产视图已操作名单到资料并返回。真实群管理 / 人数和完整无障碍 / iOS16验收仍未覆盖，详见会话交接文档。
