# 2026-10-15 交接：昨晚消息、通讯录与群聊改动

整理日期：2026-10-15（Asia/Shanghai）。业务与设备验收截至 2026-10-15 01:20；本次整理只读取源码、Git 和既有证据，没有重新构建、安装或操作设备。

## 1. 新聊天直接粘贴

> 请先完整阅读 `/Users/taobotaobo/Desktop/ddlNew/Docs/PROJECT_HANDOFF.md` 和 `/Users/taobotaobo/Desktop/ddlNew/Docs/SESSION_HANDOFF_2026-10-15_OVERNIGHT_MESSAGES_CONTACTS.md`，再检查当前分支、git status 和相关源码。延续 10 月 14 日晚至 15 日凌晨的通讯录、消息、群聊对齐工作，只读参考 `/Users/taobotaobo/Desktop/xgd`，保持首页和我的森林绿主题、既有 UIAdapter 和中文业务注释。当前整理时 HEAD 为 `4a75da8`，昨晚改动已包含其中，以实时 Git 为准；保留已有改动，不自动提交或推送。昨晚最终 62/62 组离线检查、签名构建及关键 Mac/真机双端场景已通过，优先处理本文未完成项，不重复重做已关闭问题。Mobile MCP 已获授权；仅操作已有 A/B 测试身份及可恢复测试数据，缺第三身份或测试群时记录真实条件，继续不依赖这些条件的验证。构建、匿名夹具、发送方气泡和 Toast 分别只能证明对应阶段，不能代替完整服务器验收。

## 2. 接手顺序与当前 Git

1. 阅读项目总交接和本文。查看 [116 项逐项验收台账](CONTACTS_MESSAGES_PARITY_QA_2026-10-14.md) 的最终状态，再选择未完成分支。
2. 在 `/Users/taobotaobo/Desktop/ddlNew` 执行 `git branch --show-current`、`git status --short`、`git log -3 --oneline`。源码与实时 Git 优先于所有历史快照。
3. 涉及具体模块时，按第 7 节定位源码和检查脚本。涉及旧交互时先读 xgd 实现，再改新项目。
4. 需要设备验证时，重新发现设备、核对实际业务账号和运行版本；需要构建时，确认 Xcode 与 CLI 没有同时占用同一 DerivedData。
5. 只对新的问题或尚未覆盖的分支继续修复；记录操作端、接收端、服务器回读及数据恢复结果，并更新验收台账。

本次整理开始时的实时状态：

| 项目 | 状态 |
| --- | --- |
| 分支 | `feature-message-4` |
| HEAD | `4a75da8 fix:修复bug` |
| 前一提交 | `6252ab8 fix：修改通讯录模块的bug` |
| 整理前工作区 | 干净，无暂存或未合并文件 |
| 昨晚增量 | `6252ab8..4a75da8`：84 个路径，38 个生产源码、42 个测试、4 个文档 |
| 本助手 Git 操作 | 未执行 commit / push；后续提交已在本次读取时存在 |

凌晨文档中的“HEAD 6252ab8、84 个路径未提交”是当时快照，不能继续当作当前状态。本次新增交接及证据摘要仍留工作区，不自动提交。可用 `git diff --name-status 6252ab8 4a75da8` 查看昨晚完整文件清单。

**整理期间的并行工作：**复核时新增 `Podfile`、`Podfile.lock`、`ddlNew.xcodeproj/project.pbxproj` 修改和未跟踪 `EncryptLib/`。这些属于本次文档整理之外的同期改动，未读取其业务内容、未修改或回退；新聊天先检查其当前状态，不能把“整理开始时干净”当成收尾仍干净。全仓 `git diff --check` 当前报告 Podfile 第34行尾随空白，本次保留；交接文档自身单独校验。

## 3. 保留的产品约定和既有改动

以下早前 UI 与群设置修正已在 `6252ab8` 及之前的基线中；昨晚继续保留，不能因为它们不在最新提交 diff 中就重新实现。

