# 通讯录与消息独立测试报告

日期：2026-10-13；分支：feature-message-4。**用户已在新窗口授权继续，当前恢复严格验收。** 本报告保留独立QA历史证据；最新执行见文末“继续验收记录”，历史暂停状态不代表当前状态。详见[交接文档](CONTACTS_MESSAGE_MIGRATION_HANDOFF_2026-10-13.md)。

## 状态口径与执行策略

本窗口最终：签名构建成功，最新完整43/43离线入口通过（110.00秒），日志180检查通过。clean构建与后续检索增量构建快照见RES-16/17；双端终版边界不省略。双端消息/ACK的已执行子场景与终版Mac锁屏边界见RES-04～16；21项公共严格台账仍明确保留未验证条件。

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
| C-013 | 按账号/手机号/邮箱查找用户 | Blocked：整体 | RES-17账号子场景Passed | 源码/回归/真实B查A均通过 | 手机号/邮箱搜索形式未验证 | P1；不扩展手机号/邮箱暂缓范围 |
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
| M-028 | 加载/空/错误、键盘和可访问性 | Blocked | — | QA-20默认字号宿主已修复复测 | Blocked | P1；真实VoiceOver/完整iPad与其他未执行用例仍待验证 |
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
| C-013-A1 | 空输入不查、本人输入有明确反馈；数组/空数组/错误均有对应状态。 | 部分Passed：本人/真实A结果/清查询/离线坏页；真实错误与真空数组完整状态仍Blocked |
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
| C-038-A2 | 通话待取舍标明，系统开关关闭隐藏；本轮不声称已有通话闭环。 | Deferred：本轮暂缓子范围 |
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
| M-014-A2 | 主动入口尚未确认，文档不声称旧按钮/新操作已可用。 | Deferred：本轮暂缓子范围 |
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
| M-028-A2 | 新操作及聊天页的返回/键盘/VoiceOver有验收用例且本轮未标通过。 | Blocked：QA-20默认字号宿主复测Passed，默认iPad宿主局部Passed，真实VoiceOver/完整iPad仍待验收 |
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
| CHAT-014-A2 | 商城20/10分页、重复添加/收藏与失效资源降级准确。 | Deferred：本轮暂缓子范围 |
| CHAT-015-A1 | 接收卡打开正确UID，组/单接收对象请求正确。 | Blocked |
| CHAT-015-A2 | 历史名片失效有占位/退路，部分失败不一概成功。 | Blocked |
| CHAT-016-A1 | 历史位置可识别且未知资源明确，不误当文本。 | Blocked |
| CHAT-016-A2 | 发送功能保留待确认，实际入口/API/授权另行验证后再纳入。 | Deferred：本轮暂缓子范围 |
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

离线断言为确定性场景覆盖，最新通过数只描述已执行场景。用例不是随机独立抽样，不伪造线上可靠性概率、统计显著性、95%置信区间、ROI或性能百分位。真实授权群双向文本子用例已观察；单条ACK及前后台群角标子场景已观察；持久化全矩阵与复杂回流未齐，不作发布GO结论。

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

本节是用户当时暂停的历史快照；其后继续执行结果以文末“继续验收记录”为准。

- 最新38/38离线脚本实际exit0，新增附件后台失效9项和系统配置传输3项；不计为38项需求完成。
- 邀请码1000失败时现场为ECDH成功、HTTP系统配置超时；SystemConfigService改复用既有SDK配置/TCP路径并加轮次守卫，最新签名workspace构建成功。用户反馈登录成功，实际账号UI再次确认两端身份。
- 最新版本在专用群中iPhone B发送QA_20261013_1600_B2A，My Mac A实收精确1条。最新A到B输入未核对成功，因此未发送；不将其标为发送失败或通过。ACK字段、已读计数、单聊、群管理、真实媒体及恢复仍未完成。
- 较早双向标记在更新重启后仍可见，仅作历史恢复子证据，不能推断完整持久化/草稿恢复验收。
- 键盘重叠默认字号宿主修复复测通过；M-028整体Blocked。最新根修正尚缺新的独立人员完整审查，既有子代理因模型容量失败未继续产出。
- 本任务真机自动化已停止；整理期间检测到新增提交4c8f593包含代码与测试，当前只剩交接记录修改。本助手未执行提交/推送，远端状态未联网核验。继续顺序、授权边界和工具现场见交接文档。

