# 通讯录详细迁移需求

> 需求状态：待用户审阅；本轮仅静态代码对照。旧项目 `/Users/taobotaobo/Desktop/xgd`，新项目 `/Users/taobotaobo/Desktop/ddlNew`，`feature-message-4 / 78876ca`。与[总纲](CONTACTS_MESSAGE_MIGRATION_REQUIREMENTS.md)及[消息/真实聊天需求](MESSAGE_MIGRATION_REQUIREMENTS.md)配套；没有开发、业务测试或真实服务器验证。

## 一、产品边界与阅读方法

通讯录主体负责用户的关系资产：已有好友、好友业务分组、群列表、申请与添加、资料及好友设置。发消息进入 CHAT-需求；群内权限和管理是关联模块；团队、通话、真实拉黑/举报只盘点依赖、待后续取舍。旧代码中的字母分区与好友业务分组是两种概念：字母分区已经在新页实现，业务分组没有迁移。

每个 C-ID 给出旧行为、新状态、入口和前置、字段/流程、失败取消与同步边界、验收案例及真实来源。建议迁移规则是需求目标，不能据此声称新项目已经具备操作。各条 A1/A2 验收同时适用本文件公共验收标准。

## 二、新项目当前数据合同（代码已接，不等于真机验收）

| 字段/事件 | 当前来源与页面意义 | 迁移时必须保持的规则 |
| --- | --- | --- |
| 好友稳定标识 | friendUserUID → ContactRecord.id | 不能用显示名作为关系键；空UID过滤，重复UID单项展示 |
| 账号/昵称/备注 | userName / nickname / remarks | 名称按备注→昵称→账号→UID兜底；备注改变重新排序和搜索 |
| 拼音 | nicknamePinyin / remarksPinyin，缺失时本地生成 | 完整拼音用于检索，中文逐字首字母用于排序，不能只做英文搜索 |
| 备注描述 | descRemark | 未设置显示友好占位；旧备注联系方式/图片尚未进入新模型 |
| 头像 | friend.avatar + 当前文件Host | 完整HTTP(S)/相对OSS/中文路径均需支持；不把历史Host固化为业务地址 |
| 在线 | onlineStatus | 布尔值展示在线点，未证实刷新时延或“最后在线”数据，不创造时间值 |
| 账号状态 | disableStatus | 当前只有4按已注销处理；0/1/3含义在模型注释中记录，封禁/注销中产品限制须与旧/服务端确认 |
| 普通/系统好友 | userType | 新列表仅userType==0；文件助手等系统账号使用独立入口，不混入普通好友计数 |
| 用户代理 | 同步完成、好友增删/确认、在线、备注、分组变化 | 事件触发SDK回读；当前分组变化只是刷新普通好友列表，没有业务分组UI |
| 备注变更代理 | 解析friendUID→getFriendInfo→SDK写库 | 当前跨端备注回读已接；不等于本端备注编辑已接 |
| 数据生命周期 | ContactsStore UID + generation | 登录前观察、AUTH后加载；退出/失效/换号清空展示，隔离迟到结果 |

来源：[ContactRecord.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Models/ContactRecord.swift:11)、[ContactSorter.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Services/ContactSorter.swift:29)、[SDKContactsClient.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Network/IM/Contacts/SDKContactsClient.swift:45)、[SDKContactsDelegate.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Network/IM/Contacts/SDKContactsDelegate.swift:17)。

## 三、通讯录公共状态与验收标准

| 编号 | 适用情境 | 需求与验收设计 |
| --- | --- | --- |
| C-G1 | 首次登录/无好友 | AUTH前不请求业务好友；AUTH成功且数据库就绪后读真实缓存；空好友显示暂无好友，不能出现演示联系人 |
| C-G2 | 同步中/缓存可用 | 有缓存先展示且表明同步；后台或断网不清空已有好友；同步失败与真实无好友区分 |
| C-G3 | 本地读失败 | 显示可理解错误，保留上次有效快照；重新读取只重读缓存，不宣称已重新建立网络/同步成功 |
| C-G4 | 请求取消/重复点击 | 未提交可取消；已提交不能假定服务端被取消；防重复提交，回页回读服务端/SDK状态，不用本地成功Toast代替结果 |
| C-G5 | 关系/权限在页面打开后改变 | 好友被删、账号注销、权限收回时重新评估按钮和目标UID；开放的详情显示已不在通讯录中，不能对旧快照继续危险操作 |
| C-G6 | 多端同步 | A端加好友/同意/删好友/改备注/改分组后，B端收到对应真实事件再刷新；本地隐藏申请须明确只影响本机，不当跨端拒绝 |
| C-G7 | 账号隔离 | A用户请求过程中退出并登录B；A的旧资料、申请响应、备注写库不得进入B的SDK库/页面，邀请码变更同样处理 |
| C-G8 | 后台/恢复/节点更换 | 页面恢复读取当前关系与权限；图片使用新Host；操作中断可重试但须先核对服务器已处理状态，不能重复建立关系 |
| C-G9 | 输入与隐私 | 搜索清空恢复全列表；空格/汉字/英文/数字/重名/特殊符号覆盖；日志和错误不泄露Token、敏感备注或完整本地资源路径 |
| C-G10 | 可用性与可访问性 | 键盘可收起、返回保持合理查询、长备注和昵称不遮挡按钮、加载/失败/无权限有文案、VoiceOver读出名称和状态；性能目标另行量测确定 |

## 四、详细需求

<!-- REQUIREMENTS-GENERATED -->
<a id="C-001"></a>
### C-001 页面入口、好友/业务分组/群聊切换

**新状态：部分｜建议P1｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧通讯录有好友、分组、群聊三标签，禁止左右滑动换页；加号直接到添加好友，搜索到全局搜索。新仅好友页，没有三标签及快捷入口。

**场景、入口与前置**：主Tab进入通讯录；已AUTH且数据库就绪。

**字段与规则**：标签选择状态与好友数量分开；业务分组不是字母分区；旧通讯录加号与首页更多菜单不是相同菜单。

**目标操作流程**：进入后读取好友；选择分组/群聊后读取对应真实列表；返回保持合理选中状态；搜索和添加分别进入对应业务。是否保持三标签布局由用户审阅。

**失败、取消、网络/多端与边界**：无权限入口收起或给明确提示；后台恢复刷新数据但不无故重置标签；不能跳到演示页；关系为空时不回填演示联系人。

**验收设计（尚未执行）**：

- **C-001-A1**：三类入口与列表数据一一对应，首次进入显示真实好友；没有假分组/群。
- **C-001-A2**：通讯录加号目标和首页更多菜单差异已明确；返回与重复切换不会创建多份列表请求。

**源码依据**：[CandyTalkContactVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkContactVC.m:143)；[CandyTalkContactVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkContactVC.m:222)；[ContactsView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/ContactsView.swift:20)。

<a id="C-002"></a>
### C-002 好友名单、名称优先级与排序

**新状态：已接（代码）｜建议P0｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧从toolGetMyFriendList取缓存，排除系统账号、注销放#末尾，按showName+userName的中文首字母与字符规则排序。新已接备注→昵称→账号→UID兜底、UID去重和字母分区。

**场景、入口与前置**：通讯录好友标签；有效当前用户SDK库。

**字段与规则**：稳定键friendUID；普通userType==0；disableStatus==4保留但后置；同组字母优先数字；新sortName以展示名+account生成，等值UID稳定排序。

**目标操作流程**：缓存加载→过滤/去重→排序分区→展示；备注/昵称变化重新计算分区，不能按在线优先替换普通好友排序。

**失败、取消、网络/多端与边界**：空UID过滤；同名不合并；全中文、英文、数字、空名、特殊字符、已注销均需覆盖；旧普通列表与业务分组在线排序有差别。

**验收设计（尚未执行）**：

- **C-002-A1**：给定混合名称和重复UID，结果唯一且字母/#/注销顺序符合当前规则。
- **C-002-A2**：清备注后按昵称等回退，当前好友计数与可见普通好友一致。

**源码依据**：[NoaFriendListVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaFriendListVC.m:643)；[NoaFriendListVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaFriendListVC.m:724)；[ContactSorter.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Services/ContactSorter.swift:29)；[ContactRecord.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Models/ContactRecord.swift:47)。

<a id="C-003"></a>
### C-003 好友在线、注销及异常账号状态