- 消息、通讯录及关联页面按 xgd 布局和交互对齐；强调色、实色按钮、发送气泡和底栏沿用 `HomeTheme.forest`。深色模式保留，几何适配用现有 UIAdapter。
- 默认选中消息 Tab；底栏由实际 `navigation.path.isEmpty` 控制，根页面显示、push 隐藏、返回恢复，各 Tab 独立持有路径。
- 常规底部动作按钮复用 `MessagingActionButtonStyle`，最小 48pt；导航栏保存采用紧凑文字与至少 44pt 触点，保留启用/禁用样式。
- `MessagingStatusToast` 复用 AlertToast，loading 对应真实任务，短反馈默认 3 秒；浅色灰绿 `#E1E9E3`、深色 `#2F3C34`。业务结果从正文移到 Toast，内容、申请状态、校验、失败图标和重试保留。
- 新朋友页保留独立约定：有加载反馈与记录状态，不恢复全局业务结果行；分组管理不恢复普通成功文案。
- 默认分组空名称显示“默认分组”；组排序用真实 `ugOrder`，群列表按稳定 ID 保留位置；选人分组标签间距、全选/取消和保存校验已调整。
- 备注与描述共用编辑页；复制账号居中 Toast。二维码删除右上更多菜单，保存/分享入口保留；扫码直接取景、相册入口保留、失败反馈后自动继续捕获。
- 新群人数使用服务器确认及 SDK 群表，保留已知正数免遭缓存 0 覆盖；真实后续人数仍更新，同人数不重复发代理，不用“所选人数加 1”伪造人数。
- 群设置预览头像直接进所点成员资料；“查看群成员”进完整名单，名单行直接进资料。资料携带真实 UID 和来源群，返回保持原导航层级。
- 减号进独立 `ChatGroupRemovalView`，支持搜索、多选、完成人数及“删除其已发消息”（默认关）。权限过滤排除本人、群主、注销/机器人及非下级角色，上限 500；失败保留选择，提交前重核真实权限。
- 预览、名单、移除与确认名单统一显示真实群角色：成员 role2 群主、role1 管理员；账号平台角色不能代替群角色。

早前 UI 设计和离线宿主截图仅作布局参考，详见 [10 月 14 日历史会话记录](SESSION_HANDOFF_2026-10-14_MESSAGES_CONTACTS_UI.md) 和 [UI 对齐记录](MESSAGING_UI_ALIGNMENT_2026-10-14.md)。

## 4. 昨晚新增修复：原因、当前行为与验收边界

### 4.1 群公告全文、置顶、编辑和删除

- 响应读 `content / topStatus`；`status` 是正常/删除状态，不能当置顶。写入保持 `noticeContent / isTop / isSendMsg`，置顶和发群消息独立。
- 列表真实返回摘要，不能拿摘要覆盖全文。详情保留完整正文；每次编辑先 `prepareEdit` 读取完整详情，读取失败阻止用摘要提交。
- 实际服务器一次编辑让公告 ID 从 13 变为 14，不能在保存后继续对旧 ID 操作。保存按 xgd 返回公告列表。
- 删除确认属于当前可见详情/编辑页，修复“返回父列表才弹框”。服务器受理回调先由可见页 dismiss；编辑 sheet 关闭后再关闭下层详情，修复“删完仍停留旧正文”。失败保留当前页和草稿，回读失败与写入失败分开提示。
- 时间显示 `yyyy/MM/dd HH:mm`；详情、编辑、列表及聊天顶部置顶公告按真实版本刷新，旧详情回执失效。

**实际验证：**普通发布、中文/emoji/换行全文、开置顶/关置顶、编辑保存回列表、当前页确认删除、删除后自动回公告列表及服务器回查 QA 项消失已真机通过。原有公告 ID11/7 保留。失败、权限变化和完整分页矩阵仍未全部真机覆盖。

### 4.2 通讯录备注、好友申请、入群申请和扫码

- 保留既有保存确认后写 SDK 好友缓存、撤销旧 profile 回读资格的修复。
- 真机新增发现：缓存和字母分区已新，但稳定 NavigationLink 的行文字仍旧。新增 `ContactRowPresentationIdentity`，只把 UID、展示名、实际头像 URL、在线/注销状态、角色文字组成展示身份；导航仍使用稳定 UID，不用随机 UUID 重建整页或增加第二份好友库。
- 好友申请成功反馈与本认证轮次等待状态补齐；等待按稳定申请版本/身份判断，昵称或头像变化不能提前解除等待。
- 入群申请展示邀请双方真实身份与群信息；严格解析混合类型页，坏页保留已有列表和通知未读，不把格式错误当空列表成功。
- 已验证二维码结果直接去资料或已加入群，返回后重建相机捕获；仍使用真实 SDK 业务结果。

