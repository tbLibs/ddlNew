# 消息页及关联真实聊天详细迁移需求

> 需求状态：待用户审阅；本轮仅静态代码对照。旧项目 `/Users/taobotaobo/Desktop/xgd`，新项目 `/Users/taobotaobo/Desktop/ddlNew`，`feature-message-4 / 78876ca`。与[总纲](CONTACTS_MESSAGE_MIGRATION_REQUIREMENTS.md)及[通讯录需求](CONTACTS_MIGRATION_REQUIREMENTS.md)配套；没有构建、业务测试、真机或服务端验证。

## 一、需求层次

M-ID描述消息Tab本身；CHAT-ID描述列表/通讯录进入真实单群聊后所依赖的闭环。群管理、音视频、支付、翻译服务、举报等扩展独立列出，用户审阅前不构成全量开发承诺。当前 `ChatScreen` 调用 ClubCommunity，为演示会话；真实消息页没有指向它的点击入口，不能认作真实聊天已迁移。

## 二、新项目当前会话数据合同

| 字段 | 已接行为 | 差距/约束 |
| --- | --- | --- |
| sessionID/sessionType/status | 稳定ID非空；只取sessionStatus==1；类型1单聊、2群、3群发、5系统、6签到、7支付助手 | 枚举显示不等于特殊入口及业务可用；未知类型过滤，是否兜底须后续确认 |
| 标题 | sessionName空时回退ID | 旧昵称/备注/群昵称优先级、特殊名称需对照，不把好友displayName假定直接作用于会话 |
| 头像 | 单聊优先SDK好友最新avatar，好友缺失才sessionAvatar；群/特殊会话使用sessionAvatar | 好友记录存在但头像空时不会强制回退会话头像；注销头像为空；当前Host动态解析 |
| 预览 | draftContent优先；否则sessionLatestMessage或消息表最新记录 | 当前只做文本/类型占位；群发送者、@我、失败、翻译等旧样式须后续逐项迁移 |
| 时间 | 毫秒转Date，<=0为空 | 今天HH:mm/昨天/当年M月d日/跨年yyyy/M/d为新页面格式，旧格式需确认是否保持新设计 |
| unreadCount/readTag | unreadCount取非负；readTag>0为手动未读 | 行有计数先展示数，无计数才显示手动点；角标当前两者相加，详见M-006联调差异 |
| sessionTop/sessionNoDisturb | 置顶排序/视觉条、免打扰图标及角标排除 | 仅展示状态，当前没有修改UI或提交闭环 |
| 首次同步预览 | 会话代理持久化最新消息，再通知完整回读 | 代理分页先于SDK写库，不能把分页回调视作数据库完整同步已结束 |
| 权限 | 文件助手账号100002按isShowFileAssistant过滤 | 权限隐藏后重算角标，保留完整快照以便重新开放恢复 |
| 会话生命周期 | UID + generation、防重复回读、退出reset | 真实聊天、搜索异步结果、附件上传将来也须隔离所属会话 |

来源：[SDKConversationsClient.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Network/IM/Conversations/SDKConversationsClient.swift:40)、[ConversationRecord.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Models/ConversationRecord.swift:42)、[SDKConversationsDelegate.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Network/IM/Conversations/SDKConversationsDelegate.swift:54)、[ConversationsStore.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Services/ConversationsStore.swift:99)。

## 三、消息/聊天公共状态与验收

| 编号 | 情境 | 需求与验收设计 |
| --- | --- | --- |
| M-G1 | 登录/缓存/同步 | AUTH前订阅、AUTH后可读取当前用户SDK库；先缓存再同步；无会话、无筛选结果、缓存读取失败、同步失败状态清楚区分 |
| M-G2 | 普通断网/后台 | 保留消息和会话；新发送显式待处理/失败，不假成功；恢复后核对ACK/真实同步，不能把后台暂停当账号失效 |
| M-G3 | 多端变化 | 置顶/免打扰/删除/标记/全读/撤回/编辑事件刷新单会话及角标；多人群里消息变化同步到当前视图；重复事件不重复插入 |
| M-G4 | 账号/俱乐部切换 | 列表、聊天、搜索、草稿、下载、上传和回执属于明确用户/会话轮次；旧结果不得写入下一用户；退出归零真实角标 |
| M-G5 | 取消与已提交操作 | 输入/预览/选择可取消；已提交发送/编辑/删除由回执和服务端状态判定，不认为关闭弹窗就撤销服务器动作 |
| M-G6 | 权限变化 | 角色、系统配置、群角色和禁言可在页面打开后改变；显示时和提交时都重新判断；收回权限后旧菜单/草稿不能绕过禁令 |
| M-G7 | 去重与顺序 | 本地msgID、serviceMsgID用于去重；ACK改变服务端时间后重排不复制气泡；分页交叠/重复ACK/重连补拉保持稳定位置 |
| M-G8 | 未读一致性 | 会话行、Tab、系统badge、打开/关闭聊天、多端已读使用明确同一口径；免打扰和隐藏特殊会话不能贡献错误角标 |
| M-G9 | 失败与资源 | 上传失败、文件不存在、消息被撤回/删除、原图失效、无磁盘/无系统权限显示对应提示；保留可重试上下文，重试不重复发送 |
| M-G10 | 操作安全与隐私 | 破坏性操作说明范围（仅本机/双向/群全体）并确认；日志不含消息正文、Token和密钥；资源URL不固定旧Host |
| M-G11 | UI与可访问性 | 长文本/超长昵称/缺头像/未知消息/极大未读可展示，VoiceOver读状态，键盘及选取返回行为一致，性能阈值待真实样本量测 |

## 四、消息Tab详细需求

<!-- REQUIREMENTS-GENERATED -->
<a id="M-001"></a>
### M-001 真实会话首次加载与有效类型过滤

**新状态：已接（代码）｜建议P0｜建议迁移｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：旧Home从SDK会话库和置顶库取列表；新已读SDK真实会话，仅sessionStatus==1、非空ID、已知类型可见，不提供假会话。

**场景、入口与前置**：AUTH成功进入消息Tab或重新打开；当前UID数据库就绪。

**字段与规则**：类型1单聊/2群/3群发/5系统/6签到/7支付；类型映射只是展示基础，特殊业务入口另见M-019～023。

**目标操作流程**：先缓存→同步状态→完成完整回读；未知类型目前过滤，若要兼容展示需用户另审。

**失败、取消、网络/多端与边界**：无会话、同步中、缓存失败分开；会话ID去重；后台断网保留缓存；分页代理早于写库不能当完成。

**验收设计（尚未执行）**：

- **M-001-A1**：登录真实账号显示当前用户缓存，不混演示；隐藏/未知/空ID按规则过滤。
- **M-001-A2**：首轮分页与完整回读交错不丢会话、不重复。

**源码依据**：[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:284)；[SDKConversationsClient.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Network/IM/Conversations/SDKConversationsClient.swift:40)；[SDKConversationsDelegate.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Network/IM/Conversations/SDKConversationsDelegate.swift:54)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-002"></a>
### M-002 置顶分区、时间排序与稳定去重

**新状态：已接（代码）｜建议P0｜建议迁移｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：旧统一置顶/普通列表，组内按最新消息时间降序，同时间ID，完整会话副本优先；新置顶在前/latestTime降序/ID稳定，ID去重取最新。

**场景、入口与前置**：列表加载、收到消息、置顶状态改变。

**字段与规则**：sessionTop不是消息置顶；sessionTopTime存在但本轮未证明按置顶时刻排序；nil时间置后。

**目标操作流程**：合并最新快照→按ID去重→置顶/普通排序→状态/新消息更新位置。

**失败、取消、网络/多端与边界**：旧置顶副本不能覆盖新预览；同时间、多类型、仅草稿/无时间稳定；更新中不得短暂复制一行。

**验收设计（尚未执行）**：

- **M-002-A1**：置顶收到消息仍在置顶区但区内移动正确；普通无越权置顶。
- **M-002-A2**：相同ID旧/新快照只一行，时间相同顺序稳定。

**源码依据**：[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:1678)；[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:1703)；[ConversationRecord.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Models/ConversationRecord.swift:42)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-003"></a>
### M-003 单群聊标题、备注与真实头像优先级

**新状态：部分｜建议P1｜建议迁移｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：旧单聊优先好友showName/avatar；群取sessionName/avatar；新头像单聊优先好友，标题仍sessionName空时ID，尚无好友名称合并。

**场景、入口与前置**：会话行、好友资料变更、群名称头像变化。

**字段与规则**：单聊头像好友存在但avatar空不强回退sessionAvatar；注销头像为空；名称与C备注优先不同，须明确保持新还是对齐旧；群内昵称不覆盖全局会话名称。

**目标操作流程**：加载真实资料→计算标题头像→节点/好友/群变化回读→全页一致。

**失败、取消、网络/多端与边界**：缺好友/无图/注销/相对URL/换Host降级；切号旧图不回流；showHeadLogo/showRoleName等显示开关须后续接。

**验收设计（尚未执行）**：

- **M-003-A1**：备注/头像更新后会话和资料符合确认的名称优先级。
- **M-003-A2**：空头像、无好友、注销、群资料变更均不混旧图或错误ID。

**源码依据**：[NoaSessionCell.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/Session/Views/NoaSessionCell.m:184)；[SDKConversationsClient.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Network/IM/Conversations/SDKConversationsClient.swift:40)；[TabbarView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Tabbar/Views/TabbarView.swift:34)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-004"></a>
### M-004 最新预览、群发送者、@与特殊消息摘要

**新状态：部分｜建议P1｜建议迁移｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：旧草稿优先，群前缀成员remarks→showName→fromNickname；最新别人At消息含本人或-1才[有人@我]；类型摘要及翻译展示。新只有基本类型占位，没有群前缀/@我/完整系统语义。

**场景、入口与前置**：会话更新、收消息/编辑/撤回/删除/草稿变化。

**字段与规则**：当前新文本/图/视频/位置/语音/文件/名片/撤回/@/表情/公告/合并/通话/系统摘要已映射；未知[消息]兜底；历史未读@持久化未证实。

**目标操作流程**：取最新有效消息→草稿优先→按类型摘要→群发送者→最新@条件→更新；消息编辑/撤回后摘要不保留失效内容。

**失败、取消、网络/多端与边界**：自己@不提醒自己；@别人不显示@我；latest未知类型可读兜底；资源失败不泄露路径；原文/译文优先级按旧确认。

**验收设计（尚未执行）**：

- **M-004-A1**：各种摘要/群昵称前缀/@本人/@所有人/自己@区分。
- **M-004-A2**：新旧差距明确，不能把预览支持[图片]认作能发送图片。

**源码依据**：[NSString+SessionLatestMessage.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Base/Tools/Categorys/NSString/NSString+SessionLatestMessage.m:15)；[NSString+SessionLatestMessage.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Base/Tools/Categorys/NSString/NSString+SessionLatestMessage.m:217)；[SDKConversationsClient.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Network/IM/Conversations/SDKConversationsClient.swift:99)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-005"></a>
### M-005 会话时间格式、校时与缺值

**新状态：部分｜建议P1｜建议迁移｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：旧行显示最新消息时间，真实排序依据sessionLatestTime；新毫秒转Date，今天HH:mm/昨天/当年M月d日/跨年yyyy/M/d。本轮未逐项确证旧格式等于新格式。

**场景、入口与前置**：会话行最新时间；服务器ACK更新时间。

**字段与规则**：<=0时间不显示；草稿是否改变时间不臆造；本地时区跨年跨日需测试。

**目标操作流程**：显示当前已接格式→数据新时间更新→重新排序；用户决定格式是否保留新设计。

**失败、取消、网络/多端与边界**：错误极值时间须降级；后台跨日恢复重算；ACK时间修正和列表/聊天日期分隔不同。

**验收设计（尚未执行）**：

- **M-005-A1**：毫秒单位与今天/昨天/跨年/空值正确。
- **M-005-A2**：列表时间与排序来源同一服务端字段，未来ACK更新不出现双条。

**源码依据**：[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:1703)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:269)；[SDKConversationsClient.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Network/IM/Conversations/SDKConversationsClient.swift:40)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-006"></a>
### M-006 未读行、手动提醒、免打扰与Tab角标

**新状态：部分｜建议P0｜建议迁移｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：旧普通单/群/签到行sessionUnreadCount+readTag，群发无badge，群助手红点；新行有真实数先数、无数且标记才点，>99显示99+，免打扰灰；总数=可见非免打扰unreadCount+标记1。

**场景、入口与前置**：新消息、手动未读、免打扰、权限、登入退出。

**字段与规则**：真实未读与readTag同时存在时新总数加1但行不显示额外点；这是待确认口径，不写成择一。群发/系统/签到行样式新仍通用，与旧有差异；系统通知Badge独立。

**目标操作流程**：快照→可见权限过滤→行标记→总角标→状态变更统一重算；是否保留旧特殊样式由用户确认。

**失败、取消、网络/多端与边界**：免打扰不计总数但仍可有行未读；隐藏文件助手不能残数；退出归零；新消息与清读游标交错不能清后到。

**验收设计（尚未执行）**：

- **M-006-A1**：普通真实数/只有readTag/两者都有/免打扰/隐藏助手组合精确计算。
- **M-006-A2**：Tab、行、App图标badge口径差异经确认；特殊群发无数/系统红点不可默认为已对齐。

**源码依据**：[NoaSessionCell.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/Session/Views/NoaSessionCell.m:398)；[NoaSessionCell.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/Session/Views/NoaSessionCell.m:427)；[ConversationRecord.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Models/ConversationRecord.swift:59)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:205)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-007"></a>
### M-007 同步进度、连接提示与缓存错误恢复

**新状态：部分｜建议P0｜建议迁移｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：旧Home显示无网络/连接中/重连attempt等；新显示同步spinner及同步/缓存错误，本地缓存失败有重新读取；尚无完整连接提示UI。

**场景、入口与前置**：消息Tab前后台/SDK连接及同步事件。

**字段与规则**：连接成功、AUTH、同步完成是不同阶段；旧20秒探测器/3秒TCP探测是旧实现，不能复制为新需求定时器。

**目标操作流程**：缓存可读先显示→同步或连接提示→错误说明→SDK恢复后刷新；重新读取按钮只重读本地。

**失败、取消、网络/多端与边界**：后台暂停/普通断网保留数据，既有SDK与维护Coordinator恢复；不重复部署旧网络探测；错误不删除有效凭据。

**验收设计（尚未执行）**：

- **M-007-A1**：缓存失败按钮重读有效，网络断开提示不会谎称同步完成。
- **M-007-A2**：后台/重连后数据自动更新，无额外旧探测竞赛。

**源码依据**：[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:1587)；[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:1601)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:80)；[ConversationsStore.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Services/ConversationsStore.swift:33)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-008"></a>
### M-008 全部/未读筛选与本地预览搜索

**新状态：已接（代码）｜建议P0｜建议迁移｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：新真实消息页提供全部/未读，搜索title或preview忽略大小写trim；旧主要入口是三分类全局搜索，不等同新本地过滤。

**场景、入口与前置**：消息输入框、筛选按钮；已加载会话。

**字段与规则**：未读条件unreadCount>0或isMarkedUnread；全文历史/未同步会话不在搜索范围；草稿作为当前preview可被搜到。

**目标操作流程**：输入→组合筛选→展示匹配→清空/切全部恢复；查询不改变未读和会话数据。

**失败、取消、网络/多端与边界**：无匹配、无未读、真实空区别；权限隐藏不因搜索显示；取消键盘不清业务缓存。

**验收设计（尚未执行）**：

- **M-008-A1**：查询标题/预览/草稿及全部未读组合正确。
- **M-008-A2**：文案清楚本地会话预览，不能称所有消息全文查询。

**源码依据**：[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:25)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:103)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-009"></a>
### M-009 会话点击、真实路由与进入清读边界

**新状态：未接｜建议P1｜建议迁移｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：旧类型分流到真实单群聊/文件助手/群发/系统/签到；普通单群进页清本地未读并conversationReadedStatus(readTag0,latestSMsgId)。新行无点击，不进演示ChatScreen。

**场景、入口与前置**：点击行；当前会话/身份/权限仍有效。

**字段与规则**：sessionID+type；群需真实groupInfo；清角标游标与正文逐条已读不同。旧请求前清零失败无法回滚是迁移应修的风险。

