# 通讯录与消息独立测试报告

日期：2026-10-13；分支：feature-message-4。**用户已要求暂停开发与联调。** 本报告保留独立QA历史证据，根追加最新暂停时复测结果；详见[交接文档](CONTACTS_MESSAGE_MIGRATION_HANDOFF_2026-10-13.md)。

## 状态口径与执行策略

- Passed：该证据层已实际执行并通过；不从离线通过推断UI或后端通过。
- Failed：已有可重复失败或明确实现缺口，逐需求反馈修复。
- Blocked：缺设备、认证、实现或回执，尚无通过证据。
- Deferred：用户明确暂缓，缺失不计为开发失败。
- 逐116个需求ID与232条A1/A2检查，并同时适用C-G/M-G公共要求；部分授权子能力与暂缓子能力分开。
- 专用测试身份只称账号A/B与测试租户；凭据仅通过设备登录UI输入，报告脚本不记录密码。仅操作专用身份、用户授权既有测试群与标记消息，不退出未知账号或清空已有历史。
- 独立测试直接编译生产Store/模型，注入可暂停客户端覆盖乱序、迟到、重复、取消、100分页、ACK去重、角色降级、助手开关和删除范围；这一层没有真实后端。
- UI用生产视图的隔离测试宿主，匿名固定数据限Tests/MigrationAcceptance，不增加生产登录/AUTH绕过。覆盖窄屏、横屏、最大字号、深浅色、键盘、返回、菜单、错误/空/加载与VoiceOver语义。
- 全工程无签名真机目标clean build由根统一执行；不并行占同DerivedData。

## 已执行证据

| 证据 | 状态 | 实际结果/限制 |
| --- | --- | --- |
| Tests/Contacts/run-checks.sh | Passed | 43生产逻辑 + 19SDK分页，exit0；ObjectMapper既有警告 |
| Tests/Contacts/run-business-checks.sh | Passed | 原业务规则exit0，脚本未打印断言数 |
| Tests/Conversations/run-checks.sh | Passed | 排序/Store/操作3入口exit0 |
| Tests/Chat/run-checks.sh | Passed | 最新根复测23项exit0，包含撤回/清历史失效回调；此前8项为历史快照 |
| Tests/Groups/run-checks.sh | Passed | 原群选择规则exit0 |
| Tests/MigrationAcceptance/run-contacts-checks.sh | Passed | 最新独立16/16：原9项加缺资料、删除/新增关系、搜索加载/乱序/清空；新增后实际exit0 |
| Tests/MigrationAcceptance/run-chat-checks.sh | Passed | 首轮14/15、新增旧错误后15/16均保留历史；最新修复16/16，exit0 |
| 真实两端登录与业务 | Blocked | 实际运行端为iPhone与电脑My Mac，独立通过添加好友页“我的账号”确认手机账号B、Mac账号A；第二台已连接手机仅有安装记录，未证实AUTH。8101 WDA与目标应用AX已可控制；当前已安装评审修复前版本的授权群双向QA文本实收已观察：两端各精确1条，本端输入清空；服务ACK字段、已读计数与最新安装版本复验仍待观察，不由本端气泡推断这些通过 |
| 生产App阻塞截图 | Blocked | /tmp/ddlNew-qa-invitation-blocked.png，无凭据；不证明当前代码登录能力或加密根因 |
| 全工程clean build | Passed：较早源码快照 | 根签名clean build日志/tmp/ddlNew-contacts-message-final-clean.log；最新三项修正由增量签名workspace构建验证，/tmp/ddlNew-contacts-message-system-config-transport-build.log |
| 隔离UI宿主 | Passed：已执行布局子场景 | 独立QA此前确认最大字号首屏与草稿；QA-20工具栏重叠由根修复并默认字号宿主复测，/tmp/ddlNew-qa-keyboard-final-green.png；最新最大字号、真实VoiceOver/iPad仍待测，图片/GIF替身不证明真实业务 |
| Tests/MigrationAcceptance/run-waiter-checks.sh | Passed | 独立4/4：两等待器重复回调、提前取消、Task取消及迟到结果 |
| 全部离线脚本汇总 | Passed | 最新根实际38/38入口exit0，总151.07秒，/tmp/ddlNew-migration-qa-final-transport/summary.json；含PreviewInvalidation9、SystemConfigTransport3和Chat核心23。此前独立36/36为前一快照，/tmp/ddlNew-migration-qa-postreview/summary.json，总106.59秒 |

## 新增独立执行

| 证据 | 状态 | 结果 |
| --- | --- | --- |
| Tests/MigrationAcceptance/run-media-checks.sh | Passed | 独立媒体6/6：空/录音阈值、重复、取消迟到、上传仅发送中 |
| Tests/MigrationAcceptance/run-applications-search-checks.sh | Passed | 最新独立16/16：原14项加加载/审核失败期间同步事件合并补读，红后修复独立通过；10分页/partial/角色/筛选反序与搜索生命周期 |
| Tests/Contacts/run-waiter-checks.sh | Passed | 共享资料版本4 + SDK等待3，实际执行exit0 |
| Tests/MigrationAcceptance/run-transport-checks.sh | Passed | 最新独立88/88，exit0，新增type101群头像包装/解码；历史73/78的5缺陷与追加巨大期限/空白Token的8缺陷均修复复验。AESv2/XOR短文件、损坏、取消及4供应商签名/STS合同；完全离线、不访问云账户 |
| Tests/MigrationAcceptance/run-groups-checks.sh | Passed | 独立10/10：少于2/正好200/超过200、重复UID、本人、动态权限、重复请求、cachePending、换租户、列表乱序与退出迟到 |
| Tests/MigrationAcceptance/run-notification-checks.sh | Passed | 最新独立14/14：原10项加列表发起前游标、等待期间新通知保留、筛选反序各自边界；提取原生产load/mark/request与真实ObjectMapper+SDK形状mock，不证明SDK二进制或后端 |
| Tests/MigrationAcceptance/run-cloud-policy-checks.sh | Passed | 独立14/14：101目录/无聊天配额/空字节、普通权限/溢出、4种聊天目录、HTTPS升级/桶前缀/OBS自定义/URL拒绝；提取生产无网络逻辑 |

## 缺陷与独立复核