## 继续验收记录（2026-10-13，根执行）

接手HEAD实际为`a3233e6`，位于`4c8f593`之后，后续提交仅修改四份文档；接手暂存区和工作区均干净。未切换分支、提交或推送。仍只使用已授权A/B、邀请码1000与群1008“有魄力”。以下通过限定于写明的子场景，未提升116项需求的整体状态。

| 执行ID / 关联需求 | 状态 | 操作、结果与证据边界 |
| --- | --- | --- |
| RES-01 / 最新三修正复核 | Passed：源码/离线 | 新独立审查复核键盘、媒体失效、SDK系统配置TCP路径；键盘与传输未检出新确定问题。媒体追加缺陷见RES-02；最新最大字号键盘修正见RES-14，真实播放器仍待验收 |
| RES-02 / CHAT-032、M-028 | Passed：回归/独立复核 | 失效后再次close清掉提示导致空白；生产方法回归先红（`/tmp/ddlNew-preview-invalidation-red.log`），修正仅在未失效时清错误，绿12项及独立复核关闭。`/tmp/ddlNew-preview-invalidation-green.log`；不代表真实播放已通过 |
| RES-03 / M-007、CHAT-049 | Passed：启动子场景 | iPhone同bundle覆盖安装并terminate-existing后启动，自动恢复已认证B；“添加好友→我的账号”实核ceshi002，Mac实核ceshi001。没有卸载、输入或保存密码，也没有清历史。不是退出/切账号验收 |
| RES-04 / CHAT-004、005、009 | Passed：最新群文本A→B | Mac使用typeText核对正文后发送`QA_20261013_1655_A2B`，输入清空；手机精确1条。修正后Mac运行包与手机安装产物debug.dylib摘要一致（`80995acf…`）。`/tmp/ddlNew-phone-A2B-received.json`；Unicode/失败重试等矩阵仍未完成 |
| RES-05 / CHAT-005-A1/A2 | Passed：单条真实ACK子场景 | Mac系统日志实际IMChatMessageACK：信封`7210137bc5544454b96f403bec935432`、ack_msg_id=`B60BD3FC-70F9-49E2-8AAD-41E640A025F5`、s_msg_id=`2026286165616000001`、send_time=`1791881776335`、GroupChat。SDK成功日志关联ack_msg_id与s_msg_id；仅限本次16:56:16发送，未验证错序重试。`/tmp/ddlNew-only-chat-ack.json`及`/tmp/ddlNew-only-A2B-message-events.json`只按标记/消息ID筛选，不保存认证日志 |
| RES-06 / CHAT-004、009 | Passed：最新群文本B→A | B发送`QA_20261013_1700_B2A`，本端精确1条、无失败提示；Mac实收精确1条。`/tmp/ddlNew-phone-B2A-send.json`；标记中的1700为用例名，实际发送约16:57，不当作实时时钟 |
| RES-07 / CHAT-007 | Blocked：真实计数 | 两端旧消息有1/4、2/4已读，新消息尚未观察计数或相应read系统事件。没有伪造计数；源码确认读上报与SDK通知路径已接。前台/页面恢复不重评估几何不变消息的确定时序缺口已补3个恢复回归、4个清空旧读队列回归及2个批次所有权回归：原Store分别红，修正后Chat32通过。`/tmp/ddlNew-read-recovery-behavior-red.log`、`/tmp/ddlNew-read-owner-green.log`；不直接断言此缺口是现场计数未显示的原因，修正版真机复验继续 |
| RES-08 / CHAT-033、035 | Passed：成员页修复真机复验 | A设置显示5人及群主退出转让提示，成员页却持续只见搜索栏。临时LLDB断点只查看data键名、items数量与字段名，实际键为currentPage/items/pageSize/pages/totalCount，items有5条；旧适配只读rows。新增生产解析items优先、兼容rows、错误页拒绝同步完成、数字UID完整归一化。原生产内联解析提取测试红，成员页9项绿。`/tmp/ddlNew-member-page-behavior-red.log`、`/tmp/ddlNew-member-page-green.log`。临时断点已删除并恢复执行，未展开成员资料或凭据；修正版本Mac和iPhone成员页均实见5人，A cs123显示群主，B test123未显示管理员/群主标签。`/tmp/ddlNew-phone-B-members.json` |
| RES-09 / C-029、CHAT-037～045 | 部分Blocked：身份/范围 | 已自行通过A实际设置确认其群主路径；B也已通过实际成员页复核其普通成员UI路径（test123无管理角色标签），未检查服务端原始数字角色。第三身份与临时QA群未获得授权。禁止据此操作原群其他成员、解散原群或清原历史；完整三角色、建群、移除与解散矩阵保留受阻 |
| RES-10 / 中文注释 | Passed：本次涉及方法 | 补PreviewInvalidationChecks与SystemConfigTransportChecks的测试辅助方法中文注释；新成员解析/恢复方法有中文说明。不是全仓库方法注释审计通过 |
| RES-11 / 构建与离线 | Passed：较早快照；最终验证见RES-16 | workspace签名clean build成功（`/tmp/ddlNew-continue-final-clean-build.log`），之后完整38/38离线入口exit0（205.69秒，`/tmp/ddlNew-migration-qa-continue-final/summary.json`）。成员/已读32更新快照已39/39 exit0（`/tmp/ddlNew-migration-qa-final-owners/summary.json`）及签名clean成功（`/tmp/ddlNew-continue-final-clean.log`）；后续UI/日志修正最终验证见RES-16，不能拿旧结果代替 |