**实际验证：**B 把 A 备注改为 `QA_FINAL_A_备注🙂`，直接回列表显示新文字与 Q 分区；恢复 `Affff` 后直接回列表显示原文字与 A 分区，两次均无重启，描述 `Ikf` 保留。本地账号查询、字母定位、真实好友查询、复制账号 Toast、空分组创建/更名/删除、已有新朋友及群助手空态也已观察。待处理申请及完整扫码/相册/摄像头链路未全覆盖。

### 4.3 已读协议、计数和手动未读

- xgd 正文 type13 上报使用真实原消息三段 `SID_senderUID_originalClientMID`，不能只发 SID 或猜身份。
- 新增认证范围 SDK 已读观察与 `ChatReadCountLedger` 成员/epoch 账本：历史 `isRead=false` 不自动等于当前未读数成员；只对真实保存成功的已读转换扣数。会话计数保存失败保留待补扣身份，同一 AUTH 离页不丢资格；归零、权威分页与成功全读边界使旧资格失效，等待期间新消息保留。
- 打开会话只清本机手动 `readTag`，不自动调用远端 `conversationReadedStatus` 代替可见正文已读。SDK 对应整会话清零事件没有足够消息边界。
- 手动标记未读出现“已经生效却弹拒绝 Toast”：真实 SDK 成功回调允许 nil，type512 已先更新库，新端误把 nil 当 false。仅 toggleUnread 接受成功回调的 nil/NSNull；明确 false/0、未知非空仍拒绝，其余置顶/免打扰/删除回执不扩大放宽。

**实际验证：**最新双端 Unicode/换行标记独立实收，双方发送条 1/1；B 实际可见阅读后返回列表无该未读。最终包手动标记未读→未读筛选只 A→清除未读→筛选空态，无错误拒绝 Toast，原状态恢复。

**保留限制：**未知初始正数保守保持；进程结束/新 AUTH 依赖 SDK 权威同步；SDK506 无边界整会话清零的继承行为未修改，同账号多端/重连/屏外新消息完整矩阵待验。

### 4.4 撤回重复与删除后复活

- 撤回时 SDK 同时发 type8 控制消息和更新原条，曾形成两个占位。独立 type8 不作为普通气泡显示；只用真实 `backDelServiceMsgID` 找同会话原条并更新 status2，保留原稳定身份、原时间与引用定位；原条不存在时不伪造。
- xgd 采用移除原条后追加控制提示，新端采用原身份占位，显示时间策略有差异，但应只有一个占位。
- 仅为我删除后重启复活：AUTH 首轮 latest 的替换写库覆盖 SDK status0/2。`SDKConversationsDelegate.persist` 写前按同会话 SID、MID 查真实 SDK 缓存，保护已删除/撤回状态，不增加另一套墓碑库。
- 删除操作要求找到真实本机原消息并确认 SDK 持久化成功；必要时 SID 回退。受理后本机缺行或写失败给明确错误，不能只隐藏 UI 宣称成功。

**实际验证：**B 主动新条撤回后两端各一个占位；B 新条仅为我删除→终止→重启 AUTH→会话仍无→搜索无匹配，未删除对照仍在。A 自建 DELETE_2230 已重新仅为我删除，B 保留原条符合单向范围。最终 A 方向主动撤回菜单未打开，不算双方向主动撤回全通过。

### 4.5 搜索、名片、转发、系统事件和群权限

- 全局消息搜索排除删除/撤回原文和非法会话身份；名片点击使用真实卡片 UID 直接打开资料。
- 转发专用编码保留合并作者/原时间，清除跨会话引用，把 @ 类型转成可见普通文本，兼容旧位置类型；回执缓存保留资源、尺寸、贴纸和坐标。异步预检后再读真实原消息状态，避免期间撤回仍被转发。
- 系统事件摘要与旧显示开关、静默标记、定向身份规则共用；刷新型事件不插空白气泡，置顶用独立 revision 回查。
- 群禁言到期只触发真实权限重查，失败保持禁言，取消/换号/乱序结果隔离，不靠本地时钟直接解禁。
- 退出/解散通过现有公开运输接口，服务端受理后才在当前身份与 SDK 锁内清理群/会话/历史；Runtime 带认证上下文关闭设置与聊天，迟到旧账号回执不能清新账号。