**新状态：部分｜建议P0｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧列表创建在线点但setFriendModel未赋onlineStatus，默认隐藏；旧资料页有在线缓存/通知。新好友行已按onlineStatus显示在线点，注销隐藏账号和远程头像。

**场景、入口与前置**：好友行及资料；当前真实SDK状态。

**字段与规则**：4为已注销；新模型注释0正常/1封禁/3注销中，只有4进入isDeleted分支。在线点是新已接行为，不能声称与旧主列表展示完全一致。

**目标操作流程**：普通好友按当前状态展示；注销统一文案并禁止继续发起添加/聊天等操作；封禁、注销中的操作限制待后端政策确认，不凭状态数字猜断。

**失败、取消、网络/多端与边界**：在线数据可能延迟，不显示未经证实的最后上线时间；注销事件在已打开详情中更新；旧主列表在线点差异供审阅。

**验收设计（尚未执行）**：

- **C-003-A1**：在线/离线变化来自SDK，不由本地演示状态生成。
- **C-003-A2**：注销好友仍可识别但不请求远程头像、无错误可操作入口；封禁/注销中按确认政策验收。

**源码依据**：[NoaContactListTableCell.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Views/cell/NoaContactListTableCell.m:82)；[NoaUserHomePageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaUserHomePageVC.m:542)；[ContactsView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/ContactsView.swift:102)；[ContactRecord.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Models/ContactRecord.swift:51)。

<a id="C-004"></a>
### C-004 真实头像、文件Host变化与图片降级

**新状态：已接（代码）｜建议P0｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧好友头像来自好友资料；新列表/详情已经使用同一真实头像组件，支持完整URL、相对文件路径及中文路径，注销使用占位。

**场景、入口与前置**：好友行、资料、关联消息单聊头像；当前导航文件Host。

**字段与规则**：friend.avatar为权威好友头像；不能缓存永久拼接旧Host；无图/不可访问是图片失败，不代表好友不存在。

**目标操作流程**：读取头像→当前Host解析→缓存/去重展示→占位降级；资料变更或Host改变后刷新；关联会话重新取好友头像。

**失败、取消、网络/多端与边界**：断网保留可用缓存；无Host无法解析相对URL时占位；节点切换后迟到图片不能覆盖新用户资料；不在文档展开敏感地址。

**验收设计（尚未执行）**：

- **C-004-A1**：完整URL、相对路径、中文路径、空头像、注销头像各结果明确。
- **C-004-A2**：更换文件Host与好友头像更新后，名单/详情/会话一致，不停留在旧图。

**源码依据**：[ContactRecordAvatar.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Components/ContactRecordAvatar.swift:10)；[ContactRecord.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Models/ContactRecord.swift:62)；[TabbarView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Tabbar/Views/TabbarView.swift:34)。

<a id="C-005"></a>
### C-005 SDK同步、错误恢复和跨账号隔离

**新状态：已接（代码）｜建议P0｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧同步完成、好友新增/删除/确认、备注等事件重读；同步失败主要日志。新Store已接同步状态、错误保留快照、合并回读，client用UID/generation与SDK锁校验。

**场景、入口与前置**：登录前观察、AUTH后加载；进入页面再次reload。

**字段与规则**：同步中/失败/缓存失败/真实空列表为不同状态；friendUID与当前用户UID是不同角色，不能混用。

**目标操作流程**：进入显示可用缓存→同步事件刷新→完成回读；备注事件拉完整资料写SDK→刷新；退出注销观察和当前展示。

**失败、取消、网络/多端与边界**：后台/断网保留缓存；回读失败保留上次有效数据；旧账号迟到响应和同好友旧版本响应失效；普通断网不得清凭据。

**验收设计（尚未执行）**：

- **C-005-A1**：先缓存后同步、失败保留和恢复后补同步均符合状态文案。
- **C-005-A2**：A请求未结束切B时，A资料不会写入B库或显示；多次事件不会重复好友。

**源码依据**：[NoaFriendListVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaFriendListVC.m:282)；[ContactsStore.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Services/ContactsStore.swift:31)；[SDKContactsClient.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Network/IM/Contacts/SDKContactsClient.swift:64)。

<a id="C-006"></a>
### C-006 本地好友检索与旧全局好友检索差异

**新状态：部分｜建议P1｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧全局DB搜索showName/userName/nickname及其拼音、remarks及拼音，排除注销；新页面本地含UID/排序键/完整拼音且未排除注销，支持trim/忽略大小写包含。

**场景、入口与前置**：通讯录输入框；搜索只读当前已加载好友，跨分类全局入口另见M-016。

**字段与规则**：新有UID匹配与注销可搜是范围差异；旧没有证据支持好友DB手机号/邮箱字段全文查找；添加用户精确查找是C-013。

**目标操作流程**：输入→本地过滤保留排序分区→点结果资料→清空恢复；全局搜索应标类型与更多，不用同一文案误称服务器全量搜索。

**失败、取消、网络/多端与边界**：空格、大小写、组合拼音、同名和注销用例；输入后退出切号清除所属用户结果；无匹配不显示网络错误。

**验收设计（尚未执行）**：

- **C-006-A1**：备注/昵称/账号/完整拼音的匹配与清空可复现。
- **C-006-A2**：用户确认是否保留UID及注销搜索增强，文案明确本地好友范围；不会把手机号精准搜索混入。

**源码依据**：[NoaGlobalSearchVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/NoaGlobalSearchVC.m:84)；[NoaIMDBTool+Friend.mm](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/DataBaseModule/NoaIMDBTool+Friend.mm:48)；[ContactSorter.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Services/ContactSorter.swift:29)。

<a id="C-007"></a>
### C-007 首字母快速定位

**新状态：未接｜建议P2｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧普通好友列表提供字母索引，RTL语言不启用；新只有分区标题，无快速定位索引。

**场景、入口与前置**：好友较多时点击字母条；布局取舍由用户审阅。

**字段与规则**：索引取当前可见分区，无A组不能跳错误位置；#含特殊字符/注销组。

**目标操作流程**：生成可见索引→点字母定位分区→搜索变化重算；保持现有新页视觉方案。

**失败、取消、网络/多端与边界**：空列表/仅#组/键盘打开/超长名单和RTL语言不能造成无法返回；此处键盘及可访问性是建议验收。

**验收设计（尚未执行）**：

- **C-007-A1**：有目标组准确定位，无目标组不产生空跳转。
- **C-007-A2**：搜索后的分区与索引一致；RTL行为按审阅决定，不强行照搬。

**源码依据**：[NoaFriendListVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaFriendListVC.m:89)；[ContactsView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/ContactsView.swift:20)。

<a id="C-008"></a>
### C-008 新朋友入口、申请未读与通讯录角标

**新状态：未接｜建议P1｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧顶部新朋友入口和>99显示99+，根读取toolFriendApplyCount；可见申请阅读后逐项扣未读，非进入页面全归零。

**场景、入口与前置**：通讯录新朋友入口；收到真实好友邀请事件。

**字段与规则**：申请未读与消息会话未读分开；记录以hashKey标识未读，按当前UID隔离；旧Tab数字索引不能直接复制到新Tab排列。

**目标操作流程**：通知到达更新入口与通讯录Tab→进入申请列表→可见项视作已读→刷新角标→返回保持剩余未读。

**失败、取消、网络/多端与边界**：列表加载失败或未展示项不应当已读；自发申请是否计数按SDK确认；多端已读口径需联调；旧部分MMKV key未隔离UID是缺陷，迁移不可照搬。

**验收设计（尚未执行）**：

- **C-008-A1**：只有可见/确认已读项扣数，未见申请保留未读。
- **C-008-A2**：消息与通讯录角标分别更新、>99显示规则准确，换号不继承旧申请。

**源码依据**：[CandyTalkContactVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkContactVC.m:279)；[NoaContactHeaderView.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Views/view/NoaContactHeaderView.m:166)；[NoaNewFriendListVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaNewFriendListVC.m:233)；[ContactsView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/ContactsView.swift:20)。

<a id="C-009"></a>
### C-009 好友申请列表、分页与状态

**新状态：未接｜建议P1｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧getFriendApplyListFromServerWith按pageStart/pageSize/pageNumber/userUid取rows，每页20；page1清空，rows<20结束；beStatus=0申请中/1通过/2过期，无拒绝枚举。