| 缺陷 | 需求 | 状态 | 可执行证据 |
| --- | --- | --- | --- |
| QA-01 备注计数/空白/关系守卫 | C-017/C-G5 | Passed | 独立Store回归修复已通过 |
| QA-02 同UID资料错序覆盖 | C-016 | Passed | 两请求先回新后回旧，保留最新资料 |
| QA-03 回读换号串成功提示 | C-G7 | Passed | 回读挂起后prepare新身份，旧操作false且notice为空 |
| QA-04 资料失败仍报完成 | C-010/017 | Passed | 写回执后profile失败显示待同步 |
| QA-05 删除后旧历史复活 | CHAT-002/021 | Passed | 墓碑及操作完成后迟到upsert不复活 |
| QA-06 0窗无限与禁言编辑 | CHAT-018/022/023 | Passed | 0窗关闭，禁言禁编辑 |
| QA-07 旧补页覆盖ACK时间 | CHAT-005 | Passed | 900ms确认后100ms补页不回退 |
| QA-08 旧补页回退编辑正文 | CHAT-023 | Passed | 开发修复后独立15/15已复验；历史新旧正文不回退 |
| QA-09 设置往返丢草稿 | M-015 | Passed | 初次失败；最新原页面往返独立复验保留value，/tmp/ddlNew-qa-chat-draft-retest.png；真实重启仍待测 |
| QA-10 最大字号首屏聊天 | CHAT-003 | Passed | 历史停长首消息、过度滚动空白均保留；最新独立宿主首次进入即见末条正文，媒体2列无半字裁剪；/tmp/ddlNew-qa-chat-maxfont-green.png |
| QA-11 备注未改可保存/无标签/脏取消 | C-017/C-037 | Passed | 最新UI初始保存disabled、label好友备注、脏取消放弃确认；/tmp/ddlNew-qa-remark-discard-retest.png |
| QA-12 换租户旧错误残留 | CHAT-049 | Passed | 最新run-chat-checks 16/16，第16断言通过 |
| QA-13 分组SDK空数组与跨账号写库 | C-022/C-G7 | Blocked | 静态发现helper空数组不回调，开发已改raw request+validated写库；等待SDK隔离与真实服务复核 |
| QA-14 媒体包装损坏与签名canonical | CHAT-012/013 | Passed | 历史5失败；最新Transport86/86已独立复验修复 |
| QA-15 STS巨大期限与空白Token | CHAT-012/013 | Passed | 历史4供应商各2失败；最新拒绝1e308及纯空白Token，86/86独立复验 |
| QA-16 群通知ACK计数边界 | M-021/M-G4 | Passed | 原5/6失败：10旧未读变为最新1被误清零；修后6/7失败：他端最新已读0被造1；再次修复最新独立10/10，含请求轮次/租户 |
| QA-17 群头像101包装兼容 | CHAT-034 | Passed | 旧xgd群头像明确isEncrypt:YES；原生产codec未包含101，根补齐；新增独立type101包装/解码与云策略通过 |
| QA-18 群申请事件在途丢失 | M-021 | Passed | 原加载中refresh直接返回，新增独立a100→事件应补读a101红；根修复合并pendingRefresh后独立16/16通过 |
| QA-19 列表等待期间新通知被提前读 | M-021 | Passed | 根与QA静态确认旧mark取等待后最新游标；改为每Page不可变快照；独立14/14含m1列表/m2新通知及筛选反序验证 |
| QA-20 新键盘工具栏遮composer | CHAT-003/M-028 | 修复Passed：默认字号隔离UI | 历史失败截图/tmp/ddlNew-qa-postreview-keyboard.png。根移除系统工具栏，收起行归入composer，发送按钮44×44；/tmp/ddlNew-qa-keyboard-final-green.png确认不重叠且收起后正文保留。生产Mac输入及最新最大字号/VoiceOver/iPad仍待验收 |

## 逐需求验收矩阵

最终状态按完整验收需求保守记录；离线子证据列出，必需真实双端证据缺失仍Blocked。开发尚未结束，不把仍在接入的页面标成最终Failed。