**实际验证：**B 多选本轮两条 QA，跨最近/好友保留 A 选中，合并为一条发送；A 独立看到内部两条全文、作者 cs123、原 22:31/23:08 时间，B 发送条 1/1。全局三分类/更多好友、会话置顶/免打扰及恢复已观察。权限变化、逐条转发/部分失败、实际退出/解散等未全验。

### 4.6 文件发送、原名与只读弹层关闭

- 137 字节文件曾显示上传后结束，却没有本机气泡。仅常量阶段诊断确认：云权限通过→STS 成功→嵌套合同→凭据映射拒绝；排除页面取消，不能归为 ACK 缺失。
- 真实 STS 是 `data.credentials` 的 `accessKeyId/accessKeySecret/securityToken/expiration`；供应商前缀是旧端内部模型字段。修正优先映射真实包装，坏包装禁止回退，过期、缺 token、禁止序列化守卫保留；临时凭据仅请求内存。
- 接收端丢失文件名 `qa-`：SDK 会剥掉 wire 名首个连字符前的身份前缀。type5 改用去掉连字符的稳定 localID 前缀加原名，展示仍原名；不使用带连字符的原 UUID 直接作前缀，不猜改历史文件名。
- Mac 合并详情没有可见返回/关闭，手势与 Esc 均不能退出。聊天记录、附件、历史搜索、置顶列表、@选择和位置只读 sheet 补明确“关闭”，沿用原状态和上下文。

**实际验证：**01:00 文件 A 真实发出，B 独立下载、QuickLook 三行正文；仅复制该 QA 缓存文件比对，137 字节逐字节一致，SHA256 `454873e226f0adbeb93a407d4538c7d1e686e3f3ff700fa8414656efb3b87515`。当轮文件名截断与字节链路分开记录。01:12 修正版新文件两端完整 `qa-file-20261015.txt`、A1/1；最终 Mac/真机文件详情完整原名、137 字节、关闭回聊天，Mac 合并详情关闭也通过。其他媒体/供应商、大文件、取消及实际外部分享未全验。

## 5. 最终验证与证据

| 验证 | 昨晚最终结果 | 持久保存的摘要 |
| --- | --- | --- |
| 全量离线入口 | 62/62 exit0，311.43 秒 | [逐脚本结果](HandoffEvidence/2026-10-15/offline-summary.json) |
| 签名 generic iOS build | BUILD SUCCEEDED | [构建/安装摘要](HandoffEvidence/2026-10-15/verification-summary.json) |
| 真机保数据覆盖安装 | success，未清既有数据 | 同上 |
| 受控文件下载 | 137 字节，逐字节和 SHA 一致 | [字节校验结果](HandoffEvidence/2026-10-15/file-byte-verification.json) |
| 逐需求验收 | 116 项，103 项纳入、13 项整体暂缓；完整分支并未全部通过 | [验收台账](CONTACTS_MESSAGES_PARITY_QA_2026-10-14.md) |

昨晚最后测试的 iOS debug dylib SHA256：`5c63ac3e7da68f6a6721779404bab449fd40c5dd44458125b7199f75c19adde3`。这是历史包标识；本次整理发现 DerivedData 中产物摘要已经不同，不能直接把当前构建目录或当前运行 App 当作昨晚包。下次需要安装时重新确认目标、构建与身份。

原始日志：

- `/tmp/ddlNew-parity-final-62-offline/summary.json` 及该目录逐脚本日志。
- `/tmp/ddlNew-parity-final-filename-close-build.log`。
- `/tmp/ddlNew-parity-final-filename-close-install.json`、对应 `.log`。
- `/tmp/ddlNew-parity-evidence/mac-a-qa.md`：Mac 独立操作、旧 xgd 实际 UI 对照、最终文件与关闭验证。