**目标操作流程**：校验目标→真实类型路由→CHAT或专用页就绪→按读游标提交/确认更新→返回列表预览/草稿/未读。

**失败、取消、网络/多端与边界**：目标被删/退群/注销/权限收回显示退路；连点去重；加载失败不误清未读；新消息后到不能被旧清读结果覆盖。

**验收设计（尚未执行）**：

- **M-009-A1**：每类型进入正确真实页，目标身份准确，不跳ClubCommunity。
- **M-009-A2**：进入清会话角标与正文已读分开验收，失败或迟到不丢新未读。

**源码依据**：[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:513)；[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:541)；[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:568)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:142)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-010"></a>
### M-010 会话置顶与取消置顶

**新状态：未接｜建议P1｜建议迁移｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：旧单/群侧滑调用singleConversationTop/groupConversationTop(userUid,friendUserUid或groupId,status0/1)；文件助手列表支持置顶和删除，设置也可置顶；群发/系统/签到不可滑。

**场景、入口与前置**：普通会话侧滑/设置；文件助手仅按专用设置可用。

**字段与规则**：会话top与消息pin分开；原有只读top已接，新UI没有提交。

**目标操作流程**：选置顶/取消→提交禁重→回执成功SDK更新→回读排序→多端刷新。

**失败、取消、网络/多端与边界**：失败保留原top位置；取消无变化；不可操作类型不能通过通用菜单绕过；跨号旧回执失效。

**验收设计（尚未执行）**：

- **M-010-A1**：单群置顶/取消及失败保持正确，多端一致。
- **M-010-A2**：文件助手设置可置顶而列表不伪加；特殊会话操作矩阵准确。

**源码依据**：[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:640)；[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:1278)；[NoaFileHelperSetVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/Session/Controllers/FileHelper/NoaFileHelperSetVC.m:205)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-011"></a>
### M-011 会话免打扰与取消

**新状态：未接｜建议P1｜建议迁移｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：旧singleConversationPromt/groupConversationPromt以status0/1更新会话；新只展示铃铛和总角标排除。

**场景、入口与前置**：普通单群列表/设置；特殊会话规则按专用页。

**字段与规则**：sessionNoDisturb不等于关闭所有系统推送或已读；通知声音规则待真实后端确认。

**目标操作流程**：切换→真实请求→SDK回读→图标/灰未读/总数更新→另端同步。

**失败、取消、网络/多端与边界**：网络失败不能先永久改变UI；新消息同期到达不丢未读；权限/账号变化重算。

**验收设计（尚未执行）**：

- **M-011-A1**：打开/关闭后行标识与总数恢复，缓存重开一致。
- **M-011-A2**：提交失败原状态保持；不误清消息实际未读数。

**源码依据**：[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:1314)；[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:1346)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:151)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-012"></a>
### M-012 手动标记未读/已读与读游标

**新状态：未接｜建议P1｜建议迁移｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：旧conversationReadedStatus(userUid,peerUid,dialogType0单/1群,readTag0/1,latestSMsgId)，toolUpdateSessionWith；普通会话可滑标记/清除。

**场景、入口与前置**：普通会话列表/进入聊天；当前有效最后服务端ID。

**字段与规则**：手动readTag只提醒，不把已读正文恢复为未读；最新ID控制清读边界。

**目标操作流程**：选标记→提交→成功更新SDK→显示提醒；清除/打开聊天按当前游标提交→更新，不清晚到新消息。

**失败、取消、网络/多端与边界**：空latestSMsgId/旧会话/失败/多端同时清读与新收消息需联调；不靠Swift单独set未读造成功。

**验收设计（尚未执行）**：

- **M-012-A1**：实际数0的标记/清除准确；实际数>0按M-006确认口径。
- **M-012-A2**：A清读过程中到B新消息仍保留新未读，失败无误清。

**源码依据**：[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:1428)；[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:1366)；[ConversationRecord.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Models/ConversationRecord.swift:21)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-013"></a>
### M-013 删除会话且保留历史

**新状态：未接｜建议P1｜建议迁移｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：旧deleteServerConversation(peerUid,userUid,dialogType)成功后toolDeleteSessionModelWith(andDeleteAllChatModel:NO)；普通/文件助手可删除，群发/系统/签到侧滑nil。

**场景、入口与前置**：列表删除；明确是移除会话，非清空消息。

**字段与规则**：删除会话与C删好友、CHAT清空历史、消息单条删除四层范围不同。

**目标操作流程**：确认移除范围→服务器删除→成功移列表→仍保留SDK聊天记录→新消息/再次进入能否重建按后端验收。

**失败、取消、网络/多端与边界**：取消/失败保留；没有证据会话删除后群退群/好友被删，不附加行为；后台重连旧快照不错误恢复已删会话。

**验收设计（尚未执行）**：

- **M-013-A1**：删除后会话消失但指定历史仍在，好友/群关系未变。
- **M-013-A2**：取消和失败不移除；特殊类型菜单及再次收消息重建规则确认。

**源码依据**：[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:765)；[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:1372)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-014"></a>
### M-014 全会话已读同步能力与主动入口待确认

**新状态：部分｜建议P2｜事件建议保留；主动入口待取舍｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：旧存在ackConversationRead及toolSessionListAllRead(lastServerMsgId)与全读代理；本轮未确认当前UI主动全已读按钮。新监听imSdkSessionListAllRead触发回读，无主动入口。

**场景、入口与前置**：真实全读同步事件；是否提供按钮须用户决定，不能恢复原演示假全读。

**字段与规则**：单会话ACK与全局lastServerMsgId不同；涉及后续新消息边界、免打扰/特殊会话。

**目标操作流程**：接真实全读事件回读→角标更新；若批准按钮，先确认真实服务端全读契约和范围再开放。

**失败、取消、网络/多端与边界**：服务器事件不能被本地清数组替代；全读过程中后来消息保留未读；失败不能成功toast。

**验收设计（尚未执行）**：

- **M-014-A1**：真实代理同步能重算列表和Tab；晚到消息不被旧lastServerMsgId清除。
- **M-014-A2**：主动入口尚未确认，文档不声称旧按钮/新操作已可用。

**源码依据**：[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:1366)；[SDKConversationsDelegate.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Network/IM/Conversations/SDKConversationsDelegate.swift:94)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-015"></a>
### M-015 真实草稿、@片段与恢复来源差异

**新状态：部分｜建议P1｜建议迁移｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：旧NoaDraftStore MMKV key仅sessionID，保存draftContent/atUser/atSegments，空删除；新预览仅读SDK draftDict draftContent，两来源未联通，没有真实编辑聊天。

**场景、入口与前置**：真实聊天输入未发退出→会话列表；重进/重启。

**字段与规则**：草稿优先最新预览；按UID/邀请码/sessionID隔离；@可恢复片段而非仅显示文本；旧sessionID单键串号风险不可复制。

**目标操作流程**：输入保存→离页更新对应预览→重进恢复→成功发出清草稿→取消编辑保留明确策略；以确认统一来源为准。

**失败、取消、网络/多端与边界**：断网/后台/切账号/注销不把草稿发送；失败发送是否保留输入见CHAT；文字空但@元信息残留应清理。

**验收设计（尚未执行）**：

- **M-015-A1**：退出重进/重启可恢复文字和@定位，切账号不串。
- **M-015-A2**：发成功清草稿，失败不丢可恢复输入；列表来源与真实聊天同一合同。

**源码依据**：[NoaDraftStore.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Model/Draft/NoaDraftStore.m:11)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:270)；[SDKConversationsClient.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Network/IM/Conversations/SDKConversationsClient.swift:54)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-016"></a>
### M-016 全局搜索三分类与更多

**新状态：未接｜建议P2｜建议迁移｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：旧全局分别SDK本地好友、群、消息，各默认最多3条、更多展开；输入trim，空清结果。新只有标题/预览本地筛选。

**场景、入口与前置**：消息/通讯录顶部搜索真实全局入口；当前UID缓存。

**字段与规则**：三分类边界；好友范围C-006、群名C-027、消息历史排messageStatus==0，完整类型匹配仍待验证。

**目标操作流程**：输入→三类查询→类型标题+最多3→更多→对应去向；清空取消→恢复。

**失败、取消、网络/多端与边界**：异步旧查询隔离；权限隐藏助手不能从任意类型绕过；无匹配与库尚未同步区分；不承诺云端全量全文。

**验收设计（尚未执行）**：

- **M-016-A1**：三类最多3及更多展示准确，空查询清结果。
- **M-016-A2**：搜索范围标本地真实库，非只最新预览；查不到未同步记录不假补数据。

**源码依据**：[NoaGlobalSearchVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/NoaGlobalSearchVC.m:84)；[NoaGlobalSearchVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/NoaGlobalSearchVC.m:150)；[NoaGlobalSearchVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/NoaGlobalSearchVC.m:207)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-017"></a>
### M-017 搜索好友/群/助手的目标分流与权限

**新状态：未接｜建议P2｜建议迁移｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：旧好友普通点资料，系统100002点文件助手，群点聊天；文件助手好友搜索在configValue false过滤，其他类型严格性待验证。

**场景、入口与前置**：M-016结果选择；关系/角色即时有效。

**字段与规则**：目标uid/groupId/sessionType分开；旧只显式false过滤和新默认false可能有不同策略，应统一确认。

**目标操作流程**：再次检查权限/关系→好友资料C-015/群CHAT/助手M-019；返回保持查询及分类。

**失败、取消、网络/多端与边界**：好友删/注销、群退/解散、助手权限收回不能开旧结果；不允许历史搜索绕过权限。

**验收设计（尚未执行）**：

- **M-017-A1**：各类型跳转与目标身份正确，最新权限生效。
- **M-017-A2**：失效结果有退路，资料/聊天不会闪旧用户数据。

**源码依据**：[NoaGlobalSearchVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/NoaGlobalSearchVC.m:101)；[NoaGlobalSearchVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/NoaGlobalSearchVC.m:318)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-018"></a>
### M-018 消息搜索命中、补页与原消息定位

**新状态：未接｜建议P2｜建议迁移｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：旧消息结果确定session后进聊天，clickSearchResultInChatRoomWithMessage；缺记录可requestSelectHistoryList补页定位。

**场景、入口与前置**：全局历史结果或CHAT分类结果；真实服务端消息ID/会话。

**字段与规则**：messageStatus0过滤；本地msgID/serviceMsgID和sendTime定位，不以匹配字符串找第一条冒充目标。

**目标操作流程**：选结果→打开正确真聊→本地定位或服务补页→滚动高亮原条→回搜索保查询。

**失败、取消、网络/多端与边界**：被删/撤回/退群/历史不可见/资源缺失显示不能定位原因；页补失败不自动跳最近消息声称找到。

**验收设计（尚未执行）**：

- **M-018-A1**：同内容重复消息仍定位正确serviceMsgID；跨多页可补目标。
- **M-018-A2**：消息失效/无历史权限时有明确提示，取消不误清其他会话未读。

**源码依据**：[NoaGlobalSearchVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/NoaGlobalSearchVC.m:347)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:1713)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:1888)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-019"></a>
### M-019 文件助手专用真实会话

**新状态：部分｜建议P2｜建议独立迁移｜范围：特殊会话。**

**旧项目已见行为（静态证据）**：旧100002→NoaFileHelperVC，支持历史/文本媒体文件/失败重试，列表支持置顶和删除；专用设置查记录/置顶/清空。新只权限过滤/类型单聊展示，没有可开助手页。

**场景、入口与前置**：消息100002、通讯录C-033、搜索；isShowFileAssistant允许。

**字段与规则**：本人同账号设备传输场景；不能当普通朋友设置/添加/举报；其真实发送仍需ACK和SDK库。

**目标操作流程**：权限→打开专用页→读历史→发送/接收→设置/搜索→回列表更新；独立权限变化关入口/角标。

**失败、取消、网络/多端与边界**：断网缓存/上传失败/资源缺失/权限收回/换号处理；文件助手清空与删除会话范围分别确认；仅链接SDK方法不算完成。

**验收设计（尚未执行）**：

- **M-019-A1**：两设备文件/文本传输及ACK/历史/失败符合真实状态。
- **M-019-A2**：列表置顶/删除，设置置顶/清空矩阵正确；权限动态隐藏再允许不丢快照。

**源码依据**：[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:513)；[NoaFileHelperVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/Session/Controllers/FileHelper/NoaFileHelperVC.m:259)；[NoaFileHelperSetVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/Session/Controllers/FileHelper/NoaFileHelperSetVC.m:205)；[ConversationsStore.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Services/ConversationsStore.swift:99)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-020"></a>
### M-020 群发助手、收件人选择和部分失败

**新状态：未接｜建议P3｜独立范围，用户后续取舍｜范围：特殊会话。**

**旧项目已见行为（静态证据）**：旧groupHairAssistant更多/群发类型入口→列表/新群发/收件人/错误名单/附件；GroupHairCreateHairGroupWith、GroupHairSendHairMessageWith真请求，文本或图视频文件。新只有类型预览，没有业务页。

**场景、入口与前置**：角色允许群发；会话或更多入口。

**字段与规则**：接收对象与批次区别普通群成员；标签、收件人、成功/错误名单；配额以真实config/后端，不发明全选上限。群发历史pageSize15/pageStart=(page-1)*15，成功/失败收件人也15条分页。

**目标操作流程**：选择收件人/标签→编辑正文附件→创建批次→发送→历史列表→查成功/失败人和附件；删除群发历史用专用接口。

**失败、取消、网络/多端与边界**：部分失败逐对象展示；创建成功发送失败要可恢复批次不重复；断网/资源上传失败保留输入；不能以逐条转发代替群发服务。

**验收设计（尚未执行）**：

- **M-020-A1**：批次真实创建发送，收件人与错误详情准确；返回列表预览更新。
- **M-020-A2**：取消/部分失败/重复操作处理清楚，权限关闭不可深链进入。

**源码依据**：[NoaNewMassMessageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/Session/Controllers/MassMessage/NoaNewMassMessageVC.m:246)；[NoaNewMassMessageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/Session/Controllers/MassMessage/NoaNewMassMessageVC.m:267)；[NoaMassMessageUserVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/Session/Controllers/MassMessage/NoaMassMessageUserVC.m:59)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-021"></a>
### M-021 群系统通知、申请同意/拒绝与批量审核

**新状态：未接｜建议P2｜建议独立迁移｜范围：特殊会话/群管理。**

**旧项目已见行为（静态证据）**：旧NoaSystemMessageVC全部/待审核，SessionList或GroupManage来源，每页10；get manager/notification apply list，groupJoinGroupApplyHandleWithData可同意status1/拒绝2及批量，readedMessage真实读通知。

**场景、入口与前置**：群助手/系统会话或群管理申请列表；审核者当前群角色允许。

**字段与规则**：与好友申请C-012不同：群申请有拒绝；来源groupID/系统session区分；申请ID数组、状态与分页真实字段需API联调。

**目标操作流程**：按来源载列表→读通知→单条/多选同意/拒绝→提交→重查状态与成员→角标更新；批量前显示范围。

**失败、取消、网络/多端与边界**：已处理/过期/他端先审/权限降级/群解散不能再审；部分成功逐项反馈；失败保留列表；分页重复与页码回退处理。

**验收设计（尚未执行）**：

- **M-021-A1**：每页10、全部/待审过滤、同意1/拒绝2和批量正确；好友页不套群拒绝状态。
- **M-021-A2**：批准后成员/群/会话状态同步，拒绝不假加入；通知已读与审核结果分开。

**源码依据**：[NoaSystemMessageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/SystemMessageApply/NoaSystemMessageVC.m:113)；[NoaSystemMessagePendReviewVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/SystemMessageApply/NoaSystemMessagePendReviewVC.m:95)；[NoaSystemMessagePendReviewVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/SystemMessageApply/NoaSystemMessagePendReviewVC.m:182)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-022"></a>
### M-022 签到提醒历史与真实签到依赖

**新状态：部分｜建议P3｜独立签到范围，用户后续取舍｜范围：特殊会话。**

**旧项目已见行为（静态证据）**：旧messageGetSignInHistoryRecordWith offset加载，点CandyTalkSignInViewController；SDK旧toolGetSignInSession合并ID，当前新SDK缺失toolGetSignInSession，只有SIGNIN_ASSISTANT生成会话，历史不同ID合并尚未迁移。新仅signInReminder类型显示。