**场景、入口与前置**：新朋友首次进入、下拉刷新、加载更多；AUTH有效。

**字段与规则**：from/be双方UID/头像/昵称/状态/roleId；friendAddType 1搜索/0扫码，hashKey/sendTime；根据自己是发起方还是接收方展示对方字段。

**目标操作流程**：第一页→过滤本地隐藏→渲染状态与方向→继续分页；刷新重新从第一页，邀请事件触发更新；已好友点击资料，非好友点申请详情。

**失败、取消、网络/多端与边界**：重复分页/刷新交错去重；失败恢复加载按钮、页码不跳过；注销对方不开放操作；这是迁移需补强的可靠性要求，不声称旧失败处理完善。

**验收设计（尚未执行）**：

- **C-009-A1**：20条分页与不足一页结束口径来自旧调用；双方向pending/通过/过期文案和按钮准确。
- **C-009-A2**：连续刷新和翻页不会重复/漏项，错误保留已有列表且可重试。

**源码依据**：[NoaNewFriendListVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaNewFriendListVC.m:28)；[NoaFriendApplyModel.h](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Model/NoaFriendApplyModel.h:13)；[NoaNewFriendListCell.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Views/cell/NoaNewFriendListCell.m:149)；[ContactsView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/ContactsView.swift:20)。

<a id="C-010"></a>
### C-010 同意好友申请与完整好友落库

**新状态：未接｜建议P1｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧仅对方发起且beStatus==0可confirmFriendApplyWith(userUid,friendUserUid=fromUserUid)；成功再getFriendInfoWith取完整资料toolAddMyFriendWith。

**场景、入口与前置**：新朋友通过验证、申请详情通过；关系仍pending且目标有效。

**字段与规则**：自己发出的pending不能被自己同意；申请摘要不代替完整好友资料；申请成功不直接伪造聊天记录。

**目标操作流程**：再次核对关系→提交同意→回执成功更新申请→取完整好友落SDK→通讯录/角标刷新→资料/真实发消息入口可用。

**失败、取消、网络/多端与边界**：重复同意、另一端已同意、过期/注销、申请成功但取资料失败需区分；失败保留原状态，重试先查关系；后台回执绑定UID。

**验收设计（尚未执行）**：

- **C-010-A1**：自发pending不出现同意，对方pending可同意且最终出现完整好友。
- **C-010-A2**：同意回执失败不标已添加；关系已成功而详情读取失败可恢复，不重复建立关系。

**源码依据**：[NoaNewFriendListVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaNewFriendListVC.m:296)；[NoaNewFriendListVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaNewFriendListVC.m:359)；[NoaFriendApplyPassVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaFriendApplyPassVC.m:134)。

<a id="C-011"></a>
### C-011 申请详情、重新申请与发消息分支

**新状态：未接｜建议P1｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧申请详情先checkMyFriend，好友显示发消息；自发非pending可重新申请，对方pending显示通过；聊天是真NoaChatViewController。

**场景、入口与前置**：点击申请行；需按from/be确定目标UID。

**字段与规则**：不能用过期标签决定是否永不申请；实际按钮来自当前好友关系+发起方向+状态；来源是返回字段，不捏造验证理由输入。

**目标操作流程**：打开检查关系→展示对应操作→重新申请复用addContact→同意复用C-010→已有好友去真实聊天CHAT-001。

**失败、取消、网络/多端与边界**：自己账号、注销、关系跨端变化、重复发送和限频按真实错误提示；取消关闭不提交；没有新真实聊天时不得跳演示页。

**验收设计（尚未执行）**：

- **C-011-A1**：已好友/自发pending/自发过期/对方pending四分支正确。
- **C-011-A2**：重申请成功显示已发送申请而不是立即好友；消息入口目标UID正确。

**源码依据**：[NoaNewFriendListVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaNewFriendListVC.m:271)；[NoaFriendApplyPassVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaFriendApplyPassVC.m:134)。

<a id="C-012"></a>
### C-012 申请本地隐藏与“拒绝”证据边界

**新状态：未接｜建议P2｜本地隐藏建议迁移；服务端拒绝待取舍｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧侧滑删除写HiddenFriendApply的hashKey-sendTime后移除本地显示；分页过滤该键。未发现好友申请拒绝按钮、请求或拒绝状态。

**场景、入口与前置**：新朋友列表隐藏一条申请；新增服务端拒绝须用户另行确认。

**字段与规则**：隐藏不通知对方，不删除服务器申请；新sendTime形成新键可再出现；新按用户/俱乐部隔离隐藏和阅读状态。

**目标操作流程**：用户选择隐藏→说明仅本机→保存身份键→移出当前列表→重开仍过滤；未来如批准拒绝，单独定义真实契约，不复用隐藏冒充拒绝。

**失败、取消、网络/多端与边界**：隐藏不能直接改为beStatus=拒绝；换账号不能共用key；清数据/重装行为按本地存储政策确认；隐藏是否扣未读需后续SDK口径确认。

**验收设计（尚未执行）**：

- **C-012-A1**：隐藏后重开不见原键、新申请仍可见，服务器关系未被本地伪改。
- **C-012-A2**：文案和验收均不把隐藏称拒绝；若增加拒绝必须得到真实API/状态与对方同步证据。

**源码依据**：[NoaNewFriendListVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaNewFriendListVC.m:318)；[NoaNewFriendListVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaNewFriendListVC.m:108)。

<a id="C-013"></a>
### C-013 按账号/手机号/邮箱查找用户

**新状态：未接｜建议P1｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧占位提示账号/手机号/邮箱，回车以userName向userSearchWith精确查找，非空才查；自己账号有提示，返回数组。客户端未证实后台一定支持三种形式。

**场景、入口与前置**：通讯录加号→添加好友；当前允许添加好友的角色。

**字段与规则**：请求键userName；旧trim仅检查非空，实际传原searchStr，是否规范化需确认；不存在最短3/6字符限制证据。

**目标操作流程**：展示本人账号→输入/回车→检查非空与本人→真实查询→结果卡→查看资料或C-014发送申请；清空移除结果。

**失败、取消、网络/多端与边界**：网络/接口错误与零结果分开；同一用户连续查询以最新输入为准；手机号/邮箱登录暂缓不阻止盘点该关系业务；不额外实现登录通道。

**验收设计（尚未执行）**：

- **C-013-A1**：空输入不查、本人输入有明确反馈；数组/空数组/错误均有对应状态。
- **C-013-A2**：后端验证支持的搜索形式后固定文案，不因旧placeholder声称支持所有手机号邮箱。

**源码依据**：[NoaAddFriendVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaAddFriendVC.m:43)；[NoaAddFriendVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaAddFriendVC.m:83)；[UserRoleAuthority.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Common/User/UserRoleAuthority.swift:16)；[ContactsView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/ContactsView.swift:20)。

<a id="C-014"></a>
### C-014 发送添加好友申请与权限统一

**新状态：未接｜建议P1｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧结果卡先checkMyFriendWith，已好友提示，非好友addContactWith(userUid,friendUserUid)成功已发送；主页非好友且allowAddFriend=true显示添加。结果卡与通讯录加号未见同样守卫，旧入口权限不一致。

**场景、入口与前置**：搜索结果、陌生人主页、好友二维码、群成员资料；检查不是自己/注销/已有好友，角色允许且群私聊守卫通过。

**字段与规则**：只证实两个UID请求参数；未发现发送验证文案输入/来源参数；friendAddType为返回字段，不能发明提交字段。

**目标操作流程**：点击→核对当前关系与权限→提交→成功显示申请已发送→等待真实同意/事件建立好友→刷新名单；统一所有入口权限是建议需求。

**失败、取消、网络/多端与边界**：取消未提交无变化；重复已有关系返回已有好友；网络失败保留可重试，不立即插入好友；审核/限频按真实回执；页面权限变化及时禁用。

**验收设计（尚未执行）**：

- **C-014-A1**：所有添加入口在权限关闭时不可绕过；不再沿用旧守卫差异。
- **C-014-A2**：成功只产生申请状态，实际成为好友以完整关系/同步为准，无假即时成功。

**源码依据**：[NoaAddFriendCell.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Views/cell/NoaAddFriendCell.m:95)；[NoaUserHomePageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaUserHomePageVC.m:238)；[NoaUserHomePageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaUserHomePageVC.m:562)；[UserRoleAuthority.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Common/User/UserRoleAuthority.swift:16)。

