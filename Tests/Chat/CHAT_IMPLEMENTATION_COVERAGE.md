# Chat 实现覆盖与验证边界

2026-10-13，`feature-message-4` 当前工作树；Chat 开发已冻结，等待根代理最后构建及独立审查。此表记录实际接线，不表示真实后端或双端验收已通过。

路径缩写：`F` = `ddlNew/Features/Chat`，`N` = `ddlNew/Network/IM/Chat`。根负责 Tabbar、LoginSessionService、系统配置、共享媒体 codec/cloud provider 和群申请；通讯录代理负责好友/群共享 Store、二维码与选人器。

| ID | 实现文件 | 已接子能力/边界 |
|---|---|---|
| CHAT-001 | F/Models/ChatRoute.swift, F/Services/ChatRuntime.swift, F/Views/ChatRoomView.swift, N/SDKChatClient.swift | 根 AUTH 提供 UID/tenant/session；稳定路由、来源群守卫；沿每 Tab NavigationStack；不新认证 |
| CHAT-002 | F/Services/ChatStore.swift, N/SDKChatClient.swift, N/SDKChatMessageMapper.swift | 本地缓存先显、服务100分页、双ID边界去重、清空版本屏障；无进展停止 |
| CHAT-003 | F/Views/ChatRoomView.swift, F/Services/ChatStore.swift | 首屏最新、补页保持锚点、新消息计数、双ID locate 补页高亮；AX最大字号首屏已由独立宿主复验 |
| CHAT-004 | N/SDKChatDelegate.swift, F/Models/ChatMessageMerge.swift, F/Services/ChatStore.swift | 真SDK消息/状态事件、双ID合并、删除墓碑、ACK与历史竞态隔离 |
| CHAT-005 | N/SDKChatClient.swift, F/Models/ChatACKNormalizer.swift, F/Services/ChatStore.swift | SDK真实落库后入队、sending/sent/failed；ackMsgId关联原条，ACK服务时间；无服务ID不成功 |
| CHAT-006 | F/Models/ChatFailureReason.swift, N/SDKChatMessageMapper.swift, F/Services/ChatStore.swift | SDK失败分类、人为重发原ID、成功后迟到失败无效；SDK自动重试本轮保留既有实现 |
| CHAT-007 | F/Services/ChatStore.swift, N/SDKChatClient.swift, F/Media/ChatMediaPreviewStore.swift, F/Components/ChatMessageBubble.swift | 当前视口2秒合批、实际播语音才读、后台/身份守卫；SDK读人数不伪造；showUserRead控制提示 |
| CHAT-008 | F/Views/ChatRoomView.swift, F/Components/ChatMessageBubble.swift, N/SDKChatMessageMapper.swift | 首条/跨日分隔、服务器时间、方向/名称/头像/状态/未知降级 |
| CHAT-009 | F/Services/ChatStore.swift, F/Models/ChatDraft.swift, N/SDKChatClient.swift | Unicode正文、真实敏感词替换、失败保输入、SDK draftDict恢复正文/引用/@；设置往返保草稿 |
| CHAT-010 | F/Models/ChatMentionSegment.swift, F/Services/ChatStore.swift, F/Views/ChatRoomView.swift, N/SDKChatClient.swift | UID片段、同名隔离、@所有人、整片段删除、UTF16移动、草稿恢复；普通禁止私聊群不开放@入口；过滤不改UID |
| CHAT-011 | F/Media/ChatVoiceRecorder.swift, F/Components/ChatMediaComposer.swift, F/Media/ChatMediaStore.swift, F/Media/ChatMediaPreviewStore.swift, F/Views/ChatMediaDetailView.swift | 麦克风授权、60秒停录、显式发送/取消、太短拒绝、真实上传、播放/听筒、系统中断、实际播放已读 |
| CHAT-012 | F/Components/ChatMediaComposer.swift, F/Media/ChatCameraPicker.swift, F/Media/ChatAttachmentPreparation.swift, F/Media/ChatPickedMovie.swift, N/SDKChatMediaClient.swift | PhotosPicker最多9、相机照片视频、原图/GIF、方向处理、旧大图转文件、视频真封面、进度/取消；云client与codec由根提供 |
| CHAT-013 | F/Media/ChatAttachmentPreparation.swift, F/Media/ChatMediaPreviewStore.swift, F/Views/ChatMediaDetailView.swift, F/Media/ChatFilePreview.swift, N/SDKChatMediaClient.swift | 安全书签复制、真实上传下载、原文件名/旧MIME类型、QuickLook/分享打开、账号/会话缓存分区 |
| CHAT-014 | F/Models/ChatSticker.swift, F/Services/ChatStickersStore.swift, F/Views/ChatStickersView.swift, N/SDKChatStickersClient.swift, N/SDKChatClient.swift, N/SDKChatMessageMapper.swift | 已用包/已有收藏查询、20分页去重、type12真SDK发送、静态/GIF真实资源、游戏历史实际type/result；商城/新游戏入口未做 |
| CHAT-015 | F/Services/ChatShareService.swift, N/SDKChatMessageMapper.swift, F/Views/ChatRoomView.swift, F/Views/ChatForwardRecordView.swift | recommend真实接口、cardUID资料路由及来源群上下文；资料收件人选择由Contacts实现 |
| CHAT-016 | N/SDKChatMessageMapper.swift, F/Views/ChatLocationDetailView.swift, F/Views/ChatRoomView.swift | 历史经纬度校验/地图/用户主动系统地图；未申请位置或新增位置发送 |
| CHAT-017 | N/SDKChatMessageMapper.swift, F/Views/ChatForwardRecordView.swift | 真实合并消息一层记录、作者/媒体/名片/位置可达；深层合并不递归；内层无转发/收藏/分享操作 |
| CHAT-018 | F/Models/ChatPermission.swift, F/Models/ChatActionPolicy.swift, F/Services/ChatStore.swift, N/SDKChatClient.swift, N/SDKChatMediaClient.swift | 服务端群身份/个人及全员禁言、0普通频控/1与2豁免、图片视频与文件独立上传权限和MB配额、发送时二次校验 |
| CHAT-019 | F/Models/ChatActionPolicy.swift, F/Views/ChatRoomView.swift, F/Components/ChatMessageBubble.swift | 当前菜单矩阵、原文复制、HTTP链接用户主动打开；未接独立翻译/链接收藏 |
| CHAT-020 | F/Services/ChatStore.swift, F/Components/ChatMessageBubble.swift, F/Views/ChatRoomView.swift, N/SDKChatClient.swift | 支持类型引用serviceID、草稿取消/恢复、原文实时摘要、编辑/删除/撤回占位、点击补页定位 |
| CHAT-021 | F/Services/ChatStore.swift, F/Views/ChatRoomView.swift, F/Models/ChatActionPolicy.swift, N/SDKChatClient.swift | 单条/多选确认、one/both范围、remoteDelete权限、真msgIdList、失败本地删、逐条部分失败保选择/明细；群1/2双向他人沿旧6668-6735矩阵 |
| CHAT-022 | F/Models/ChatActionPolicy.swift, N/SDKChatClient.swift, F/Services/ChatStore.swift | 本人分钟窗口>0、管理他人独立开关和同角色/群主保护；scalar false拒绝；占位/引用同步 |
| CHAT-023 | F/Views/ChatMessageEditorView.swift, N/SDKChatActionsClient.swift, F/Models/ChatMentionSegment.swift | 独立编辑草稿、本人text/@、分钟及禁言复核、保持UID片段/双ID/原时间/读数、真protobuf回执、dirty取消确认 |
| CHAT-024 | F/Services/ChatStore.swift, F/Models/ChatActionPolicy.swift, F/Views/ChatRoomView.swift | 100上限、稳定ID、未知/公告/合并/通话等禁多选、取消无发送删除 |
| CHAT-025 | F/Views/ChatForwardRecipientView.swift, N/SDKChatActionsClient.swift | 稳定收件人UID、时间排序、真实preflight、逐对象结果、逐条真服务ID、merged count1且标入队待ACK；引用清除 |
| CHAT-026 | 无 | 明确暂缓：消息收藏/保存链接模块 |
| CHAT-027 | 无 | 明确暂缓：翻译配置/扣费外部服务 |
| CHAT-028 | F/Views/ChatPinActionView.swift, F/Views/ChatPinnedMessagesView.swift, F/Views/ChatRoomView.swift, N/SDKChatActionsClient.swift, F/Models/ChatPinStatus.swift | 真type0..3状态、个人/全局范围、真pin列表/顶部条、原文双ID定位、删/撤回过滤、事件后重查 |
| CHAT-029 | 无 | 明确暂缓：定时自动删除 |
| CHAT-030 | F/Views/ChatSettingsView.swift, F/Services/ChatSettingsStore.swift, N/SDKChatSettingsClient.swift | 单聊置顶/免打扰、好友资料、async选人成群、真实清空及缓存；文件助手无免打扰 |
| CHAT-031 | F/Views/ChatHistorySearchView.swift, F/Services/ChatHistorySearchStore.swift, N/SDKChatHistorySearchClient.swift | 全SDK本地缓存文字/媒体/文件分类、50结果游标、字面关键字、真成员过滤、closeSearchUser守卫、原条定位 |
| CHAT-032 | F/Views/ChatMediaDetailView.swift, F/Media/ChatMediaPreviewStore.swift, F/Media/ChatFilePreview.swift | 真下载、旧XOR/AES解码、独立缓存、系统打开/分享、视频音频退出暂停、VO等价打开动作 |
| CHAT-033 | F/Views/ChatSettingsView.swift, F/Services/ChatSettingsStore.swift, N/SDKChatSettingsClient.swift, F/Models/ChatGroupAction.swift | 真详情、0/1/2独立矩阵、服务端每次提交复核、角色事件回读/群失效关闭；未确认role3禁提交 |
| CHAT-034 | F/Views/ChatGroupAvatarView.swift, F/Views/ChatSettingsView.swift, N/SDKChatSettingsClient.swift, N/SDKChatMediaClient.swift | 群头像显示/照片上传101、前后真实角色校验、原值保留、真改名；成功同步SDK群/会话名称头像；根codec/cloud支持101 |
| CHAT-035 | F/Views/ChatGroupMembersView.swift, F/Views/ChatSettingsView.swift, N/SDKChatSettingsClient.swift | 真成员100分页去重、人数独立角色开关、搜索、私聊资料guard、ContactsRoute携来源groupID |
| CHAT-036 | F/Views/ChatSettingsView.swift, F/Services/ChatSettingsStore.swift, N/SDKChatSettingsClient.swift, N/SDKChatMessageMapper.swift | 本人群昵称旧UTF16最多30、空用本人名、真接口；remark→群昵称→nickname优先；事件回读 |
| CHAT-037 | F/Views/ChatSettingsView.swift, F/Models/ChatGroupAction.swift, N/SDKChatSettingsClient.swift | 真好友选择/排除群已有成员、去重/禁失效、审核说明inviteDesc、async回执成功才关闭/失败留选择 |
| CHAT-038 | F/Views/ChatGroupMembersView.swift, N/SDKChatSettingsClient.swift, F/Services/ChatRuntime.swift, F/Services/ChatStore.swift | 目标角色复核、显式delMemberMsg勾选、真实移除、SDK成员/其消息清理、打开聊天墓碑同步、错误在当前页可见 |
| CHAT-039 | F/Views/ChatGroupManagementView.swift, F/Models/ChatGroupAction.swift, N/SDKChatSettingsClient.swift | 已批准逐项策略/禁言/成员/申请管理；机器人/活跃见047全部暂缓，已移除对应新增文件/入口 |
| CHAT-040 | F/Views/ChatGroupMembersView.swift, F/Views/ChatGroupManagementView.swift, N/SDKChatSettingsClient.swift | 全员、7档真实分钟/永久-1、解除0、目标角色保护、操作前后服务端校验/回读 |
| CHAT-041 | F/Views/ChatGroupManagementView.swift；根Features/GroupApplications | 已接群申请路由；真分页/审核/事件实现归根，不在Chat重复请求 |
| CHAT-042 | F/Views/ChatGroupMembersView.swift, F/Models/ChatGroupAction.swift, N/SDKChatSettingsClient.swift | 仅当前群主设置/撤销管理和转让、目标有效/不是本人群主、明确确认、真接口回读；失败不退出 |
| CHAT-043 | F/Views/ChatGroupManagementView.swift, N/SDKChatSettingsClient.swift, N/SDKChatClient.swift | 私聊/邀请审核String、历史/提示/二维码/禁止音视频Number独立真接口；根SDK群缓存同步私聊guard；无通话发起 |
| CHAT-044 | F/Views/ChatGroupNoticesView.swift, F/Services/ChatNoticesStore.swift, N/SDKChatNoticesClient.swift, F/Views/ChatRoomView.swift | 真20分页/详情checkOne/已读/创建编辑删除、旧isTop/isSendMsg、普通读/1与2写、dirty输入保护、顶部公告；翻译暂缓 |
| CHAT-045 | F/Views/ChatSettingsView.swift, F/Services/ChatSettingsStore.swift, N/SDKChatSettingsClient.swift | 非群主退出、群主转让前置/解散确认、服务端成功后SDK群/消息/缓存及runtime清理 |
| CHAT-046 | 无 | 明确暂缓：音视频发起/LiveKit/Zego依赖 |
| CHAT-047 | 无 | 明确暂缓：机器人只读及活跃等级，未绕入039实施 |
| CHAT-048 | N/SDKChatDelegate.swift, N/SDKChatClient.swift, N/SDKChatSettingsClient.swift, F/Services/ChatStore.swift, F/Services/ChatSettingsStore.swift | SDK业务事件分流、真群权限资料回读、忙时角色事件待回读、双ID原文更新、已读/名称/成员回流、context/generation隔离 |
| CHAT-049 | F/Models/ChatMessageRecord.swift, N/SDKChatMessageMapper.swift, F/Services/ChatRuntime.swift, F/Media/ChatMediaPreviewStore.swift | 未知/不兼容占位、保原SDK记录/加密/阅后/版本字段、UID+tenant+session观察/等待隔离、根退出媒体/录音/下载清理；加密/阅后发起未做 |