**场景、入口与前置**：签到助手会话；真实签到业务服务开放。

**字段与规则**：旧/新会话ID兼容与未读合并应SDK负责；新活动演示签到不同该旧服务。当前按sessionID去重不能合并不同旧/新签到ID。

**目标操作流程**：打开提醒历史→分页→点有效提醒进入真实签到→返回刷新状态，空列表准确。

**失败、取消、网络/多端与边界**：过期/已签到/无服务/断网/ID重复待联调；不得点进活动demo宣称实现。

**验收设计（尚未执行）**：

- **M-022-A1**：真实提醒与签到记录属于同账户服务，不重复助手ID/角标。
- **M-022-A2**：同名SDK方法缺失明确处理，实际签到成功需后续服务端证据。

**源码依据**：[NoaSignInMessageViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/Session/Controllers/NoaSignInMessageViewController.m:52)；[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:307)；[SDKConversationsClient.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Network/IM/Conversations/SDKConversationsClient.swift:40)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-023"></a>
### M-023 支付助手类型与不可达边界

**新状态：需取舍｜建议P3｜仅类型盘点，用户后续取舍｜范围：独立支付。**

**旧项目已见行为（静态证据）**：旧有支付类型和图标，但Home主动removePaymentAssistantModel且cellClickAction无支付分支；新识别type7显示creditcard占位，仍无入口。

**场景、入口与前置**：仅目前类型展示；真实支付入口需后续产品/后端调研。

**字段与规则**：枚举不是付款/收款/红包能力，账户、交易、余额和外部支付未证实。

**目标操作流程**：用户确认是隐藏还是保留不可操作类型占位；如迁移真实支付需独立需求与协议，不从类型推导功能。

**失败、取消、网络/多端与边界**：不能出现可点击假支付/假余额/假交易成功；未知支付会话退路清晰。

**验收设计（尚未执行）**：

- **M-023-A1**：文档与页面不宣称支付已迁移，旧过滤差异保留。
- **M-023-A2**：未来若启用，必须有真入口/API和交易验收另项。

**源码依据**：[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:1138)；[NoaSessionCell.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/Session/Views/NoaSessionCell.m:553)；[SDKConversationsClient.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Network/IM/Conversations/SDKConversationsClient.swift:92)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-024"></a>
### M-024 更多菜单、添加/创建群/业务扫码/群发

**新状态：未接｜建议P2｜建议迁移｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：旧Home更多allowAddFriend/createGroup/groupHairAssistant控制，业务扫码总显示；建群min2/max200，与单聊设置min1预选不同。新无该菜单。

**场景、入口与前置**：消息标题更多；当前角色，业务扫码不含导航恢复。

**字段与规则**：菜单能力分别引用C-013/28/31与M-020；不是复制旧通讯录加号。

**目标操作流程**：展示可用项→选择对应真实页→返回保留会话状态；动态权限立即更新。

**失败、取消、网络/多端与边界**：权限关闭和缺省不出现死入口；无真实模块可暂缓项而非去演示；二维码导航处于既有暂缓。

**验收设计（尚未执行）**：

- **M-024-A1**：权限组合及动态变化正确；每项对应已批准真实能力。
- **M-024-A2**：两个建群入口不同minimum和预选规则准确。

**源码依据**：[NoaSessionMoreView.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/Session/Views/NoaSessionMoreView.m:48)；[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:227)；[UserRoleAuthority.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Common/User/UserRoleAuthority.swift:16)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-025"></a>
### M-025 双击消息Tab循环定位未读

**新状态：未接｜建议P2｜交互保留待用户审阅｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：旧双击消息Tab按统一展示顺序循环未读，无未读回顶部；新没有该交互。

**场景、入口与前置**：消息Tab再次双击；是否保持旧交互待UI审阅。

**字段与规则**：未读依据当前确认readTag+真实数；可见权限过滤和当前排序决定目标，不读旧副本。

**目标操作流程**：双击→定位下一个可见未读→到尾循环；全部无未读回顶部，不改变已读。

**失败、取消、网络/多端与边界**：列表更新/删目标/筛选中行为需定；VoiceOver替代定位动作属建议验收；不因定位自动清角标。

**验收设计（尚未执行）**：

- **M-025-A1**：按当前列表顺序轮转并无未读回顶部。
- **M-025-A2**：定位不清读；目标并发删除可跳下一合法项。

**源码依据**：[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:1524)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-026"></a>
### M-026 多端会话事件、删除与退出清理

**新状态：已接（代码）｜建议P0｜建议迁移｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：旧session receive/update/delete/sync与全读回调刷新；新已监听会话和好友变化回读、首轮预览持久化、UID/generation reset，操作本身仍未接。

**场景、入口与前置**：任何真实会话事件/好友头像备注事件；账号切换或失效。

**字段与规则**：SDK会话与消息库为真实源；多端操作刷新不等于新客户端可发操作。

**目标操作流程**：事件合并回读→更新可见列表/角标；退出reset→取消/移观察→旧回调失效→新用户重新AUTH加载。

**失败、取消、网络/多端与边界**：事件风暴/回读期间再变化补读；旧分页最新消息写入有当前用户和版本校验；断网保留而非退出。

**验收设计（尚未执行）**：

- **M-026-A1**：多事件不重复、重读期间变化不会漏；首轮最新预览重启可恢复。
- **M-026-A2**：切号/邀请码切换旧事件不能写新会话或旧未读。

**源码依据**：[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:931)；[ConversationsStore.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Services/ConversationsStore.swift:33)；[SDKConversationsDelegate.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Network/IM/Conversations/SDKConversationsDelegate.swift:96)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-027"></a>
### M-027 消息角色权限与系统业务配置缺口

**新状态：部分｜建议P0｜建议迁移｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：旧删除/上传/读提示/翻译/消息置顶/编辑/通话各受role/system/group配置；新RoleAuthority已有18项，但SystemConfigRecord只映射登录注册/tenant/captcha/品牌/邀请码/英文符号，无messageRecallTime/enableAudioAndVideoCalls/video_source_config。

**场景、入口与前置**：所有操作显示、进入及提交时；当前权限/有效配置。

**字段与规则**：edited_message_sent旧映射editMsgSwitch为整数分钟，不能使用allows普通bool（分钟字符串2会false）；configData/authorityKey可保留并需业务解析。

**目标操作流程**：逐项按真实语义解析→区分布尔/配额/分钟→UI和服务提交守卫→动态刷新；未迁移系统字段不宣称可直接读。

**失败、取消、网络/多端与边界**：非法/缺失默认策略与旧端比对；系统刷新框架已接≠聊天业务字段已接；后台/多端角色降级不能绕过。

**验收设计（尚未执行）**：

- **M-027-A1**：布尔、分钟、配额、缺省和非法条目各测试，edit窗口不当bool。
- **M-027-A2**：依赖列表明确缺消息系统字段，未拿默认常量冒充服务端配置。

**源码依据**：[UserRoleAuthority.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Common/User/UserRoleAuthority.swift:16)；[SystemConfigRecord.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Network/SystemConfig/SystemConfigRecord.swift:14)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6742)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-028"></a>
### M-028 加载/空/错误、键盘和可访问性

**新状态：部分｜建议P1｜建议迁移｜范围：消息Tab主体。**

**旧项目已见行为（静态证据）**：新页已有多空态、错误、同步spinner与无障碍会话摘要；扩展列表操作和聊天复杂交互未接。旧空态/加载存在，但完整无障碍没有本轮证据。

**场景、入口与前置**：消息Tab与所有关联页；质量需求。

**字段与规则**：当前查询为空/未读筛选为空/列表真实空/同步中/缓存失败区分；建议目标不是旧已完成事实。

**目标操作流程**：错误可采取有效动作→保留缓存→键盘收起/返回→长标题/预览截断可读→VoiceOver读出置顶/免打扰/未读/草稿。

**失败、取消、网络/多端与边界**：极大未读、未知消息、未命名、窄屏、键盘、加载取消明确；性能量级/阈值另定。

**验收设计（尚未执行）**：

- **M-028-A1**：当前空态与可访问摘要不回归；可见缓存不会被错误全屏遮住。
- **M-028-A2**：新操作及聊天页的返回/键盘/VoiceOver有验收用例且本轮未标通过。

**源码依据**：[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:103)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:257)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。

<a id="M-029"></a>
### M-029 通知/深链打开真实会话与Badge依赖

**新状态：需取舍｜建议P2｜推送/深链独立待确认｜范围：跨模块通知依赖。**

**旧项目已见行为（静态证据）**：本轮确认旧会话点击真实路由，未独立确认当前推送/深链完整发起链；新MessageView无真实路由。不能凭SDK存在宣称通知点开已迁移。

**场景、入口与前置**：若未来批准：系统推送或内部会话深链；用户身份/俱乐部有效且目标存在。

**字段与规则**：通知sessionID/type必须与当前真实库核对，不仅信任展示正文；App图标badge与Tab口径需联调。

**目标操作流程**：身份就绪→查目标→合法真页→按真实读边界更新；目标失效返回列表并说明。

**失败、取消、网络/多端与边界**：冷启动AUTH未完成等待；账号不匹配/群被踢/隐藏助手不可绕过；旧消息通知不能清新消息未读。

**验收设计（尚未执行）**：

- **M-029-A1**：未来纳入后冷启动/后台/前台同目标一致，权限和账号核对有效。
- **M-029-A2**：旧入口链待验证，未列为旧已完成推送能力或本轮通过。

**源码依据**：[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:513)；[TabbarView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Tabbar/Views/TabbarView.swift:25)；[MessageView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/MessageView.swift:11)。


## 五、关联真实聊天需求（不自动等于全部纳入本次开发）

<a id="CHAT-001"></a>
### CHAT-001 真实单群聊建立与路由上下文

**新状态：未接｜建议P1｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧列表/资料打开NoaChatViewController携带sessionID/chatType/chatName，群从SDK群库转info再请求群/禁言/成员。新未接真实聊天代理/Store，ChatScreen为本地演示。

**场景、入口与前置**：M-009、C-038、群列表/搜索；AUTH及数据库就绪，目标身份有效。

**字段与规则**：单聊UID vs 群groupID；会话类型、本人UID、俱乐部、所属连接轮次；群info不是演示群。

**目标操作流程**：校验目标→准备真实会话→缓存历史→刷新资料/权限→进入可用发送/只读状态→离页清观察和保存草稿。

**失败、取消、网络/多端与边界**：陌生/非好友/被删是否可发由后端定；注销、退群、被踢、解散显示只读/退出；取消加载和换号迟到隔离；不把SDK存在当新功能。

**验收设计（尚未执行）**：

- **CHAT-001-A1**：由列表/通讯录/搜索进入同会话且路由身份一致；不使用ClubCommunity发送。
- **CHAT-001-A2**：群状态变化禁发/退页准确，快速切会话不会插错消息。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:171)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:179)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:191)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:482)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-002"></a>
### CHAT-002 历史首屏、本地缓存与100条游标分页

**新状态：未接｜建议P1｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧先本地DB再服务器第一页补缺；kPageNumber100，pageSize100/pageNumber1/sMsgId最早serviceMsgID/isThanMsgId1，单fromUid/群groupId，失败回本地，群rows空结束。

**场景、入口与前置**：真聊打开和下拉更早记录；群历史可见配置生效。

**字段与规则**：本地offset当前加载数量；游标服务端ID不能拿本地msgID替代；SDK历史返回记录写真实库。

**目标操作流程**：首本地→第一页补缺→合并去重→向前分页→空结束→恢复可刷新；维持浏览锚点。

**失败、取消、网络/多端与边界**：100/101/多页/仅本地/无游标/错误/退群历史权限；新消息同时到达不能替换旧列表；未证实云端所有记录永远可读。

**验收设计（尚未执行）**：

- **CHAT-002-A1**：分页请求字段/100条边界正确，页交叠不重复。
- **CHAT-002-A2**：服务器失败保留缓存，恢复后补缺；被删/撤回记录不能从旧历史又恢复。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:1495)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:1624)；[NoaIMSDKManager+ChatMessage.m](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1040)；[NoaIMSDKManager+ChatMessage.m](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1038)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-003"></a>
### CHAT-003 滚动位置、新消息提示与搜索定位

**新状态：未接｜建议P1｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧首屏到底；主动上滑/编辑取消强制滚动；历史前插保持锚点，缺历史搜索可补页；loading有20秒兜底。

**场景、入口与前置**：读历史、自己发送、他人实时收、搜索结果跳转、键盘变化。

**字段与规则**：浏览锚点为稳定消息ID；自动到底条件必须区分用户正在看历史与当前位置。

**目标操作流程**：首屏定位末条→上滑保持→新消息给返回底部提示→自己发送按交互定位→前插保持原锚→搜索补页高亮。

**失败、取消、网络/多端与边界**：20秒为旧实现阈值非新承诺，迁移加载超时策略需确认；编辑/选择中不被滚动打断；资源高度更新不乱跳。

**验收设计（尚未执行）**：

- **CHAT-003-A1**：看中部收新消息不强拉到底，点提示回最新；前插历史锚点稳定。
- **CHAT-003-A2**：搜索同文本多条定位准确，键盘/图片加载不造成丢位置。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:1521)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:1713)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:1888)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:7574)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-004"></a>
### CHAT-004 实时收消息、双ID去重与状态事件分流

**新状态：未接｜建议P1｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧SDKtoolDealReceiveChatMessage按单聊from/to、群to归会话，msgId查重；UI过滤当前会话并按msgID/serviceMsgID合并。业务事件不全追加气泡。

**场景、入口与前置**：SDK真实MessageDelegate接收；当前会话/用户归属。

**字段与规则**：本地msgID或serviceMsgID任一相同视同条；本人另一端消息是发送方向但仍只一条；事件种类见附录。

**目标操作流程**：SDK落库→过滤归属→合并记录→刷新会话预览/未读→按事件改权限/原消息，不乱加系统文本。

**失败、取消、网络/多端与边界**：重复推送/离线补拉/ACK与历史交错/切号迟到；本人被踢直接禁发处理；不能从其他ccChat记忆推定新旧同修复。

**验收设计（尚未执行）**：

- **CHAT-004-A1**：实时、ACK、补拉同消息只一条，自己另一端发送方向准确。
- **CHAT-004-A2**：编辑/群角色/解散等事件更新对应状态而非全部显示普通文本。

**源码依据**：[NoaIMSDKManager+ChatMessage.m](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:48)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3175)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3448)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-005"></a>
### CHAT-005 发送落库、发送中/成功/失败与ACK重排

**新状态：未接｜建议P1｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧toolSendChatMessageWith转换协议、MMKV待发、会话和DB后socket发；ACK ackMsgId匹配msgID、sMsgId成为serviceMsgID、sendTime服务端，Success并重新排序日期。

**场景、入口与前置**：所有批准的真实消息发送；已AUTH、关系/群/上传前置满足。

**字段与规则**：正文不只放Swift数组；ACK需匹配本地ID且sMsgId非空；失败原因字段保留；成功消息服务时间差<=3000ms旧合并保留时间规则需与ACK回写区分。

**目标操作流程**：校验→建唯一发送记录→发送中→发送任务→ACK成功或失败→SDK持久化→更新预览/时间/排序→重启恢复。

**失败、取消、网络/多端与边界**：离页不等于发送被撤销；ACK迟到/重复/次序交错只更新原条；上传成功不等于消息成功；退出不得写下一用户。

**验收设计（尚未执行）**：

- **CHAT-005-A1**：发出显发送中，只有有效ACK/SDK成功才成功；重启可恢复。
- **CHAT-005-A2**：ACK重排不产生副本，时间/日期/列表预览一致。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3688)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3723)；[NoaIMSocketManagerTool.m](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/ConnectModule/Socket/TcpManager/NoaIMSocketManagerTool.m:293)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-006"></a>
### CHAT-006 SDK失败分类、ACK重试与人工重发

**新状态：未接｜建议P1｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧点击失败messageReSendClick/reSendFailMessageWithReSendMsg；新SDK已有sendFailureReason和reason代理，3秒ACK检查、reSendCount<=3继续，否则HTTP MessagePushMsg兜底，另60秒终止。

**场景、入口与前置**：发送Fail记录→用户重试；当前原所属用户/会话仍合法。

**字段与规则**：3秒/<=3/60秒是源码判断，不能换算总重发次数；NetworkUnavailable/ConnectionNotReady/FileTooLarge/RateLimited/ConnectionLost/InvalidResponse/ServerRejected/Timeout来自新SDK。