关键截图位于 `/tmp/ddlNew-parity-evidence`，按问题读取：

| 场景 | 文件 |
| --- | --- |
| 公告删除自动返回 | `notice-final-delete-return-list.png` |
| 备注即时修改/恢复 | `contact-final-immediate-remark.png`、`contact-final-immediate-restored.png` |
| 最新双端正文/已读 | `phone-B-epoch-final-received.png`、`phone-B-epoch-final-read1.png`、`mac-a-epoch-final-read1.png`、`mac-a-b2a-epoch-received.png` |
| 新条撤回单占位 | `phone-B-recall-final-single.png`、`mac-a-final-recall-incoming-single.png` |
| 删除后重启与搜索 | `phone-B-delete-persist-before-restart.png`、`phone-B-delete-persist-after-restart.png`、`phone-B-delete-persist-search-empty.png` |
| 草稿重启恢复 | `phone-B-draft-after-restart.png` |
| 合并真实接收/关闭 | `mac-a-merged-forward-received-details.png`、`mac-a-merged-final-close-button.png` |
| 文件下载正文/最终原名 | `phone-B-file-downloaded-preview.png`、`phone-B-file-final-original-name.png`、`phone-B-file-final-name-close.png` |
| 手动未读最终恢复 | `phone-B-manual-unread-final-success.png`、`phone-B-manual-read-final-cleared.png` |
| 仅选一位好友不能建群 | `phone-B-new-group-one-disabled.png` |
| 旧 App 实际对照 | `xgd-mac-` 开头的截图，具体文件见 Mac QA 记录 |

三份安全 JSON 已随本交接持久保存；原始日志、截图仍在 `/tmp`，可能被系统清理。缺失时按源码和验证命令重验，不能将不存在的文件称为新证据。匿名宿主只作本地布局/状态证明。

## 6. 测试账号、数据恢复与工具状态

- 邀请码 1000；A `ceshi001`，真实 UID `2108428960873541633`，昵称 cs123；B `ceshi002`，UID `2108452019483406338`，昵称 test123。密码及任何 Token 不写本文或证据文件；需要认证时通过当前获授权渠道取得。
- 最后新 App 分工：Mac Designed for iPhone 跑 A，iPhone 12 真机跑 B。真机历史工具 ID `00008101-000100820E41001E`，下次先重新发现设备再使用。模拟器/匿名账号不能代替这两端。
- 核对身份用真实添加好友页/个人业务二维码/资料账号；“我的”部分演示资料不能证明当前业务身份。
- 实测群 Qqqqq（ID1025）7 人，B 群主，A 管理员；只验证角色显示、成员直达与移除选择/确认后取消，没有移除既有成员。
- B 对 A 原备注 `Affff`、描述 `Ikf` 已恢复；会话置顶、免打扰、未读筛选与测试草稿已恢复；A 自建空分组 QA1014A→QA1014B→删除已清理。原公告 ID11/7 保留，自建 QA 公告已删。
- 本轮消息标记保留。`QA_RECALL_FINAL_2240 中文🙂` 实际是 23:08 的普通文本，名字带 RECALL 不等于已经撤回；B23:01 新条才是最终主动撤回证据。A22:31 DELETE_2230 仅在 A 删除，B 保留及转发副本符合单向范围。
- 01:00 文件旧显示 `file-20261015.txt`，01:12 新显示完整 `qa-file-20261015.txt`；旧记录不被批量改名，不把旧显示判为新修复失败。
- xgd 源码只读；旧 Mac 实际启动并核对同服务器独有消息/同群，而不只是源码对照。旧 App 已停止，临时 Workspace Per-User DerivedData 已恢复 Default，未改旧共享工程或全局配置。
- 临时 MediaParity/NoticeQA 运行诊断已移除。新聊天重新取得 App/窗口/设备引用，不复用旧 Wrapper、AX ref 或假定旧代理仍持有 UI。

## 7. 源码和测试入口

以下路径相对于仓库根目录，按正在处理的分支读取，不需要先把全部源码重新排查一遍。