## 离线证据

- `sh Tests/Chat/run-checks.sh`：21项生产ChatStore/merge/ACK/已读/部分删除/独立文件权限/成员历史删除/昵称保正文回归通过。
- `sh Tests/Chat/run-group-checks.sh`：14项生产角色、目标、邀请/禁言合同/普通5名管理4名预览回归通过。
- `sh Tests/Chat/run-settings-checks.sh`：7项生产Store成败Bool回执、UTF16上限、头像子页保留权限/可提交及父页退出隔离通过。
- `sh Tests/Chat/run-media-checks.sh`：4项大小/取消/录音界限/MB溢出回归通过。
- `sh Tests/Chat/run-mention-checks.sh`：3项重名UID、片段编辑和敏感过滤UID保护通过。
- `sh Tests/Chat/run-sticker-checks.sh`：3项生产Store分页去重和迟到隔离通过。
- 独立QA `Tests/MigrationAcceptance/run-chat-checks.sh` 最近已观察16/16；归独立QA所有，未修改预期。
- 全Chat Swift文件`swiftc -frontend -parse`及`git diff --check`通过；完整Xcode构建、SDKSwift签名和设备安装由根统一执行，不以此语法检查替代构建。
- 新增Settings回执、群重复邀请/role3/禁言分钟和敏感UID测试有实际先失败再实现证据；后加已读/多选删除/贴纸项为回归补充，不宣称全部首次测试都先红。

