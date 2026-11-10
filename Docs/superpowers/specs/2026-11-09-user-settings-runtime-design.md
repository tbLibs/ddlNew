# userInfo.userSettings 驱动账号配置

状态：用户于2026-11-10要求按剩余字段实施，现已完成源码接线、离线回归与iOS编译。2026-11-09 对照 feature-all-5 与只读 xgd 源码；不修改 xgd，不自动提交或推送。

独立设计复核：原版已完成 builder check，结论为 nothing important left；后续按用户要求删除字段并收窄范围，本文不代表实现或运行验收。

## 目标与已确认边界

用户要求不再调用 getSystemConfig，改从 `/biz/user/userInfo` 的 `userSettings` 取得配置，并按 xgd 的实际消费逻辑接入功能。用户已确认：登录前使用本地默认值，登录后应用当前账号配置。

现有 UserSettings 负责解析与缓存；本轮模型检查发现原56字段漏掉 `oss_obs_bucket_name`、`oss_config_end_point_jia_su`，已补齐58字段并逐项添加中文注释，映射检查先失败再通过。用户随后明确删除 loginMethod、registerMethod、isMustInviteCode、captchaChannel 四项纯登录配置，2026-11-10 用户又要求删除 projectLogo、tenantCode、registerInviteCode、projectName、checkEnglishSymbol、captchaVersion 六项，随后又按用户指定清单删除18项未见配置字段及7项仅模型声明字段，当前模型保留23字段；showUserRead和isEncrypt继续保留。登录／注册及修改密码继续使用 LocalAccountPolicy，SDK租户参数继续使用 LocalSDKSettings。本轮功能接线已完成，验证及设备边界见交接文档2026-11-10对应章节。

继续保留启动不连接TCP、消息页后台恢复、列表始终可见与断线可点。`userInfo` 失败不能阻塞消息列表，不能重新引入 getSystemConfig 或第二套配置刷新定时器。

## 方案选择

建议使用统一、按账号隔离的有效配置快照：本地默认值 → 当前账号已验证的 userSettings → 各业务消费。

逐页面直接读取字符串会重复转换、漏刷新和账号隔离；恢复旧的全局系统配置服务违背不调用 getSystemConfig 的要求。统一快照是本次建议的实现方式；用户已确认的是登录前后边界，具体实现由开发者负责，按用户本轮实施指令执行。

## 数据流、生效时机与错误处理

1. LocalSDKSettings 和 LocalAccountPolicy 保持本地固定规则；保留 LocalMessagingSettings、LocalMediaSettings 作为消息及媒体配置的默认值。新增纯值解析模型及 MainActor 账号配置 Store，以企业邀请码、UID、认证轮次标识所有权。业务不能直接修改原始 UserSettings。
2. 启动与 AUTH 前一律使用本地有效默认值。即使已有本地用户资料，也不能仅凭 currentUser 非空激活账号业务配置。首次 AUTH 成功后，在通话配置、ChatRuntime 等业务激活前，恢复同账号／同企业缓存配置；没有配置则用默认值。
3. 沿 SessionMaintenanceCoordinator 现有首次／前台／定时／节点切换的 userInfo 刷新入口发布新快照。沿用 UID、企业、认证轮次、导航版本及 profileRevision 拒收规则；配置在资料合并成功后才更新。读取别人的资料不得更新当前账号配置。
4. 缺失／null 字段继续沿用同账号旧值。显式空字符串在原始模型中保留清空语义：可选自定义域名等清空后使用该供应商普通节点；必需字段为空或非法时该功能组不可用，不能拼接另一租户的默认桶或密钥。初次完全未提供一个功能组时沿用本地默认组；服务端提供该组后，按组验证原子发布，避免供应商与桶／域名来自不同配置。解析器需区分字段未提供与显式空值，不能仅凭 String.isEmpty 判断。
5. 普通临时断线保留当前已认证账号配置供列表展示及恢复使用；不授予网络业务资格。退出、认证明确失败、切换账号／企业撤销账号快照，业务回到本地默认值；SDK签名及验证码参数始终沿用本地规则。同UID重新认证仍需新轮次，旧回调不能重新安装配置。
6. 相同有效值不重复发布。配置刷新失败保留上一份同账号快照；尚无有效配置时维持默认状态或功能不可用状态，不清空消息列表，不输出响应、签名参数、STS 或 AppSign 日志。

### 缓存兼容与配置组补充