受用户“不清空既有历史”约束，真实清历史、删除原成员历史等验收保留Blocked；不因缺少身份自动注册账号或临时扩大群权限。尚未执行的专项与公共用例仍按原表保留Blocked/Deferred，不将源码或离线检查批量改为真实验收Passed。

| 执行ID / 关联需求 | 状态 | 操作、结果与证据边界 |
| --- | --- | --- |
| RES-12 / CHAT-004、007、M-002/004 | Passed：前后台群正文/角标子场景 | 最终成员/已读修正版本两端debug.dylib摘要5c19bcd6…一致；B先HOME后台，A发送完整QA_20261013_1826_FULL_A2B，B恢复列表显示群1008两条未读及同正文，开群精确1份，返回列表群1008未读消失。其他未授权群的角标没有手动清理。`/tmp/ddlNew-phone-after-background-list.json`、`/tmp/ddlNew-phone-final-read-group.json`、`/tmp/ddlNew-phone-B-list-after-qa.json`。群消息已读人数仍Blocked；标记时间只是用例名。Mac测试工具曾只改AX显示值而发出3_1823_FINAL_A2B，未删除此新QA历史，稳定聚焦typeText后重发完整标记确认通过，不归因服务截断 |
| RES-13 / CHAT-004、007 | 局部Passed；A接收UI受阻 | B发送QA_20261013_1910_B2A，本端精确1份且无失败提示，列表预览正确。`/tmp/ddlNew-phone-final-B2A-send.json`。Mac锁屏无法观察本次A气泡；不复用17:00旧接收证据代替 |
| RES-14 / M-028、CHAT-003、007 | Failed→修复局部Passed | 本轮发现默认字号键盘后未保持末条、AXXXL键盘时附件占满正文（`/tmp/ddlNew-ui-final-default-keyboard.png`、`/tmp/ddlNew-ui-final-max-keyboard.png`）。改真实锚点几何+仅原末尾跟随，拖动取消待跟随；组件compact保持上传/录音所有者，键盘收拢附件/@但保留展开44×44入口、草稿和进度。Viewport7通过；宿主AXXXL键盘时正文4可见、收起恢复工具且QA_LARGE保留，拖旧历史后重开键盘仍停正文2，未强跳底（`/tmp/ddlNew-ui-viewport-max-green.png`）。独立SwiftUI复核未检出确定新缺陷；横屏/引用/多选/上传录音叠加及真实VoiceOver仍不可据此全部Passed |
| RES-15 / C-G9、M-G10 | Failed→日志边界修复/独立验证 | 现场曾见SDK密钥/解密整包日志；只修13处文件日志诊断，不改握手/签名/Token/收发/日志开关。84个实际日志调用、2个HTTP方法、1个Socket诊断方法在clang匿名宿主180检查通过，原HEAD同测试172项失败；输出仅case名，不保存凭据。HTTP通知仍原event_http封套，数据白名单；Socket阶段目前仅内存，不虚称已远端泄漏。`/tmp/ddlNew-log-redaction-red.log`、`/tmp/ddlNew-log-redaction-green.log`。整个SDK所有历史日志/其他供应商资源故障矩阵仍未覆盖 |
| RES-16 / 最终全工程与离线 | Passed：最终41入口与签名构建 | 最终UI+日志签名clean build成功 `/tmp/ddlNew-final-autonomous-clean-build.log`。首轮41入口40绿、LoginSecurity退出成功断言失败，192.59秒 `/tmp/ddlNew-migration-final-autonomous/summary.json`；原测试仅25次yield等待嵌套Task，无负载单跑69绿。仅测试该场景改为等待exits/passwordChanged/!isBusy可观察完成，2秒截止，不改登录业务，69绿。最终全量41/41 exit0，149.19秒（`/tmp/ddlNew-migration-final-autonomous-confirmed/summary.json`）；保留首轮失败证据，不替换/删除红日志 |