| ID | 需求 | 最终状态 | 离线/静态证据 | UI | 真实双端 | 范围/阻塞 |
| --- | --- | --- | --- | --- | --- | --- |
| C-001 | 页面入口、好友/业务分组/群聊切换 | Blocked | — | Blocked | Blocked | P1；建议迁移 |
| C-002 | 好友名单、名称优先级与排序 | Blocked | Contacts43/19 Passed | Blocked | Blocked | P0；建议迁移 |
| C-003 | 好友在线、注销及异常账号状态 | Blocked | Contacts43/19 Passed | Blocked | Blocked | P0；建议迁移 |
| C-004 | 真实头像、文件Host变化与图片降级 | Blocked | Contacts43/19 Passed | Blocked | Blocked | P0；建议迁移 |
| C-005 | SDK同步、错误恢复和跨账号隔离 | Blocked | Contacts43/19 Passed | Blocked | Blocked | P0；建议迁移 |
| C-006 | 本地好友检索与旧全局好友检索差异 | Blocked | Contacts43/19 Passed | Blocked | Blocked | P1；建议迁移 |
| C-007 | 首字母快速定位 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| C-008 | 新朋友入口、申请未读与通讯录角标 | Blocked | 通讯录业务101未读/可见扣1/重开/新版本 Passed | Blocked | Blocked | P1；建议迁移 |
| C-009 | 好友申请列表、分页与状态 | Blocked | 业务规则与方向 Passed | Blocked | Blocked | P1；建议迁移 |
| C-010 | 同意好友申请与完整好友落库 | Blocked | 独立Contacts对应断言Passed | Blocked | Blocked | P1；建议迁移 |
| C-011 | 申请详情、重新申请与发消息分支 | Blocked | — | Blocked | Blocked | P1；建议迁移 |
| C-012 | 申请本地隐藏与“拒绝”证据边界 | Blocked | 独立Contacts对应断言Passed | Blocked | Blocked | P2；本地隐藏建议迁移；服务端拒绝待取舍 |
| C-013 | 按账号/手机号/邮箱查找用户 | Blocked | — | Blocked | Blocked | P1；建议迁移 |
| C-014 | 发送添加好友申请与权限统一 | Blocked | — | Blocked | Blocked | P1；建议迁移 |
| C-015 | 本人/陌生人/群成员资料关系判断 | Blocked | — | Blocked | Blocked | P1；建议迁移 |
| C-016 | 好友资料展示、现场刷新与实时变化 | Blocked | 独立Contacts对应断言Passed | Blocked | Blocked | P1；建议迁移 |
| C-017 | 编辑备注与备注描述 | Blocked | 独立Contacts规则及备注UI子证据Passed | 局部Passed | Blocked | P1；建议迁移 |
| C-018 | 推荐好友名片 | Blocked | — | Blocked | Blocked | P2；建议迁移（依赖CHAT名片） |
| C-019 | 删除好友、审核受理与聊天记录清理 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| C-020 | 真实黑名单能力盘点 | Deferred | — | Deferred | Deferred | P3；仅盘点，用户后续取舍 |
| C-021 | 真实投诉/举报表单与上传依赖盘点 | Deferred | — | Deferred | Deferred | P3；仅盘点，用户后续取舍 |
| C-022 | 好友业务分组、默认组与展开收起 | Blocked | 共享资料版本/SDK等待 Passed；空组SDK静态修复 | Blocked | Blocked | P2；建议迁移 |
| C-023 | 创建、改名与删除业务分组 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| C-024 | 业务分组排序管理 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| C-025 | 将好友移动到业务分组 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| C-026 | 真实群列表与成员关系同步 | Blocked | 独立群列表乱序/去重/退出 Passed | Blocked | Blocked | P1；建议迁移 |
| C-027 | 全局群搜索与群聊天定位 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| C-028 | 建群选人、最近联系人及跨列表选中 | Blocked | 群规则10/10 Passed；最近/分组静态 | 选人局部Passed | Blocked | P2；建议迁移 |
| C-029 | 创建群请求、返回与真实群聊天 | Blocked | 独立群建群2/200/201/重复/权限/迟到/待同步 Passed | Blocked | Blocked | P2；建议迁移 |
| C-030 | 本人好友二维码、复制账号与保存分享 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| C-031 | 业务扫码添加好友及其他结果分流 | Blocked | — | Blocked | Blocked | P2；建议迁移业务扫码；导航/PC等另取舍 |
| C-032 | 群二维码、扫码入群与待审核 | Blocked | — | Blocked | Blocked | P2；建议迁移（依赖群资料/审批） |
| C-033 | 通讯录文件助手入口与权限 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| C-034 | 通讯录群助手/群系统通知入口 | Blocked | — | Blocked | Blocked | P2；建议迁移（依赖M-021） |
| C-035 | 我的团队与团队建群边界 | Deferred | — | Deferred | Deferred | P3；仅关联盘点，用户后续取舍 |
| C-036 | 角色、系统配置与群成员访问统一守卫 | Blocked | — | Blocked | Blocked | P0；建议迁移 |
| C-037 | 空态、取消、键盘与可访问性 | Blocked | — | Blocked | Blocked | P1；建议迁移 |
| C-038 | 好友发真实消息与音视频入口依赖 | Blocked | — | Blocked | Blocked | P1；真实聊天建议迁移；通话另行取舍 |
| M-001 | 真实会话首次加载与有效类型过滤 | Blocked | Conversations对应检查Passed | Blocked | Blocked | P0；建议迁移 |
| M-002 | 置顶分区、时间排序与稳定去重 | Blocked | Conversations对应检查Passed | Blocked | Blocked | P0；建议迁移 |
| M-003 | 单群聊标题、备注与真实头像优先级 | Blocked | — | Blocked | Blocked | P1；建议迁移 |
| M-004 | 最新预览、群发送者、@与特殊消息摘要 | Blocked | — | Blocked | Blocked | P1；建议迁移 |
| M-005 | 会话时间格式、校时与缺值 | Blocked | — | Blocked | Blocked | P1；建议迁移 |
| M-006 | 未读行、手动提醒、免打扰与Tab角标 | Blocked | Conversations对应检查Passed | Blocked | Blocked | P0；建议迁移 |
| M-007 | 同步进度、连接提示与缓存错误恢复 | Blocked | — | Blocked | Blocked | P0；建议迁移 |
| M-008 | 全部/未读筛选与本地预览搜索 | Blocked | Conversations对应检查Passed | Blocked | Blocked | P0；建议迁移 |
| M-009 | 会话点击、真实路由与进入清读边界 | Blocked | — | Blocked | Blocked | P1；建议迁移 |
| M-010 | 会话置顶与取消置顶 | Blocked | — | Blocked | Blocked | P1；建议迁移 |
| M-011 | 会话免打扰与取消 | Blocked | — | Blocked | Blocked | P1；建议迁移 |
| M-012 | 手动标记未读/已读与读游标 | Blocked | — | Blocked | Blocked | P1；建议迁移 |
| M-013 | 删除会话且保留历史 | Blocked | — | Blocked | Blocked | P1；建议迁移 |
| M-014 | 全会话已读同步能力与主动入口待确认 | Blocked | — | Blocked | Blocked | P2；事件建议保留；主动入口待取舍 |
| M-015 | 真实草稿、@片段与恢复来源差异 | Blocked | — | Blocked | Blocked | P1；建议迁移 |
| M-016 | 全局搜索三分类与更多 | Blocked | 独立搜索生命周期/迟到 Passed | Blocked | Blocked | P2；建议迁移 |
| M-017 | 搜索好友/群/助手的目标分流与权限 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| M-018 | 消息搜索命中、补页与原消息定位 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| M-019 | 文件助手专用真实会话 | Blocked | — | Blocked | Blocked | P2；建议独立迁移 |
| M-020 | 群发助手、收件人选择和部分失败 | Deferred | — | Deferred | Deferred | P3；独立范围，用户后续取舍 |
| M-021 | 群系统通知、申请同意/拒绝与批量审核 | Blocked | 独立群申请10分页/partial/角色/迟到 Passed | Blocked | Blocked | P2；建议独立迁移 |
| M-022 | 签到提醒历史与真实签到依赖 | Deferred | — | Deferred | Deferred | P3；独立签到范围，用户后续取舍 |
| M-023 | 支付助手类型与不可达边界 | Deferred | — | Deferred | Deferred | P3；仅类型盘点，用户后续取舍 |
| M-024 | 更多菜单、添加/创建群/业务扫码/群发 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| M-025 | 双击消息Tab循环定位未读 | Deferred | — | Deferred | Deferred | P2；交互保留待用户审阅 |
| M-026 | 多端会话事件、删除与退出清理 | Blocked | Conversations对应检查Passed | Blocked | Blocked | P0；建议迁移 |
| M-027 | 消息角色权限与系统业务配置缺口 | Blocked | — | Blocked | Blocked | P0；建议迁移 |
| M-028 | 加载/空/错误、键盘和可访问性 | Blocked | — | QA-20默认字号宿主已修复复测 | Blocked | P1；真实VoiceOver/iPad及其他未执行用例仍待验证 |
| M-029 | 通知/深链打开真实会话与Badge依赖 | Deferred | — | Deferred | Deferred | P2；推送/深链独立待确认 |
| CHAT-001 | 真实单群聊建立与路由上下文 | Blocked | — | Blocked | Blocked | P1；建议迁移 |
| CHAT-002 | 历史首屏、本地缓存与100条游标分页 | Blocked | 独立Chat对应断言Passed | Blocked | Blocked | P1；建议迁移 |
| CHAT-003 | 滚动位置、新消息提示与搜索定位 | Blocked | 首屏UI QA-10修复Passed | 局部Passed | Blocked | P1；中部新消息提示/搜索定位仍未完整验证 |
| CHAT-004 | 实时收消息、双ID去重与状态事件分流 | Blocked | 独立Chat对应断言Passed | Blocked | 双向群文本子用例Passed；完整Blocked | P1；建议迁移 |
| CHAT-005 | 发送落库、发送中/成功/失败与ACK重排 | Blocked | 独立Chat对应断言Passed | Blocked | Blocked | P1；建议迁移 |
| CHAT-006 | SDK失败分类、ACK重试与人工重发 | Blocked | — | Blocked | Blocked | P1；建议迁移 |
| CHAT-007 | 正文可见批量已读、语音播放与已读提示 | Blocked | — | Blocked | Blocked | P1；建议迁移 |
| CHAT-008 | 消息日期分隔、服务端校时与气泡基础 | Blocked | — | Blocked | Blocked | P1；建议迁移 |
| CHAT-009 | 文本、Unicode emoji、敏感处理与输入恢复 | Blocked | — | Blocked | Blocked | P1；建议迁移 |
| CHAT-010 | @选择、@所有人、片段编辑与限制 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-011 | 语音录制、取消、上传、播放与已读 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-012 | 相册/拍摄图片视频、转换文件与上传任务 | Blocked | Media6/6、Transport88/88 Passed | 附件入口局部Passed | Blocked | P2；建议迁移；真实上下载与ACK待验 |
| CHAT-013 | 文件选择、上传/下载、文件名与系统打开 | Blocked | Media6/6、Transport88/88 Passed | 文件入口局部Passed | Blocked | P2；建议迁移；真实打开待验 |
| CHAT-014 | 贴纸/GIF/游戏表情及表情商城 | Blocked | — | Blocked | Blocked | P2；贴纸建议迁移；商城独立取舍 |
| CHAT-015 | 真实名片推荐、接收与资料分流 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-016 | 历史位置气泡与位置发送待取舍 | Blocked | — | Blocked | Blocked | P2；历史展示建议迁移；新发位置待取舍 |
| CHAT-017 | 合并聊天记录呈现与嵌套边界 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-018 | 禁言/角色/上传开关与群发送间隔 | Blocked | 独立Chat对应断言Passed | Blocked | Blocked | P1；建议迁移 |
| CHAT-019 | 长按菜单矩阵、复制与链接 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-020 | 引用回复、原文定位与变更同步 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-021 | 单条/多选删除、单向与双向范围 | Blocked | 独立Chat对应断言Passed | Blocked | Blocked | P2；建议迁移 |
| CHAT-022 | 撤回窗口、管理者撤回与撤回占位 | Blocked | 独立Chat对应断言Passed | Blocked | Blocked | P2；建议迁移 |
| CHAT-023 | 本人文本/@编辑、分钟权限与回写 | Blocked | QA-08/0窗/禁言独立已修复 | Blocked | Blocked | P2；建议迁移 |
| CHAT-024 | 消息多选、100条上限及不可选类型 | Blocked | 独立Chat对应断言Passed | Blocked | Blocked | P2；建议迁移 |
| CHAT-025 | 逐条/合并转发、合规预检与逐对象结果 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-026 | 消息收藏与保存链接模块 | Deferred | — | Deferred | Deferred | P2；关联收藏/链接范围待用户审阅 |
| CHAT-027 | 翻译配置、状态、再次翻译与服务依赖 | Deferred | — | Deferred | Deferred | P3；独立翻译范围待取舍 |
| CHAT-028 | 聊天消息置顶、个人/全局与原文定位 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-029 | 定时自动删除：1/7/30天与关闭 | Deferred | — | Deferred | Deferred | P2；自动清理范围待用户审阅 |
| CHAT-030 | 单聊设置、加好友成群与清空记录 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-031 | 会话内文本/媒体/文件分类搜索与成员筛选 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-032 | 媒体/文件详情、下载与系统分享打开 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-033 | 群设置总入口与0/1/2角色矩阵 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-034 | 群头像、群名称与资料编辑权限 | Blocked | 101包装/云策略 Passed | Blocked | Blocked | P2；建议迁移 |
| CHAT-035 | 群成员预览、成员列表、人数与资料守卫 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-036 | 我的群昵称、30字符与跨端名称刷新 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-037 | 邀请好友进群、排除已有成员及审核原因 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-038 | 移除群成员与同时删除其发言 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-039 | 群管理菜单与逐项授权 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-040 | 全员/单人/永久禁言与解除 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-041 | 群入群申请列表、审核与成员同步依赖 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-042 | 群主转让与管理员增减 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-043 | 群私聊、历史、提示、二维码及通话开关 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-044 | 群公告列表、详情、创建编辑删除及已读 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-045 | 退出群、转让前置与群主解散 | Blocked | — | Blocked | Blocked | P2；建议迁移 |
| CHAT-046 | 音视频发起、群选择与LiveKit/Zego依赖 | Deferred | — | Deferred | Deferred | P3；独立通话范围待取舍 |
| CHAT-047 | 群机器人只读列表与活跃等级 | Deferred | — | Deferred | Deferred | P3；扩展群能力待取舍 |
| CHAT-048 | 业务事件、群角色与昵称同步回流合同 | Blocked | — | Blocked | Blocked | P1；建议迁移 |
| CHAT-049 | 未知消息、旧消息兼容及生命周期清理 | Blocked | 独立16/16含旧错误修复 | Blocked | Blocked | P1；基础兼容建议迁移；加密/阅后发起另取舍 |