现有 UserSettings 的所有属性默认空字符串且序列化全部键，旧缓存不能区分“未提供”和“显式清空”。实施时增加本地缓存版本及字段存在性信息，仍附着现有用户资料缓存，不建立第二套远端缓存。新响应在合并前记录实际提供的有效键；新格式只对已提供字段保留存在性。旧版本缓存中的设置不直接应用于业务或上传配置，等当前轮次 userInfo 成功后升级；等待期间用本地默认配置。旧用户资料和消息缓存继续显示。缓存元信息不得作为请求字段发送给服务端。

有效组具体分为：群间隔、普通撤回、管理撤回、群人数、通话、文件存储。相互独立的开关不因其它配置坏值整体失效。人数／撤回／通话开关的非法值采取保守值（人数仅管理、撤回和新通话关闭）；群间隔非法值使用本地默认且不能变成0节流。数值撤回非法关闭，不把负数／溢出解释为无限撤回。

通话组要求供应商合法，Zego的AppID为非零UInt32，LiveKit不要求Zego字段；无效时禁用新通话，当前通话快照维持。文件存储组按供应商验证必要参数；同供应商部分更新可合并上一份同账号配置，切换供应商时必须在本次响应中拿到该供应商的完整必要参数，不能借用旧供应商的桶／节点／区域。MinIO使用现有业务节点与协议目录；云供应商要求对应桶和endpoint，AWS／腾讯同时要求区域；OBS自定义域名可空。新供应商组不完整时新上传报配置不可用，已开始上传按其快照继续。独立开关允许逐项变更，不把整个23字段配置作为全有或全无事务。

## 对照 xgd 的接线范围

### 接入项目已有业务

| 字段 | xgd 用途 | ddlNew 处理 |
| --- | --- | --- |
| groupMessageInterval | 群普通成员发送节流；毫秒，0回退2000ms | SDKChatClient 权限快照及 ChatStore 发送前复核，保留管理员豁免；非法／负数不解释为无节流 |
| messageRecallTime | 自己消息撤回窗口；分钟，0关闭 | ChatPermission 与长按操作刷新；动作执行前再校验，正数转换要防溢出 |
| groupMangerMessageRecallTime | 群管理撤回他人消息的0/1开关 | 接入 canRecallOthers，继续校验群主／管理员及目标成员级别，不当作时长 |
| onlyAllowAdminViewGroupPersonCount | 普通成员隐藏人数，角色 showGroupPersonNum 可放行 | 群设置等已有群人数入口共用判断，配置变化更新可见页面，保留角色放行 |
| enableAudioAndVideoCalls、video_source_config、video_source_config_zg_appId | 通话开关、LiveKit/Zego、Zego AppID | CallConfigurationStore 从账号快照取值，已有通话入口与呼入校验同步更新 |
| oss_config_type、oss_config_bucket_name、oss_config_end_point、oss_config_region_id | MinIO/Ali/AWS/Tencent/OBS选择与上传参数 | SDKChatMediaClient、SDKCloudChatMediaClient 使用同一份上传配置快照 |
| oss_obs_bucket_name、oss_obs_end_point、oss_obs_custom_domain_put、oss_obs_custom_domain_get | OBS桶、普通节点、上传／下载自定义域名 | OBS分支完整接线；维持当前HTTPS规则和临时STS认证 |

### 保留原始字段，不能伪造接线的部分

用户要求移除的25项（18项在xgd无对应配置字段，7项只有模型声明）已从模型及设计中删除。除下述字段外，不再保留这些无消费配置。

- `isEncrypt`：按用户本轮指定范围继续保留；xgd 中同名上传任务参数不等于系统配置消费者，不据此切换现有加密协议。
- `showUserRead`：xgd 系统模型中的字段已注释掉，实际使用角色接口的同名权限。ddlNew 保留现有 UserRoleAuthorityStore，不以 userSettings 覆盖角色权限。同理添加好友、建群和上传配额继续使用现有角色权限和服务端结果。
- `video_source_config_zg_appSign`、`video_source_config_zg_server_address`、备用 WebSocket 地址：xgd 传入旧 NoaCallManager，进一步核对其Zego实现发现这些值仅保存、创建引擎仍只传AppID和房间token；ddlNew 直接集成 ZegoExpressEngine 并使用服务端房间 token。保留解析，当前功能接线继续使用现有 token 模式，不把旧通信地址当成媒体房间地址，也不切换旧呼叫协议。若以后迁移旧信令通道再接入这些字段。
- `verifyAppVersion`、`sys_uploadlog_domain`：用户明确不新增版本检查和日志上传，保留字段。
- `member_active_points_interval`：用户明确纳入群成员活跃积分同步。进入群、群设置成员读取成功及账号配置更新时检查间隔；先完整读取成员，再以SDK lastSyncActiviteScoreime为游标分页请求积分，全部成功且认证身份仍有效才写入已有SDK成员表并推进游标。失败不阻塞成员和聊天展示，不新增后台全群轮询。空增量成功也记完成时间；同群在途去重，失败最短5秒重试，避免间隔0及重入造成循环。