<a id="C-015"></a>
### C-015 本人/陌生人/群成员资料关系判断

**新状态：未接｜建议P1｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧资料每次出现checkMyFriendWith，好友getFriendInfoWith、非好友getUserInfoWith；groupID存在另拉群昵称并写成员缓存。新真实入口只支持已有好友快照。

**场景、入口与前置**：搜索/申请/二维码/群成员点资料；本人UID、目标UID、来源groupID分别明确。

**字段与规则**：本人隐藏添加/好友操作；陌生人与好友字段/按钮不同；群昵称仅同群上下文，不能覆盖全局个人昵称；群禁止私聊及groupSecurity守卫见CHAT群成员需求。

**目标操作流程**：检查关系→拉对应真实资料→可选群昵称→显示合法操作；被建立好友/删除后重新评估，返回来源页不丢目标。

**失败、取消、网络/多端与边界**：群成员未同步/禁私聊/注销/已被删/用户不存在有明确退路；资料请求失败可保留已知安全字段但不假定关系成功。

**验收设计（尚未执行）**：

- **C-015-A1**：本人/陌生人/好友/群成员返回资料使用正确接口和按钮。
- **C-015-A2**：同UID在不同群昵称各自正确；无权限不能经头像或搜索绕过访问限制。

**源码依据**：[NoaUserHomePageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaUserHomePageVC.m:228)；[NoaUserHomePageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaUserHomePageVC.m:291)；[ContactRecordDetailView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/ContactRecordDetailView.swift:17)。

<a id="C-016"></a>
### C-016 好友资料展示、现场刷新与实时变化

**新状态：部分｜建议P1｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧主页取完整资料、角色标签/群昵称、回写好友与会话名称、在线通知；新sheet显示账号昵称备注描述在线，随Store变化，已删显示空态，无服务器现场刷新。

**场景、入口与前置**：好友行→资料；当前好友UID仍存在。

**字段与规则**：名称备注优先；账号/昵称/备注/描述空值未设置；角色和群昵称受显示开关及上下文控制；新姓名只是displayName，会话标题另来自sessionName。

**目标操作流程**：先显示缓存→如采用完整主页则拉真实资料→更新SDK→资料/列表/会话一致→展示真实发消息/更多；按钮具体见C-038及C-019等。

**失败、取消、网络/多端与边界**：快速切联系人/账号迟到结果隔离；好友被删除保留不可操作说明；头像/在线及时更新；不能把缓存只读称完整主页。

**验收设计（尚未执行）**：

- **C-016-A1**：现有只读字段不回退演示数据；新增现场刷新后更新名单排序和会话名。
- **C-016-A2**：详情打开时好友被删/注销会立即调整页面和按钮，空资料不会闪出旧联系人。

**源码依据**：[NoaSampleUserInfoView.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Views/view/NoaSampleUserInfoView.m:357)；[NoaUserHomePageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaUserHomePageVC.m:542)；[ContactRecordDetailView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/ContactRecordDetailView.swift:17)。

<a id="C-017"></a>
### C-017 编辑备注与备注描述

**新状态：部分｜建议P1｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧friendSetFriendRemarkAndDesWith提交userUid/friendUserUid/remark/descRemark，成功再拉资料写SDK；备注50、描述200按text.length截断，全空格备注禁止，空字符串允许清除。新仅跨端备注回读已接，没有编辑UI。

**场景、入口与前置**：好友主页更多→编辑备注/描述；必须当前仍好友。

**字段与规则**：上限是旧UTF-16 text.length口径，中文输入法/emoji组合需确认截断体验；备注清空回昵称；没有证据本页支持电话/备注图片，不追加为旧既有字段。

**目标操作流程**：进入预填→编辑→校验→保存禁重复→接口成功→完整资料回读→SDK写库→列表/搜索/资料/会话更新；取消还原旧值。

**失败、取消、网络/多端与边界**：保存失败保留输入可重试；另端更新与本端提交交错取最新版本；注销/删好友/切号阻断旧提交；成功但回读失败提示同步中而非假更新完整。

**验收设计（尚未执行）**：

- **C-017-A1**：50/200边界、空值清除、全空格拒绝、汉字/组合输入/emoji不破坏文本。
- **C-017-A2**：成功后二端备注、排序分区、搜索及会话名称一致；失败不改SDK权威值。

**源码依据**：[NoaFriendManageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaFriendManageVC.m:370)；[NoaSheetInputView.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Base/Base/Views/NoaTipView/NoaSheetInputView.m:258)；[SDKContactsClient.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Network/IM/Contacts/SDKContactsClient.swift:64)；[ContactRecordDetailView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/ContactRecordDetailView.swift:17)。

<a id="C-018"></a>
### C-018 推荐好友名片

**新状态：未接｜建议P2｜建议迁移（依赖CHAT名片）｜范围：关联消息依赖。**

**旧项目已见行为（静态证据）**：旧好友更多推荐进入NoaChatMultiSelectViewController，multiSelectType=RecommentCard并传完整cardFriendInfo；真实名片发送/接收归CHAT-富消息需求。

**场景、入口与前置**：已有好友更多→推荐给朋友；合法目标会话与名片对象。

**字段与规则**：名片UID不是接收会话UID；头像/名称取真实好友，批量限制只采用消息选择器已证实规则，不编造。

**目标操作流程**：选择目标→检查目标允许接收→确认推荐→发送真实名片→逐目标回执→接收卡可打开资料。

**失败、取消、网络/多端与边界**：取消选择不发送；已注销名片/失效会话/禁止私聊处理；批量部分失败不能全成功；弱网重试去重。

**验收设计（尚未执行）**：

- **C-018-A1**：推荐卡使用正确对象且接收方打开同一UID资料。
- **C-018-A2**：批量成功/失败与取消可区分，不本地插假消息。

**源码依据**：[NoaFriendManageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaFriendManageVC.m:313)；[ContactRecordDetailView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/ContactRecordDetailView.swift:17)。

<a id="C-019"></a>
### C-019 删除好友、审核受理与聊天记录清理

**新状态：未接｜建议P2｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧二次确认说明删除好友同时删聊天且不可恢复；deleteContact成功后deleteServerConversation(peerUid,dialogType=0,userUid)，服务器会话删除成功才删本地session/chat及媒体。44016受理稍后处理/44017已提交审核有专门提示。

**场景、入口与前置**：好友更多→删除；当前关系有效，用户确认删除范围。

**字段与规则**：好友UID、会话peerUid和dialogType=0；关系删除、服务端会话删除、本地消息/媒体清理是分开的阶段。

**目标操作流程**：确认→删好友回执→成功再删会话与历史→更新SDK/UI→返回；受理审核保留未完成状态，不能当已删；对端变化由真实同步处理。

**失败、取消、网络/多端与边界**：取消无修改；好友成功但会话失败需显示部分状态与恢复途径；断网/重复审核/换号旧回执隔离；不能清错群/其他用户消息。

**验收设计（尚未执行）**：

- **C-019-A1**：取消和44016/44017不会伪装最终删除，重复受理有正确提示。
- **C-019-A2**：最终成功后好友、指定会话/历史/媒体一致；部分失败按实际阶段提示并能恢复。

**源码依据**：[NoaFriendManageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaFriendManageVC.m:320)；[NoaFriendManageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaFriendManageVC.m:427)；[NoaFriendManageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaFriendManageVC.m:457)。

<a id="C-020"></a>
### C-020 真实黑名单能力盘点

> **2026-10-15当前状态覆盖**：用户已追加批准，真实SDK黑态、加入/移出、我的黑名单及资料页发消息入口控制已实现；离线检查/构建通过，服务器双端阻断/解除恢复待验。bool false、审核码与失败不显示最终成功，切号隔离、旧读取不覆盖新写入及空名单清旧黑态已有离线证据。下方“需取舍/仅盘点/未来授权/尚未执行”为最初盘点快照，当前范围及分层证据见[迁移记录](SAFETY_REPORT_BLOCK_MIGRATION_2026-10-15.md)。

**新状态：需取舍｜建议P3｜仅盘点，用户后续取舍｜范围：独立真实安全能力。**

**旧项目已见行为（静态证据）**：旧getUserBlackStateWith读取bool；加入addUserToBlackListWith status=1、移除status=0，成功bool决定结果；主页拉黑态隐藏聊天/通话，加入处理审核码。新没有真实入口，演示版本已按用户要求删除。