## 逐ID可执行用例

由需求提取，文字存在不表示已通过。

| 用例 | 执行内容 | 当前状态 |
| --- | --- | --- |
| C-001-A1 | 三类入口与列表数据一一对应，首次进入显示真实好友；没有假分组/群。 | Blocked |
| C-001-A2 | 通讯录加号目标和首页更多菜单差异已明确；返回与重复切换不会创建多份列表请求。 | Blocked |
| C-002-A1 | 给定混合名称和重复UID，结果唯一且字母/#/注销顺序符合当前规则。 | Blocked |
| C-002-A2 | 清备注后按昵称等回退，当前好友计数与可见普通好友一致。 | Blocked |
| C-003-A1 | 在线/离线变化来自SDK，不由本地演示状态生成。 | Blocked |
| C-003-A2 | 注销好友仍可识别但不请求远程头像、无错误可操作入口；封禁/注销中按确认政策验收。 | Blocked |
| C-004-A1 | 完整URL、相对路径、中文路径、空头像、注销头像各结果明确。 | Blocked |
| C-004-A2 | 更换文件Host与好友头像更新后，名单/详情/会话一致，不停留在旧图。 | Blocked |
| C-005-A1 | 先缓存后同步、失败保留和恢复后补同步均符合状态文案。 | Blocked |
| C-005-A2 | A请求未结束切B时，A资料不会写入B库或显示；多次事件不会重复好友。 | Blocked |
| C-006-A1 | 备注/昵称/账号/完整拼音的匹配与清空可复现。 | Blocked |
| C-006-A2 | 用户确认是否保留UID及注销搜索增强，文案明确本地好友范围；不会把手机号精准搜索混入。 | Blocked |
| C-007-A1 | 有目标组准确定位，无目标组不产生空跳转。 | Blocked |
| C-007-A2 | 搜索后的分区与索引一致；RTL行为按审阅决定，不强行照搬。 | Blocked |
| C-008-A1 | 只有可见/确认已读项扣数，未见申请保留未读。 | Blocked |
| C-008-A2 | 消息与通讯录角标分别更新、>99显示规则准确，换号不继承旧申请。 | Blocked |
| C-009-A1 | 20条分页与不足一页结束口径来自旧调用；双方向pending/通过/过期文案和按钮准确。 | Blocked |
| C-009-A2 | 连续刷新和翻页不会重复/漏项，错误保留已有列表且可重试。 | Blocked |
| C-010-A1 | 自发pending不出现同意，对方pending可同意且最终出现完整好友。 | Blocked |
| C-010-A2 | 同意回执失败不标已添加；关系已成功而详情读取失败可恢复，不重复建立关系。 | Blocked |
| C-011-A1 | 已好友/自发pending/自发过期/对方pending四分支正确。 | Blocked |
| C-011-A2 | 重申请成功显示已发送申请而不是立即好友；消息入口目标UID正确。 | Blocked |
| C-012-A1 | 隐藏后重开不见原键、新申请仍可见，服务器关系未被本地伪改。 | Blocked |
| C-012-A2 | 文案和验收均不把隐藏称拒绝；若增加拒绝必须得到真实API/状态与对方同步证据。 | Blocked |
| C-013-A1 | 空输入不查、本人输入有明确反馈；数组/空数组/错误均有对应状态。 | Blocked |
| C-013-A2 | 后端验证支持的搜索形式后固定文案，不因旧placeholder声称支持所有手机号邮箱。 | Blocked |
| C-014-A1 | 所有添加入口在权限关闭时不可绕过；不再沿用旧守卫差异。 | Blocked |
| C-014-A2 | 成功只产生申请状态，实际成为好友以完整关系/同步为准，无假即时成功。 | Blocked |
| C-015-A1 | 本人/陌生人/好友/群成员返回资料使用正确接口和按钮。 | Blocked |
| C-015-A2 | 同UID在不同群昵称各自正确；无权限不能经头像或搜索绕过访问限制。 | Blocked |
| C-016-A1 | 现有只读字段不回退演示数据；新增现场刷新后更新名单排序和会话名。 | Blocked |
| C-016-A2 | 详情打开时好友被删/注销会立即调整页面和按钮，空资料不会闪出旧联系人。 | Blocked |
| C-017-A1 | 50/200边界、空值清除、全空格拒绝、汉字/组合输入/emoji不破坏文本。 | Blocked |
| C-017-A2 | 成功后二端备注、排序分区、搜索及会话名称一致；失败不改SDK权威值。 | Blocked |
| C-018-A1 | 推荐卡使用正确对象且接收方打开同一UID资料。 | Blocked |
| C-018-A2 | 批量成功/失败与取消可区分，不本地插假消息。 | Blocked |
| C-019-A1 | 取消和44016/44017不会伪装最终删除，重复受理有正确提示。 | Blocked |
| C-019-A2 | 最终成功后好友、指定会话/历史/媒体一致；部分失败按实际阶段提示并能恢复。 | Blocked |
| C-020-A1 | 未来授权后bool false/审核/网络失败均不得成功，退出换号状态隔离。 | Deferred |
| C-020-A2 | 双端发送/接收阻断与解除恢复得到服务端证据后才标完成。 | Deferred |
| C-021-A1 | 未来授权后图片上传真实成功且目标类型/UID正确，最多9张边界与邮箱条件明确。 | Deferred |
| C-021-A2 | 回执失败保留表单、重复点击不重复投诉；本轮文档不声称已恢复。 | Deferred |
| C-022-A1 | 未分组好友全部进入默认组，普通与系统/注销处理符合规则。 | Blocked |
| C-022-A2 | 展开/收起及组内在线排序可复现，名称相同但ID不同不串组。 | Blocked |
| C-023-A1 | 非空与默认不可删正确；删除组不删除任何好友，全部归默认组。 | Blocked |
| C-023-A2 | 增改删失败/取消保持原结构，跨端更新后各端一致。 | Blocked |
| C-024-A1 | 移动后重进/另端顺序一致；不会重复/丢组。 | Blocked |
| C-024-A2 | 失败恢复和最新请求版本处理明确，默认组限制按确认值执行。 | Blocked |
| C-025-A1 | 移动后仅所属业务分组改变、总好友数和好友资料不丢。 | Blocked |
| C-025-A2 | 取消/失败/目标被删/切号等场景不会遗留双归属。 | Blocked |
| C-026-A1 | 群列表来自真实已加入群，点击目标groupID正确。 | Blocked |
| C-026-A2 | 新增/退群/解散/被移除与切号后列表状态一致，排序标准经用户确认。 | Blocked |
| C-027-A1 | 群名称中文/英文/部分匹配及更多正确。 | Blocked |
| C-027-A2 | 结果失效不能误入旧缓存群；不显示未经批准的群ID/公告搜索能力。 | Blocked |
| C-028-A1 | 跨最近/分组/搜索同UID选中一致；200上限/最低2及预选计数按入口配置测试。 | Blocked |
| C-028-A2 | 全选/取消/顶部删除与按钮启用一致；没有凭客户端选择数量宣称服务器容量。 | Blocked |
| C-029-A1 | 有效创建回执生成同一真实groupID并两入口可见。 | Blocked |
| C-029-A2 | 失败/超限/重复点击/取消和弱网不产生假群或多群，返回栈清理符合目标。 | Blocked |
| C-030-A1 | 二维码接口目标UID与展示本人一致，换号不会复用旧码。 | Blocked |
| C-030-A2 | 保存权限拒绝有提示，分享失败不报成功；复制结果是当前账号。 | Blocked |
| C-031-A1 | 好友码只打开正确资料、申请仍另一步；无假添加成功。 | Blocked |
| C-031-A2 | 过期/禁止群码/相册无图/无权限处理与恢复可测；导航和业务码严格区分。 | Blocked |
| C-032-A1 | 已在/未在需审/未在直入/过期/禁码/解散六分支正确。 | Blocked |
| C-032-A2 | 需审只显示已提交，不立即加入；真实加入后群列表和会话变化一致。 | Blocked |
| C-033-A1 | 开放/关闭/再开放时入口、消息会话及角标一致。 | Blocked |
| C-033-A2 | 普通好友列表不混系统账号，点击不进普通好友主页/演示聊天。 | Blocked |
| C-034-A1 | 全局系统会话与群内申请上下文正确，不拿空groupID当普通群聊天。 | Blocked |
| C-034-A2 | 消息读取及审批结果回流群状态/未读，失败不假同意。 | Blocked |
| C-035-A1 | 未来选定范围只使用已证明可达的真实入口。 | Deferred |
| C-035-A2 | showTeam关闭无绕过；团队群能力另拿接口和运行证据。 | Deferred |
| C-036-A1 | 每入口至少权限允许/关闭/缺失/非法值及动态收回组合覆盖。 | Blocked |
| C-036-A2 | 群普通成员/管理员/群主及groupSecurity访问规则准确，缓存不跨UID/邀请码。 | Blocked |
| C-037-A1 | 已有新页空态不回归；新增申请/分组/群也能区分加载、真实空、无匹配、错误。 | Blocked |
| C-037-A2 | 键盘收起、返回、VoiceOver及重复提交可验收，不把建议用例记为本轮已通过。 | Blocked |
| C-038-A1 | 资料发消息打开同UID真实单聊并能回资料；重复点击只有一聊天实例。 | Blocked |
| C-038-A2 | 通话待取舍标明，系统开关关闭隐藏；本轮不声称已有通话闭环。 | Blocked |
| M-001-A1 | 登录真实账号显示当前用户缓存，不混演示；隐藏/未知/空ID按规则过滤。 | Blocked |
| M-001-A2 | 首轮分页与完整回读交错不丢会话、不重复。 | Blocked |
| M-002-A1 | 置顶收到消息仍在置顶区但区内移动正确；普通无越权置顶。 | Blocked |
| M-002-A2 | 相同ID旧/新快照只一行，时间相同顺序稳定。 | Blocked |
| M-003-A1 | 备注/头像更新后会话和资料符合确认的名称优先级。 | Blocked |
| M-003-A2 | 空头像、无好友、注销、群资料变更均不混旧图或错误ID。 | Blocked |
| M-004-A1 | 各种摘要/群昵称前缀/@本人/@所有人/自己@区分。 | Blocked |
| M-004-A2 | 新旧差距明确，不能把预览支持[图片]认作能发送图片。 | Blocked |
| M-005-A1 | 毫秒单位与今天/昨天/跨年/空值正确。 | Blocked |
| M-005-A2 | 列表时间与排序来源同一服务端字段，未来ACK更新不出现双条。 | Blocked |
| M-006-A1 | 普通真实数/只有readTag/两者都有/免打扰/隐藏助手组合精确计算。 | Blocked |
| M-006-A2 | Tab、行、App图标badge口径差异经确认；特殊群发无数/系统红点不可默认为已对齐。 | Blocked |
| M-007-A1 | 缓存失败按钮重读有效，网络断开提示不会谎称同步完成。 | Blocked |
| M-007-A2 | 后台/重连后数据自动更新，无额外旧探测竞赛。 | Blocked |
| M-008-A1 | 查询标题/预览/草稿及全部未读组合正确。 | Blocked |
| M-008-A2 | 文案清楚本地会话预览，不能称所有消息全文查询。 | Blocked |
| M-009-A1 | 每类型进入正确真实页，目标身份准确，不跳ClubCommunity。 | Blocked |
| M-009-A2 | 进入清会话角标与正文已读分开验收，失败或迟到不丢新未读。 | Blocked |
| M-010-A1 | 单群置顶/取消及失败保持正确，多端一致。 | Blocked |
| M-010-A2 | 文件助手设置可置顶而列表不伪加；特殊会话操作矩阵准确。 | Blocked |
| M-011-A1 | 打开/关闭后行标识与总数恢复，缓存重开一致。 | Blocked |
| M-011-A2 | 提交失败原状态保持；不误清消息实际未读数。 | Blocked |
| M-012-A1 | 实际数0的标记/清除准确；实际数>0按M-006确认口径。 | Blocked |
| M-012-A2 | A清读过程中到B新消息仍保留新未读，失败无误清。 | Blocked |
| M-013-A1 | 删除后会话消失但指定历史仍在，好友/群关系未变。 | Blocked |
| M-013-A2 | 取消和失败不移除；特殊类型菜单及再次收消息重建规则确认。 | Blocked |
| M-014-A1 | 真实代理同步能重算列表和Tab；晚到消息不被旧lastServerMsgId清除。 | Blocked |
| M-014-A2 | 主动入口尚未确认，文档不声称旧按钮/新操作已可用。 | Blocked |
| M-015-A1 | 退出重进/重启可恢复文字和@定位，切账号不串。 | Blocked |
| M-015-A2 | 发成功清草稿，失败不丢可恢复输入；列表来源与真实聊天同一合同。 | Blocked |
| M-016-A1 | 三类最多3及更多展示准确，空查询清结果。 | Blocked |
| M-016-A2 | 搜索范围标本地真实库，非只最新预览；查不到未同步记录不假补数据。 | Blocked |
| M-017-A1 | 各类型跳转与目标身份正确，最新权限生效。 | Blocked |
| M-017-A2 | 失效结果有退路，资料/聊天不会闪旧用户数据。 | Blocked |
| M-018-A1 | 同内容重复消息仍定位正确serviceMsgID；跨多页可补目标。 | Blocked |
| M-018-A2 | 消息失效/无历史权限时有明确提示，取消不误清其他会话未读。 | Blocked |
| M-019-A1 | 两设备文件/文本传输及ACK/历史/失败符合真实状态。 | Blocked |
| M-019-A2 | 列表置顶/删除，设置置顶/清空矩阵正确；权限动态隐藏再允许不丢快照。 | Blocked |
| M-020-A1 | 批次真实创建发送，收件人与错误详情准确；返回列表预览更新。 | Deferred |
| M-020-A2 | 取消/部分失败/重复操作处理清楚，权限关闭不可深链进入。 | Deferred |
| M-021-A1 | 每页10、全部/待审过滤、同意1/拒绝2和批量正确；好友页不套群拒绝状态。 | Blocked |
| M-021-A2 | 批准后成员/群/会话状态同步，拒绝不假加入；通知已读与审核结果分开。 | Blocked |
| M-022-A1 | 真实提醒与签到记录属于同账户服务，不重复助手ID/角标。 | Deferred |
| M-022-A2 | 同名SDK方法缺失明确处理，实际签到成功需后续服务端证据。 | Deferred |
| M-023-A1 | 文档与页面不宣称支付已迁移，旧过滤差异保留。 | Deferred |
| M-023-A2 | 未来若启用，必须有真入口/API和交易验收另项。 | Deferred |
| M-024-A1 | 权限组合及动态变化正确；每项对应已批准真实能力。 | Blocked |
| M-024-A2 | 两个建群入口不同minimum和预选规则准确。 | Blocked |
| M-025-A1 | 按当前列表顺序轮转并无未读回顶部。 | Deferred |
| M-025-A2 | 定位不清读；目标并发删除可跳下一合法项。 | Deferred |
| M-026-A1 | 多事件不重复、重读期间变化不会漏；首轮最新预览重启可恢复。 | Blocked |
| M-026-A2 | 切号/邀请码切换旧事件不能写新会话或旧未读。 | Blocked |
| M-027-A1 | 布尔、分钟、配额、缺省和非法条目各测试，edit窗口不当bool。 | Blocked |
| M-027-A2 | 依赖列表明确缺消息系统字段，未拿默认常量冒充服务端配置。 | Blocked |
| M-028-A1 | 当前空态与可访问摘要不回归；可见缓存不会被错误全屏遮住。 | Blocked |
| M-028-A2 | 新操作及聊天页的返回/键盘/VoiceOver有验收用例且本轮未标通过。 | Blocked：QA-20默认字号宿主复测Passed，真实VoiceOver/iPad仍待验收 |
| M-029-A1 | 未来纳入后冷启动/后台/前台同目标一致，权限和账号核对有效。 | Deferred |
| M-029-A2 | 旧入口链待验证，未列为旧已完成推送能力或本轮通过。 | Deferred |
| CHAT-001-A1 | 由列表/通讯录/搜索进入同会话且路由身份一致；不使用ClubCommunity发送。 | Blocked |
| CHAT-001-A2 | 群状态变化禁发/退页准确，快速切会话不会插错消息。 | Blocked |
| CHAT-002-A1 | 分页请求字段/100条边界正确，页交叠不重复。 | Blocked |
| CHAT-002-A2 | 服务器失败保留缓存，恢复后补缺；被删/撤回记录不能从旧历史又恢复。 | Blocked |
| CHAT-003-A1 | 看中部收新消息不强拉到底，点提示回最新；前插历史锚点稳定。 | Blocked |
| CHAT-003-A2 | 搜索同文本多条定位准确，键盘/图片加载不造成丢位置。 | Blocked |
| CHAT-004-A1 | 实时、ACK、补拉同消息只一条，自己另一端发送方向准确。 | Blocked |
| CHAT-004-A2 | 编辑/群角色/解散等事件更新对应状态而非全部显示普通文本。 | Blocked |
| CHAT-005-A1 | 发出显发送中，只有有效ACK/SDK成功才成功；重启可恢复。 | Blocked |
| CHAT-005-A2 | ACK重排不产生副本，时间/日期/列表预览一致。 | Blocked |
| CHAT-006-A1 | 新SDK原因文案与可恢复动作正确；自动SDK与人工重试无重复消息。 | Blocked |
| CHAT-006-A2 | 原账号退出/资源丢失/权限被收回无法误发，3秒/<=3/60秒按SDK实际流程联调。 | Blocked |
| CHAT-007-A1 | 只有可见收到正文上报，语音未播未读、播放后读。 | Blocked |
| CHAT-007-A2 | 多端已读/前后台/离页与新消息交错状态正确；群计数不伪造。 | Blocked |
| CHAT-008-A1 | 同日不强插5分钟日期；跨日/前插/ACK重排分隔准确。 | Blocked |
| CHAT-008-A2 | 方向、头像昵称和发送状态长字适配，不泄露内部路径。 | Blocked |
| CHAT-009-A1 | 文本与emoji两端内容一致，空不发，失败可恢复。 | Blocked |
| CHAT-009-A2 | ACK成功后列表预览/草稿/持久化正确；无本地假回复。 | Blocked |
| CHAT-010-A1 | 同名不同UID、@所有人、删除片段、草稿恢复及接收匹配正确。 | Blocked |
| CHAT-010-A2 | 普通禁私聊群不能通过@选择绕过，@所有人权限待确认。 | Blocked |
| CHAT-011-A1 | 太短/60边界/取消无发送，正常语音双端可播并有ACK。 | Blocked |
| CHAT-011-A2 | 无麦克风/中断/下载失败提示正确，播放后已读而仅可见未读。 | Blocked |
| CHAT-012-A1 | 0/1/9/超过9、阈值前后、原图视频/封面分开正确。 | Blocked |
| CHAT-012-A2 | 附件上传成功仍等待消息ACK；失败重试不重复发，节点变化可恢复。 | Blocked |
| CHAT-013-A1 | 文件名类型大小准确、双端下载可打开；失败原因/进度/重试明确。 | Blocked |
| CHAT-013-A2 | 未证实上限不写固定数值；文件缓存归属正确，切号不会打开旧用户资源。 | Blocked |
| CHAT-014-A1 | 静态/GIF/游戏与普通emoji区分，结果及资源真实。 | Blocked |
| CHAT-014-A2 | 商城20/10分页、重复添加/收藏与失效资源降级准确。 | Blocked |
| CHAT-015-A1 | 接收卡打开正确UID，组/单接收对象请求正确。 | Blocked |
| CHAT-015-A2 | 历史名片失效有占位/退路，部分失败不一概成功。 | Blocked |
| CHAT-016-A1 | 历史位置可识别且未知资源明确，不误当文本。 | Blocked |
| CHAT-016-A2 | 发送功能保留待确认，实际入口/API/授权另行验证后再纳入。 | Blocked |
| CHAT-017-A1 | 合并文字媒体等顺序与原作者时间正确，接收者可离线读缓存。 | Blocked |
| CHAT-017-A2 | 已有合并不无限再次合并；附件失效与内文件操作矩阵准确。 | Blocked |
| CHAT-018-A1 | 普通频控/1和2豁免、全员/个人禁言、上传关闭各入口准确。 | Blocked |
| CHAT-018-A2 | 旧未映射配置标缺口，临界提交被拒时提示真实原因而非假成功。 | Blocked |
| CHAT-019-A1 | 本人/他人、成功/失败、文本/公告/通话/系统等矩阵对应正确动作。 | Blocked |
| CHAT-019-A2 | 复制与链接对象正确，动态变更后不能用旧菜单越权。 | Blocked |
| CHAT-020-A1 | 引用文字/@/支持类型成功且ID指向原条，不靠文本搜索。 | Blocked |
| CHAT-020-A2 | 删除/撤回/编辑后原引用和列表一致，缺本地页可补或提示。 | Blocked |
| CHAT-021-A1 | 本人/他人×0/1/2×Success/Fail×单向/双向完整验证。 | Blocked |
| CHAT-021-A2 | 指定范围双端一致、失败不移除、撤回/清空/删会话不混为删除消息。 | Blocked |
| CHAT-022-A1 | 窗口0/关闭/边界内外和角色保护可验收，未映射字段不默认开启。 | Blocked |
| CHAT-022-A2 | 双端原文不从补历史复活，引用和列表显示撤回，失败原文保留。 | Blocked |
| CHAT-023-A1 | 只本人text/@可编辑，分钟边界/组合@/取消正确。 | Blocked |
| CHAT-023-A2 | 新原条替换无重复，接收方引用和预览更新，服务拒绝保输入。 | Blocked |
| CHAT-024-A1 | 0/1/100/101与所有排除类型正确。 | Blocked |
| CHAT-024-A2 | 实时消息变化不丢有效选择/越权，取消恢复浏览与草稿。 | Blocked |
| CHAT-025-A1 | 逐条排序稳定、合并count1、异常全无禁止、部分失败明细准确。 | Blocked |
| CHAT-025-A2 | 附件/作者/引用归属正确，每个接收方实际回执而非批量假成功。 | Blocked |
| CHAT-026-A1 | 批准后收藏真回执和读取一致，重复/失败明确。 | Deferred |
| CHAT-026-A2 | 发收藏内容仍走真实发送，链接无自动访问，退出归属隔离。 | Deferred |
| CHAT-027-A1 | 翻译开关/自动/手動/隐藏/再次及失败原文可读正确。 | Deferred |
| CHAT-027-A2 | @/emoji/编辑后旧译文不误复用，账户服务依赖另联调。 | Deferred |
| CHAT-028-A1 | 无引用Text/@限制、四status及0/1/2角色范围正确。 | Blocked |
| CHAT-028-A2 | 原文定位/取消两端一致，撤回/删后置顶不保留失效内容。 | Blocked |
| CHAT-029-A1 | 1/7/30及0开关与现值一致，取消/失败保原。 | Deferred |
| CHAT-029-A2 | 真实到期多端范围有后续证据，缓存/搜索/引用不恢复到期正文。 | Deferred |
| CHAT-030-A1 | 入口/预选min1和200限制正确，与首页差异明确。 | Blocked |
| CHAT-030-A2 | 清空成功指定会话DB/缓存/预览/搜索一致，失败不假清；投诉未自动恢复。 | Blocked |
| CHAT-031-A1 | 分类/关键词/成员组合与隐藏开关正确，不标云端无限搜索。 | Blocked |
| CHAT-031-A2 | 结果删除/回跳/清空/无匹配一致，50边界与更多真实契约另核。 | Blocked |
| CHAT-032-A1 | 状态、资源原图/封面/视频/文件和系统操作真实；失败有下一步。 | Blocked |
| CHAT-032-A2 | 合并内操作矩阵与普通文件不同，返回聊天原浏览位置稳定。 | Blocked |
| CHAT-033-A1 | 三角色和关键开关矩阵正确，普通看不到管理员动作。 | Blocked |
| CHAT-033-A2 | 开页后降权不能通过旧行继续提交，退群/解散关闭对应页面。 | Blocked |
| CHAT-034-A1 | 普通0不可编辑，1/2与服务端规则一致，保存成功群/会话两处同步。 | Blocked |
| CHAT-034-A2 | 上传/保存失败保原值，另端改名/头像后当前页刷新。 | Blocked |
| CHAT-035-A1 | 0/1/2人数和预览规则、不同groupSecurity/私聊组合准确。 | Blocked |
| CHAT-035-A2 | 未同步阻跳，聊天头像/设置/名单都不能绕过资料限制。 | Blocked |
| CHAT-036-A1 | 0/30/超过、空恢复、未变禁用正确。 | Blocked |
| CHAT-036-A2 | 成功后两端预览/气泡/@列表更新，并验证专用同步契约，不能只因Socket有事件就称UI通过。 | Blocked |
| CHAT-037-A1 | 普通需审/不需审与1/2路径准确，已入/系统/注销不可重复选。 | Blocked |
| CHAT-037-A2 | 真实加入与待审有不同结果，二端成员/@/人数同步。 | Blocked |
| CHAT-038-A1 | 合法角色/目标矩阵明确、群主保护、delMemberMsg开关分别验收。 | Blocked |
| CHAT-038-A2 | 被移端与群其他端成员和发言范围一致，失败不假移除。 | Blocked |
| CHAT-039-A1 | 普通0无管理，管理与群主差异具体到每行。 | Blocked |
| CHAT-039-A2 | 各开关成功失败和另端同步可独立验收，不把有群列表当群管理完成。 | Blocked |
| CHAT-040-A1 | 7期限/1和0操作及角色豁免准确，永久确认/取消正确。 | Blocked |
| CHAT-040-A2 | 目标即时禁发，文本/语音/附件/@/转发均被守卫；过期/解除二端恢复。 | Blocked |
| CHAT-041-A1 | 群审批有拒绝/批量真实分支，好友不复用该状态。 | Blocked |
| CHAT-041-A2 | 批准/拒绝两端关系和通知正确，重复/降权不能继续审批。 | Blocked |
| CHAT-042-A1 | 仅当前群主能设置管理/转让，群主不能误列普通管理。 | Blocked |
| CHAT-042-A2 | 转让成功双方角色/输入/管理菜单同步；失败不得先退出或清记录。 | Blocked |
| CHAT-043-A1 | 每开关参数/单位/类型明确，页面联动正确。 | Blocked |
| CHAT-043-A2 | 默认/格式非法/动态收回/多端同步矩阵覆盖，未映射新系统字段不当可用。 | Blocked |
| CHAT-044-A1 | 20条分页与置顶分区正确，0只读/1和2编辑创建删除准确。 | Blocked |
| CHAT-044-A2 | 成功后各端公告栏与已读提示同步；失败/取消保原，删除详情有退路。 | Blocked |
| CHAT-045-A1 | 0/1退出、群主转让前置、仅群主解散各正确。 | Blocked |
| CHAT-045-A2 | 成功清对应群，不误清其他聊天；被移/解散各端禁发和退页一致。 | Blocked |
| CHAT-046-A1 | 未来选定后两种服务路由和单群权限正确，有真实呼叫回执。 | Deferred |
| CHAT-046-A2 | 历史通话消息可展示与实际发起分开，未批准不默认P1迁移整个媒体模块。 | Deferred |
| CHAT-047-A1 | 只读列表及计数真实，空/错误区别，无虚构创建删除。 | Deferred |
| CHAT-047-A2 | 活跃等级开关/展示联动与权限正确，后端未开放明确暂不可用。 | Deferred |
| CHAT-048-A1 | 附录事件每类有后续验收，正文/引用/群菜单/输入一致。 | Blocked |
| CHAT-048-A2 | 昵称更新最终UI证据和当前新SDK真实接口待联调，不以Socket收到代替完成。 | Blocked |
| CHAT-049-A1 | 未知类型有可理解占位，原记录不因UI不支持被删除。 | Blocked |
| CHAT-049-A2 | 退出/切号/节点恢复迟到历史、上传、读回执、昵称和权限结果都隔离。 | Blocked |