## 转换规则与实时刷新

- 布尔配置解析 true/false 与 1/0；数字配置按各字段枚举或范围校验。原始值不被归一化后的值覆盖，方便将来扩展。
- 默认值保留当前项目设置。服务端明确关闭立即生效；非法值不能误当开启。撤回窗口0与群间隔0具有不同含义，分别处理。
- 通过已有 ChatRuntime／SDK观察的 permissionsChanged 路径让当前聊天页重读权限；群设置视图订阅有效配置。不能只修改提交侧而长期保留过期菜单。
- 通话配置变化约束新呼入／发起／加入操作；已经开始的通话持有原始会话配置直到正常结束，避免更新开关直接拆毁媒体引擎。尚在创建房间中的旧配置操作，回执回来需校验完整配置版本（含AppID，不只provider），失效则按既有清理流程结束未接通房间。
- 上传开始时捕获供应商、桶、节点和区域，在 STS、分片和完成请求中使用同一配置。新上传用新快照；旧上传同账号配置变化可继续用原快照，退出／换号仍立即取消并拒收结果。

## 本地认证参数边界

用户已删除 userSettings 中的 tenantCode 与 checkEnglishSymbol。SDK接口签名、响应解密及自建上传继续使用 LocalSDKSettings.tenantCode；登录／注册／修改密码继续使用 LocalAccountPolicy。账号配置刷新不得覆盖这些本地参数。本轮不再涉及动态tenantCode切换及其请求快照改造。

## 验证与交付

1. 保留的23字段完整往返、中文注释覆盖、旧缓存、部分更新、显式空／null、布尔数字、账号UID拒收；已有本轮模型检查已通过，功能接线后补配置解析与分组验证检查。
2. 初次登录无配置、本地缓存同账号、AUTH前不可应用、AUTH后发布、退出默认、跨企业同UID、同UID新轮次迟到回包、临时断线保留、profileRevision拒收。
3. 撤回0／正数／非法、群间隔0回退／非零／非法、群角色和人数权限、角色showUserRead不受系统字段覆盖。
4. 通话开启／关闭／供应商及AppID变化、未完成建房回执、已接通通话维持快照；上传中途变更配置及退出，OBS自定义域名为空，供应商切换不混用旧桶。
5. 确认删除字段不会重新进入模型或覆盖本地认证参数，登录／注册／修改密码仍沿原规则运行。
6. 回归 SessionMaintenance、Login／SessionRestore、Calls、Chat／Groups、Media、Network 合适入口；generic iOS无签名构建，PATH排除sentry-cli。真实服务连接／通话／上传需另行设备验收，离线检查不能代替。
7. 修改交接文档对应章节，说明有效数据源、刷新与清理语义、未移植功能。源码搜索确认 App 不新增 getSystemConfig 请求。保留用户既有改动，不操作实体设备、不提交推送。

## 源码依据

- xgd `NoaChatKit/CandyTalk/Base/Base/Manager/SsoRacing/NoaSystemSettingModel.h`：字段文档；`NoaUrlHostManager.m` requestSystemConfigInfo／requestTimedRefreshSystemConfigInfo／callSDKConfig：旧配置获取及应用。
- xgd `Modules/ChatModule/Controllers/NoaChatViewController.m`、`Views/GroupSet/NoaChatSetGroupInfoCell.m`：群间隔、撤回、人数、活跃积分。
- xgd `Base/NoaFileUpload/NoaFileUploadTask.m`、`Auth/Model/LoginAccount/NoaLoginAccountDataHandle.m`、`Base/Tools/Tool/NoaAppUpdateTools.m`：上传、认证方式、版本开关。
- ddlNew `Common/User/UserSettings.swift`、`UserSessionStore.swift`、`Network/Session/SessionMaintenanceCoordinator.swift`、`Network/IM/Chat/SDKChatClient.swift`、`SDKChatMediaClient.swift`、`SDKCloudChatMediaClient.swift`、`Features/Calls/Services/CallConfigurationStore.swift`、`CallCoordinator.swift`。
- ddlNew内嵌SDK `ConnectModule/HttpRequest/NoaIMHttpManager.m`、`HttpToTcpRequest/LingIMTcpCommonTool.m`：保持现有本地tenantCode使用方式，本轮不改动态签名逻辑。