**目标操作流程**：呈现SDK原因→核对当前发送权限/资源→人工重发→保持同逻辑消息去重→跟踪回执；自动重试复用SDK已有合同。

**失败、取消、网络/多端与边界**：断网/未AUTH不误报账号密码错；413/429/明确拒绝等区别；不加独立无限重发；附件缺失需重新取资源；成功回执与人工点击交错先确认已成功。

**验收设计（尚未执行）**：

- **CHAT-006-A1**：新SDK原因文案与可恢复动作正确；自动SDK与人工重试无重复消息。
- **CHAT-006-A2**：原账号退出/资源丢失/权限被收回无法误发，3秒/<=3/60秒按SDK实际流程联调。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6016)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6387)；[NoaIMSDKDelegate.h](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/SdkDelegate/NoaIMSDKDelegate.h:57)；[NoaIMSocketManagerTool.m](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/ConnectModule/Socket/TcpManager/NoaIMSocketManagerTool.m:231)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-007"></a>
### CHAT-007 正文可见批量已读、语音播放与已读提示

**新状态：未接｜建议P1｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧可见多类型收到消息入待读集合，serviceMsgID_fromID_msgID，2秒批量HaveRead，离页flush暂停；语音播放成功才加入。showUserRead控制提示。

**场景、入口与前置**：聊天可见收到正文；语音实际播放，前后台/离页。

**字段与规则**：会话readTag、chatMessageReaded、haveReadCount/totalNeedReadCount分开；群已读成员详情独立入口本轮未确认。

**目标操作流程**：可见→去重收集→按旧2秒批量发送→回执更新→离页flush→后台停止；语音未播不自动读。

**失败、取消、网络/多端与边界**：后来消息不能被旧会话清读游标覆盖；无serviceID不发假已读；权限关闭隐藏提示不必推断不发送协议；群详情未确认不承诺。

**验收设计（尚未执行）**：

- **CHAT-007-A1**：只有可见收到正文上报，语音未播未读、播放后读。
- **CHAT-007-A2**：多端已读/前后台/离页与新消息交错状态正确；群计数不伪造。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:369)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:875)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:4990)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6162)；[NoaMessageSendHander.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Tools/NoaMessageSendHander.m:932)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-008"></a>
### CHAT-008 消息日期分隔、服务端校时与气泡基础

**新状态：未接｜建议P1｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧首条显示日期，同日相邻不插日期，跨日插；computeVisibleTime/computeOneMessageVisibleTime，ACK/删/撤回/历史插入重算，没有每5分钟分隔证据。

**场景、入口与前置**：真聊历史/实时/ACK；长文本与多类型气泡。

**字段与规则**：发/收方向、头像/名称/时间/状态、缺资料兜底；server sendTime和本地时区一致，不造未证实规则。

**目标操作流程**：消息排序→按相邻日计算分隔→渲染气泡→资料/日期变化局部刷新。

**失败、取消、网络/多端与边界**：跨UTC日、跨年、相同时间、消息删除空列表、注销/空头像；群名优先级见群昵称需求。

**验收设计（尚未执行）**：

- **CHAT-008-A1**：同日不强插5分钟日期；跨日/前插/ACK重排分隔准确。
- **CHAT-008-A2**：方向、头像昵称和发送状态长字适配，不泄露内部路径。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:7601)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:7635)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-009"></a>
### CHAT-009 文本、Unicode emoji、敏感处理与输入恢复

**新状态：未接｜建议P1｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧chatInputViewSend→ZMessageTextSend，可带referenceMsgId，经过敏感过滤；空不发，发后清正文和草稿。

**场景、入口与前置**：真聊输入/键盘发送/按钮；不禁言且群频控通过。

**字段与规则**：纯文字/emoji与网络贴纸区分；文本最大长度本轮未明确，不造数值；过滤策略采用真实旧/服务端合同。

**目标操作流程**：输入→非空校验→权限/频控→真实发送→发送中→ACK→清成功输入/草稿按确定时点→失败保可重试。

**失败、取消、网络/多端与边界**：全空白/组合emoji/换行/长字/非法字符/断网；过滤失败给提示不静默改意思；发送失败不能丢全部输入上下文。

**验收设计（尚未执行）**：

- **CHAT-009-A1**：文本与emoji两端内容一致，空不发，失败可恢复。
- **CHAT-009-A2**：ACK成功后列表预览/草稿/持久化正确；无本地假回复。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:2057)；[NoaMessageSendHander.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Tools/NoaMessageSendHander.m:153)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-010"></a>
### CHAT-010 @选择、@所有人、片段编辑与限制

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧ZMessageAtUserSend，atUsersInfoList UID/nick，正文UID标记；单聊好友/群成员可选；普通群成员isPrivateChat不弹@列表；本地成员存在时选择页首位直接插-1所有人，无role条件；入口仍受普通成员禁私聊限制。

**场景、入口与前置**：输入@/头像长按@；当前可访问成员和群策略。

**字段与规则**：文本片段与UID绑定，不能只靠昵称；@所有人旧UI无额外role条件，但服务端是否限角色仍须联调；草稿atSegments完整恢复。

**目标操作流程**：选成员→插带UID片段→编辑/删整个片段→提交@协议→气泡显示→M预览判断@我。

**失败、取消、网络/多端与边界**：重名/改群昵称/特殊符号/多次@/成员退出/禁私聊/权限收回；引用中@处理；后台草稿不串号。

**验收设计（尚未执行）**：

- **CHAT-010-A1**：同名不同UID、@所有人、删除片段、草稿恢复及接收匹配正确。
- **CHAT-010-A2**：普通禁私聊群不能通过@选择绕过，@所有人权限待确认。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:2825)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:5096)；[NoaMessageSendHander.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Tools/NoaMessageSendHander.m:429)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)；[NoaMsgAtListViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Views/AtUserView/NoaMsgAtListViewController.m:166)。

<a id="CHAT-011"></a>
### CHAT-011 语音录制、取消、上传、播放与已读

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧maxSecond60，文件<1024字节提示太短，VoiceSend真实上传；播放成功才已读，支持听筒/播放状态。

**场景、入口与前置**：输入切语音、按住录制、播放语音气泡；麦克风允许、不禁言/频控通过。

**字段与规则**：60秒录音/1024字节为旧具体阈值；语音路径/时长/资源信息；收到未播不标已读。

**目标操作流程**：权限→录制→上滑/取消或完成→检查过短→上传→消息发送状态；气泡下载/播放→停止/切换→播后读。

**失败、取消、网络/多端与边界**：拒权/来电音频中断/后台/录制超时/上传失败/资源失效/离页停播放；未确认自动发送时点须跟录音组件核对，不能一律假设60秒自动成功。

**验收设计（尚未执行）**：

- **CHAT-011-A1**：太短/60边界/取消无发送，正常语音双端可播并有ACK。
- **CHAT-011-A2**：无麦克风/中断/下载失败提示正确，播放后已读而仅可见未读。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:2452)；[NoaChatInputView.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Base/Base/Views/NoaInputView/NoaChatInputView.m:732)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6162)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-012"></a>
### CHAT-012 相册/拍摄图片视频、转换文件与上传任务

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧NoaImagePicker最高9，PHAsset→MediaSend；upImageVideoFile控制，原图>30MiB转文件、视频>200MiB转文件；封面/缩略/原资源分任务。

**场景、入口与前置**：底栏相册/拍摄；相册/相机授权，role允许与群状态合法。

**字段与规则**：9为旧选择器上限；30MiB/200MiB是转换阈值不是服务端上传容量；图片尺寸/视频时长/封面与远程相对路径。

**目标操作流程**：选择→预览/取消→处理PHAsset/iCloud→按阈值转换→真实上传→消息发送→进度/ACK→接收下载。

**失败、取消、网络/多端与边界**：iCloud不可用/转换失败/无权限/权限关闭/换Host/断网/磁盘不足/取消；走文件时upFile交互需确认，不能绕上传权限。

**验收设计（尚未执行）**：

- **CHAT-012-A1**：0/1/9/超过9、阈值前后、原图视频/封面分开正确。
- **CHAT-012-A2**：附件上传成功仍等待消息ACK；失败重试不重复发，节点变化可恢复。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:2488)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:2591)；[NoaMessageSendHander.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Tools/NoaMessageSendHander.m:153)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-013"></a>
### CHAT-013 文件选择、上传/下载、文件名与系统打开

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧FilePicker→ZMessageFileSendData→STS/上传/SDK；upFile控制，本地/网盘来源，文件详情支持下载/转发/打开；总大小上限未验证。

**场景、入口与前置**：底栏文件或系统选取；允许上传，文件存在且可读。

**字段与规则**：原文件名/展示名/类型/大小/本地所属路径/远程路径；临时凭据不入文档，缓存按UID/session隔离。

**目标操作流程**：选取→校验→上传进度→消息ACK→气泡→下载→本地预览/系统分享打开；失败显示阶段与动作。

**失败、取消、网络/多端与边界**：源文件被移/iCloud/无权限/格式不支持/无磁盘/Host变化/服务器413；取消已提交有真实回执边界；未批准不能声明任意网盘支持。

**验收设计（尚未执行）**：

- **CHAT-013-A1**：文件名类型大小准确、双端下载可打开；失败原因/进度/重试明确。
- **CHAT-013-A2**：未证实上限不写固定数值；文件缓存归属正确，切号不会打开旧用户资源。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:2696)；[NoaChatFileDetailViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatFileDetailViewController.m:237)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-014"></a>
### CHAT-014 贴纸/GIF/游戏表情及表情商城

2026-10-15当前追加：用户明确批准默认石头剪刀布和骰子发送、旧资源与动画，已接现有type21 SDK字段；商城和其它新游戏仍暂缓。旧端结果在客户端随机生成后随消息提交，不能表述为服务器裁决，实际收发仍需ACK/双端验证。以下原建议为需求盘点快照，最新状态见[统一交接](SESSION_HANDOFF_2026-10-15_CHAT_INPUT_GAMES.md)。

**新状态：未接｜建议P2｜贴纸建议迁移；商城独立取舍｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧Stickers/GameStickers真发送；收藏图片找原包，游戏完成定格；底栏表情商城真实可达，精选搜索20/未使用包10分页。

**场景、入口与前置**：底栏表情/更多表情；合法资源和发送权限。

**字段与规则**：贴纸URL/尺寸/大小、包ID；Unicode emoji不用网络商城；骰子等结果不得前端伪造服务端 outcome。

**目标操作流程**：展示已用包→选贴纸→资源处理→SDK发送→接收渲染；商城搜索/包详情/添加/收藏→返回输入。

**失败、取消、网络/多端与边界**：资源过期/包被删/重复收藏/iCloud网络失败/未完成游戏动画；分页去重；权限禁言/频控遵循统一守卫。

**验收设计（尚未执行）**：

- **CHAT-014-A1**：静态/GIF/游戏与普通emoji区分，结果及资源真实。
- **CHAT-014-A2**：商城20/10分页、重复添加/收藏与失效资源降级准确。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:2989)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3023)；[NoaChatInputFunctionView.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Base/Base/Views/NoaInputView/NoaChatInputFunctionView.m:55)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-015"></a>
### CHAT-015 真实名片推荐、接收与资料分流

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧Card气泡可点资料；推荐来自好友更多/转发工具MessageUserCardRecommend，未在聊天底栏确认生成名片入口。

**场景、入口与前置**：C-018推荐或收到Card；可访问的名片目标。

**字段与规则**：friendUserId+receiveUsers[{chatType GROUP_CHAT/SINGLE_CHAT,friendIdOrGroupId}]+userUid；名片UID与收件对象分开。

**目标操作流程**：从资料选目标→真实推荐→回执→名片气泡→点击当前目标资料；历史卡片至少可读。

**失败、取消、网络/多端与边界**：注销/关系变化/禁私聊/部分接收失败/头像失效；不新增虚构底栏名片按钮声称旧已有。

**验收设计（尚未执行）**：

- **CHAT-015-A1**：接收卡打开正确UID，组/单接收对象请求正确。
- **CHAT-015-A2**：历史名片失效有占位/退路，部分失败不一概成功。

**源码依据**：[NoaChatMultiSelectSendHander.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Tools/NoaChatMultiSelectSendHander.m:136)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3126)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-016"></a>
### CHAT-016 历史位置气泡与位置发送待取舍

**新状态：未接｜建议P2｜历史展示建议迁移；新发位置待取舍｜范围：历史兼容/候选发送。**

**旧项目已见行为（静态证据）**：旧GeoMessage气泡和LocationSend工具存在；当前Function/More列表无位置，ChatController未实现chatInputViewShowLoction；选择地点发起链未确认。

**场景、入口与前置**：至少历史位置消息；新发起定位是独立候选。

**字段与规则**：经纬度/地址仅按真实消息模型，地图提供者/定位授权/精度未确认，不编造。

**目标操作流程**：历史位置渲染→用户点击查看有效地点；若批准新增发送另确定地图/权限/选取页面与协议闭环。

**失败、取消、网络/多端与边界**：无位置权限、无地图/资源、无效经纬度有降级；不自动请求定位或声称底栏已可发送；取消新增选地点不发。

**验收设计（尚未执行）**：

- **CHAT-016-A1**：历史位置可识别且未知资源明确，不误当文本。
- **CHAT-016-A2**：发送功能保留待确认，实际入口/API/授权另行验证后再纳入。

**源码依据**：[NoaChatInputFunctionView.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Base/Base/Views/NoaInputView/NoaChatInputFunctionView.m:55)；[NoaChatInputMoreView.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Base/Base/Views/NoaInputView/NoaChatInputMoreView.m:23)；[NoaChatInputView.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Base/Base/Views/NoaInputView/NoaChatInputView.m:574)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-017"></a>
### CHAT-017 合并聊天记录呈现与嵌套边界

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧sendChatRecordMessage→MergeForwardSend；记录详情可显示文字/媒体/文件/卡片/内嵌记录，已有ForwardMessage不能再转发/多选以限制链。

**场景、入口与前置**：收到合并记录/多选合并发送；选中消息均合规。

**字段与规则**：标题/原发送者/时间/记录体/资源；脱离原会话后仍需可读，引用ID及附件所属重建规则由转发工具决定。

**目标操作流程**：选条→合并→真实发送→卡片点击详情→资源下载/原类型呈现；不可选类型见CHAT-024。

**失败、取消、网络/多端与边界**：缺附件/已撤回原文/递归异常/记录不完整降级；内文件详情isShowRightBtn=NO，不能套普通文件所有操作。

**验收设计（尚未执行）**：

- **CHAT-017-A1**：合并文字媒体等顺序与原作者时间正确，接收者可离线读缓存。
- **CHAT-017-A2**：已有合并不无限再次合并；附件失效与内文件操作矩阵准确。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6216)；[NoaChatRecordDetailViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatRecordDetailViewController.m:50)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6914)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-018"></a>
### CHAT-018 禁言/角色/上传开关与群发送间隔

**新状态：未接｜建议P1｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧群普通成员groupMessageInterval毫秒，0默认2000，1/2豁免，文本/@/语音/附件/贴纸调用频控；禁言改输入栏。新权限模型有字段，真实输入未消费。

**场景、入口与前置**：所有发送/编辑/转发提交；当前群角色和禁言。

**字段与规则**：0普通/1管理/2群主；groupMessageInterval毫秒不要当秒；upFile/upImageVideoFile及动态变化；角色3含义未验证。

**目标操作流程**：最新权限/群状态→入口可见与输入状态→提交再次检查→频控提示→恢复后解除；客户端策略与服务端限频一致。

**失败、取消、网络/多端与边界**：仅隐藏按钮不足；后台权限下调/群被踢/解除禁言/发包前变化；0默认两秒为旧规则不擅自用于新缺字段。

**验收设计（尚未执行）**：

- **CHAT-018-A1**：普通频控/1和2豁免、全员/个人禁言、上传关闭各入口准确。
- **CHAT-018-A2**：旧未映射配置标缺口，临界提交被拒时提示真实原因而非假成功。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:1958)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:1024)；[UserRoleAuthority.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Common/User/UserRoleAuthority.swift:16)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-019"></a>
### CHAT-019 长按菜单矩阵、复制与链接

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧长按随本人/类型/Success/群角色/删除权限/撤回窗给菜单，复制原文或译文，链接可存顶部Tag并经MiniAppWeb打开。