## 隔离UI执行记录

宿主包为com.sigua.ddlNew.MigrationQA，生产认证入口未更改。图片占位/匿名客户端及设置、附件详情、编辑、转发、合并记录、地图、历史搜索导航目标替代仅位于Tests/MigrationAcceptance/UIHost，因此以下证据仅代表生产视图的布局和状态交互；不能证明替代页面业务、网络图片、真实设置SDK或登录通过。最新宿主源快照位于/tmp/ddlNew-migration-ui-host/source，减少开发写文件时混编。

| 页面/动作 | 结果 | 截图/证据 |
| --- | --- | --- |
| 聊天默认深色、长文本/emoji/未知消息 | 局部Passed | /tmp/ddlNew-qa-chat-default.png；未知占位与失败原因可见 |
| 聊天输入与键盘 | 修复Passed：默认字号局部 | QA-20根复测/tmp/ddlNew-qa-keyboard-final-green.png；发送与输入无工具栏重叠，收起保留正文。最终最大字号及生产端输入仍待验收 |
| 聊天设置往返草稿 | 修复局部Passed | /tmp/ddlNew-qa-chat-draft-retest.png；设置往返保留匿名草稿 |
| 聊天搜索按钮与正文label | 修复Passed | 最新辅助树搜索44×44、TextField label消息正文 |
| 聊天AXXXL最大字号/浅色首屏 | 修复局部Passed | /tmp/ddlNew-qa-chat-maxfont-green.png；最新首屏末条正文4可见、4媒体按钮2列文字完整；旧空白截图只代表历史失败 |
| 聊天AXXXL横屏附件区 | 局部Passed | /tmp/ddlNew-qa-chat-landscape-green.png；旋转稳定后输入/搜索/发送与4附件入口可见，不证明历史锚点始终稳定 |
| 备注AXXXL最大字号/浅色 | 局部Passed | /tmp/ddlNew-qa-remark-maxfont.png；备注/描述计数及导航保存取消可见 |
| 备注未改与字段语义 | 修复Passed | 保存初始disabled、备注label好友备注、脏取消出现放弃确认 |
| 选人最少2位 | 局部Passed | /tmp/ddlNew-qa-picker-default.png 0人禁确认，/tmp/ddlNew-qa-picker-selected.png 2人可确认 |
| 选人AXXXL、选中行与横向已选 | 局部Passed | /tmp/ddlNew-qa-picker-maxfont.png；选中项可滚动、姓名换行、0/2数仍可见 |
| 选人分组UID、失败保留与重试 | 局部Passed | /tmp/ddlNew-qa-picker-failure-retains.png；不同昵称同UID分组仍正确“选择/取消本组”，提交失败保留2人及错误；取消本组清0，再选2并切最近保留，第二次宿主成功关闭sheet。没有创建真实群 |
| VoiceOver真实朗读/Reduce Motion/iPad | Blocked | 目前只观察辅助树，未使用屏幕阅读器或执行完整流程；不会声明可访问性全部通过 |