**场景、入口与前置**：若未来用户批准：好友更多拉黑/移出，个人中心关联名单；本轮仅盘点。

**字段与规则**：userUid/friendUserUid/status及真实bool；阻断收发的全SDK/双端行为未验证，不能仅由UI推断。

**目标操作流程**：确认真实黑态→二次确认加入或直接解除→提交→bool true再更新→刷新主页和相关列表；bool false或审核保留对应状态。

**失败、取消、网络/多端与边界**：本轮不会恢复入口或演示状态；实际单向/双向关系、已拉黑再加好友、审批回流须联调；普通网络失败不能显示成功。

**验收设计（尚未执行）**：

- **C-020-A1**：未来授权后bool false/审核/网络失败均不得成功，退出换号状态隔离。
- **C-020-A2**：双端发送/接收阻断与解除恢复得到服务端证据后才标完成。

**源码依据**：[NoaFriendManageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaFriendManageVC.m:338)；[NoaFriendManageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaFriendManageVC.m:412)；[NoaFriendManageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaFriendManageVC.m:474)；[ContactRecordDetailView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/ContactRecordDetailView.swift:17)。

<a id="C-021"></a>
### C-021 真实投诉/举报表单与上传依赖盘点

> **2026-10-15当前状态覆盖**：用户批准仅系统投诉，不含邀请码/IP域名；好友资料、群设置、我的分别对应用户0、群1、通用3，真实SDK已接入。8类原因、1–9图、选填内容UTF16最多200、有效邮箱必填；图片最大边2048/JPEG0.5，经通用目录加密，ufbImages保留供应商原始资源串再以逗号拼接，不能假定全部为相对路径。所有图片成功才提交，失败保留表单，SDK业务成功回调才显示提交；审核码只显示审核状态。离线/编译通过，真实上传及受理待验。下方“需取舍/仅盘点/本轮不恢复/未来授权/尚未执行”为最初盘点快照，当前以[迁移记录](SAFETY_REPORT_BLOCK_MIGRATION_2026-10-15.md)为准。

**新状态：需取舍｜建议P3｜仅盘点，用户后续取舍｜范围：独立真实安全能力。**

**旧项目已见行为（静态证据）**：旧好友投诉与群投诉可达NoaComplainVC；表单必须图片、最多9张，提交还需邮箱格式有效，先上传再userAddFeedBackWith；另有ssoFeedBackWith连接反馈。新无真实闭环，演示举报已删除。

**场景、入口与前置**：未来批准：好友更多/群设置→对应类型投诉；本轮不恢复。

**字段与规则**：userUid/nickname/username/ufbImages相对路径逗号串/ufbContentGroup；用户类型0+ufbToUserId、群类型1+ufbToGroupId，可选comment/email/to字段；邮箱实际启用条件差异待审阅。；旧真实投诉正文上限200字。

**目标操作流程**：选择真实类型/原因→填写→选图片→校验→上传成功→提交真实反馈→成功返回；各失败阶段保留输入与证据。

**失败、取消、网络/多端与边界**：图片失败不能提交假路径；取消上传/离开需有状态；空图片/无效邮箱/超9张/权限拒绝明确；不承诺旧举报记录/处理结果已证实。

**验收设计（尚未执行）**：

- **C-021-A1**：未来授权后图片上传真实成功且目标类型/UID正确，最多9张边界与邮箱条件明确。
- **C-021-A2**：回执失败保留表单、重复点击不重复投诉；本轮文档不声称已恢复。

**源码依据**：[NoaFriendManageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaFriendManageVC.m:361)；[NoaComplainFromVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/ReportComplain/NoaComplainFromVC.m:645)；[NoaComplainFromVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/ReportComplain/NoaComplainFromVC.m:689)。

<a id="C-022"></a>
### C-022 好友业务分组、默认组与展开收起

**新状态：未接｜建议P2｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧toolGetMyFriendGroupList以ugOrder升序；默认ugType==-1含本组及ugUuid空好友，系统过滤；组内再分在线/离线/注销，展开用当前friendGroupOpenList。新只有普通好友分区与groupChange刷新。

**场景、入口与前置**：通讯录分组标签；SDK分组和好友同步就绪。

**字段与规则**：ugUuid/ugType/ugOrder/ugName与好友ugUuid；业务分组排序不能直接用新普通好友字母分区代替；默认组保底收未分配好友。

**目标操作流程**：回读组和成员→显示名称/计数→展开收起→组内按旧规则显示→点资料；分组变化重新计算当前结构。

**失败、取消、网络/多端与边界**：删组/移动/在线变化不得丢好友；组无成员仍可存在；展开状态跨账号隔离；组内排序与普通列表差异必须保留或明确取舍。

**验收设计（尚未执行）**：

- **C-022-A1**：未分组好友全部进入默认组，普通与系统/注销处理符合规则。
- **C-022-A2**：展开/收起及组内在线排序可复现，名称相同但ID不同不串组。

**源码依据**：[NoaFriendGroupListVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/FriendGroup/NoaFriendGroupListVC.m:196)；[NoaFriendGroupListVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/FriendGroup/NoaFriendGroupListVC.m:254)；[ContactsStore.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Services/ContactsStore.swift:31)。

<a id="C-023"></a>
### C-023 创建、改名与删除业务分组

**新状态：未接｜建议P2｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧长按组头进管理；createFriendGroup(userUid,ugName)、updateFriendGroup(userUid,ugUuid,ugName)、deleteFriendGroup(userUid,ugUuid)；非空，默认组不能删除，删除后好友回默认。

**场景、入口与前置**：分组管理编辑模式；选择移动模式不显示相同编辑操作。

**字段与规则**：组名数量/长度无明确源码限制证据，不设虚构上限；默认组标识ugType=-1；删除组不同于删除好友。

**目标操作流程**：新增/改名预填→非空校验→提交禁重→成功SDK/服务回读；删自定义组先确认回默认→删除→刷新成员归属。

**失败、取消、网络/多端与边界**：失败保留输入/原组；取消无变化；重复组名是否允许后端确认；默认组改名/排序权限待审阅；旧3秒延迟回读是实现细节不当需求。

**验收设计（尚未执行）**：

- **C-023-A1**：非空与默认不可删正确；删除组不删除任何好友，全部归默认组。
- **C-023-A2**：增改删失败/取消保持原结构，跨端更新后各端一致。

**源码依据**：[NoaFriendGroupManagerVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/FriendGroup/NoaFriendGroupManagerVC.m:212)；[NoaFriendGroupAddView.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Views/friendGroup/NoaFriendGroupAddView.m:133)；[NoaFriendGroupManagerCell.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Views/friendGroup/NoaFriendGroupManagerCell.m:71)；[NoaFriendGroupDeleteView.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Views/friendGroup/NoaFriendGroupDeleteView.m:59)。

<a id="C-024"></a>
### C-024 业务分组排序管理

**新状态：未接｜建议P2｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧管理可移动行，updateFriendGroupWith(userUid,ugUuid,ugOrder=目标order)；数据库按ugOrder升序。

**场景、入口与前置**：分组管理编辑模式拖动/移动；真实分组ID。

**字段与规则**：顺序权威为服务端/SDK ugOrder，不能只保存UI位置；默认组能否移动需确认。

**目标操作流程**：调整位置→提交顺序→成功回读完整列表→退出管理后新顺序；另端变化刷新。

**失败、取消、网络/多端与边界**：提交失败恢复原顺序并提示；多次拖动/异步回执不能回退更新；后台取消不假定服务端排序取消。

**验收设计（尚未执行）**：

- **C-024-A1**：移动后重进/另端顺序一致；不会重复/丢组。
- **C-024-A2**：失败恢复和最新请求版本处理明确，默认组限制按确认值执行。

**源码依据**：[NoaFriendGroupManagerVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/FriendGroup/NoaFriendGroupManagerVC.m:152)。

<a id="C-025"></a>
### C-025 将好友移动到业务分组

**新状态：未接｜建议P2｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧好友更多移动组进入manager canEdit=NO，updateFriendForFriendGroupWith(userUid,uguUserUid,uguUgUuid)成功返回。

**场景、入口与前置**：好友更多→移动分组；当前好友和目标组仍存在。