## 公共严格验收台账（21项，逐项保留完整标准）

下表补齐专题253条之外的公共标准。Partial证据不提升完整用例：离线State/SDK合同与隔离UI不能代替真实后端、多端、故障和屏幕阅读器。

| 公共ID | 完整状态 | 本轮证据与剩余条件 |
| --- | --- | --- |
| C-G1 | Blocked；启动子场景Passed | AUTH前不启动业务、DBready后真实缓存/空态合同离线通过；已认证冷启动实核A/B，未执行真实未登录→DB初始化完整链路 |
| C-G2 | Blocked | 缓存先显/同步失败/真空态离线覆盖；真实离线与恢复保缓存全矩阵未执行 |
| C-G3 | Blocked | 失败与过期快照、缓存回读合同覆盖；无真实通讯录同步失败与重读实例 |
| C-G4 | Blocked | 取消/重复提交/SDK受理与完成分离离线覆盖；关系变更真实回读未执行 |
| C-G5 | Blocked | 动态删除/注销/权限及UID守卫离线覆盖；不删除原好友，缺真实动态关系实例 |
| C-G6 | Blocked | A/B真实既有好友资料可见；缺关系事件双端与同一账号双端私有备注/分组同步 |
| C-G7 | Blocked | UID/租户/generation隔离离线覆盖；未实际切号/租户，不读取凭据绕过 |
| C-G8 | Blocked | 节点恢复与SDK系统配置TCP合同通过；中断业务变更服务回读/新fileHost全链路未实测 |
| C-G9 | Blocked；本轮日志修复Passed | 本人反馈/真实B查A/清查询、匿名检索/排序合同及180日志检查通过；真实全字符检索、整SDK日志边界仍非完整覆盖 |
| C-G10 | Blocked；UI子场景Passed | 默认/AXXXL生产视图宿主、草稿和选择交互有证据；iPad默认键盘布局子场景Passed；真实VoiceOver、性能、大列表全流程未执行 |
| M-G1 | Blocked；启动子场景Passed | 列表AUTH/DB/缓存/空态离线通过；真实同步失败/无结果与空列表矩阵未齐 |
| M-G2 | Blocked；前后台正文Passed | B后台→A群正文→B列表未读→开群/返回清群角标已观察；断网pending/失败重试/认证恢复ACK未齐 |
| M-G3 | Blocked；正文/ACKPassed | 双端群正文与单条ACK实证，事件去重离线通过；所有置顶/免打扰/撤回/编辑/读事件联动未齐 |
| M-G4 | Blocked | UID/租户资源隔离离线通过；实际退出/切号和角标清理未做 |
| M-G5 | Blocked | 取消/提交时序离线，宿主草稿保持通过；实际业务提交中关闭/失败复原全矩阵未齐 |
| M-G6 | Blocked；群角色UIPassed | A群主、B普通成员路径实见；缺管理员身份与动态降权/群开关/全员禁言真实变更 |
| M-G7 | Blocked；单条ACKPassed | 本次双ID/服务时间ACK已匹配，错序/重叠离线通过；实际弱网重试/分页锚点/恢复错序未齐 |
| M-G8 | Blocked；群列表角标Passed | B可见群正文后列表群未读清除；实际群读人数/未播语音、草稿、助手及跨页全一致性未齐 |
| M-G9 | Blocked；失效状态回归Passed | 附件失效close提示、取消/隔离离线通过；真实上传/下载、资源失效、磁盘/系统权限失败矩阵缺样本 |
| M-G10 | Blocked；日志修复Passed | 日志现场发现已修并有可执行反向回归；不清原历史，破坏操作成功范围/供应商host全矩阵未齐 |
| M-G11 | Blocked；键盘/大字局部Passed | 最新宿主正文/发送/收起可达、历史不强跳；引用/多选/媒体进度叠加、性能、VoiceOver仍待环境 |