## 统计方法

离线断言为确定性场景覆盖，最新通过数只描述已执行场景。用例不是随机独立抽样，不伪造线上可靠性概率、统计显著性、95%置信区间、ROI或性能百分位。真实授权群双向文本子用例已观察；持久化、ACK字段与复杂回流尚未观测，不作发布GO结论。

## 真机控制状态与用户协助用例

最初mobile-mcp 1.0.10因未发现go-ios及WDA转发而无法控制真机，此项是历史阻碍。随后根代理在/tmp独立安装go-ios并建立指定测试iPhone的localhost:8101→设备8100转发与userspace tunnel；WDA status ready已观察。测试桥只用8101，避免mobile-mcp固定8100路由误指模拟器。My Mac的ddlNew/叮咚聊窗口AX已获用户许可，UIKit控件需要超过20层查找，并以真实AXTextField聚焦输入。未修改生产登录、全局PATH或工具账户配置，未调用向开发者发送上下文的get_more_tools。

用户已反馈iPhone与My Mac运行端两专用账号登录成功，测试已独立通过真实UI核实两端身份；第二台连接手机不作为已认证运行端。用户已授权既有专用测试群“有魄力”，两端群页面可见。当前已安装评审修复前版本完成真实双向QA文本：B发送QA_20261013_1405_B2A，A发送QA_20261013_1403_A2B；Mac截图/tmp/ddlNew-qa-mac-after-send.png及手机8101实时辅助树均观察两条各1份且方向正确，双方输入清空。服务ACK字段、已读计数、恢复持久化及最新安装版本仍需复验；不得扩为全部消息需求Passed。只在账号A/B、测试租户及授权测试群间操作，不记录凭据，不清空原历史。