**字段与规则**：好友UID、当前组、目标组ID；同组选择是否提交按交互决定，但不能创建重复好友。

**目标操作流程**：显示当前组→选目标→提交→成功回读SDK→从原组移除并入目标→普通好友总量不变。

**失败、取消、网络/多端与边界**：目标组并发被删回默认/刷新；好友被删/注销不误创建；取消无变化；失败保留原归属；多端事件更新。

**验收设计（尚未执行）**：

- **C-025-A1**：移动后仅所属业务分组改变、总好友数和好友资料不丢。
- **C-025-A2**：取消/失败/目标被删/切号等场景不会遗留双归属。

**源码依据**：[NoaFriendManageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaFriendManageVC.m:304)；[NoaFriendGroupManagerVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/FriendGroup/NoaFriendGroupManagerVC.m:187)。

<a id="C-026"></a>
### C-026 真实群列表与成员关系同步

**新状态：未接｜建议P1｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧群标签取toolGetMyGroupList；群新增/更新/删除/同步完成重读，点击群到真实GroupChat。DB未明确指定排序；标签内searchView.hidden=YES。

**场景、入口与前置**：通讯录群聊标签；AUTH和群数据库就绪。

**字段与规则**：groupID/groupName/avatar与当前成员关系；顺序需产品定义，不能臆造旧按名称/时间排序；群列表不是会话列表。

**目标操作流程**：缓存显示→SDK群事件刷新→点合法群CHAT-001；加入/退出/解散更新该列表与相关会话。

**失败、取消、网络/多端与边界**：空群独立空态；普通断网保留缓存；退出/被移除/解散不能保留可发入口；群搜索通过C-027全局，不把隐藏搜索方法当可达。

**验收设计（尚未执行）**：

- **C-026-A1**：群列表来自真实已加入群，点击目标groupID正确。
- **C-026-A2**：新增/退群/解散/被移除与切号后列表状态一致，排序标准经用户确认。

**源码依据**：[NoaGroupListVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Group/NoaGroupListVC.m:28)；[NoaGroupListVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Group/NoaGroupListVC.m:162)；[ContactsView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/ContactsView.swift:20)。

<a id="C-027"></a>
### C-027 全局群搜索与群聊天定位

**新状态：未接｜建议P2｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧全局搜索groupName LIKE，三类各先最多3项更多展开；普通群标签内部搜索隐藏。

**场景、入口与前置**：通讯录顶部全局搜索；只当前SDK已有群。

**字段与规则**：只证实群名检索，不声称群ID/公告/成员全文检索；更多展开与M-017共用。

**目标操作流程**：输入→群结果→更多→选群→校验关系→真实群聊天；清空取消恢复。

**失败、取消、网络/多端与边界**：无匹配不是未加入群邀请码搜索；群刚退出/解散重查关系；文件助手等权限过滤作用于相应类型。

**验收设计（尚未执行）**：

- **C-027-A1**：群名称中文/英文/部分匹配及更多正确。
- **C-027-A2**：结果失效不能误入旧缓存群；不显示未经批准的群ID/公告搜索能力。

**源码依据**：[NoaGlobalSearchVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/NoaGlobalSearchVC.m:119)；[NoaIMDBTool+Group.mm](/Users/taobotaobo/Desktop/xgd/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/DataBaseModule/NoaIMDBTool+Group.mm:50)。

<a id="C-028"></a>
### C-028 建群选人、最近联系人及跨列表选中

**新状态：未接｜建议P2｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧首页更多创建群maxNum=200/minNum=2为可选好友数量；最近从单聊且现好友取最多50，排系统/注销；friendUid预选排除并提交自动加入；各组/搜索/已选勾选联动。

**场景、入口与前置**：首页/消息共享创建入口（通讯录加号旧只添加）；createGroup允许；当前可邀请好友。

**字段与规则**：200/2是旧入口配置，不等于服务端群最大人数；50是旧最近候选上限；自定义入口预选对象改变实际计数/最低数须确认。单聊设置另为max200/min1且带当前好友预选，不能共用首页min2。

**目标操作流程**：按最近/分组/搜索选人→顶部已选可删除→UID统一选中→显示人数→达到入口最低数方可完成→C-029真实建群。

**失败、取消、网络/多端与边界**：非好友/系统/注销/已有预选剔除；分组全选不能突破上限；角色在选择中收回禁止提交；取消不造群；另端删好友及时更新候选。

**验收设计（尚未执行）**：

- **C-028-A1**：跨最近/分组/搜索同UID选中一致；200上限/最低2及预选计数按入口配置测试。
- **C-028-A2**：全选/取消/顶部删除与按钮启用一致；没有凭客户端选择数量宣称服务器容量。

**源码依据**：[CandyTalkHomeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkHomeViewController.m:222)；[NoaInviteFriendVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/Session/Controllers/NoaInviteFriendVC.m:134)；[NoaInviteFriendVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/Session/Controllers/NoaInviteFriendVC.m:305)；[UserRoleAuthority.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Common/User/UserRoleAuthority.swift:16)；[NoaChatSingleSetVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatSingleSetVC.m:189)。

<a id="C-029"></a>
### C-029 创建群请求、返回与真实群聊天

**新状态：未接｜建议P2｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧createGroupWith包含ownerUid/ownerNickname/userUid/groupMemberParams[{userUid,nickName}]；返回LingIMGroup写SDK后跳真群聊并清创建导航。

**场景、入口与前置**：C-028完成选择；角色createGroup仍允许且成员有效。

**字段与规则**：owner与操作用户UID、成员列表/昵称；客户端初置userGroupRole=2等不应替代服务端权限权威。

**目标操作流程**：核对成员/权限→提交禁重复→有效群返回→SDK建群记录/会话→打开真实CHAT群页→通讯录群/消息同步。

**失败、取消、网络/多端与边界**：失败留选择并提示；成功但后续同步/导航失败可按groupID恢复，不能重复造群；后台/切号回执隔离；服务端人数/容量限制优先。

**验收设计（尚未执行）**：

- **C-029-A1**：有效创建回执生成同一真实groupID并两入口可见。
- **C-029-A2**：失败/超限/重复点击/取消和弱网不产生假群或多群，返回栈清理符合目标。

**源码依据**：[NoaInviteFriendVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/Session/Controllers/NoaInviteFriendVC.m:224)；[NoaInviteFriendVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/Session/Controllers/NoaInviteFriendVC.m:273)。

<a id="C-030"></a>
### C-030 本人好友二维码、复制账号与保存分享

**新状态：未接｜建议P2｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧添加页显示本人账号，长按0.8秒复制；生成二维码UserGetCreatQrcodeContentWith(content空/type=1/userUid)返回content再本地渲染，显示本人头像昵称账号，可保存/分享。

**场景、入口与前置**：添加好友页我的二维码；有效当前用户，保存需相册权限，分享依赖真实消息。

**字段与规则**：二维码内容由真实接口返回，不是前端直接写UID；生成失败不显示旧账号码；有效期只能按服务返回，不写固定天数。

**目标操作流程**：显示当前资料→请求content→渲染→保存相册/分享选择；复制账号给系统剪贴板明确反馈。

**失败、取消、网络/多端与边界**：离线/权限拒绝/图片失败/账号变化恢复；分享目标与发送结果分开；复制手势时长为旧值，是否保留可审阅。

**验收设计（尚未执行）**：

- **C-030-A1**：二维码接口目标UID与展示本人一致，换号不会复用旧码。
- **C-030-A2**：保存权限拒绝有提示，分享失败不报成功；复制结果是当前账号。

**源码依据**：[NoaAddFriendVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaAddFriendVC.m:140)；[NoaAddFriendVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaAddFriendVC.m:43)；[NoaMyQRCodeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/MineModule/Controllers/NoaMyQRCodeViewController.m:165)；[NoaMyQRCodeViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/MineModule/Controllers/NoaMyQRCodeViewController.m:242)。

<a id="C-031"></a>
### C-031 业务扫码添加好友及其他结果分流

**新状态：未接｜建议P2｜建议迁移业务扫码；导航/PC等另取舍｜范围：关联业务扫码。**

**旧项目已见行为（静态证据）**：旧首页扫码isRacing=NO→UserGetTransformQrcodeContentWith(content,userUid)，User结果到资料；Group/PCAuth/URL/Text另分流。isRacing=YES为导航码，已暂缓。