**场景、入口与前置**：有效气泡长按；消息当前状态和权限。

**字段与规则**：每类型不是完整同菜单；文本原/译/合并复制对象明确；保存链接属独立数据能力。

**目标操作流程**：生成当前可用动作→选复制/其他操作→使用当前消息而非旧快照；链接由用户主动打开/保存。

**失败、取消、网络/多端与边界**：消息被删/撤回/编辑或角色收回重建菜单；不可用动作不冒充成功；不自动外访链接；操作取消无修改。

**验收设计（尚未执行）**：

- **CHAT-019-A1**：本人/他人、成功/失败、文本/公告/通话/系统等矩阵对应正确动作。
- **CHAT-019-A2**：复制与链接对象正确，动态变更后不能用旧菜单越权。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:5230)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6598)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6830)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6934)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-020"></a>
### CHAT-020 引用回复、原文定位与变更同步

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧messageModelReference/referenceMsgId=原serviceMsgID发文本/@；引用点定位，原文编辑/删/撤回刷新引用。

**场景、入口与前置**：长按引用→输入；原消息ID有效，当前能发。

**字段与规则**：引用原作者/类型/摘要与serviceID；编辑/转发时引用ID规则不同；原文不是复制一份永不变正文。

**目标操作流程**：选择引用→输入显示引用卡→可取消→真实发送→接收卡→点补页定位；原文事件更新引用。

**失败、取消、网络/多端与边界**：原文已删/撤回/权限无历史明确占位；消息被引用后编辑两端同步；输入取消清引用不会清草稿正文错误。

**验收设计（尚未执行）**：

- **CHAT-020-A1**：引用文字/@/支持类型成功且ID指向原条，不靠文本搜索。
- **CHAT-020-A2**：删除/撤回/编辑后原引用和列表一致，缺本地页可补或提示。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:4607)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:4630)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6598)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-021"></a>
### CHAT-021 单条/多选删除、单向与双向范围

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧deleteMessage带OneWay/BothWay operationStatus；成功消息真实请求，失败消息本地删分支；deleteMessage/remoteDeleteMessage及0/1/2与作者控制，多选群分支和单条有差异。

**场景、入口与前置**：长按/多选删除；当前消息、发送状态和合法范围。

**字段与规则**：单向本人、本人与对方/群全体不同；不能套所有人删所有消息；成功/失败消息不同路径，确定各协议参数见接口附录。

**目标操作流程**：按矩阵显示可删范围→确认说明→真实请求或失败本地清→成功更新SDK、气泡、搜索、预览与引用→多端同步。

**失败、取消、网络/多端与边界**：取消不删；部分多选失败逐条反馈；权限降级/原消息不在/旧回执隔离；单条和多选矩阵需联调，不掩盖旧差异。

**验收设计（尚未执行）**：

- **CHAT-021-A1**：本人/他人×0/1/2×Success/Fail×单向/双向完整验证。
- **CHAT-021-A2**：指定范围双端一致、失败不移除、撤回/清空/删会话不混为删除消息。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6668)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6698)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6710)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6558)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:7475)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-022"></a>
### CHAT-022 撤回窗口、管理者撤回与撤回占位

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧本人messageRecallTime分钟>0，now<=发秒+分钟60；管理/群主另判断他人和同角色保护；recallMessage成功更新SDK和撤回展示。

**场景、入口与前置**：长按撤回；当前消息可撤回、合法群角色。

**字段与规则**：系统分钟窗口尚未映射新SystemConfigRecord；管理员不能无条件撤群主，管理他人规则与自撤分开。

**目标操作流程**：读取当前时间/权限→显示撤回→确认/请求→成功替换原文占位→更新引用/预览/资源与历史；失败保原文。

**失败、取消、网络/多端与边界**：分钟边界、校时、已撤回/被删除/管理员降级、对方离线再同步；不能仅本地抹气泡。

**验收设计（尚未执行）**：

- **CHAT-022-A1**：窗口0/关闭/边界内外和角色保护可验收，未映射字段不默认开启。
- **CHAT-022-A2**：双端原文不从补历史复活，引用和列表显示撤回，失败原文保留。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:5025)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:5353)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:5439)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:7510)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-023"></a>
### CHAT-023 本人文本/@编辑、分钟权限与回写

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧本人Text/@、非禁言、editMsgSwitch整数分钟>0且校准时间差<=分钟60000可编辑；editMessage提交原二进制保留sMsgId/isEncry/snapchat/sendTime/ext；成功替换原条。

**场景、入口与前置**：长按编辑；当前作者是本人，窗口及群发送条件满足。

**字段与规则**：edited_message_sent对应分钟值，不用allows bool把2错判关闭；原@片段可恢复；EditedOneMsg用于引用刷新不新增系统气泡。

**目标操作流程**：回填文字/@→编辑提示→取消或提交→服务端校验→成功SDK更新原消息/已读翻译→两端、引用/预览/搜索刷新。

**失败、取消、网络/多端与边界**：失败保编辑输入；过时/权限下调/禁言/原文被删或撤回禁止；编辑不重设发送时间逃自动删除。

**验收设计（尚未执行）**：

- **CHAT-023-A1**：只本人text/@可编辑，分钟边界/组合@/取消正确。
- **CHAT-023-A2**：新原条替换无重复，接收方引用和预览更新，服务拒绝保输入。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6742)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6763)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:2316)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3455)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:4401)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-024"></a>
### CHAT-024 消息多选、100条上限及不可选类型

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧最多100、只Success，排公告/卡片/游戏贴纸/通话/系统/合并/撤回；已有Forward禁转发/多选。

**场景、入口与前置**：长按多选→勾选气泡；当前可操作类型。

**字段与规则**：选择集合稳定消息ID，不能选100条记录但重复同ID算两条；支持删除/逐条/合并各权限另算。

**目标操作流程**：进多选→可选/不可选区分→0禁完成/达到100阻止新增→选动作→确认→结束或取消恢复输入。

**失败、取消、网络/多端与边界**：101提示、消息实时消失/权限改变更新集合；取消不触发发送/删除；非成功变更不可留已选绕过。

**验收设计（尚未执行）**：

- **CHAT-024-A1**：0/1/100/101与所有排除类型正确。
- **CHAT-024-A2**：实时消息变化不丢有效选择/越权，取消恢复浏览与草稿。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:92)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:5764)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6914)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-025"></a>
### CHAT-025 逐条/合并转发、合规预检与逐对象结果

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧逐条按时间升序，接收来自最近/群/好友分组；transpondComplianceMessage forwardCount逐条为数量/合并1；异常名单可看并排除继续，全异常禁；transpondMessage返回嵌套failId/sMsgId。

**场景、入口与前置**：长按转发或多选→接收选择；群频控/对象合规。

**字段与规则**：转发归当前发送者和新接收者，清引用ID；附件不能误带原聊天本地路径；每收件人/每消息分别落DB结果。

**目标操作流程**：选消息→选对象→预检→异常明细→用户排除或取消→确认发→逐对象回执→成功/失败详情→当前会话只加属于其记录。

**失败、取消、网络/多端与边界**：部分失败不整体成功；资源可复用不重复上传；无合法对象禁提交；重复点击/后台回执所属隔离。

**验收设计（尚未执行）**：

- **CHAT-025-A1**：逐条排序稳定、合并count1、异常全无禁止、部分失败明细准确。
- **CHAT-025-A2**：附件/作者/引用归属正确，每个接收方实际回执而非批量假成功。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6532)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6544)；[NoaChatMultiSelectViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatMultiSelectViewController.m:480)；[NoaChatMultiSelectSendHander.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Tools/NoaChatMultiSelectSendHander.m:29)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-026"></a>
### CHAT-026 消息收藏与保存链接模块

**新状态：未接｜建议P2｜关联收藏/链接范围待用户审阅｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧MessageCollectionSave/UserAddCollection相关真方法、独立收藏列表；可保存文本链接到顶栏Tag和MiniAppWeb。

**场景、入口与前置**：长按收藏、底栏收藏内容发送、链接保存；该独立模块若批准。

**字段与规则**：收藏对象与消息本地删除相互独立；收藏类型/数量限额未定量证实不造数；远程资源是否长期有效需确认。

**目标操作流程**：选择收藏→真实提交→回执→列表查询/选取发送；保存链接→更新Tag→用户点击打开。

**失败、取消、网络/多端与边界**：重复收藏/资源失效/网络/账号变化/权限关闭；取消不外访；本轮不迁移整收藏系统承诺。

**验收设计（尚未执行）**：

- **CHAT-026-A1**：批准后收藏真回执和读取一致，重复/失败明确。
- **CHAT-026-A2**：发收藏内容仍走真实发送，链接无自动访问，退出归属隔离。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6836)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6934)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6952)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-027"></a>
### CHAT-027 翻译配置、状态、再次翻译与服务依赖

**新状态：未接｜建议P3｜独立翻译范围待取舍｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧translationSwitch未配置默认允许，send/receive channel/lang/自动译可同步；None/Loading/Success/Fail、隐藏/再次翻译；@/emoji拆出重组，无余额/未绑定可关闭。

**场景、入口与前置**：底栏翻译/长按/设置；角色translation_switch及外部翻译账户。

**字段与规则**：channelCode/to/content/userUid；localTranslatedShown和译文状态；新Role有开关但业务服务未接。

**目标操作流程**：配置真实请求→翻译加载→成功并展示/缓存→失败仍原文→用户重试/隐藏；变更同步另一端。

**失败、取消、网络/多端与边界**：扣费/无余额/未绑/限频/断网/语言非法/旧消息被编辑；@不串UID、emoji不丢；不把原文隐藏导致读不了。

**验收设计（尚未执行）**：

- **CHAT-027-A1**：翻译开关/自动/手動/隐藏/再次及失败原文可读正确。
- **CHAT-027-A2**：@/emoji/编辑后旧译文不误复用，账户服务依赖另联调。

**源码依据**：[NoaTranslateSettingVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/TranslateTools/NoaTranslateSettingVC.m:66)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:2391)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:6965)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:7026)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-028"></a>
### CHAT-028 聊天消息置顶、个人/全局与原文定位

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧groupMsgPinning/userMsgPinning；只无引用Text/@可置顶；先查状态，群普通个人、1/2可所有成员，单聊可双方；status1全局/2个人/3取消全局/4取消个人。

**场景、入口与前置**：合法气泡长按置顶、顶部条/置顶列表；与会话top不同。

**字段与规则**：MessageQueryGroupMsgStatus/UserMsgStatus、groupSetMsgTop/MessageSetMsgTop；serviceID、范围及当前角色；新对应布尔角色已保留无真实UI。群请求userUid/groupId/smsgId/msgStatus，单请求userUid/friendUid/smsgId/msgStatus；必须有serviceMsgID。

**目标操作流程**：查询现态→选择范围确认→提交→成功回查列表→置顶条点定位→取消/删/撤回回查。

**失败、取消、网络/多端与边界**：含引用消息不允许；个人和全局并存/权限降级/原消息删除/群公告旧存在时隐藏消息置顶条应审阅；配额未知不造数。

**验收设计（尚未执行）**：

- **CHAT-028-A1**：无引用Text/@限制、四status及0/1/2角色范围正确。
- **CHAT-028-A2**：原文定位/取消两端一致，撤回/删后置顶不保留失效内容。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:5811)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:5881)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:7089)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:7254)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:8092)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-029"></a>
### CHAT-029 定时自动删除：1/7/30天与关闭

**新状态：未接｜建议P2｜自动清理范围待用户审阅｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧右上时间入口MessageTimeDeleteInfoWith freqValue，组件选1/7/30天，freq1/7/30，0关闭；ScheduleDeleteMessage更新并删旧时间消息。

**场景、入口与前置**：真实会话时间入口；服务端支持且当前操作角色允许。

**字段与规则**：MessageTimeDeleteSetWith(freq)；自动删除范围/时间基准和多端执行仍须联调；不能把编辑时间作为重置发送时间。旧关闭按钮仅已启用时显示，遮罩/取消不提交。

**目标操作流程**：获取现频率→选择确认范围→提交→回查→提示当前政策→真实事件移除到期消息/搜索/预览/资源。

**失败、取消、网络/多端与边界**：取消无变化；修改失败保持旧；后台到期恢复不能复活；服务器时间漂移与历史补页过滤；不本地定时假装已在所有端删除。

**验收设计（尚未执行）**：

- **CHAT-029-A1**：1/7/30及0开关与现值一致，取消/失败保原。
- **CHAT-029-A2**：真实到期多端范围有后续证据，缓存/搜索/引用不恢复到期正文。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:495)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:1826)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3657)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:7874)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:7906)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-030"></a>
### CHAT-030 单聊设置、加好友成群与清空记录

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧单设置含资料、加人成群max200/min1且预置当前好友、查记录/top/mute、deleteMessage允许清空，真实投诉。

**场景、入口与前置**：单聊右上设置；当前目标关系与role。

**字段与规则**：min1是额外选人不同首页min2；清空clearChatMessageHistory与删会话andDeleteAllChatModelNO不同；投诉仅盘点C-021。

**目标操作流程**：读当前好友→显示设置→资料/选人/搜索分别路由→置顶免打扰真实更新→清空确认→成功清SDK记录和媒体/索引。

**失败、取消、网络/多端与边界**：非好友/注销后是否可读/操作按后台确认；取消不清；清成功但缓存清失败有恢复；头像点击不能绕关系限制。

**验收设计（尚未执行）**：

- **CHAT-030-A1**：入口/预选min1和200限制正确，与首页差异明确。
- **CHAT-030-A2**：清空成功指定会话DB/缓存/预览/搜索一致，失败不假清；投诉未自动恢复。

**源码依据**：[NoaChatSingleSetVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatSingleSetVC.m:158)；[NoaChatSingleSetVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatSingleSetVC.m:189)；[NoaChatSingleSetVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatSingleSetVC.m:142)；[NoaChatSingleSetVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatSingleSetVC.m:327)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-031"></a>
### CHAT-031 会话内文本/媒体/文件分类搜索与成员筛选

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧ChatHistory分类text/@、图片视频、文件，SDKtoolGetChatMessageHistoryWith(session,offset0,type,textLike,userIdList)单次limit50；group.closeSearchUser隐藏成员筛选。

**场景、入口与前置**：单群设置查聊天记录；当前可见本地历史。

**字段与规则**：50是一次本地查询限制非用户永久只许50；后续分页/服务全文更多本轮未确证；文本/文件名/成员组合。

**目标操作流程**：选类→输入/选成员→查询→结果→点击原文或媒体→清空重置→回页保合理上下文。

**失败、取消、网络/多端与边界**：关键词变化旧结果隔离；被删/撤回/到期索引清除；禁成员搜索不能借筛选直接资料；超过50更多能力待确认。

**验收设计（尚未执行）**：

- **CHAT-031-A1**：分类/关键词/成员组合与隐藏开关正确，不标云端无限搜索。
- **CHAT-031-A2**：结果删除/回跳/清空/无匹配一致，50边界与更多真实契约另核。

**源码依据**：[NoaChatHistoryVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatHistoryVC.m:84)；[NoaChatHistoryTextVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatHistoryTextVC.m:149)；[NoaChatHistoryFileVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatHistoryFileVC.m:88)；[NoaIMSDKManager+ChatMessage.m](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:316)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-032"></a>
### CHAT-032 媒体/文件详情、下载与系统分享打开

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧媒体KNPhotoBrowser，文件ChatFileDetail含下载、转发等；合并记录内isShowRightBtnNO。

**场景、入口与前置**：气泡/历史分类/合并记录点资源；当前访问权限与有效资源。

**字段与规则**：状态可用/未下载/下载中/失败/失效/本地已存；原图视频封面文件区别；远程相对路径和账号隔离缓存。

**目标操作流程**：查本地→下载/进度→预览/播放→用户保存/系统打开/分享/转发/收藏→返回原定位。

**失败、取消、网络/多端与边界**：无系统权限/格式不支持/断网/资源到期/磁盘不足/原文删除/换Host，用户取消可恢复；不可误显示合并内右操作。

**验收设计（尚未执行）**：

- **CHAT-032-A1**：状态、资源原图/封面/视频/文件和系统操作真实；失败有下一步。
- **CHAT-032-A2**：合并内操作矩阵与普通文件不同，返回聊天原浏览位置稳定。

**源码依据**：[NoaChatHistoryMediaVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatHistoryMediaVC.m:73)；[NoaChatFileDetailViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatFileDetailViewController.m:237)；[NoaChatRecordDetailViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatRecordDetailViewController.m:50)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-033"></a>
### CHAT-033 群设置总入口与0/1/2角色矩阵

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧GroupSet含群信息/成员/二维码公告/管理/查记录/top/mute/我的群昵称/清空/投诉/退出；普通0无管理，1/2可管理，清空受deleteMessage。

**场景、入口与前置**：群聊天右上设置；getGroupInfo及真实当前role。

**字段与规则**：0成员/1管理/2群主；群groupStatus、历史/QR/私聊/成员可见；不能只用“有管理权限”概括所有动作。

**目标操作流程**：缓存群资料→真实刷新→按角色/role/系统配置生成行→每项进入复核→事件改行与操作能力。

**失败、取消、网络/多端与边界**：群不存在/被踢/解散/角色降级/成员未同步/断网，提示并禁合法性未知操作；不凭库缓存可读代表可管理。

**验收设计（尚未执行）**：

- **CHAT-033-A1**：三角色和关键开关矩阵正确，普通看不到管理员动作。
- **CHAT-033-A2**：开页后降权不能通过旧行继续提交，退群/解散关闭对应页面。

**源码依据**：[NoaChatGroupSetVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatGroupSetVC.m:139)；[NoaChatGroupSetVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatGroupSetVC.m:169)；[NoaChatGroupSetVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatGroupSetVC.m:208)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-034"></a>
### CHAT-034 群头像、群名称与资料编辑权限

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧群资料cell点击编辑头像/名称只role1/2；ChangeGroupAvatar(groupId,avatar,userUid)/ChangeGroupName(groupId,groupName,userUid)真实更新，成功同步session头像名称。

**场景、入口与前置**：群设置信息→基本资料；1/2且服务端允许；相机/相册授权。

**字段与规则**：groupName/avatar真实字段；群名称长度本轮未统一确认不造数；不能只见控制器可跳就声称全员可编辑。

**目标操作流程**：打开只读/可编辑→改名或选照片→上传/接口→成功SDK群/会话资料刷新→另端变化。

**失败、取消、网络/多端与边界**：普通只读；上传成功接口失败保旧图；取消/空名/重复/角色变更/换号隔离；姓名和成员群昵称分开。

**验收设计（尚未执行）**：

- **CHAT-034-A1**：普通0不可编辑，1/2与服务端规则一致，保存成功群/会话两处同步。
- **CHAT-034-A2**：上传/保存失败保原值，另端改名/头像后当前页刷新。

**源码依据**：[NoaChatSetGroupInfoCell.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Views/GroupSet/NoaChatSetGroupInfoCell.m:281)；[NoaGroupSetBasicInfoVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupSetBasicInfoVC.m:178)；[NoaGroupModifyNameVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupModifyNameVC.m:114)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-035"></a>
### CHAT-035 群成员预览、成员列表、人数与资料守卫

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧群主→管理→普通层次；showGroupPersonNum或群adminOnly控制人数；普通预览5+邀请，管理4+邀请/删除；lastSyncMemberTime!=0才进列表，groupSecurity可绕禁私聊，普通isPrivateChat禁资料。

**场景、入口与前置**：群设置成员/头像、聊天头像；成员真实同步完成。

**字段与规则**：成员UID/role/remarks/group nickname/showName；本人/群主/机器人等分层；成员人数显示和是否可访问资料不是同一权限。

**目标操作流程**：显示合法预览/人数→完整列表→排序/搜索范围按真实页→选择资料→校验群私聊与安全角色→C-015。

**失败、取消、网络/多端与边界**：未同步不给空列表假完成；名单降权/成员退出/群被移除及时更新；多个入口包括聊天头像统一守卫；分页容量未知不臆造。

**验收设计（尚未执行）**：

- **CHAT-035-A1**：0/1/2人数和预览规则、不同groupSecurity/私聊组合准确。
- **CHAT-035-A2**：未同步阻跳，聊天头像/设置/名单都不能绕过资料限制。

**源码依据**：[NoaChatGroupSetVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatGroupSetVC.m:281)；[NoaChatSetGroupInfoCell.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Views/GroupSet/NoaChatSetGroupInfoCell.m:197)；[NoaGroupMemberListVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupMemberListVC.m:135)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:5053)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-036"></a>
### CHAT-036 我的群昵称、30字符与跨端名称刷新

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧群昵称<=30字符trim，空恢复本人昵称，未变禁完成；groupMyNicknameWith(groupId,groupNickname,userUid)成功更新groupInfo并重建成员表。

**场景、入口与前置**：群设置我的群昵称；当前已在群。

**字段与规则**：群内昵称不是好友备注，优先备注→群昵称→个人昵称的气泡/列表展示要依当前实际模型；新旧GroupMemberNick专用同步回调未确证。

**目标操作流程**：预填→编辑校验→未变禁完成→保存→成功SDK群/成员→会话群发送者/气泡/@列表刷新。

**失败、取消、网络/多端与边界**：30字符emoji口径按旧text确认；失败留输入/取消原值；不同群同UID不串昵称；迟到跨号/退出群结果失效。

**验收设计（尚未执行）**：

- **CHAT-036-A1**：0/30/超过、空恢复、未变禁用正确。
- **CHAT-036-A2**：成功后两端预览/气泡/@列表更新，并验证专用同步契约，不能只因Socket有事件就称UI通过。

**源码依据**：[NoaGroupMyNicknameVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaGroupMyNicknameVC.m:148)；[NoaGroupMyNicknameVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaGroupMyNicknameVC.m:159)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-037"></a>
### CHAT-037 邀请好友进群、排除已有成员及审核原因

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧GroupInvite排已在成员，角色1/2直接提交、普通isNeedVerify需原因；groupInviteFriendWith(groupId,inviteDesc,groupMemberParams[{userUid,nickName}],userUid)。

**场景、入口与前置**：群设置邀请；当前成员身份及群邀请策略。

**字段与规则**：当前群成员排重，候选好友过滤系统/注销；选人跨搜索/分组同UID统一，不照搬建群容量。

**目标操作流程**：读群策略/成员→选合法好友→普通需审填原因→提交→直入或等待审批→回读成员/通知。

**失败、取消、网络/多端与边界**：已入/删好友/空理由/权限收回/服务器容量/重复申请/部分失败处理；需审不直接写新成员；取消不邀请。

**验收设计（尚未执行）**：

- **CHAT-037-A1**：普通需审/不需审与1/2路径准确，已入/系统/注销不可重复选。
- **CHAT-037-A2**：真实加入与待审有不同结果，二端成员/@/人数同步。

**源码依据**：[NoaChatGroupSetVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatGroupSetVC.m:312)；[NoaGroupInviteFriendVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupInviteFriendVC.m:222)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-038"></a>
### CHAT-038 移除群成员与同时删除其发言

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧取除群主成员，GroupRemove(groupMemberUidList,delMemberMsg,groupId,userUid)，成功删成员缓存，选删消息时删该成员发言。

**场景、入口与前置**：管理/群主删除成员入口；当前目标/角色合法。

**字段与规则**：群主不可误选；管理能否移其他管理/自己和最低保留人数待联调；delMemberMsg是附加范围不默认勾。

**目标操作流程**：选择成员→确认移除及可选发言删除范围→提交→成功SDK成员/消息更新→被移方禁发/清对应会话。

**失败、取消、网络/多端与边界**：目标已退出/角色变更/部分失败/消息删除失败需提示阶段；取消不处理；不能管理员无条件压群主。

**验收设计（尚未执行）**：

- **CHAT-038-A1**：合法角色/目标矩阵明确、群主保护、delMemberMsg开关分别验收。
- **CHAT-038-A2**：被移端与群其他端成员和发言范围一致，失败不假移除。

**源码依据**：[NoaGroupRemoveFriendVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupRemoveFriendVC.m:47)；[NoaGroupRemoveFriendVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupRemoveFriendVC.m:112)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3578)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-039"></a>
### CHAT-039 群管理菜单与逐项授权

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧群管理1/2有机器人、全员/单人禁言、活跃、私聊、邀请确认、申请、新历史、提示、二维码、音视频；群主另外转让/设置管理/解散。

**场景、入口与前置**：群设置管理；role1/2及群最新info。

**字段与规则**：每个菜单自己的角色/开关，role3/超级权限本轮未明确；当前newRoleAuthority不替代群role。

**目标操作流程**：加载真实策略/统计→各行显当前值→对应真实接口→成功回读→另端角色/菜单即时更新。

**失败、取消、网络/多端与边界**：接口失败不可仅改开关本地；后台/降级关闭旧弹窗；机器人只查列表不造创建删除。

**验收设计（尚未执行）**：

- **CHAT-039-A1**：普通0无管理，管理与群主差异具体到每行。
- **CHAT-039-A2**：各开关成功失败和另端同步可独立验收，不把有群列表当群管理完成。

**源码依据**：[NoaGroupManageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupManageVC.m:334)；[NoaGroupManageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupManageVC.m:453)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-040"></a>
### CHAT-040 全员/单人/永久禁言与解除

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧全员禁言普通生效、1/2豁免；个体isGroupForbid/start/end；单人expireTime分钟10/60/720/1440/10080/43200/-1永久，operationType1禁/0解，永久二次确认。

**场景、入口与前置**：群管理/头像长按；管理/群主合法目标。

**字段与规则**：groupSetNotalkAllWith(groupId,userUid,operationType字符串)、groupSetNotalkMemberWith(expireTime,forbidUidList,operationType)；已禁列表和目标角色保护。

**目标操作流程**：查看当前禁言→选择对象/期限→永久确认→提交→回读列表/群状态→目标输入栏变禁言→到期/解除恢复。

**失败、取消、网络/多端与边界**：禁止管理任意覆盖群主；群全员与个人叠加、时间偏差、重连/后台到期/解除事件、批量部分失败；-1不能当1分钟。

**验收设计（尚未执行）**：

- **CHAT-040-A1**：7期限/1和0操作及角色豁免准确，永久确认/取消正确。
- **CHAT-040-A2**：目标即时禁发，文本/语音/附件/@/转发均被守卫；过期/解除二端恢复。

**源码依据**：[NoaGroupManageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupManageVC.m:117)；[NoaGroupSetNotalkMemberVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupSetNotalkMemberVC.m:142)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:676)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:1024)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:5096)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-041"></a>
### CHAT-041 群入群申请列表、审核与成员同步依赖

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧管理和全局通知两来源，申请单/批同意拒绝真接口；群邀请确认开关控制需审核，与好友申请无拒绝不同。

**场景、入口与前置**：群管理申请→M-021专用页；管理权限有效。

**字段与规则**：来源groupID、申请ID集合、status1同意/2拒；申请过期/已处理字段以服务返回；二维码inviteType4来自C-032。

**目标操作流程**：显示当前群申请→选择处理→提交→回查申请状态→批准后群成员同步→申请方看到真实结果。

**失败、取消、网络/多端与边界**：另一管理已处理、群已解散/降权/人数满/部分失败清楚；批准请求成功但成员延迟不假入。

**验收设计（尚未执行）**：

- **CHAT-041-A1**：群审批有拒绝/批量真实分支，好友不复用该状态。
- **CHAT-041-A2**：批准/拒绝两端关系和通知正确，重复/降权不能继续审批。

**源码依据**：[NoaSystemMessagePendReviewVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/SystemMessageApply/NoaSystemMessagePendReviewVC.m:182)；[NoaGroupManageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupManageVC.m:1125)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-042"></a>
### CHAT-042 群主转让与管理员增减

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧群主入口groupGetManagerList、groupSetGroupManagerWith(groupMemberUidList,status)；groupChangeGroupOwnerWith(groupId,ownerUid,userUid)，成功更新双方角色。

**场景、入口与前置**：群主群管理；目标有效成员不是当前群主误选。

**字段与规则**：管理员配置status和批量目标；group主唯一；转让与原主退出分阶段，不能成功前变本地身份。

**目标操作流程**：选人→确认→真实请求→成功SDK成员/群info→新主权限、原主降级→按需原主再退。

**失败、取消、网络/多端与边界**：失败保持旧身份、另一端角色变化失效、目标离群/注销；管理员数量上限未确认不造数。

**验收设计（尚未执行）**：

- **CHAT-042-A1**：仅当前群主能设置管理/转让，群主不能误列普通管理。
- **CHAT-042-A2**：转让成功双方角色/输入/管理菜单同步；失败不得先退出或清记录。

**源码依据**：[NoaGroupSetManagerOwnerVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupSetManagerOwnerVC.m:54)；[NoaGroupSetGroupManagerVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupSetGroupManagerVC.m:109)；[NoaGroupChangeOwnerVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupChangeOwnerVC.m:105)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-043"></a>
### CHAT-043 群私聊、历史、提示、二维码及通话开关

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧groupSetPrivateChatStatus/status字符串、groupSetJoinGroupStatus字符串；新成员历史status数字；Remind/QRCode/AudioVideo等专用键，不能统一假写一个status。

**场景、入口与前置**：群管理各开关；角色允许、群现值已取。

**字段与规则**：PrivateChatStatus/JoinGroupStatus、NewMemberHistory、GroupRemind、IsShowQrCode、AudioAndVideoCallStatus分别以旧方法真实键；数字/字符串差异需遵契约。

**目标操作流程**：显示旧值→用户改→真实接口→成功回读→私聊资料守卫、审核、历史页、公告/系统提示、二维码、通话菜单联动。

**失败、取消、网络/多端与边界**：失败回原值；已开资料/扫码/历史/通话受动态收回约束；旧群成员历史可见与是否保存本地历史另政策。

**验收设计（尚未执行）**：

- **CHAT-043-A1**：每开关参数/单位/类型明确，页面联动正确。
- **CHAT-043-A2**：默认/格式非法/动态收回/多端同步矩阵覆盖，未映射新系统字段不当可用。

**源码依据**：[NoaGroupManageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupManageVC.m:1097)；[NoaGroupManageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupManageVC.m:1125)；[NoaGroupManageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupManageVC.m:186)；[NoaGroupManageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupManageVC.m:242)；[NoaGroupManageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupManageVC.m:264)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-044"></a>
### CHAT-044 群公告列表、详情、创建编辑删除及已读

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧聊天顶部/群设置公告可达，20条分页、置顶/普通按时间；1/2可建改删，普通读；可置顶/发送群消息/多语言翻译，detail checkOneNotice已读。

**场景、入口与前置**：聊天公告栏/群设置公告；当前群关系/角色。

**字段与规则**：公告ID/内容/时间/置顶/发送群消息/语言；公告置顶不同聊天消息pin，旧有公告会隐藏消息pin条是需审阅交互差异。

**目标操作流程**：列表→详情/已读→1/2创建或编辑→校验→提交→成功回查→顶部提示/群消息/语言更新；删除确认。

**失败、取消、网络/多端与边界**：空内容/上传或翻译资源失败/20页边界/他端删公告/降权/返回；失败保输入/旧列表；普通不能经详情绕编辑。

**验收设计（尚未执行）**：

- **CHAT-044-A1**：20条分页与置顶分区正确，0只读/1和2编辑创建删除准确。
- **CHAT-044-A2**：成功后各端公告栏与已读提示同步；失败/取消保原，删除详情有退路。

**源码依据**：[NoaGroupNoticeListVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupNoticeListVC.m:25)；[NoaGroupModifyNoticeVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupModifyNoticeVC.m:25)；[NoaGroupNoticeDetailVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupNoticeDetailVC.m:25)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-045"></a>
### CHAT-045 退出群、转让前置与群主解散

**新状态：未接｜建议P2｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧群主退出先提示移交，0/1 groupQuitWith(groupId,userUid)成功删会话/历史/媒体，另删server conversation；群主解散groupDissolutionGroupWith只有groupId/userUid，无operationStatus模式证据。

**场景、入口与前置**：群设置退出或群主管理解散；明确影响范围及身份。

**字段与规则**：本人退出与全群解散不同；是否“无感”解散文案的后端语义待联调，不造额外模式；阶段性清理状态。

**目标操作流程**：确认→群主先转让或选择解散→真实请求→成功SDK关系/会话/消息/资源清理→退页→多端收到群事件。