| 优先级/需求 | 可执行动作 | 应观察的结果 | 状态 |
| --- | --- | --- | --- |
| P0 C-014/010/016 | 若A/B尚非好友，A在添加好友查找B并申请，B在新朋友同意；已是好友则直接查看双方资料 | 申请双方方向正确；接受后双方真实好友列表/资料可见，退出详情返回关系仍正确 | 待用户协助业务证据 |
| P0 CHAT-004/005/006/007 | A/B在授权群双向发送唯一QA文本，继续验证ACK/已读/前后台恢复 | 已安装评审修复前版本两端各可见两条各1份且方向正确；ACK字段、已读计数与恢复仍未观察 | 双向文本子用例Passed；完整需求Blocked，待最新版本复验 |
| P1 C-017/M-003/015 | A仅对B改匿名测试备注；返回消息/联系人查看标题，输入匿名草稿进设置再返回 | A本机备注回读与会话标题一致；B自己的资料未被A备注覆盖；草稿保留 | 待用户协助业务证据 |
| P1 CHAT-012/013/032 | A/B分别发一张非敏感测试图片及一个匿名小文件，再在对端打开 | 上传完成仍经真实消息确认；对端图片/文件可打开，文件名/大小正确，错误无假成功 | 待用户协助业务证据 |
| P1 CHAT-021/022 | 仅对新增标记文本执行范围明确的删除或窗口内撤回，并查看另一端 | 删除仅影响确认的范围，旧缓存/返回不会复活；撤回双方显示占位 | 待用户协助业务证据 |
| P1 C-029新建群 | 当前只有A/B两个获授权身份，建群要求选至少2位好友且群主另算 | A只能选择B一位，未满足真实新建群前提，不能选择未知好友或新建未授权账号 | Blocked：新建群测试身份数量 |
| P1 CHAT-033至045既有群 | 用户已授权专用既有群“有魄力”；只查看角色与操作新增QA消息/自身群昵称 | 两端已打开该群；角色权限与各管理能力仍需逐项实际观察，不删除原群、不移除其他成员 | 测试中 |