| 问题 | 主要入口 |
| --- | --- |
| 公告字段与读写 | `Features/Chat/Models/ChatGroupNoticePayload.swift`、`Features/Chat/Models/ChatGroupNotice.swift`；`Network/IM/Chat/SDKChatNoticesClient.swift` |
| 公告全文/版本/返回 | `Features/Chat/Services/ChatNoticesStore.swift`；`Features/Chat/Views/ChatGroupNoticesView.swift` |
| 成员直达、独立移除、角色徽标 | `Features/Chat/Views/ChatSettingsView.swift`、`Features/Chat/Views/ChatGroupMembersView.swift`、`Features/Chat/Views/ChatGroupRemovalView.swift`；`Features/Chat/Components/ChatGroupMemberRoleBadge.swift`；`Features/Chat/Models/ChatGroupAction.swift` 中的 ChatGroupPolicy |
| 群设置提交与退出 | `Features/Chat/Services/ChatSettingsStore.swift`、`Features/Chat/Services/ChatRuntime.swift`；`Network/IM/Chat/SDKChatSettingsClient.swift` |
| 群人数与顺序 | `Features/Groups/Models/GroupRecord.swift`、`Features/Groups/Services/GroupsStore.swift`；`Network/IM/Chat/SDKChatClient.swift` |
| 备注展示与申请状态 | `Features/Contacts/Models/ContactRowPresentationIdentity.swift`；`Features/Contacts/Views/ContactsView.swift`、`Features/Contacts/Views/ContactRecordDetailView.swift`；`Features/Contacts/Services/ContactsBusinessStore.swift` |
| 备注确认写库/旧回读隔离 | `Network/IM/Contacts/SDKContactsBusinessClient.swift`；`Features/Contacts/Services/ContactProfileRequestGate.swift` |
| 入群申请解析与显示 | `Network/IM/GroupApplications/GroupApplicationPayload.swift`、`Network/IM/GroupApplications/GroupApplicationsPayload.swift`、`Network/IM/GroupApplications/SDKGroupApplicationsClient.swift`；`Features/GroupApplications/` |
| 可见已读与计数 | `Features/Chat/Models/ChatVisibleReadPolicy.swift`、`Features/Chat/Models/ChatReadCountLedger.swift`；`Features/Chat/Services/ChatRuntime.swift`；`Network/IM/Chat/SDKChatClient.swift`、`Network/IM/Chat/SDKChatUnreadObserver.swift` |
| 手动未读与删除持久化 | `Network/IM/Conversations/SDKConversationOperations.swift`、`Network/IM/Conversations/SDKConversationsDelegate.swift` |
| 撤回、系统、权限与禁言到期 | `Network/IM/Chat/SDKChatDelegate.swift`、`Network/IM/Chat/SDKChatMessageMapper.swift`、`Network/IM/Chat/SDKChatClient.swift`；`Features/Chat/Models/ChatMessageRecord.swift`、`Features/Chat/Models/ChatSystemEventVisibility.swift`、`Features/Chat/Models/ChatGroupMuteExpiry.swift`、`Features/Chat/Models/ChatGroupPermissionPayload.swift` |
| 搜索、转发、名片和弹层 | `Network/IM/Search/SDKGlobalSearchClient.swift`；`Network/IM/Chat/SDKChatActionsClient.swift`、`Network/IM/Chat/SDKChatMessageMapper.swift`；`Features/Chat/Views/ChatRoomView.swift` |
| STS 与文件名 | `Network/IM/Chat/Cloud/CloudMediaCredentialPayload.swift`；`Network/IM/Chat/SDKChatClient.swift` 的 `makeModel`；[云传输说明](CHAT_CLOUD_TRANSPORT.md) |
| 扫码与公共反馈 | `Features/Contacts/Views/BusinessQRScannerView.swift`；`Common/Components/MessagingStatusToast.swift`、`Common/Components/MessagingActionButtonStyle.swift`；`Features/Message/Views/MessageView.swift` |

表中生产相对路径均加 `ddlNew/` 前缀。新增/扩展的测试重点：