## 尚待真实后端/双端验证

未登录或操作后端账号、未对外发消息。AUTH后首屏/离线重启draftDict、SDK自动ACK重试与HTTP兜底、另一端收发/读数/删除撤回编辑pin、成员/昵称/权限另端回流、群邀请待审核部分结果、服务器公告字段、所有真实云STS/上传/解码、系统麦克风路由与摄像头、VoiceOver实际朗读，均需根安排真实账号和设备验收。已编译的真实方法及离线状态机证明接线，不证明这些场景成功。

## 已知实现风险与范围

暂未发现仍需占位补齐的已批准核心页面入口；最终独立审查可能定位新的具体缺陷。聊天首屏采用VStack解决最大字号Lazy估算空白，深历史连续补页渲染成本需要真实设备长历史评估。媒体原图/视频工作量受实际资源影响；网络图片与云SDK不在隔离UI宿主的验证范围。暂缓026/027/029/046/047及014商城、016新位置、049加密/阅后发起全部保持未实施。


## 最终独立审查修正（7项缺陷 + 3项已批准子能力）

2026-10-13审查后的这批变更由Chat实现，QR/转发已读/管理员他人撤回3项由根协助；既有GIF和键盘收起由UI代理完成，未覆盖其修改。

| 审查项 | 实际修正与文件 | 离线/构建证据 |
|---|---|---|
| 1 个人禁言仅upsert，旧groupMute不失效 | N/SDKChatDelegate.swift从真实model.serverMessage识别221个人禁言；F/Models/ChatGroupEventPolicy.swift产生permissionsChanged；N/SDKChatClient.swift立即清旧权限缓存并真实回读 | ReviewSemantic协议用例先红后绿；真实SwiftSDK桥接签名已通过签名build2 |
| 2 他端移除/删除成员历史仍显示 | 原SDKGroupDeleteMemberHistoryNotification的gid/deleteMemberUidList及KickGroupMessage204.msgDel→memberHistoryDeleted；Runtime失效内容轮次/清该会话媒体、已打开被删作者预览停播/停下载且禁重试，Store保墓碑、清选择/待读并即时同步引用；旧等待页不能回写SDK | 生产Store新增他端删除/迟到页/引用/再改昵称用例通过 |
| 3 晚到历史覆写SDK正文/读状态 | N/SDKChatClient.swift发HTTP前抓当前SDK完整缓存版本，回写前比最新SDK条目；原条被物理删不重插；期间编辑/读/ACK/墓碑变更选最新完整SDK对象；读字段单调；F/Models/ChatHistoryCachePolicy.swift只比真实字段，排除@每次新UUID，允许未变缓存接纳离线另端编辑正文 | ReviewSemantic真实版本/删除/@临时UUID与远端编辑用例实际先红后绿；签名build3验证最终版 |
| 4 QR写错status参数 | N/SDKChatSettingsClient.swift.qr专用isShowQrCode数字，根已核对旧GroupManage242及现SDKGroup.h252 | 旧项目/SDK参数及生产源码核对，签名构建；没有专用QR字段离线断言 |
| 5 管理撤他人错套自己分钟窗 | F/Models/ChatActionPolicy.swift本人窗口与他人管理规则分开，保持群角色/目标层次/支持类型条件 | 根ReviewActionChecks9项先红后绿 |
| 6 转发自己未读+1 | N/SDKChatActionsClient.swift真实转发新记录chatMessageReaded=true；SDKSession按该标志不增未读 | 生产源码及SDKSession读标志分支核对；签名构建已包含，未实测本人转发未读数 |
| 7 媒体后台close后回来空白 | F/Views/ChatMediaDetailView.swift后台停止并置空播放器，返回active且本轮身份仍有效时重新load，重建视频播放器；下载失败仍有重试 | 编译后源分支核对；实际前后台媒体播放需QA/真实资源验收，未声称已实测 |
| CHAT-035角色成员预览 | F/Components/ChatGroupMemberPreview.swift + Models/ChatGroupMember.swift：普通5名/管理4名，群主→管理→普通，真实头像/角色，邀请与管理移除入口；member API完成才开放完整名单；资料路由sourceGroupID和private/security守卫 | GroupChecks新增角色预览2项先红后绿；14/14 |
| CHAT-040当前禁言列表/状态 | N/SDKChatSettingsClient.swift真实GetUserNotalkState/GetNotalkList，DTO保服务器forbidUserUid/name/icon/expireTime/updateTime；群管理当前名单+期限/永久/解除，成员名单已禁言标识；旧超过30整天远期日期识别永久 | ReviewSemantic永久期限用例；SDKSwift签名build2通过；实际禁言名单/解除需双端验收 |
| CHAT-036/048明确昵称同步 | N/SDKChatMessageForwarder.swift + SDKChatNicknameObserver.swift透明观察Socket sync2/GroupMemberNick15/cType1，先原SDK后复制不可变值；AUTH安装/身份轮次隔离，close仅自身仍持有时还原；不同群独立任务、同群重复变化排队；真实API更新SDK成员表，Runtime重映射已加载作者名称/角色，保编辑正文/ACK/读数/墓碑 | 实际ObjC selector转发检查4/4（先红）；生产队列/版本ReviewSemantic12/12；生产Store昵称保存元数据及不复活墓碑21/21 |