## 云签名独立合同依据

COS请求参数名称在签名前规范为小写；该断言依据[腾讯云请求签名规范](https://intl.cloud.tencent.com/zh/document/product/436/7778?lang=zh)。Ali与OBS的规范资源包含合法子资源，acl差异必须进入签名；依据[阿里OSS V1签名规范](https://www.alibabacloud.com/help/en/oss/developer-reference/include-signatures-in-the-authorization-header)与[华为OBS头部鉴权规范](https://support.huaweicloud.com/intl/en-us/api-obs/obs_04_0010.html)。当前上传入口没有查询子资源，历史失败是离线合同缺陷，已修复复验；不作为已经观测到的线上上传失败。

静态对照xgd的NoaFileUploadTask/Tools：供应商1至4、AWS region字段、OBS自定义put/get域名、聊天日期目录及独立avatar_group目录与旧端相符。CloudUploadSessionDelegate沿系统TLS验证且拒绝HTTP重定向；本轮objectURL将HTTP配置升级HTTPS并移除80端口，独立云策略14/14通过。真实四供应商可达性未验证。

## 用户暂停时的最新增补（根执行）

本节及交接文档优先于前文真实设备章节的历史快照；暂停后没有继续开发或业务测试。

- 最新38/38离线脚本实际exit0，新增附件后台失效9项和系统配置传输3项；不计为38项需求完成。
- 邀请码1000失败时现场为ECDH成功、HTTP系统配置超时；SystemConfigService改复用既有SDK配置/TCP路径并加轮次守卫，最新签名workspace构建成功。用户反馈登录成功，实际账号UI再次确认两端身份。
- 最新版本在专用群中iPhone B发送QA_20261013_1600_B2A，My Mac A实收精确1条。最新A到B输入未核对成功，因此未发送；不将其标为发送失败或通过。ACK字段、已读计数、单聊、群管理、真实媒体及恢复仍未完成。
- 较早双向标记在更新重启后仍可见，仅作历史恢复子证据，不能推断完整持久化/草稿恢复验收。
- 键盘重叠默认字号宿主修复复测通过；M-028整体Blocked。最新根修正尚缺新的独立人员完整审查，既有子代理因模型容量失败未继续产出。
- 本任务真机自动化已停止；整理期间检测到新增提交4c8f593包含代码与测试，当前只剩交接记录修改。本助手未执行提交/推送，远端状态未联网核验。继续顺序、授权边界和工具现场见交接文档。
