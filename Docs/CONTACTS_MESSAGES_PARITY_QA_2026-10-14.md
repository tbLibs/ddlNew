# 2026-10-14 通讯录、消息与群聊对齐验收台账

> 2026-10-15整理补注：下述01:20状态为昨晚验收快照。当前代码已包含在后续4a75da8提交中；新聊天先读[统一交接](SESSION_HANDOFF_2026-10-15_OVERNIGHT_MESSAGES_CONTACTS.md)，再按本台账的116项未完成分支推进。离线/构建安全摘要已持久保存在统一交接的证据目录，原始/tmp日志和截图可能被清理。

## 2026-10-15 聊天布局及资料路由后续修正

用户批准整体按xgd调整聊天布局；输入区、内嵌表情/录音、引用、多选底栏、消息展示和群公告入口已调整，并修正设置页查看好友资料走错导航层级的问题。66/66组离线exit0，最终聚焦复跑及无签名generic iOS workspace构建通过。独立复核的视频文字对比问题已关闭。详见[聊天布局记录](CHAT_LAYOUT_ALIGNMENT_2026-10-15.md)。当前仅源码/离线/编译证据，Mobile MCP继续暂停；新布局的真机输入、实际资料目标与返回、多选转发删除等不沿用昨晚旧布局的已验截图作新版本通过证据。

## 2026-10-15 举报与拉黑追加范围（当前）

用户已批准C-020/C-021，举报限定系统投诉，不含邀请码/IP域名。资料页加入/移出黑名单、“我的”真实黑名单及好友/群/通用投诉已接入SDK。统一离线65/65组exit0（逐脚本耗时合计236.06秒），最终投诉专项复跑及无签名generic iOS workspace构建通过。详细源码、回执、图片上传和待验矩阵见[迁移记录](SAFETY_REPORT_BLOCK_MIGRATION_2026-10-15.md)。

Mobile MCP继续暂停，未操作设备或真实业务服务器。这两项仅代码/离线及编译阶段通过；真实拉黑阻断/解除恢复、各存储供应商上传及服务器投诉受理/审核仍待验。下方历史“13项暂缓”为当时快照，当前整体暂缓11项，不将新增两项标为真实验收完成。

## 2026-10-15 后续离线补充（Mobile MCP 暂停）