**失败、取消、网络/多端与边界**：取消/失败保持关系；请求成功后局部清失败可恢复；解散/被踢页面不能发，重启/历史补页不能复活无效群。

**验收设计（尚未执行）**：

- **CHAT-045-A1**：0/1退出、群主转让前置、仅群主解散各正确。
- **CHAT-045-A2**：成功清对应群，不误清其他聊天；被移/解散各端禁发和退页一致。

**源码依据**：[NoaChatGroupSetVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatGroupSetVC.m:643)；[NoaChatGroupSetVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatGroupSetVC.m:671)；[NoaGroupManageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupManageVC.m:136)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-046"></a>
### CHAT-046 音视频发起、群选择与LiveKit/Zego依赖

**新状态：需取舍｜建议P3｜独立通话范围待取舍｜范围：独立媒体业务。**

**旧项目已见行为（静态证据）**：旧输入/好友主页可达真实通话，enableAudioAndVideoCalls开关、普通群isNetCall禁发起、注销禁；video_source_config0 LiveKit/1 Zego，实际媒体界面独立模块。

**场景、入口与前置**：未来批准：聊天输入/好友详情音视频；麦克风/相机、未已有通话、系统部署可用。

**字段与规则**：本人/对端UID或群成员列表；系统字段新未映射；call状态与MessageType20历史通话气泡分开。

**目标操作流程**：检查角色/群/系统/资源权限→选人→真实发起→连接/接受/拒绝/取消/结束→通话记录；具体来电页需独立全链需求。

**失败、取消、网络/多端与边界**：已在通话/拒权/无人接/超时/后台/断网/被踢/路由服务不可用；仅依赖链接不算能力，不能假来电/假接通。

**验收设计（尚未执行）**：

- **CHAT-046-A1**：未来选定后两种服务路由和单群权限正确，有真实呼叫回执。
- **CHAT-046-A2**：历史通话消息可展示与实际发起分开，未批准不默认P1迁移整个媒体模块。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:298)；[NoaUserHomePageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaUserHomePageVC.m:582)；[NoaChatInputFunctionView.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Base/Base/Views/NoaInputView/NoaChatInputFunctionView.m:55)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-047"></a>
### CHAT-047 群机器人只读列表与活跃等级

**新状态：需取舍｜建议P3｜扩展群能力待取舍｜范围：关联扩展群业务。**

**旧项目已见行为（静态证据）**：旧管理真机器人count/list，只读NoaRobotListViewController，活跃开关及ChatActivityLevel页；未确认创建删除机器人UI。

**场景、入口与前置**：群管理机器人/活跃；1/2合法入口。

**字段与规则**：robotCount/list字段和群活动等级来自真实服务/成员缓存；不承诺机器人编排、添加删除和自动回复。

**目标操作流程**：显示计数→真实列表→空/失败/资料可读范围；活跃开关→回读→展示真实等级；涉及新UI另审。

**失败、取消、网络/多端与边界**：角色降级/空列表/网错/机器人资料权限/缓存过期；不能把机器人头像当普通好友无守卫。

**验收设计（尚未执行）**：

- **CHAT-047-A1**：只读列表及计数真实，空/错误区别，无虚构创建删除。
- **CHAT-047-A2**：活跃等级开关/展示联动与权限正确，后端未开放明确暂不可用。

**源码依据**：[NoaGroupManageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupManageVC.m:50)；[NoaRobotListViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaRobotListViewController.m:28)；[NoaChatActivityLevelVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatActivityLevelVC.m:86)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-048"></a>
### CHAT-048 业务事件、群角色与昵称同步回流合同

**新状态：未接｜建议P1｜建议迁移｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧Edited/Owner/Admin/Name/禁言/历史/通话/通知/公告/Top/Kick/Out/DelGroup/ScheduleDelete/Back/Bilateral等事件重取对应数据或更新原条；新真实聊天事件未接。

**场景、入口与前置**：SDK真实事件或重连补同步；当前所属UID/group/session。

**字段与规则**：事件与普通正文分流；GroupMemberNick专用回调在两个工作树未确证，不引用其他版本记忆当既有；同会话也需generation。

**目标操作流程**：识别→更新群/成员/消息/权限真实库→刷新页面/列表/索引/草稿允许状态→必要退页；去重及后到校验。

**失败、取消、网络/多端与边界**：A→B→A会话/账号交错、后台/重连/重复事件、群成员昵称/备注优先、多端已读；先变UI而库未变可在重启复活需避免。

**验收设计（尚未执行）**：

- **CHAT-048-A1**：附录事件每类有后续验收，正文/引用/群菜单/输入一致。
- **CHAT-048-A2**：昵称更新最终UI证据和当前新SDK真实接口待联调，不以Socket收到代替完成。

**源码依据**：[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3448)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3461)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3514)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3578)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3650)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:4451)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

<a id="CHAT-049"></a>
### CHAT-049 未知消息、旧消息兼容及生命周期清理

**新状态：未接｜建议P1｜基础兼容建议迁移；加密/阅后发起另取舍｜范围：关联真实单群聊。**

**旧项目已见行为（静态证据）**：旧有多消息类型/系统事件，当前新仅会话类型预览；真实聊天未知类型、加密/阅后属性和版本兼容仍需根据实际模型确认。

**场景、入口与前置**：历史新旧混合消息、资源不完整、账号退出/俱乐部切换。

**字段与规则**：模型原ID/类型/发送时间/已读/引用/加密与扩展不能被新UI丢弃；显示未知占位不代表支持发送所有类型。

**目标操作流程**：可识别类型正确呈现→未知清晰兼容占位→留原SDK记录→可读缓存；退出清当前用户观察/任务/展示并阻旧回执，资源按政策清理。

**失败、取消、网络/多端与边界**：不丢未支持历史、不显示协议原文或敏感二进制；未独立确证阅后/加密聊天配置和发起UI，列待验证不承诺新增；附件/ACK跨账号禁止。

**验收设计（尚未执行）**：

- **CHAT-049-A1**：未知类型有可理解占位，原记录不因UI不支持被删除。
- **CHAT-049-A2**：退出/切号/节点恢复迟到历史、上传、读回执、昵称和权限结果都隔离。

**源码依据**：[NoaIMChatMessageModel.h](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/Models/ChatModels/NoaIMChatMessageModel.h:103)；[NoaChatViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:2316)；[LoginSessionService.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Login/Services/LoginSessionService.swift:178)；[ChatScreen.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Views/ChatScreen.swift:142)。

## 六、消息/会话/群接口静态存在索引

下表按本轮调查实际ObjC方法首段名称核对96项，其中95项在新SDK本地实现存在，1项toolGetSignInSession明确缺失。**仅证明静态方法存在，尚未验证Swift桥接签名、参数/返回结构、数据库时序、真实后端行为或完整兼容。**各业务输入、成功/失败/取消和验收以对应M/CHAT卡片为准；不是开发清单或实施授权。不补写未经核实HTTP endpoint。

表内只证明Objective-C实现存在；Swift公开header/导入别名、返回结构兼容和真实服务器行为需实施时核对。存在不等于新应用已接入。表中“未在限定目录定位”仅是方法名/搜索目录未匹配，不声称产品无能力。