**场景、入口与前置**：共享业务扫码入口（不恢复导航扫码）；相机/相册授权。

**字段与规则**：扫码原文+当前UID；结果code/data类型；41055群禁扫码、50005过期；好友result.userInfo.uid是目标，不可本地直接建立关系。

**目标操作流程**：相机或相册识别→真实解析→User到C-015资料→用户再添加；群到C-032；PC/URL/Text只盘点共享模块，是否迁移另行确认。

**失败、取消、网络/多端与边界**：无权限、空码、无效/跨俱乐部/过期返回可重新扫码；页面退出停采集；并发识别去重；导航码不进入好友添加，也不能借此恢复邀请码/直连。

**验收设计（尚未执行）**：

- **C-031-A1**：好友码只打开正确资料、申请仍另一步；无假添加成功。
- **C-031-A2**：过期/禁止群码/相册无图/无权限处理与恢复可测；导航和业务码严格区分。

**源码依据**：[NoaQRcodeScanViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Base/Tools/ThirdLibs/QRCodeScan/NoaQRcodeScanViewController.m:73)；[NoaQRcodeScanViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Base/Tools/ThirdLibs/QRCodeScan/NoaQRcodeScanViewController.m:457)；[NoaQRcodeScanViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Base/Tools/ThirdLibs/QRCodeScan/NoaQRcodeScanViewController.m:523)。

<a id="C-032"></a>
### C-032 群二维码、扫码入群与待审核

**新状态：未接｜建议P2｜建议迁移（依赖群资料/审批）｜范围：关联群模块。**

**旧项目已见行为（静态证据）**：旧群设置isShowQrCode控制；type=2/content JSON groupId返回content+expireTime；扫码groupStatus==1且已在直接群聊，未在去申请；UserApplyJoinGroupWithData含inviteType=4、shareUserUid、需审原因。

**场景、入口与前置**：群资料二维码及C-031群码结果；群存在、二维码开放和本人关系有效。

**字段与规则**：groupID/expireTime/isOnGroup/isNeedVerify/shareUserUid；申请adviceStatus=0/topStatus=0/inviteType=4/当前userUid；不虚构7天有效期。

**目标操作流程**：获取/保存/分享真实群码→解析→已入直接CHAT→未入根据需审收原因→提交→需审返回等待；无需审成功进真实群。

**失败、取消、网络/多端与边界**：禁止二维码/过期/解散/已入/重复申请/请求成功但关系未同步区分；邀请码导航码另流程；审批需群管理关联消息，不提前写本地成员成功。

**验收设计（尚未执行）**：

- **C-032-A1**：已在/未在需审/未在直入/过期/禁码/解散六分支正确。
- **C-032-A2**：需审只显示已提交，不立即加入；真实加入后群列表和会话变化一致。

**源码依据**：[NoaChatGroupSetVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatGroupSetVC.m:716)；[NoaGroupQRCodeVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/GroupSet/NoaGroupQRCodeVC.m:145)；[NoaApplyJoinGroupViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Base/Tools/ThirdLibs/QRCodeScan/NoaApplyJoinGroupViewController.m:174)。

<a id="C-033"></a>
### C-033 通讯录文件助手入口与权限

**新状态：未接｜建议P2｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧顶部文件助手只有isShowFileAssistant.configValue=true显示，点击单聊sessionID=100002的NoaFileHelperVC；角色变化重新布局。新消息过滤已经接，但通讯录无入口。

**场景、入口与前置**：通讯录功能卡→文件助手；当前角色明确允许。

**字段与规则**：系统账号不算普通好友；100002为旧/新代码明确系统单聊账号；隐藏时不能残留角标或搜索绕过。

**目标操作流程**：权限允许展示入口→获取/建立真实系统会话→专用助手M-019→返回；权限变化重新过滤。

**失败、取消、网络/多端与边界**：权限缺失/关闭收入口，保留缓存供再次开启而不误删会话；当前未知字段默认false与旧所有入口严格一致需确认。

**验收设计（尚未执行）**：

- **C-033-A1**：开放/关闭/再开放时入口、消息会话及角标一致。
- **C-033-A2**：普通好友列表不混系统账号，点击不进普通好友主页/演示聊天。

**源码依据**：[CandyTalkContactVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkContactVC.m:228)；[NoaContactHeaderView.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Views/view/NoaContactHeaderView.m:126)；[ConversationsStore.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Message/Services/ConversationsStore.swift:99)；[ContactsView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/ContactsView.swift:20)。

<a id="C-034"></a>
### C-034 通讯录群助手/群系统通知入口

**新状态：未接｜建议P2｜建议迁移（依赖M-021）｜范围：关联系统会话。**

**旧项目已见行为（静态证据）**：旧顶部群助手到NoaSystemMessageVC，groupHelperType=SessionList/groupId空，系统session按SDK类型取得；具体通知/审批见M-021。

**场景、入口与前置**：通讯录群助手卡；真实系统会话，审批按当前群角色。

**字段与规则**：系统通知会话不等于普通群ID；全局群助手与某群申请页目标上下文分开。

**目标操作流程**：入口→专用系统列表→分类消息/群审核→选相关群或申请→真实处理→回执刷新。

**失败、取消、网络/多端与边界**：通知过期/已审核/群失效/角色降级不能继续处理；网络失败保留列表；不能只枚举systemMessage就称入口可用。

**验收设计（尚未执行）**：

- **C-034-A1**：全局系统会话与群内申请上下文正确，不拿空groupID当普通群聊天。
- **C-034-A2**：消息读取及审批结果回流群状态/未读，失败不假同意。

**源码依据**：[CandyTalkContactVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTalkContactVC.m:249)；[ContactsView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/ContactsView.swift:20)。

<a id="C-035"></a>
### C-035 我的团队与团队建群边界

**新状态：需取舍｜建议P3｜仅关联盘点，用户后续取舍｜范围：独立团队业务。**

**旧项目已见行为（静态证据）**：旧真实团队入口在我的showTeam→NoaTeamListVC；CandyTalkTeamViewController作为Tab的创建已注释，不能把其一键建群称当前可达通讯录能力。

**场景、入口与前置**：若未来批准：我的团队独立模块；通讯录本轮仅写关联。

**字段与规则**：showTeam角色控制；团队组织关系不同好友分组/群成员；新真实团队页未验证。

**目标操作流程**：用户决定团队是否迁移→按真实NoaTeamListVC/当前后端盘点列表/详情/邀请能力；不直接照搬死Tab入口。

**失败、取消、网络/多端与边界**：缺真实可达一键建群证据，待进一步调查；角色动态收回入口；跨用户团队数据隔离。

**验收设计（尚未执行）**：

- **C-035-A1**：未来选定范围只使用已证明可达的真实入口。
- **C-035-A2**：showTeam关闭无绕过；团队群能力另拿接口和运行证据。

**源码依据**：[CandyTallkMineViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTallkMineViewController.m:294)；[CandyTallkMineViewController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/CandyTallkMineViewController.m:442)；[CandyTabBarController.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Tab/Tabbar/CandyTabBarController.m:104)；[UserRoleAuthority.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Common/User/UserRoleAuthority.swift:16)。

<a id="C-036"></a>
### C-036 角色、系统配置与群成员访问统一守卫

**新状态：部分｜建议P0｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧添加/建群/文件助手/团队/角色标识/群成员访问受不同开关，部分直接入口权限不统一；新权限已缓存18个key和configData/authorityKey，但通讯录主体多数未消费。

**场景、入口与前置**：页面入口、资料按钮、提交前；当前UID/邀请码权限快照和群角色。

**字段与规则**：allowAddFriend/createGroup/isShowFileAssistant/showTeam/showRoleName/showHeadLogo/groupSecurity/showGroupPersonNum；数字/字符串/非法条目按当前解析，配额不写死。

**目标操作流程**：先算可见/可操作→进入仍复核→提交再次校验→权限变更立即更新入口/操作→失败解释原因。

**失败、取消、网络/多端与边界**：缓存A不能赋B；后台权限降级/群禁私聊与管理员绕过一起测；不能只隐藏菜单而允许深链/头像绕过。

**验收设计（尚未执行）**：

- **C-036-A1**：每入口至少权限允许/关闭/缺失/非法值及动态收回组合覆盖。
- **C-036-A2**：群普通成员/管理员/群主及groupSecurity访问规则准确，缓存不跨UID/邀请码。