本次末段操作补证：最终签名包debug.dylib SHA256为398eb2c5964110467e63948440a9aaf930acb0883f041a05afc204349080e343，已覆盖安装iPhone并冷启动；添加好友页实核仍ceshi002（/tmp/ddlNew-phone-final-B-identity.json）。My Mac仍锁屏，运行包未升级到这一后续UI/日志快照，不声称该快照已完成双端终版闭环。默认字号横屏闭键盘生产视图宿主实见正文4/四附件/输入/发送且QA_LAYOUT_FINAL草稿保留（/tmp/ddlNew-ui-viewport-landscape-observed.png）；横屏键盘全矩阵仍Blocked。

B对A备注编辑只写匿名草稿QA_B_TO_A_20261013，未点保存；取消首次仅收焦点，未观察放弃确认，不将其判为通过。随后仅删除自己新输入18字符，回读为空原备注并取消返回资料（/tmp/ddlNew-phone-B-remark-resetdraft.json、/tmp/ddlNew-phone-B-remark-closed.json），服务备注没有提交变更。


## 最后新增检索与宽屏复验

| 执行ID / 需求 | 当前状态 | 证据 |
| --- | --- | --- |
| RES-17 / C-013/014、C-G3 | Passed：检索缺陷闭环子场景 | 最终B查自身ceshi002实见“这是你自己的账号”；清查询后查已确认存在A ceshi001却显示“没有找到用户”（/tmp/ddlNew-phone-add-A-settled.json）。旧xgd精确搜索只传userName，迁移搜索额外带当前B userUid；旧NoaUserModel使用userUID，迁移mapper缺该别名且compactMap静默吞行。两确定协议偏差经独立复核后窄修：搜索仅userName、identity守卫仍留；兼容userUID且拒绝冲突；非空损坏页报格式错误，真[]才未找到。参数提取Swift先红→2绿，旧mapper形状先红→25绿，未记录现场原始body，不能断言两偏差哪个单独导致此响应；两项一起修正后终版iPhone冷启动B查ceshi001实见cs123结果，未再显示未找到（`/tmp/ddlNew-phone-search-final-settled.json`）。独立复核关闭，不发送申请或删/重加已有好友。`/tmp/ddlNew-contact-search-parameters-{red,green}.log`、`/tmp/ddlNew-contact-search-payload-{red,green}.log` |
| RES-18 / M-028、M-G11 | Passed：iPad默认键盘布局子场景 | 新启动指定iPad Pro13(M5)iOS26.5隔离宿主（匿名SDK），安装测试agent后真实操控；输入QA_IPAD_CURRENT，正文/输入/发送/收起在键盘上方且可见，截图/tmp/ddlNew-ui-ipad-default-keyboard.png。不是实际iPad后端或多窗口/最大字号/VoiceOver全矩阵；验收后恢复初始关机状态 |

RES-17之后源码重新有变更，41/41与clean是UI/日志完成快照；新的SDK检索终版增量签名build已成功（`/tmp/ddlNew-final-search-payload-build.log`），42/42完整入口exit0，127.88秒（`/tmp/ddlNew-migration-final-search-confirmed/summary.json`）。检索终版iPhone覆盖安装/冷启动已成功，SHA256为685476c9a8141913a8c3b5d3b8686a878d297ae971e34837c73c910a29a86634；未据此冒报Mac终版已运行。


## 单聊缓存权限最后补修