|方法首段名称|旧SDK实现|新SDK实现|迁移解释|
|---|---|---|---|
|`toolSendChatMessageWith`|[NoaIMSDKManager+ChatMessage.m:48](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:48)|[NoaIMSDKManager+ChatMessage.m:48](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:48)|实现存在，应用尚未接聊天/操作|
|`toolDealReceiveChatMessage`|[NoaIMSDKManager+ChatMessage.m:89](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:89)|[NoaIMSDKManager+ChatMessage.m:89](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:89)|实现存在，应用尚未接聊天/操作|
|`toolInsertOrUpdateChatMessageWith`|[NoaIMSDKManager+ChatMessage.m:350](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:350)|[NoaIMSDKManager+ChatMessage.m:348](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:348)|实现存在，应用尚未接聊天/操作|
|`toolInsertOrUpdateSessionWith`|[NoaIMSDKManager+Session.m:28](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Session.m:28)|[NoaIMSDKManager+Session.m:22](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Session.m:22)|实现存在，应用尚未接聊天/操作|
|`toolGetOneChatMessageWithMessageID`|[NoaIMSDKManager+ChatMessage.m:493](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:493)|[NoaIMSDKManager+ChatMessage.m:491](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:491)|实现存在，应用尚未接聊天/操作|
|`messageGetHistoryRecordWith`|[NoaIMSDKManager+ChatMessage.m:1040](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1040)|[NoaIMSDKManager+ChatMessage.m:1038](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1038)|实现存在，应用尚未接聊天/操作|
|`toolGetChatMessageHistoryWith`|[NoaIMSDKManager+ChatMessage.m:285](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:285)|[NoaIMSDKManager+ChatMessage.m:285](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:285)|实现存在，应用尚未接聊天/操作|
|`querySingleMsgRecord`|[NoaIMSDKManager+ChatMessage.m:830](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:830)|[NoaIMSDKManager+ChatMessage.m:828](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:828)|实现存在，应用尚未接聊天/操作|
|`queryGroupMsgRecord`|[NoaIMSDKManager+ChatMessage.m:836](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:836)|[NoaIMSDKManager+ChatMessage.m:834](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:834)|实现存在，应用尚未接聊天/操作|
|`editMessage`|[NoaIMSDKManager+ChatMessage.m:1454](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1454)|[NoaIMSDKManager+ChatMessage.m:1452](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1452)|实现存在，应用尚未接聊天/操作|
|`deleteMessage`|[NoaIMSDKManager+ChatMessage.m:860](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:860)|[NoaIMSDKManager+ChatMessage.m:858](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:858)|实现存在，应用尚未接聊天/操作|
|`recallMessage`|[NoaIMSDKManager+ChatMessage.m:866](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:866)|[NoaIMSDKManager+ChatMessage.m:864](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:864)|实现存在，应用尚未接聊天/操作|
|`toolBackDeleteChatMessageWith`|[NoaIMSDKManager+ChatMessage.m:449](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:449)|[NoaIMSDKManager+ChatMessage.m:447](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:447)|实现存在，应用尚未接聊天/操作|
|`toolDeleteChatMessageWith`|[NoaIMSDKManager+ChatMessage.m:394](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:394)|[NoaIMSDKManager+ChatMessage.m:392](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:392)|实现存在，应用尚未接聊天/操作|
|`clearChatMessageHistory`|[NoaIMSDKManager+ChatMessage.m:813](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:813)|[NoaIMSDKManager+ChatMessage.m:811](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:811)|实现存在，应用尚未接聊天/操作|
|`toolDeleteGroupMemberAllSendMessageWith`|[NoaIMSDKManager+ChatMessage.m:525](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:525)|[NoaIMSDKManager+ChatMessage.m:523](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:523)|实现存在，应用尚未接聊天/操作|
|`singleConversationTop`|[NoaIMSDKManager+ChatMessage.m:763](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:763)|[NoaIMSDKManager+ChatMessage.m:761](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:761)|实现存在，应用尚未接聊天/操作|
|`groupConversationTop`|[NoaIMSDKManager+ChatMessage.m:690](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:690)|[NoaIMSDKManager+ChatMessage.m:688](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:688)|实现存在，应用尚未接聊天/操作|
|`singleConversationPromt`|[NoaIMSDKManager+ChatMessage.m:730](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:730)|[NoaIMSDKManager+ChatMessage.m:728](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:728)|实现存在，应用尚未接聊天/操作|
|`groupConversationPromt`|[NoaIMSDKManager+ChatMessage.m:659](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:659)|[NoaIMSDKManager+ChatMessage.m:657](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:657)|实现存在，应用尚未接聊天/操作|
|`conversationReadedStatus`|[NoaIMSDKManager+ChatMessage.m:807](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:807)|[NoaIMSDKManager+ChatMessage.m:805](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:805)|实现存在，应用尚未接聊天/操作|
|`deleteServerConversation`|[NoaIMSDKManager+ChatMessage.m:646](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:646)|[NoaIMSDKManager+ChatMessage.m:644](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:644)|实现存在，应用尚未接聊天/操作|
|`ackConversationRead`|[NoaIMSDKManager+ChatMessage.m:653](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:653)|[NoaIMSDKManager+ChatMessage.m:651](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:651)|实现存在，应用尚未接聊天/操作|
|`toolSessionListAllRead`|[NoaIMSDKManager+Session.m:560](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Session.m:560)|[NoaIMSDKManager+Session.m:543](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Session.m:543)|实现存在，应用尚未接聊天/操作|
|`toolOneSessionAllReadWith`|[NoaIMSDKManager+Session.m:555](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Session.m:555)|[NoaIMSDKManager+Session.m:538](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Session.m:538)|实现存在，应用尚未接聊天/操作|
|`toolGetMySessionListExcept`|[NoaIMSDKManager+Session.m:501](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Session.m:501)|[NoaIMSDKManager+Session.m:491](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Session.m:491)|实现存在，应用尚未接聊天/操作|
|`toolGetMyTopSessionListExcept`|[NoaIMSDKManager+Session.m:527](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Session.m:527)|[NoaIMSDKManager+Session.m:516](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Session.m:516)|实现存在，应用尚未接聊天/操作|
|`toolGetSignInSession`|[NoaIMSDKManager+Session.m:19](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Session.m:19)|未在SdkManager实现定位，待验证|需确认别名/调用所属层|
|`toolSearchMyFriendWith`|[NoaIMSDKManager+Friend.m:70](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Friend.m:70)|[NoaIMSDKManager+Friend.m:70](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Friend.m:70)|实现存在，应用尚未接聊天/操作|
|`toolSearchMyGroupWith`|[NoaIMSDKManager+Group.m:374](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:374)|[NoaIMSDKManager+Group.m:374](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:374)|实现存在，应用尚未接聊天/操作|
|`toolSearchMessageWith`|[NoaIMSDKManager+ChatMessage.m:578](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:578)|[NoaIMSDKManager+ChatMessage.m:576](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:576)|实现存在，应用尚未接聊天/操作|
|`transpondComplianceMessage`|[NoaIMSDKManager+ChatMessage.m:854](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:854)|[NoaIMSDKManager+ChatMessage.m:852](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:852)|实现存在，应用尚未接聊天/操作|
|`transpondMessage`|[NoaIMSDKManager+ChatMessage.m:848](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:848)|[NoaIMSDKManager+ChatMessage.m:846](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:846)|实现存在，应用尚未接聊天/操作|
|`MessageUserCardRecommend`|[NoaIMSDKManager+ChatMessage.m:1342](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1342)|[NoaIMSDKManager+ChatMessage.m:1340](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1340)|实现存在，应用尚未接聊天/操作|
|`MessageQueryGroupMsgStatusWith`|[NoaIMSDKManager+ChatMessage.m:1429](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1429)|[NoaIMSDKManager+ChatMessage.m:1427](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1427)|实现存在，应用尚未接聊天/操作|
|`MessageQueryUserMsgStatusWith`|[NoaIMSDKManager+ChatMessage.m:1439](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1439)|[NoaIMSDKManager+ChatMessage.m:1437](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1437)|实现存在，应用尚未接聊天/操作|
|`groupSetMsgTopWith`|[NoaIMSDKManager+Group.m:379](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:379)|[NoaIMSDKManager+Group.m:379](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:379)|实现存在，应用尚未接聊天/操作|
|`MessageSetMsgTopWith`|[NoaIMSDKManager+ChatMessage.m:1444](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1444)|[NoaIMSDKManager+ChatMessage.m:1442](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1442)|实现存在，应用尚未接聊天/操作|
|`MessageQueryGroupTopMsgsWith`|[NoaIMSDKManager+ChatMessage.m:1434](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1434)|[NoaIMSDKManager+ChatMessage.m:1432](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1432)|实现存在，应用尚未接聊天/操作|
|`MessageQueryUserTopMsgsWith`|[NoaIMSDKManager+ChatMessage.m:1449](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1449)|[NoaIMSDKManager+ChatMessage.m:1447](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1447)|实现存在，应用尚未接聊天/操作|
|`MessageTimeDeleteInfoWith`|[NoaIMSDKManager+ChatMessage.m:1348](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1348)|[NoaIMSDKManager+ChatMessage.m:1346](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1346)|实现存在，应用尚未接聊天/操作|
|`MessageTimeDeleteSetWith`|[NoaIMSDKManager+ChatMessage.m:1353](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1353)|[NoaIMSDKManager+ChatMessage.m:1351](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1351)|实现存在，应用尚未接聊天/操作|
|`groupGetUserNotalkStateWith`|[NoaIMSDKManager+Group.m:261](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:261)|[NoaIMSDKManager+Group.m:261](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:261)|实现存在，应用尚未接聊天/操作|
|`groupGetNotalkListWith`|[NoaIMSDKManager+Group.m:194](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:194)|[NoaIMSDKManager+Group.m:194](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:194)|实现存在，应用尚未接聊天/操作|
|`groupSetNotalkMemberWith`|[NoaIMSDKManager+Group.m:199](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:199)|[NoaIMSDKManager+Group.m:199](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:199)|实现存在，应用尚未接聊天/操作|
|`groupSetNotalkAllWith`|[NoaIMSDKManager+Group.m:204](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:204)|[NoaIMSDKManager+Group.m:204](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:204)|实现存在，应用尚未接聊天/操作|
|`getGroupInfoWith`|[NoaIMSDKManager+Group.m:15](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:15)|[NoaIMSDKManager+Group.m:15](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:15)|实现存在，应用尚未接聊天/操作|
|`imSdkGetAllGroupMemberWith`|[NoaIMSDKManager+GroupMember.m:66](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+GroupMember.m:66)|[NoaIMSDKManager+GroupMember.m:66](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+GroupMember.m:66)|实现存在，应用尚未接聊天/操作|
|`groupSetPrivateChatStatusWith`|[NoaIMSDKManager+Group.m:301](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:301)|[NoaIMSDKManager+Group.m:301](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:301)|实现存在，应用尚未接聊天/操作|
|`groupSetJoinGroupStatusWith`|[NoaIMSDKManager+Group.m:306](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:306)|[NoaIMSDKManager+Group.m:306](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:306)|实现存在，应用尚未接聊天/操作|
|`groupNewMemberCheckHistoryStatusWith`|[NoaIMSDKManager+Group.m:331](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:331)|[NoaIMSDKManager+Group.m:331](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:331)|实现存在，应用尚未接聊天/操作|
|`groupUpdateGroupRemindSwitchStatusWith`|[NoaIMSDKManager+Group.m:316](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:316)|[NoaIMSDKManager+Group.m:316](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:316)|实现存在，应用尚未接聊天/操作|
|`groupUpdateIsShowQrCodeWith`|[NoaIMSDKManager+Group.m:324](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:324)|[NoaIMSDKManager+Group.m:324](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:324)|实现存在，应用尚未接聊天/操作|
|`groupUpdateAudioAndVideoCallStatusWith`|[NoaIMSDKManager+Group.m:311](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:311)|[NoaIMSDKManager+Group.m:311](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:311)|实现存在，应用尚未接聊天/操作|
|`groupUpdateActivityLevelEnableStatusWith`|[NoaIMSDKManager+Group.m:342](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:342)|[NoaIMSDKManager+Group.m:342](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:342)|实现存在，应用尚未接聊天/操作|
|`groupDissolutionGroupWith`|[NoaIMSDKManager+Group.m:224](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:224)|[NoaIMSDKManager+Group.m:224](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:224)|实现存在，应用尚未接聊天/操作|
|`groupQuitWith`|[NoaIMSDKManager+Group.m:117](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:117)|[NoaIMSDKManager+Group.m:117](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:117)|实现存在，应用尚未接聊天/操作|
|`groupChangeGroupOwnerWith`|[NoaIMSDKManager+Group.m:214](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:214)|[NoaIMSDKManager+Group.m:214](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:214)|实现存在，应用尚未接聊天/操作|
|`groupGetManagerListWith`|[NoaIMSDKManager+Group.m:249](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:249)|[NoaIMSDKManager+Group.m:249](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:249)|实现存在，应用尚未接聊天/操作|
|`groupSetGroupManagerWith`|[NoaIMSDKManager+Group.m:219](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:219)|[NoaIMSDKManager+Group.m:219](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:219)|实现存在，应用尚未接聊天/操作|
|`groupInviteFriendWith`|[NoaIMSDKManager+Group.m:183](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:183)|[NoaIMSDKManager+Group.m:183](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:183)|实现存在，应用尚未接聊天/操作|
|`groupRemoveMemberWith`|[NoaIMSDKManager+Group.m:150](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:150)|[NoaIMSDKManager+Group.m:150](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:150)|实现存在，应用尚未接聊天/操作|
|`changeGroupNameWith`|[NoaIMSDKManager+Group.m:27](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:27)|[NoaIMSDKManager+Group.m:27](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:27)|实现存在，应用尚未接聊天/操作|
|`changeGroupAvatarWith`|[NoaIMSDKManager+Group.m:55](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:55)|[NoaIMSDKManager+Group.m:55](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:55)|实现存在，应用尚未接聊天/操作|
|`groupMyNicknameWith`|[NoaIMSDKManager+Group.m:145](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:145)|[NoaIMSDKManager+Group.m:145](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:145)|实现存在，应用尚未接聊天/操作|
|`groupCheckGroupNoticeWith`|[NoaIMSDKManager+Group.m:170](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:170)|[NoaIMSDKManager+Group.m:170](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:170)|实现存在，应用尚未接聊天/操作|
|`groupCheckOneGroupNoticeWith`|[NoaIMSDKManager+Group.m:174](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:174)|[NoaIMSDKManager+Group.m:174](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:174)|实现存在，应用尚未接聊天/操作|
|`groupReadGroupNoticeWith`|[NoaIMSDKManager+Group.m:178](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:178)|[NoaIMSDKManager+Group.m:178](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:178)|实现存在，应用尚未接聊天/操作|
|`groupChangeGroupNoticeWith`|[NoaIMSDKManager+Group.m:165](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:165)|[NoaIMSDKManager+Group.m:165](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:165)|实现存在，应用尚未接聊天/操作|
|`groupCreateGroupNoticeWith`|[NoaIMSDKManager+Group.m:155](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:155)|[NoaIMSDKManager+Group.m:155](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:155)|实现存在，应用尚未接聊天/操作|
|`groupDeleteGroupNoticeWith`|[NoaIMSDKManager+Group.m:160](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:160)|[NoaIMSDKManager+Group.m:160](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:160)|实现存在，应用尚未接聊天/操作|
|`groupGetRobotCountWith`|[NoaIMSDKManager+Group.m:257](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:257)|[NoaIMSDKManager+Group.m:257](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:257)|实现存在，应用尚未接聊天/操作|
|`groupGetRobotListWith`|[NoaIMSDKManager+Group.m:253](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:253)|[NoaIMSDKManager+Group.m:253](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:253)|实现存在，应用尚未接聊天/操作|
|`userTranslateDefaultWith`|[NoaIMSDKManager+User.m:136](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+User.m:136)|[NoaIMSDKManager+User.m:136](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+User.m:136)|实现存在，应用尚未接聊天/操作|
|`imSdkTranslateUploadNewTranslateConfig`|[NoaIMSDKManager+Translate.m:183](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Translate.m:183)|[NoaIMSDKManager+Translate.m:183](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Translate.m:183)|实现存在，应用尚未接聊天/操作|
|`imSdkTranslateGetChannelLanguage`|[NoaIMSDKManager+Translate.m:171](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Translate.m:171)|[NoaIMSDKManager+Translate.m:171](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Translate.m:171)|实现存在，应用尚未接聊天/操作|
|`imSdkTranslateYuueeContent`|[NoaIMSDKManager+Translate.m:165](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Translate.m:165)|[NoaIMSDKManager+Translate.m:165](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Translate.m:165)|实现存在，应用尚未接聊天/操作|
|`imSdkUserFindStickersForName`|[NoaIMSDKManager+Stickers.m:33](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Stickers.m:33)|[NoaIMSDKManager+Stickers.m:33](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Stickers.m:33)|实现存在，应用尚未接聊天/操作|
|`imSdkUserAddStickersToCollectList`|[NoaIMSDKManager+Stickers.m:21](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Stickers.m:21)|[NoaIMSDKManager+Stickers.m:21](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Stickers.m:21)|实现存在，应用尚未接聊天/操作|
|`imSdkUserFindUnUsedStickersPackageList`|[NoaIMSDKManager+Stickers.m:45](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Stickers.m:45)|[NoaIMSDKManager+Stickers.m:45](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Stickers.m:45)|实现存在，应用尚未接聊天/操作|
|`imSdkUserAddStickersPackage`|[NoaIMSDKManager+Stickers.m:39](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Stickers.m:39)|[NoaIMSDKManager+Stickers.m:39](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Stickers.m:39)|实现存在，应用尚未接聊天/操作|
|`imSdkUserGetStickersPackageDetail`|[NoaIMSDKManager+Stickers.m:57](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Stickers.m:57)|[NoaIMSDKManager+Stickers.m:57](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Stickers.m:57)|实现存在，应用尚未接聊天/操作|
|`imSdkUserGetPackageFromStickersId`|[NoaIMSDKManager+Stickers.m:63](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Stickers.m:63)|[NoaIMSDKManager+Stickers.m:63](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Stickers.m:63)|实现存在，应用尚未接聊天/操作|
|`userAddFeedBackWith`|[NoaIMSDKManager+User.m:111](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+User.m:111)|[NoaIMSDKManager+User.m:111](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+User.m:111)|实现存在，应用尚未接聊天/操作|
|`ssoFeedBackWith`|[NoaIMSDKManager+User.m:116](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+User.m:116)|[NoaIMSDKManager+User.m:116](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+User.m:116)|实现存在，应用尚未接聊天/操作|
|`GroupHairCreateHairGroupWith`|[NoaIMSDKManager+ChatMessage.m:1364](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1364)|[NoaIMSDKManager+ChatMessage.m:1362](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1362)|实现存在，应用尚未接聊天/操作|
|`GroupHairSendHairMessageWith`|[NoaIMSDKManager+ChatMessage.m:1369](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1369)|[NoaIMSDKManager+ChatMessage.m:1367](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1367)|实现存在，应用尚未接聊天/操作|
|`GroupHairGetMessageListWith`|[NoaIMSDKManager+ChatMessage.m:1374](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1374)|[NoaIMSDKManager+ChatMessage.m:1372](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1372)|实现存在，应用尚未接聊天/操作|
|`GroupHairDeleteHairMessageWith`|[NoaIMSDKManager+ChatMessage.m:1379](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1379)|[NoaIMSDKManager+ChatMessage.m:1377](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1377)|实现存在，应用尚未接聊天/操作|
|`GroupHairGetGroupHairUserListWith`|[NoaIMSDKManager+ChatMessage.m:1384](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1384)|[NoaIMSDKManager+ChatMessage.m:1382](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1382)|实现存在，应用尚未接聊天/操作|
|`GroupHairGetGroupHairErrorUserListWith`|[NoaIMSDKManager+ChatMessage.m:1389](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1389)|[NoaIMSDKManager+ChatMessage.m:1387](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1387)|实现存在，应用尚未接聊天/操作|
|`messageGetSignInHistoryRecordWith`|[NoaIMSDKManager+ChatMessage.m:1335](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1335)|[NoaIMSDKManager+ChatMessage.m:1333](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:1333)|实现存在，应用尚未接聊天/操作|
|`groupManagerApplyJoinGroupListWithData`|[NoaIMSDKManager+Group.m:286](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:286)|[NoaIMSDKManager+Group.m:286](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:286)|实现存在，应用尚未接聊天/操作|
|`groupNotificationApplyJoinGroupListWithData`|[NoaIMSDKManager+Group.m:291](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:291)|[NoaIMSDKManager+Group.m:291](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:291)|实现存在，应用尚未接聊天/操作|
|`groupJoinGroupApplyHandleWithData`|[NoaIMSDKManager+Group.m:296](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:296)|[NoaIMSDKManager+Group.m:296](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.m:296)|实现存在，应用尚未接聊天/操作|
|`readedMessage`|[NoaIMSDKManager+ChatMessage.m:872](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:872)|[NoaIMSDKManager+ChatMessage.m:870](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.m:870)|实现存在，应用尚未接聊天/操作|
## 七、业务事件与数据刷新合同

以下事件均需当前UID/会话/generation验证；事件是业务状态更新，不一律新增普通气泡。

这些事件不是普通文本，Swift Store要先处理业务状态再决定是否加气泡；回调必须校验UID/sessionID/generation。

|事件/回调|旧实际处理|验收|
|---|---|---|
|EditedOneMsg / cimToolEditChatMessageUpdate|替换原消息，刷新被引用原文；不新增系统气泡|两端/原引用/会话预览一致|
|TransferOwnerMessage/AdminGroupMessage/NameGroupMessage|重取groupInfo和成员|标题与权限、管理页和输入同步|
|EstoppelGroupMessage/GroupSingleForbidMessage/IsShowHistoryMessage|重取groupInfo/禁言与历史配置|全员禁言豁免/个人禁言准确|
|GroupIsAllowNetCallMessage|群通话开关变化|正在显示的按钮失效处理|
|UpdateGroupInformStatusForAdminSystem/GroupMessageInform|重取群通知配置|是否显示系统提示按最新状态|
|NoticeGroupMessage/DelGroupNotice|重取群公告/群信息|顶部公告移除/更新/翻译同步|
|GroupMessageTop/DialogUserMessageTop|回查置顶消息列表|个人/全局置顶和取消两端一致|
|KickGroupMessage|本人移除则清会话/历史，其他人更新群；msgDel可删除该成员所有发言|退出页面/不能继续发；部分成员历史移除|
|DelGroupMessage/OutGroupMessage|清会话/历史，别人退群同步成员|解散/退群页面恢复与缓存一致|
|InviteConfirmGroupMessage|刷新群/成员|新增成员昵称与@列表即时可见|
|ScheduleDeleteMessage / messageTimeDelete通知|更新freq/删旧消息|删除范围、定时状态与缓存一致|
|BackMessage/BilateralDel|移除目标消息/显示撤回和引用刷新|原文不从历史再次恢复|
|发送ACK/Fail、ChatMessageUpdate、MessageDeleteAll、翻译配置与角色变化|更新状态/已读、列表、翻译和当前入口|弱网/迟到/换账号场景|

当前行号：[NoaChatViewController.m:3448](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3448) [NoaChatViewController.m:3455](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3455) [NoaChatViewController.m:3461](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3461) [NoaChatViewController.m:3469](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3469) [NoaChatViewController.m:3476](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3476) [NoaChatViewController.m:3484](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3484) [NoaChatViewController.m:3492](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3492) [NoaChatViewController.m:3499](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3499) [NoaChatViewController.m:3514](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3514) [NoaChatViewController.m:3521](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3521) [NoaChatViewController.m:3530](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3530) [NoaChatViewController.m:3578](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3578) [NoaChatViewController.m:3623](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3623) [NoaChatViewController.m:3637](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3637) [NoaChatViewController.m:3650](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3650) [NoaChatViewController.m:3658](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:3658) [NoaChatViewController.m:4368](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:4368) [NoaChatViewController.m:4382](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:4382) [NoaChatViewController.m:4432](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:4432) [NoaChatViewController.m:4451](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatViewController.m:4451)。

群成员昵称同步专用消息代理/好友头像资料更新等来自SDK同步层，必须与联系人Store一致；本轮未把新Store只读好友更新等同聊天气泡改名已验收。
## 八、跨模块待确认与接口差异

- 新SystemConfigRecord仍没有聊天撤回/通话服务/群频控等对应字段；刷新框架不等于业务配置可消费。新权限edited_message_sent为分钟语义，不能用通用allows布尔判断。
- 旧toolGetSignInSession合并历史签到ID，新SDK仅SIGNIN_ASSISTANT，当前sessionID去重不能合并不同ID；后续单独确认兼容及未读。
- 新SDK失败原因/3秒ACK检查/reSendCount<=3/HTTP兜底60秒应被真实聊天消费，不能叠加独立无限重试。次数总口径未换算。
- 群消息昵称专用GroupMemberNick回调在选定新旧源码未确证；所需气泡/预览/@同步以真实SDK与后端验收，不能引用别的项目修复代替。
- 位置仅历史气泡/工具，发起入口未证；支付旧Home过滤且无跳转；推送/深链、全读主动按钮、已读成员详情页、分类50条之后更多/远端全文检索均待确认。
- 单条/多选删除授权分支、撤回管理角色保护、定时删除多端范围、音视频/翻译服务部署与收费、真实投诉恢复均需用户审阅和后续联调。