- `Tests/Chat/`：NoticePayload/NoticesStore、ForwardContract/ForwardFreshness、MessageParity/SDKMessageParity、ReadPermission、ReadCountClient/Epoch/Observer/Operation/Runtime、RuntimeDeparture、SystemVisibility、FileNameContract。
- `Tests/Contacts/RowPresentationChecks.swift` 与 ContactsBusiness；`Tests/GroupApplications/PayloadChecks.swift`。
- `Tests/Conversations/DeletePersistenceChecks.swift`；`Tests/Search/MessageIdentityChecks.swift`。
- `Tests/MigrationAcceptance/TransportAdversarialChecks.swift`：STS 合同，最终 transport108项；`Tests/Chat/FileNameContractChecks.swift`13项、ReadCountOperation16项。
- 登录安全仅修测试等待：固定 `Task.yield` 改为等待可观察退出稳定状态，生产登录链路未因该测试调整。

## 8. 未完成项与下一步优先级

| 优先级 | 工作 | 验收完成条件/当前限制 |
| --- | --- | --- |
| P1 | 新建群人数立即同步 | 用第三个可控身份满足至少两位好友；服务器人数、通讯录、设置同步正确，不重启，不猜数；单选完成禁用已验 |
| P1 | 实际移除与邀请恢复 | 在可恢复测试群真移除/回查成员与人数/对端回流；验证删除发言开关、失败保选、降权与三角色；既有群未执行该写操作 |
| P1 | 群主转让、退出、解散、禁言与设置回流 | 专用群完成服务器受理、缓存和页面关闭、另一端实际结果及角色变化；源码/离线通过不等于已真操作 |
| P1 | 媒体剩余链路 | 真实语音/图片/视频/各已部署供应商、大文件、取消/失败重试、删除后停播/禁止重载；当前仅当前云部署小 txt 有完整收发字节证据 |
| P1 | 已读/同步并发矩阵 | 同账号多端、屏外新到达、前后台、断网重连、冷启动及迟到回执；保留 SDK506 和未知初始计数限制 |
| P2 | 好友/群申请完整业务 | 当前只有已添加历史或空列表，需真实待处理样本；不删除原好友制造申请，逐结果核对申请双方与未读 |
| P2 | 其它业务和交互分支 | 逐条转发/部分失败、名片全关系、完整搜索分页定位、扫码/相册/相机；按116项台账未完成分支推进 |
| P2 | UI 适配与可访问性 | iOS16、最大字号、VoiceOver、iPad/宽窗口与明暗模式完整真机走查；已有匿名局部预览保留证据级别 |

缺少第三身份/测试群时继续媒体、搜索、UI 等独立分支，准确记录条件；不邀请不明第三人或动原群关系来凑人数。下一轮针对实际新发现补最小回归，已通过的分支仅在相关代码改变或证据失效时复验。

原整体暂缓13项继续保留：拉黑、举报、团队；群发、签到、支付、双击未读、推送深链；收藏/链接、翻译、自动删除、发起通话、机器人/活跃等级。子范围：贴纸商城/新游戏、位置发送、新增全读按钮、新发起加密/阅后等暂缓；群禁止通话设置仍在批准范围。完整边界见 [开发范围](CONTACTS_MESSAGE_DEVELOPMENT_SCOPE.md)。

## 9. 复现命令与结束标准

在仓库根执行；以下命令供后续需要改代码或重新验收时使用，本次文档整理没有重跑。

```sh
python3 Tests/MigrationAcceptance/run-all-checks.py --output /tmp/ddlNew-next-session-offline
git diff --check
```

真机签名构建使用 workspace。确认构建所有权后再执行，避免与 Xcode 同时构建同一 DerivedData：

```sh
xcodebuild -workspace ddlNew.xcworkspace -scheme ddlNew -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /Users/taobotaobo/Library/Developer/Xcode/DerivedData/ddlNew-gouvoiamsobqkuevngdfnxdlbzay \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=YES build
```

同一 DerivedData 在 My Mac 与 generic iOS 之间切换会较多重编 WCDB；build.db 被占用先核对在途任务，不把锁库当代码失败。模拟器不能代替真实 LXChatEncrypt/系统配置/登录/服务器链路。

完成一个分支应同时记录实现和相应层级证据：哪些离线脚本、哪一版构建、哪端真实操作、另一端/服务器如何核对、哪些数据恢复、剩余条件。新问题更新逐项台账和本文对应章节；本轮范围内保留工作区，不自动提交或推送。