**源码依据**：[NoaSessionMoreView.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/Session/Views/NoaSessionMoreView.m:48)；[NoaChatGroupSetVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ChatModule/Controllers/NoaChatGroupSetVC.m:281)；[UserRoleAuthority.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Common/User/UserRoleAuthority.swift:16)；[UserRoleAuthorityStore.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Common/User/UserRoleAuthorityStore.swift:22)。

<a id="C-037"></a>
### C-037 空态、取消、键盘与可访问性

**新状态：部分｜建议P1｜建议迁移｜范围：通讯录主体。**

**旧项目已见行为（静态证据）**：旧普通好友空态暂无好友；新区分无搜索结果/同步中/无好友/不可用，键盘可收起并有可访问标识。分组/群/申请扩展状态未接。

**场景、入口与前置**：所有通讯录页面；不是独立业务接口。

**字段与规则**：错误与无数据文案应准确；建议无障碍、键盘、长字适配为迁移质量要求，并非已证实旧完整支持。

**目标操作流程**：展示加载/有效缓存/空/错误→可用动作→取消/返回→保留合理上下文；操作提交中按钮反馈。

**失败、取消、网络/多端与边界**：同页加载失败与缓存并存不遮挡已有好友；输入法/屏幕阅读器/长描述/窄屏可使用；性能数据量与阈值待定义。

**验收设计（尚未执行）**：

- **C-037-A1**：已有新页空态不回归；新增申请/分组/群也能区分加载、真实空、无匹配、错误。
- **C-037-A2**：键盘收起、返回、VoiceOver及重复提交可验收，不把建议用例记为本轮已通过。

**源码依据**：[NoaFriendListVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaFriendListVC.m:121)；[ContactsView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/ContactsView.swift:79)；[ContactsView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/ContactsView.swift:72)。

<a id="C-038"></a>
### C-038 好友发真实消息与音视频入口依赖

**新状态：未接｜建议P1｜真实聊天建议迁移；通话另行取舍｜范围：关联真实聊天。**

**旧项目已见行为（静态证据）**：旧好友主页发消息跳SingleChat(sessionID=userUID)，通话显示依赖enableAudioAndVideoCalls==1并调用真实通话请求。新资料无聊天/通话按钮。

**场景、入口与前置**：有效好友资料→发消息；音视频若未来批准还需系统开关、权限/媒体依赖。

**字段与规则**：目标UID与真实单聊sessionID；资料来源groupID不把发消息误设群会话；注销/黑态/禁私聊按确认政策。

**目标操作流程**：发消息进入CHAT-001并准备真实会话/历史；通话作为CHAT独立扩展盘点，不能本地弹演示通话成功。

**失败、取消、网络/多端与边界**：无真实聊天页时不开假入口；对方删/注销/权限收回/断网准确；通话相机/麦克风和SDK路由另验收，不将其自动纳入P1文本聊天。

**验收设计（尚未执行）**：

- **C-038-A1**：资料发消息打开同UID真实单聊并能回资料；重复点击只有一聊天实例。
- **C-038-A2**：通话待取舍标明，系统开关关闭隐藏；本轮不声称已有通话闭环。

**源码依据**：[NoaUserHomePageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaUserHomePageVC.m:555)；[NoaUserHomePageVC.m](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaUserHomePageVC.m:243)；[ContactRecordDetailView.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Features/Contacts/Views/ContactRecordDetailView.swift:17)。

## 五、通讯录SDK调用/参数/返回及事件索引

以下为旧实际调用与当前新SDK静态声明核对。方法名保留旧拼写；Swift桥接名须后续以实际生成接口为准。**声明存在不是参数签名完全兼容、服务端成功或新UI已接**。不记录未经确认的HTTP endpoint，业务继续复用现有SDK验签/转TCP与会话所有权。

| 对应需求 | 方法/参数（旧已查） | 旧使用返回/后续动作 | 新SDK声明 |
| --- | --- | --- | --- |
| C-002/005 | toolGetMyFriendList、toolCheckMyFriendWith、toolUpdateMyFriendWith | 好友缓存数组/模型/写库结果；新已用于展示 | [SDKContactsClient](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Network/IM/Contacts/SDKContactsClient.swift:45) |
| C-013 | userSearchWith：userName | 数组→NoaUserModel结果，不保证所有手机号邮箱可查 | [User.h](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+User.h:16) |
| C-014/015 | checkMyFriendWith：userUid、friendUserUid | bool关系；好友/陌生资料分流 | [Friend.h](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Friend.h:121) |
| C-009 | getFriendApplyListFromServerWith：userUid、pageStart、pageSize20、pageNumber | 字典rows；20条分页/隐藏过滤 | [Friend.h](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Friend.h:125) |
| C-014/011 | addContactWith：userUid、friendUserUid | success表示已发送申请；不是立即好友 | [Friend.h](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Friend.h:133) |
| C-010 | confirmFriendApplyWith：userUid、friendUserUid（from方） | success后拉完整好友资料 | [Friend.h](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Friend.h:141) |
| C-016/017 | getFriendInfoWith：userUid、friendUserUid | 资料→SDK写库，备注空回昵称 | [Friend.h](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Friend.h:146) |
| C-017 | friendSetFriendRemarkAndDesWith：userUid、friendUserUid、remark、descRemark | success后回读完整资料；50/200旧输入规则 | [Friend.h](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Friend.h:150) |
| C-019 | deleteContactWith：userUid、friendUserUid | success后删服务会话；44016/44017仍受理/审核，非最终删 | [Friend.h](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Friend.h:137) |
| C-020 | getUserBlackStateWith、addUserToBlackListWith、removeUserFromBlackListWith：userUid、friendUserUid、status | bool为真才按真实成功；本轮不恢复UI | [Friend.h](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Friend.h:105) |
| C-022 | toolGetMyFriendGroupList、toolGetMyFriendGroupFriendsWith | 组/好友缓存，默认收空ugUuid，ugOrder排序 | [Friend.h](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Friend.h:81) |
| C-023 | createFriendGroupWith：userUid、ugName；updateFriendGroupWith：userUid、ugUuid、ugName；deleteFriendGroupWith：userUid、ugUuid | success后SDK/服务列表回读；删除不删好友 | [Friend.h](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Friend.h:159) |
| C-024/025 | updateFriendGroupWith：ugOrder；updateFriendForFriendGroupWith：userUid、uguUserUid、uguUgUuid | 回读排序/归属；与编辑模式分开 | [Friend.h](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Friend.h:163) |
| C-029 | createGroupWith：ownerUid、ownerNickname、userUid、groupMemberParams | 群对象转换SDK→真实群页 | [Group.h](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.h:24) |
| C-030/032 | UserGetCreatQrcodeContentWith：content、type1好友/2群、userUid | content、群expireTime；本地渲染 | [Group.h](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.h:192) |
| C-031 | UserGetTransformQrcodeContentWith：content、userUid | code、data(JSON)分类；41055禁止群码、50005过期 | [Group.h](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.h:198) |
| C-032 | UserApplyJoinGroupWithData：adviceStatus0、applyDesc、groupId、inviteType4、inviteUserId、topStatus0、userUid | bool成功后需审等待/无需审进群，两分支 | [Group.h](/Users/taobotaobo/Desktop/ddlNew/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+Group.h:204) |

**事件合同**：好友同步start/finish/failed；friendAdd/delete/change/confirm/online/groupChange触发当前用户回读；remarkChange获取friendUID再拉资料、按请求版本合并SDK；新朋友邀请/未读需要独立申请列表订阅，当前ContactsStore的普通changed不能代替申请业务。来源：[SDKContactsDelegate.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Network/IM/Contacts/SDKContactsDelegate.swift:17)、[SDKContactsClient.swift](/Users/taobotaobo/Desktop/ddlNew/ddlNew/Network/IM/Contacts/SDKContactsClient.swift:64)、[旧申请邀请代理](/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk/Modules/ContactsModule/Controllers/Friend/NoaNewFriendListVC.m:28)。

**仍待联调**：资料稀疏字段/成功但后续取资料失败，申请隐藏/已读多端范围，好友删除审核回流及分阶段清理，分组默认权限/数量，群服务端容量，精确搜索手机号邮箱，二维码跨俱乐部/过期与群需审，真实黑态/投诉范围。没有拒绝好友请求证据，不在接口表发明该方法。