| 执行ID / 需求 | 状态 | 操作与证据 |
| --- | --- | --- |
| RES-19 / CHAT-004/006、C-G5 | Passed：禁用缺陷与本端单聊子场景；对端受阻 | 检索A→真实好友资料ceshi001→发消息，单聊显示“当前好友关系不可用”，输入禁用。Unicode试输入未匹配即停止，未点发送、没有改旧草稿（现场回读仍占位发送消息）。独立核对SDK：LingIMFriendModel.mm与WCT声明没有status，DB好友查询重新取模型使非持久化status默认0；服务端增量0则由SDK物理删除行。迁移把DB字段硬要求1造成正常好友禁发。仅DB来源缓存允许0/1，缺好友/注销4/未知状态仍拒绝，identity/来源群禁私聊守卫保留，未改表结构或服务端删除语义。生产条件提取Swift先红→6绿，/tmp/ddlNew-single-cache-permission-{red,green}.log；不采用“在persist写1”无效修法。最终43/43完整入口exit0，106.08秒（`/tmp/ddlNew-migration-final-single-confirmed/summary.json`），签名增量build成功（`/tmp/ddlNew-final-single-permission-build.log`），终版iPhone已覆盖安装冷启动保B，SHA256 b59cc4a63a455767759a2a0eca97257f6294b82f1966362f06dee583767dd806；真实输入复验见下一段 |

此前42/42与检索版本685476c9…是RES-19前快照；最新最终状态以RES-19及下一段补证为准。


RES-19终版真机补证：B从A好友资料进入单聊，禁用原因消失（/tmp/ddlNew-phone-single-final-ready.json），稳定聚焦后输入完整QA_20261013_SINGLE_FINAL_B2A 中文🙂＋换行第二行，输入回读精确后点击发送，本端输入清空且没有失败提示；返回消息列表，A会话2108428960873541633预览完整保留中文/emoji/换行（/tmp/ddlNew-phone-final-single-list.json）。发送后当前聊天视口未观察到该气泡，因此最初脚本localCopies=0不能当发送失败/通过；列表实证证明已入消息数据，本端气泡/锚点已在RES-20修正版返页确认，A实收UI及单聊ACK字段因Mac锁屏仍Blocked。没有重发该Unicode标记或清原历史。


| 执行ID / 需求 | 状态 | 操作与证据 |
| --- | --- | --- |
| RES-20 / CHAT-003、M-G7/11 | Passed：真实首屏返页子场景 | 发送Unicode标记后消息列表有完整预览，但单聊当前视口及返页稳定后均无该QA气泡。现有证据指向旧首屏滚动的布局时序：在消息ID变化时单次DispatchQueue.async未落到长历史末尾；本次改首屏使用已有350ms稳定布局滚动到固定latest锚点，只有第一次强制末尾，用户拖动取消、搜索target仍不跳。没有重发同标记，不把“已入消息数据”冒报成正文可见。仅此时序修正版签名build已成功（`/tmp/ddlNew-final-initial-scroll-build.log`），完整43/43入口exit0，110秒（`/tmp/ddlNew-migration-final-initial-scroll/summary.json`）；终版iPhone覆盖安装冷启动后，从列表返A单聊实见原QA_20261013_SINGLE_FINAL_B2A 中文🙂＋换行第二行精确1份，稳定再读仍1，输入空，无重发；首屏force小diff最终独立只读复核未检出确定回归，目标路由守卫及拖动/离页取消均保留。`/tmp/ddlNew-phone-scroll-final-single.json`、`/tmp/ddlNew-phone-scroll-final-single-settled.json` |


最终运行快照：终版手机debug.dylib SHA256 b45628368b4192ece749675104f4090955f5474c3691d0e1ee4916020dbd62d6，安装和冷启动成功。最新状态覆盖RES-16/17/19较早构建数字；当前Mac尚未运行UI/日志/检索/单聊守卫终版，最终双端运行一致性与本次单聊A实收不能标通过。此前Mac→iPhone群完整正文、单条群ACK和前后台角标子证据仍有效但限相应快照。

本轮仅使用A/B及授权群、新QA文本；未发送申请/移除成员/创建群/切账号，备注草稿恢复原空值且未保存，未清原历史或提交推送。iPhone模拟器已恢复原light/large/portrait；新开的iPad测试agent已卸载且恢复初始shutdown。测试工具停止后设备仍保持已登录B，不在后台继续发送。