追加脚本：`run-review-semantic-checks.sh` 12项、`run-message-forwarder-checks.sh` 4项、根`run-review-action-checks.sh` 9项。全Chat自有及根协助回归分项合计77项；以本次各脚本真实输出为准。第2轮设备签名构建成功日志`/tmp/ddlNew-chat-review-corrections-build2.log`；最终字段语义修正需第3轮日志确认后由根更新签名包，尚未自行重装设备。

不存在用“后端未验证”代替此次三个明确缺失子能力的情况：代码/真实接口/入口已经补齐。剩余后台媒体实际恢复、另一端禁言/删历史/昵称响应等产品行为仍需QA实际双端验证；本文件的回归与编译证据只证明对应接线与可控离线竞态。

## 暂停时最新补充（2026-10-13）

用户要求停止，当前状态见[迁移交接文档](../../Docs/CONTACTS_MESSAGE_MIGRATION_HANDOFF_2026-10-13.md)。上文77项/设备尚未更新为较早快照：根已补后台close后的消息失效识别与停播/禁重载，PreviewInvalidation9项通过，核心Store现23项通过；Chat各入口合计88项，完整仓库最新38个离线入口exit0。键盘工具栏重叠已由根默认字号匿名宿主复测。最新系统配置SDK/TCP修正后的签名workspace构建通过并更新两端，但这些最后根修正尚待新的独立审查及真实媒体回流验收。

最新两端邀请码1000连接与真实身份已确认，授权群B到A文本实收1条；最新A到B尚未发送，ACK/已读和完整后台恢复不标通过。测试报告保留逐需求状态。