本轮基线 `feature-message-4 / ecf1b89`。附件下载完成后解包期间取消加载的回归先失败，修正后通过：取消传入真实流式解包、不回显旧结果、下载临时文件清理、同页重试字节完整，以及删除后保持失效/禁止重新下载。既有预览失效12项继续通过；统一离线63/63组exit0（265.92秒），无签名generic iOS workspace构建 `BUILD SUCCEEDED`。复现入口和证据边界见[统一交接第10节](SESSION_HANDOFF_2026-10-15_OVERNIGHT_MESSAGES_CONTACTS.md#10-2026-10-15后续离线延续mobile-mcp暂停)。

本轮未操作设备或真实服务器；CHAT-011/012/013/032只补本地取消分支证据，逐项真实媒体/后台/弱网和系统操作仍按原台账待验。用户已暂停Mobile MCP，代码与文档不提交/推送。

## 最终状态：2026-10-15 01:20

当前 `feature-message-4`，HEAD `6252ab8`；保留工作区改动，未自动提交或推送。首页/我的森林绿未改，xgd仓库只读且干净。以下历史时刻的“待复验”以本节及逐项表的最终结果为准。

最后冻结源码统一 **62/62组离线exit0**，总311.43秒，结果 `/tmp/ddlNew-parity-final-62-offline/summary.json`。最终签名generic iOS build `/tmp/ddlNew-parity-final-filename-close-build.log` 为BUILD SUCCEEDED，真机保数据覆盖安装exit0；debug dylib SHA256 `5c63ac3e7da68f6a6721779404bab449fd40c5dd44458125b7199f75c19adde3`。Mac最终62C0包已实际运行A，真机最终包恢复B。

本轮真机/双端已实际验证：群公告普通发布、全文/换行、置顶开关、编辑保存回列表、当前页删除确认及删除后自动回公告列表；群预览/名单点击直接资料和真实角色徽标；备注即时改/恢复；双端Unicode文本及双方1/1已读；撤回单占位；仅为我删除后重启AUTH不复活；草稿重进/重启恢复；空分组建改删；会话置顶/免打扰恢复；全局三类/本地预览搜索；合并2条真实转发、作者/时间/正文；受控文件真实上传/下载/预览及字节SHA一致。

最终01:12新文件B完整实收 `qa-file-20261015.txt`，A1/1已读；最终真机文件详情完整原名/137字节/“关闭”，点击返回原聊天。Mac聊天记录和文件详情关闭也已实测。01:15真机手动标记未读→未读筛选只A→“清除未读”→筛选空态，未再出现错误拒绝Toast，随后恢复全部筛选。证据 `phone-B-file-final-original-name.png`、`phone-B-file-final-name-close.png`、`phone-B-manual-unread-final-success.png`、`phone-B-manual-read-final-cleared.png`、`mac-a-merged-final-close-button.png`，均在 `/tmp/ddlNew-parity-evidence`。未执行第二次文件下载字节验收；01:00一次下载已逐字节证明，最后一轮针对名字与关闭差异。

完整服务器验收仍有未完成分支：建群至少两位好友需第三个可控身份，实际移除/邀请恢复、转让/解散、管理员/普通成员权限变化需可恢复测试群；当前无待处理好友/群申请；媒体各类型/各部署供应商/大文件、后台弱网重连与同账号多端并发未全覆盖。未移除原群成员、未清空既有历史、未删除原公告。临时备注/置顶/免打扰/空分组已恢复或清理；本轮受控QA消息保留，原暂缓13项及子能力不伪报通过。116项逐项状态见下表。

## 文件联调过程（最终结果见上）

真实云STS回执已确认成功返回嵌套 `data.credentials`，新端此前找供应商内部前缀字段导致映射拒绝。现在优先读取通用临时凭据字段；显式损坏包装禁止回退，过期/缺字段/禁止序列化守卫保留。生产ObjectMapper回归先RED后GREEN，transport108项通过；未修改Vendor，临时MediaParity诊断已全部移除。00:54安全阶段日志 /tmp/ddlNew-media-stage.log 只含常量事件：权限通过→STS成功→嵌套合同→旧映射拒绝。

修正版Mac A于01:00实际发出原137字节受控文件且1/1已读，B独立实收、下载、QuickLook完整三行内容实见；通过devicectl仅复制该单一QA缓存文件，137字节与SHA256 454873e226f0adbeb93a407d4538c7d1e686e3f3ff700fa8414656efb3b87515逐字节一致。证据 phone-B-file-downloaded-preview.png、qa-file-B-downloaded-0100-verification.json。

接收端显示file-20261015.txt而非原qa-file-20261015.txt，另一个真实合同回归已补：xgd文件wire名称带不含连字符的身份前缀，SDK接收时剥除首个分隔符。新端只对type5按稳定localID生成该前缀，展示仍用原名，不猜改旧历史。生产makeModel+mapper13项RED/GREEN通过；最终包真实原名待复验。

真实合并转发：B多选两条本轮QA，跨最近/好友保留A选中，合并确认发送1条；发送条1/1已读。Mac独立打开包含两条完整原文、正确作者cs123及原22:31/23:08时间，截图 mac-a-merged-forward-received-details.png；B自己的详情显示本机备注Affff及相同原时间/正文，截图 phone-B-forward-merged-own-detail.png。Mac详情缺关闭按钮而无法退出，已为只读聊天记录/附件/搜索/置顶列表/@选择/位置sheet补明确关闭入口，最终包交互复验待补。

STS和空成功回执冻结快照统一61/61离线通过、291.60秒：/tmp/ddlNew-parity-media-unread-final-offline/summary.json；签名generic iOS build /tmp/ddlNew-parity-media-unread-final-build.log成功。随后文件名13项及关闭入口有新增改动；最终62组统一与最终签名包正在验证，前述61/61不冒充覆盖最后新增改动。

## 2026-10-15 凌晨实际旧客户端对照记录

xgd Mac已实际启动并核实ceshi002/test123，同服务器依据是Qqqqq7人/真实角色，以及本轮独有22:09、22:11、22:31、23:08聊天标记。群主/管理员徽标、成员行直达cs123/ceshi001资料、减号进入独立移除候选页、两条既有公告置顶/全文/编辑删除入口均有实际截图。未删除原公告、未提交移除。旧设置预览头像点击未得到导航，不能把成员行证据混为头像证据。旧收件长按菜单实际可打开；新Mac最后一轮主动菜单为自动化入口限制，真机主动撤回和Mac对端单占位已通过。详细独立证据 /tmp/ddlNew-parity-evidence/mac-a-qa.md，截图以xgd-mac-开头。旧Per-User DerivedData已复核恢复原Default，旧App已Stop，返回ddlNew工作区；旧源码/共享工程/全局设置未修改，git status干净。

## 22:xx 末轮验证状态

00:38–00:49补充真机：A单聊输入受控Unicode草稿，返回列表有草稿预览；重进、终止重启AUTH后仍恢复完整输入，最后全选删除，列表恢复原消息预览，未发送该草稿。截图 phone-B-draft-preview.png、phone-B-draft-reopen.png、phone-B-draft-after-restart.png。会话本地query Affff同时匹配好友名称与另一群最新预览，唯一不存在query为空；已清除查询。通讯录账号ceshi001检索得到原Affff，分区仅A；字母索引Y可定位到可见Yyy，菜单A回到Affff，未改变关系。

00:42真实标记未读出现“已标记”但错误Toast：SDK512已写readTag，成功回调data为空却被新端当false。旧xgd CandyTalkHomeViewController.m:1469不读取data；SDK成功路径允许nil。已窄修仅toggleUnread空成功回执受理，明确false/0及未知非空仍拒绝，pin/mute/delete不变；生产边界Operations16项通过。真机当轮进入聊天后清回原readTag，未读筛选回空；修正版安装复验待最终包。证据 phone-B-mark-unread-server-error.png / phone-B-mark-unread-filter.png。

00:46文件安全阶段诊断：store_upload_begin→provider_cloud→store_error chat/code1/current=true，没有取消或页面消失；不能归因picker/ACK。正在核对旧STS data.credentials与新端映射，诊断仅常量阶段和非敏感码，未记录URL或认证数据。

2026-10-15最新补充：Mac A此前复活的自建DELETE_2230已在839源码最新包主动重新删除，稳定页面视觉与AX均消失，截图 mac-a-own-delete-final-cleaned.png；B保留原条符合仅为我删除。Mac A一次选择本地137字节QA文本文件，上传状态结束后没有发送气泡，真机B独立未收到；正在诊断真实阶段，不能计入文件收发通过。文件SHA256为454873e226f0adbeb93a407d4538c7d1e686e3f3ff700fa8414656efb3b87515，证据目录 /tmp/ddlNew-parity-evidence。

最新删除持久化闭环：签名build /tmp/ddlNew-parity-delete-persistence-final-build.log成功，debug dylib SHA256 83936f4de5bb498605b9b1a980fd7b5e118a044ad90912e8494b5e5eb43613b7，真机保数据覆盖安装exit0。统一61/61组离线exit0、287.11秒，/tmp/ddlNew-parity-delete-persistence-final-offline/summary.json。新B_DELETE_PERSIST_FINAL 中文🙂真实发送→仅为我删除确认→稳定页面无条→终止APP重启→AUTH成功→打开原会话，删除条仍无、未删QA_RECALL_FINAL_2240仍完整；再搜索删除原文“暂无匹配”。证据 phone-B-delete-persist-before-restart.png、phone-B-delete-persist-after-restart.png、phone-B-delete-persist-search-empty.png 在 /tmp/ddlNew-parity-evidence。不是内存隐藏验收。

旧客户端实际运行进展：第二次Run Wrapper48E7已显示真实窗口，“我的”当前test123/ceshi002，旧缓存B，未猜身份或输入其他账号。当前只读核对同俱乐部及关键入口；临时Per-User DerivedData设/tmp旧构建目录，完成后恢复原设置，不改旧源码/共享工程/全局。

23:xx修正：新包Mac一次Stop/Run后66722 Wrapper已真实恢复A会话；B在真机主动发送 QA_20261014_B_RECALL_FINAL 中文🙂 23:01、确认撤回23:02，活跃SDK回调只更新原23:01单占位。截图 phone-B-recall-final-single.png 已实看，Mac独立确认同一单占位。A另发 QA_RECALL_FINAL_2240 中文🙂 23:08，真实1/1已读，但该轮Mac菜单自动化未打开，未执行其撤回，不冒充双方向主动撤回皆通过。

23:xx历史发现（已由上述最终闭环覆盖）：A本人仅为我删除 DELETE_2230 后当时UI消失/搜索空，但AUTH重启恢复，根因为SDK首次同步latest覆盖status0；B保留原条属正常。最终包已保护SDK持久状态，真机重启闭环通过，A旧测试条重新清理。

真机即时备注闭环通过：保存 QA_FINAL_A_备注🙂 直接返回列表，新文字与Q分区同步；再次恢复 Affff 直接返回列表，文字与A分区同步。两次全程无重启，描述Ikf保留。视觉证据 contact-final-immediate-remark.png / contact-final-immediate-restored.png 在 /tmp/ddlNew-parity-evidence。

最新A2B_EPOCH_FINAL_UNICODE与B2A_EPOCH_FINAL双方独立完整实收中文、emoji和换行，双方发送条1/1已读；B接收前1条未读，实际可见阅读后返回列表无该未读。Mac copy/reference/本人文本编辑实收/仅为我删除/search正负例详见 /tmp/ddlNew-parity-evidence/mac-a-qa.md；B单向删除条完整保留。B置顶、免打扰开关已恢复原状态，期间新到达消息保持1条未读。真机新建群选1A完成(1)禁用、取消无写入，截图 phone-B-new-group-one-disabled.png。

一次撤回实际出现原条22:23及控制条22:26两个气泡。SDK为type8 BackMessage；补修隐藏独立控制记录，仅以真实backDelServiceMsgID更新原条status2占位，保留稳定身份供引用定位；xgd采用移除原条后追加控制提示，二者显示时间方式不同但均应一条。末包签名build成功，日志 /tmp/ddlNew-parity-recall-final-build.log；debug dylib SHA256 3fc46349212103122fcede97116ff8e80504baa3bca74c6dafa5609421d4e6a2；真机覆盖安装exit0。最终统一60/60组离线exit0，273.16秒，/tmp/ddlNew-parity-recall-final-offline/summary.json。真机末包重开历史旧重复占位已消除；新marker活跃回调双端复验继续。

xgd旧源保持只读，独立MacDesigned签名构建 /tmp/xgd-parity-mac-build.log 为BUILD SUCCEEDED，git status仍干净；不把旧构建当旧App已运行或真实服务器验收。Mac末包Run遇CUA LSOpen -1712超时，当前正在一次Stop/Run恢复，未发送新的recall marker；结果待补。

持续更新；工作区保留，不自动提交或推送。旧项目参考 xgd，首页/我的森林绿和短 Toast 保持。

## 验收口径

源码与匿名离线检查证明本地行为和合同，不能代替真实服务器。真机为 iPhone 12（iOS 26.6.1），Mac 为 Designed for iPhone App；A/B 测试账号分别为 ceshi001/ceshi002，不记录密码。已有好友/群历史不清空，已有公告不删除。新建群按 xgd 至少选择两位好友，需要第三个可控身份；仅 A/B 不冒充三角色或建群人数全验收。

当前报告未宣称全部通过；下表逐项覆盖116项原需求，13项原暂缓能力保留明确边界。已执行局部场景不等于该行所有A1/A2和公共异常分支通过。

2026-10-14阶段子能力：CHAT-014当时仅既有贴纸/历史游戏；2026-10-15用户追加批准默认石头剪刀布/骰子发送，商城与其它游戏仍暂缓；CHAT-016仅历史位置，位置发送暂缓；C-038聊天不含发起通话；M-014兼容同步、不新增全读按钮；CHAT-049兼容历史加密/阅后，不新增发起。详见2026-10-13迁移交接，不将这些子项的无入口判为本轮回归。

## 实际观察记录

| 时间 | 环境/行为 | 当前证据与限制 |
| --- | --- | --- |
| 18:33 | 真机 B 添加好友页 | 我的账号ceshi002，查ceshi001得到cs123且资料账号一致；真实服务器返回 |
| 18:38 | 真机 B 为A保存临时备注 | 资料标题、备注字段、单聊标题为QA1014_A_备注🙂，描述Ikf保留；Toast尚未捕获；通讯录排序变Q但行旧文字Affff，待最终覆盖安装复核 |
| 18:40 | 真机 B→A 文本 | QA_20261014_B2A_1840 中文🙂及第二行显示发送方气泡 |
| 18:49 | Mac A接收 | 独立Mac实例会话新增1条未读，打开B单聊见完整1840标记/中文/emoji/第二行；当前版本早于交叉复核最后修正 |
| 18:53/19:00 | Mac A→B 文本 | 真机B会话出现1条未读，打开见完整1850标记及第二行；独立两端实收已观察，B发1840条仍显示0/1已读，真实已读人数待查 |

## 稳定版本验证与公告实测新发现

19:00稳定签名build成功 /tmp/ddlNew-parity-stable-device-build.log，覆盖安装debug dylib SHA256 c4850dd9d29ecc7f10a3a3a4dff247409a70bc8d780ecc556364e8387b2c29f0；54/54离线脚本全exit0，共260.56秒，/tmp/ddlNew-parity-stable-offline/summary.json。这是公告真机新发现补修之前的快照。

19:04 编辑QA1856删除prompt在当前页立即出现，取消后留正文。19:07确认后编辑仍停留，手动取消返回详情也未自动退出，手动返回列表才出现“公告已删除”Toast。最新补修改为受理callback直接由可见页面dismiss，不再依赖隐藏父页onChange。截图 /tmp/ddlNew-parity-evidence/notice-delete-editor-stuck.png。

19:05 不变保存后详情及再次编辑显示字面省略号而非第二行；实际列表接口返回摘要。最新补修让详情保持提交的完整正文，任何编辑先读取真实完整详情，读失败禁止拿摘要覆盖。19:11/19:13列表仍有QA1856且时间更新19:05；暂不把Toast视为服务器删除验收，正在核对公告ID版本变化/真实响应。原有两条公告保留。

19:30诊断证实编辑回执ID变化：save requestedID13 → resultID14，服务器列表改为14+原11/7。全文第二行仍完整。19:35从真实14详情进入编辑确认删除，**自动回公告列表**，delete14受理，随后真实服务器load只剩原11/7，UI同步无QA项。证据 /tmp/ddlNew-parity-evidence/notice-id-lifecycle.log。保存后按xgd跳过旧详情回列表已补，待最新无诊断包复验；删除自动返回已实测。

正文批量已读还发现旧项目type13为SID_senderUID_clientMID，新仅SID。已按实际原记录补三段，51项离线通过，最终双端新marker回执继续（旧本地已标读的1840不会自然再上报）。

20:22最终双端新marker完成：B2A_READ_FINAL实际A视口完整实收、B发送条1/1；A2B_READ_FINAL_UNICODE实际B视口完整实收、A发送条1/1；截图 phone-B-read-final.png、mac-a-a2b-unicode-read1.png 在 /tmp/ddlNew-parity-evidence。新marker以完整当前提交/收件事实计，不把AX输入框setValue作为实际绑定或送达。

20:xx已核对Qqqqq设置头像直接进A资料，群成员列表点击A直接进资料（BackButton群成员），群主/管理员标识真实可见。移除按钮独立页面，真实A勾选进入确认，删除其已发消息默认关；已取消，没有移除现有群成员，不宣称服务器移除通过。新群需要第三个可控身份，当前只A/B不能完成建群/移除恢复/三角色全矩阵。

最终通讯录当前包列表显示测试备注；恢复A原备注Affff真实受理、描述Ikf保留。另source审计发现旧历史/标全读后的旧false可能扣屏外新未读，正在补计数成员归属及epoch；SDK506强制整会话清零的继承边界单列，不伪报全矩阵。

## 覆盖索引

| 需求 | 原范围 | 本轮验收状态 |
| --- | --- | --- |
| [C-001 页面入口、好友/业务分组/群聊切换](CONTACTS_MIGRATION_REQUIREMENTS.md#C-001) | 开发/回归 | Mac/真机好友、分组、群列表入口实测；异常及全部取消分支待验 |
| [C-002 好友名单、名称优先级与排序](CONTACTS_MIGRATION_REQUIREMENTS.md#C-002) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-003 好友在线、注销及异常账号状态](CONTACTS_MIGRATION_REQUIREMENTS.md#C-003) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-004 真实头像、文件Host变化与图片降级](CONTACTS_MIGRATION_REQUIREMENTS.md#C-004) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-005 SDK同步、错误恢复和跨账号隔离](CONTACTS_MIGRATION_REQUIREMENTS.md#C-005) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-006 本地好友检索与旧全局好友检索差异](CONTACTS_MIGRATION_REQUIREMENTS.md#C-006) | 开发/回归 | 真机账号ceshi001本地匹配原Affff、索引仅A通过；昵称/异常/多字段全矩阵待验 |
| [C-007 首字母快速定位](CONTACTS_MIGRATION_REQUIREMENTS.md#C-007) | 开发/回归 | 真机侧边Y定位可见Yyy、字母菜单A回到Affff通过；大量名单/RTL待验 |
| [C-008 新朋友入口、申请未读与通讯录角标](CONTACTS_MIGRATION_REQUIREMENTS.md#C-008) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-009 好友申请列表、分页与状态](CONTACTS_MIGRATION_REQUIREMENTS.md#C-009) | 开发/回归 | Mac真实已添加申请列表通过；真实待处理申请及分页不足，未改既有关系 |
| [C-010 同意好友申请与完整好友落库](CONTACTS_MIGRATION_REQUIREMENTS.md#C-010) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-011 申请详情、重新申请与发消息分支](CONTACTS_MIGRATION_REQUIREMENTS.md#C-011) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-012 申请本地隐藏与“拒绝”证据边界](CONTACTS_MIGRATION_REQUIREMENTS.md#C-012) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-013 按账号/手机号/邮箱查找用户](CONTACTS_MIGRATION_REQUIREMENTS.md#C-013) | 开发/回归 | 局部真机通过：B查A账号；异常/权限分支待验 |
| [C-014 发送添加好友申请与权限统一](CONTACTS_MIGRATION_REQUIREMENTS.md#C-014) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-015 本人/陌生人/群成员资料关系判断](CONTACTS_MIGRATION_REQUIREMENTS.md#C-015) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-016 好友资料展示、现场刷新与实时变化](CONTACTS_MIGRATION_REQUIREMENTS.md#C-016) | 开发/回归 | 局部备注/标题已观察；全同步矩阵待验 |
| [C-017 编辑备注与备注描述](CONTACTS_MIGRATION_REQUIREMENTS.md#C-017) | 开发/回归 | 真机即时改/恢复后直接回列表，文字/字母分区同步，无重启，原Affff/Ikf恢复；弱网/同账号多端完整矩阵待验 |
| [C-018 推荐好友名片](CONTACTS_MIGRATION_REQUIREMENTS.md#C-018) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-019 删除好友、审核受理与聊天记录清理](CONTACTS_MIGRATION_REQUIREMENTS.md#C-019) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-020 真实黑名单能力](CONTACTS_MIGRATION_REQUIREMENTS.md#C-020) | 开发/回归 | 10月15日追加批准，真实SDK/离线通过；双端阻断与恢复待验 |
| [C-021 系统投诉/举报](CONTACTS_MIGRATION_REQUIREMENTS.md#C-021) | 开发/回归 | 10月15日批准仅系统投诉，真实SDK/离线通过；上传与受理待服务器验收 |
| [C-022 好友业务分组、默认组与展开收起](CONTACTS_MIGRATION_REQUIREMENTS.md#C-022) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-023 创建、改名与删除业务分组](CONTACTS_MIGRATION_REQUIREMENTS.md#C-023) | 开发/回归 | Mac自建空QA分组创建→更名→删除真实回查通过；长名称服务器拒绝且保稿，未知限制未猜 |
| [C-024 业务分组排序管理](CONTACTS_MIGRATION_REQUIREMENTS.md#C-024) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-025 将好友移动到业务分组](CONTACTS_MIGRATION_REQUIREMENTS.md#C-025) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-026 真实群列表与成员关系同步](CONTACTS_MIGRATION_REQUIREMENTS.md#C-026) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-027 全局群搜索与群聊天定位](CONTACTS_MIGRATION_REQUIREMENTS.md#C-027) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-028 建群选人、最近联系人及跨列表选中](CONTACTS_MIGRATION_REQUIREMENTS.md#C-028) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-029 创建群请求、返回与真实群聊天](CONTACTS_MIGRATION_REQUIREMENTS.md#C-029) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-030 本人好友二维码、复制账号与保存分享](CONTACTS_MIGRATION_REQUIREMENTS.md#C-030) | 开发/回归 | Mac本人真实业务二维码及资料复制Toast通过；相册/扫码完整链路待验 |
| [C-031 业务扫码添加好友及其他结果分流](CONTACTS_MIGRATION_REQUIREMENTS.md#C-031) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-032 群二维码、扫码入群与待审核](CONTACTS_MIGRATION_REQUIREMENTS.md#C-032) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-033 通讯录文件助手入口与权限](CONTACTS_MIGRATION_REQUIREMENTS.md#C-033) | 开发/回归 | Mac真实文件助手历史/输入入口通过；媒体上传下载和角色开关待验 |
| [C-034 通讯录群助手/群系统通知入口](CONTACTS_MIGRATION_REQUIREMENTS.md#C-034) | 开发/回归 | Mac群助手全部/待审核真实空态通过；无待处理申请，不能验批量审核 |
| [C-035 我的团队与团队建群边界](CONTACTS_MIGRATION_REQUIREMENTS.md#C-035) | 暂缓/待取舍 | 原暂缓；本轮未扩大开发或伪报通过 |
| [C-036 角色、系统配置与群成员访问统一守卫](CONTACTS_MIGRATION_REQUIREMENTS.md#C-036) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-037 空态、取消、键盘与可访问性](CONTACTS_MIGRATION_REQUIREMENTS.md#C-037) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [C-038 好友发真实消息与音视频入口依赖](CONTACTS_MIGRATION_REQUIREMENTS.md#C-038) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [M-001 真实会话首次加载与有效类型过滤](MESSAGE_MIGRATION_REQUIREMENTS.md#M-001) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [M-002 置顶分区、时间排序与稳定去重](MESSAGE_MIGRATION_REQUIREMENTS.md#M-002) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [M-003 单群聊标题、备注与真实头像优先级](MESSAGE_MIGRATION_REQUIREMENTS.md#M-003) | 开发/回归 | 局部备注/标题已观察；全同步矩阵待验 |
| [M-004 最新预览、群发送者、@与特殊消息摘要](MESSAGE_MIGRATION_REQUIREMENTS.md#M-004) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [M-005 会话时间格式、校时与缺值](MESSAGE_MIGRATION_REQUIREMENTS.md#M-005) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [M-006 未读行、手动提醒、免打扰与Tab角标](MESSAGE_MIGRATION_REQUIREMENTS.md#M-006) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [M-007 同步进度、连接提示与缓存错误恢复](MESSAGE_MIGRATION_REQUIREMENTS.md#M-007) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [M-008 全部/未读筛选与本地预览搜索](MESSAGE_MIGRATION_REQUIREMENTS.md#M-008) | 开发/回归 | 真机本地名称/群最新预览匹配、无匹配空态、未读空态及手动标记入筛选通过；查询已清，组合全矩阵待验 |
| [M-009 会话点击、真实路由与进入清读边界](MESSAGE_MIGRATION_REQUIREMENTS.md#M-009) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [M-010 会话置顶与取消置顶](MESSAGE_MIGRATION_REQUIREMENTS.md#M-010) | 开发/回归 | 真机开启排前/取消恢复通过，原状态已恢复；失败及多账号矩阵待验 |
| [M-011 会话免打扰与取消](MESSAGE_MIGRATION_REQUIREMENTS.md#M-011) | 开发/回归 | 真机开启/取消恢复、新到达未读保留通过；后台推送/全角标矩阵待验 |
| [M-012 手动标记未读/已读与读游标](MESSAGE_MIGRATION_REQUIREMENTS.md#M-012) | 开发/回归 | 最终真机标记未读→筛选只A→清除未读→空态且无错误Toast通过，原状态恢复；屏外新到达/同账号多端完整矩阵待验 |
| [M-013 删除会话且保留历史](MESSAGE_MIGRATION_REQUIREMENTS.md#M-013) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [M-014 全会话已读同步能力与主动入口待确认](MESSAGE_MIGRATION_REQUIREMENTS.md#M-014) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [M-015 真实草稿、@片段与恢复来源差异](MESSAGE_MIGRATION_REQUIREMENTS.md#M-015) | 开发/回归 | 真机Unicode草稿列表预览→重进→终止重启AUTH恢复通过，测试草稿清除未发送；@/切账号完整矩阵待验 |
| [M-016 全局搜索三分类与更多](MESSAGE_MIGRATION_REQUIREMENTS.md#M-016) | 开发/回归 | 真机query1好友/群聊/单聊消息及更多好友展开/收起通过；完整分页/失效定位待验 |
| [M-017 搜索好友/群/助手的目标分流与权限](MESSAGE_MIGRATION_REQUIREMENTS.md#M-017) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [M-018 消息搜索命中、补页与原消息定位](MESSAGE_MIGRATION_REQUIREMENTS.md#M-018) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [M-019 文件助手专用真实会话](MESSAGE_MIGRATION_REQUIREMENTS.md#M-019) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [M-020 群发助手、收件人选择和部分失败](MESSAGE_MIGRATION_REQUIREMENTS.md#M-020) | 暂缓/待取舍 | 原暂缓；本轮未扩大开发或伪报通过 |
| [M-021 群系统通知、申请同意/拒绝与批量审核](MESSAGE_MIGRATION_REQUIREMENTS.md#M-021) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [M-022 签到提醒历史与真实签到依赖](MESSAGE_MIGRATION_REQUIREMENTS.md#M-022) | 暂缓/待取舍 | 原暂缓；本轮未扩大开发或伪报通过 |
| [M-023 支付助手类型与不可达边界](MESSAGE_MIGRATION_REQUIREMENTS.md#M-023) | 暂缓/待取舍 | 原暂缓；本轮未扩大开发或伪报通过 |
| [M-024 更多菜单、添加/创建群/业务扫码/群发](MESSAGE_MIGRATION_REQUIREMENTS.md#M-024) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [M-025 双击消息Tab循环定位未读](MESSAGE_MIGRATION_REQUIREMENTS.md#M-025) | 暂缓/待取舍 | 原暂缓；本轮未扩大开发或伪报通过 |
| [M-026 多端会话事件、删除与退出清理](MESSAGE_MIGRATION_REQUIREMENTS.md#M-026) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [M-027 消息角色权限与系统业务配置缺口](MESSAGE_MIGRATION_REQUIREMENTS.md#M-027) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [M-028 加载/空/错误、键盘和可访问性](MESSAGE_MIGRATION_REQUIREMENTS.md#M-028) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [M-029 通知/深链打开真实会话与Badge依赖](MESSAGE_MIGRATION_REQUIREMENTS.md#M-029) | 暂缓/待取舍 | 原暂缓；本轮未扩大开发或伪报通过 |
| [CHAT-001 真实单群聊建立与路由上下文](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-001) | 开发/回归 | 双端真实单聊局部观察；完整分支待验 |
| [CHAT-002 历史首屏、本地缓存与100条游标分页](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-002) | 开发/回归 | 双端真实单聊局部观察；完整分支待验 |
| [CHAT-003 滚动位置、新消息提示与搜索定位](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-003) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-004 实时收消息、双ID去重与状态事件分流](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-004) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-005 发送落库、发送中/成功/失败与ACK重排](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-005) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-006 SDK失败分类、ACK重试与人工重发](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-006) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-007 正文可见批量已读、语音播放与已读提示](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-007) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-008 消息日期分隔、服务端校时与气泡基础](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-008) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-009 文本、Unicode emoji、敏感处理与输入恢复](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-009) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-010 @选择、@所有人、片段编辑与限制](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-010) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-011 语音录制、取消、上传、播放与已读](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-011) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-012 相册/拍摄图片视频、转换文件与上传任务](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-012) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-013 文件选择、上传/下载、文件名与系统打开](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-013) | 开发/回归 | STS与wire文件名合同修复后实际A发送/B下载预览137字节且SHA一致；最终新文件原名/关闭入口通过，大文件/异常/取消全矩阵待验 |
| [CHAT-014 贴纸/GIF/游戏表情及表情商城](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-014) | 开发/回归 | 真机已用/收藏空态为既有证据；2026-10-15默认石头剪刀布/骰子代码已接入，离线/构建见最新交接，真实游戏双端待验；商城/其它新游戏仍暂缓 |
| [CHAT-015 真实名片推荐、接收与资料分流](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-015) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-016 历史位置气泡与位置发送待取舍](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-016) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-017 合并聊天记录呈现与嵌套边界](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-017) | 开发/回归 | B合并2条本轮QA为1条，Mac独立内部2条全文/真实作者/原时间通过；嵌套/媒体完整矩阵待验 |
| [CHAT-018 禁言/角色/上传开关与群发送间隔](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-018) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-019 长按菜单矩阵、复制与链接](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-019) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-020 引用回复、原文定位与变更同步](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-020) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-021 单条/多选删除、单向与双向范围](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-021) | 开发/回归 | 真机新条本机删除→重启AUTH→不复活→搜索空通过；Mac单向删时B保留原条通过，多选/双向完整分支待验 |
| [CHAT-022 撤回窗口、管理者撤回与撤回占位](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-022) | 开发/回归 | 真机B主动新条撤回及Mac收件只有一个占位通过；A最终主动撤回菜单未打开、管理者/期限完整分支待验 |
| [CHAT-023 本人文本/@编辑、分钟权限与回写](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-023) | 开发/回归 | 真机B本人新QA文本编辑成功、1/1已读通过；跨端内容/边界权限完整分支待验 |
| [CHAT-024 消息多选、100条上限及不可选类型](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-024) | 开发/回归 | 真机普通文本多选计数1/100→2、转发确认2条通过；100上限/全部类型待验 |
| [CHAT-025 逐条/合并转发、合规预检与逐对象结果](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-025) | 开发/回归 | 真机跨最近/好友保留A选中、合并2条实际1个气泡、1/1已读及Mac独立详情通过；逐条/部分失败/群禁转发矩阵待验 |
| [CHAT-026 消息收藏与保存链接模块](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-026) | 暂缓/待取舍 | 原暂缓；本轮未扩大开发或伪报通过 |
| [CHAT-027 翻译配置、状态、再次翻译与服务依赖](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-027) | 暂缓/待取舍 | 原暂缓；本轮未扩大开发或伪报通过 |
| [CHAT-028 聊天消息置顶、个人/全局与原文定位](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-028) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-029 定时自动删除：1/7/30天与关闭](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-029) | 暂缓/待取舍 | 原暂缓；本轮未扩大开发或伪报通过 |
| [CHAT-030 单聊设置、加好友成群与清空记录](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-030) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-031 会话内文本/媒体/文件分类搜索与成员筛选](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-031) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-032 媒体/文件详情、下载与系统分享打开](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-032) | 开发/回归 | 真机受控txt下载/QuickLook全文与字节SHA一致；Mac/真机详情关闭回聊天通过，其他媒体/实际外部分享完整矩阵待验 |
| [CHAT-033 群设置总入口与0/1/2角色矩阵](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-033) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-034 群头像、群名称与资料编辑权限](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-034) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-035 群成员预览、成员列表、人数与资料守卫](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-035) | 开发/回归 | 真机Q群预览头像及名单点击直接资料、7人数/真实群主与管理员标识通过；完整角色限制矩阵待验 |
| [CHAT-036 我的群昵称、30字符与跨端名称刷新](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-036) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-037 邀请好友进群、排除已有成员及审核原因](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-037) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-038 移除群成员与同时删除其发言](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-038) | 开发/回归 | 真机独立移除选择及确认页/默认关闭删除发言通过，取消未改变成员；服务端实际移除需可恢复测试群 |
| [CHAT-039 群管理菜单与逐项授权](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-039) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-040 全员/单人/永久禁言与解除](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-040) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-041 群入群申请列表、审核与成员同步依赖](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-041) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-042 群主转让与管理员增减](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-042) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-043 群私聊、历史、提示、二维码及通话开关](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-043) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-044 群公告列表、详情、创建编辑删除及已读](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-044) | 开发/回归 | 真机普通发布、全文/emoji/换行、置顶及取消置顶、编辑保存回列表、编辑删除自动返回与回查消失通过；弱网/权限变化/全分页待验 |
| [CHAT-045 退出群、转让前置与群主解散](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-045) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-046 音视频发起、群选择与LiveKit/Zego依赖](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-046) | 暂缓/待取舍 | 原暂缓；本轮未扩大开发或伪报通过 |
| [CHAT-047 群机器人只读列表与活跃等级](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-047) | 暂缓/待取舍 | 原暂缓；本轮未扩大开发或伪报通过 |
| [CHAT-048 业务事件、群角色与昵称同步回流合同](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-048) | 开发/回归 | 源码已对照；真机完整分支待验 |
| [CHAT-049 未知消息、旧消息兼容及生命周期清理](MESSAGE_MIGRATION_REQUIREMENTS.md#CHAT-049) | 开发/回归 | 源码已对照；真机完整分支待验 |

## 21:xx 最终公告闭环与读计数修正

最新无诊断包真机自建 QA_20261014_NOTICE_FINAL_2113：普通发布 isTop0/isSendMsg0，详情完整中文/emoji/换行；编辑仅开置顶后保存自动返回列表，新版本详情正文完整；取消置顶保存再次自动回列表且无置顶标识。进入其最新版本编辑点击删除，当前页立即弹确认，确认受理后自动回列表，QA项消失，原有18:03/17:36两条仍在。截图 /tmp/ddlNew-parity-evidence/notice-final-delete-return-list.png。不把成功Toast替代列表回查。

读计数新增AUTH期间SDK真实receive/计数/权威会话分页观察，以及计数成员epoch账本：历史记录的isRead=false不自动当作未读数成员；实际正文写true与会话计数持久化分离，同AUTH页面退出不丢待扣身份；SDK归零/权威分页/成功手动全读边界使旧资格失效，等待期间新消息保留。不使用SDK reconnect watermark当已读边界。未知初始正数保守保持；进程结束/新AUTH依赖SDK权威同步；SDK506无边界整会话清零的继承行为未改，完整后台/重连/多端矩阵待验。

最终统一离线59/59组exit0，232.34秒：/tmp/ddlNew-parity-final-epoch-offline/summary.json；真实SDK签名build /tmp/ddlNew-parity-final-epoch-build.log 成功。之后真机截图证实恢复Affff时分区A已更新但好友行视觉仍QA旧备注，增加仅实际展示字段的行identity、导航仍稳定UID的最小修正。后续构建 /tmp/ddlNew-parity-contact-row-final-build.log 成功，debug dylib SHA256 8da2743a7a3963edcd85823bc4b4d500fde9a753a89c05e585e6f38a813c1dda。即时再次改/恢复仍待覆盖安装复验，不能把重启初始正确当同步通过。


## 2026-10-15后续：原生导航栏与输入修正（离线阶段）

四Tab实际页面、活动重复标题改用原生toolbar；基础表情补旧157资源及文本标记，群@改为键入触发和光标UID插入；工具栏四等分。只读复核发现的特殊昵称UID错位、迟到成员请求弹层/焦点问题已修正复核。验证日志和最终组数见[聊天布局记录](CHAT_LAYOUT_ALIGNMENT_2026-10-15.md)；页面范围见[导航记录](NAVIGATION_TOOLBAR_MIGRATION_2026-10-15.md)。Mobile MCP仍暂停，以上仅离线/构建阶段，未将实际系统键盘、输入法、设备布局及服务器群提及验收改为通过，既有未完成矩阵保持。

本次最终统一离线68/68组exit0（351.63秒），无签名generic iOS workspace构建exit0、`BUILD SUCCEEDED`，独立复核重要问题关闭。详细日志与设备待验边界仍见上引记录；未进行真实群@发送/接收验收。


## 2026-10-15最终续接入口

本轮群权限已获真实字段并修正、UIKit手动焦点已修、默认石头剪刀布/骰子已新增；实现、RED/GREEN和最终日志、设备待验及同期头像改动保留统一见[最新交接](SESSION_HANDOFF_2026-10-15_CHAT_INPUT_GAMES.md)。Mobile MCP暂停，本台账既有真实通过项保留；新代码不得借用之前设备结论。

本轮当前版本统一离线72/72组exit0（347.34秒），最终无签名workspace重试构建通过；包含同期头像专项。依旧仅离线/构建阶段，真实键盘、群发送权限/收发及游戏动画双端按最新交接待验，不改既有服务器矩阵结论。
