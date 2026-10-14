# 本次对话交接：消息、通讯录与群聊 UI / 交互

日期：2026-10-14。用途：在新聊天窗口接着处理 ddlNew，保留本次对话的最终要求、改动和验证边界。

## 新聊天窗口可以直接发送

> 请先完整阅读 `/Users/taobotaobo/Desktop/ddlNew/Docs/PROJECT_HANDOFF.md` 和 `/Users/taobotaobo/Desktop/ddlNew/Docs/SESSION_HANDOFF_2026-10-14_MESSAGES_CONTACTS_UI.md`，然后检查当前分支和 git status。延续本次消息、通讯录、群聊 UI 与交互改动，保持首页和我的主题色，按 xgd 老项目核对。保留工作区已有改动，不自动提交或推送。代码及离线验证已完成；后续优先真机检查备注同步、新建群人数、群成员跳转和 Toast，不把匿名模拟器证据当作真实服务器验收。

## 工作区与阅读顺序

- 新项目：`/Users/taobotaobo/Desktop/ddlNew`。
- 旧项目：`/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk`；本次作为 UI / 交互的只读参考，没有修改旧项目。
- 当前分支：`feature-message-4`；本次收尾时 HEAD：`89cc7a4`，标题 `feat:修改消息和通讯录相关页面的UI和配色`。
- 首轮整体 UI 改动已在该 HEAD 中；后续用户逐项反馈的修正保留在工作区，未提交、未推送。开始新任务时以实时 Git 状态为准。
- 工作区包含用户另行修改的 `ddlNew/Features/Login/Services/LocalCredentialStore.swift`，本次未更改该文件，不要回退或覆盖。
- 新增未跟踪生产文件包括 `MessagingActionButtonStyle.swift`、`MessagingStatusToast.swift`、`ActivityRoute.swift`；交接时本文件也未跟踪。提交时检查新增文件，不能只提交已有文件的 diff。
- 先读项目总交接，再读本文件，最后按需读 [UI 对齐记录](MESSAGING_UI_ALIGNMENT_2026-10-14.md)。旧迁移验收边界见 [迁移交接](CONTACTS_MESSAGE_MIGRATION_HANDOFF_2026-10-13.md) 和 [测试报告](CONTACTS_MESSAGE_TEST_REPORT.md)。早期快照不代表当前完成度。

## 用户最终要求与已实现行为

### 整体风格、适配、导航

1. 消息、通讯录及关联页面的 UI 和交互参考 xgd，使用指定的 `ui-ux-pro-max`；几何适配继续使用已有 UIAdapter，不引入第二套屏幕缩放。
2. 品牌主题色使用首页 / 我的 `HomeTheme.forest`，不使用首轮历史预览中的紫蓝色。主列表使用紧凑标题、浅灰背景、白色分区、名单与分类；深色配色保留。
3. App 主界面默认选中消息；ClubStore 初始化和相关会话重置路径同步修正。
4. TabView 底栏按实际导航路径控制：`.toolbar(navigation.path.isEmpty ? .visible : .hidden, for: .tabBar)`。各 Tab 独立持有路径。消息 / 通讯录进入聊天以及首页签到入口接入实际 path；移除重复固定隐藏的 ClubDetailChrome。
5. 原本因 frame 与系统按钮内边距叠加而过高的操作按钮统一使用 `MessagingActionButtonStyle`，默认最小高度48pt，大辅助字号自然增高。保留表单保存按钮的启用 / 禁用背景与文字色。
6. 导航栏内的保存使用紧凑文字按钮和至少44pt触点，启用森林绿、禁用次要文字色；避免将底部48pt全宽按钮样式放进导航栏。群名称和公告编辑已修正。

### 通讯录、分组、好友资料

1. SDK 默认分组原始 name 为空时，通过 `FriendBusinessGroup.displayName` 显示“默认分组”；列表、管理、移动、选人和编辑初值统一复用。真实 ID、排序值和默认组不可删除规则保留。
2. 群列表按稳定 ID 保留原有位置，刷新资料和反复进入 / 返回不会把点击的群移到末尾；真正消失的群移除，新群追加。
3. 创建群聊的分组标签与“选择本组好友”之间移除原生 Section 的多余留白；全选 / 取消、预选和数量校验保留。
4. 资料页备注与箭头之间收紧为6.zoom；描述行增加箭头，备注与描述均进入同一编辑页。
5. 资料底部删除“账号已复制”“操作完成”等操作结果文案。复制账号仍写系统剪贴板，并使用居中“账号已复制”短 Toast，避免顶部不可见。
6. 备注保存、移动分组、添加 / 重命名分组、分组管理加载改成 Toast；页面不再插入操作进度和成功结果行。弹出名称编辑 sheet 时，父页面暂停 Toast，防止反馈被遮住或重复显示。
7. 添加分组保存按钮始终存在；空白 / 纯空白、未修改、正在提交时禁用，有效名称后启用。颜色、48pt高度与“备注与描述”保存共用样式。
8. 分组前移、后移和拖动统一使用 `moveGroup(id:toIndex:)`，向服务器提交目标组真实 `ugOrder`，不再把排序值简单加减1；边界或原位不提交。
9. 添加好友页不保留历史用户搜索结果。进入 / 离开清空搜索并撤销旧轮次；迟到请求不能恢复旧用户。精确搜索确认用户不存在时显示空态，不显示“用户不存在！”；网络 / 格式异常仍可 Toast。
10. 新朋友页加载及提交用 Toast，整行资料入口的箭头在 cell 最右侧。按用户最后对此页面的具体要求，不显示全局业务结果行，也不弹这类成功 / 错误状态 Toast；保留“等待验证”“已添加”等申请记录本身的状态和按钮。

### 备注同步修复：不能只靠返回时重新读取

用户两次反馈保存后通讯录仍旧值，已分别补齐等待回读和根因修正。

- `ContactRemarkEditor` 等待真实保存成功及 ContactsStore 缓存刷新后，再更新资料关系和关闭页面。保存前已经在读缓存时，显式刷新会追加新一轮读取，避免复用旧快照。
- `SDKContactsBusinessClient.persistSavedRemark` 在服务器保存确认后，在当前身份校验及 SDK 共用锁内更新真实好友模型的 `remarks / descRemark / remarksPinyin / showName`；`toolUpdateMyFriend` 继续触发原有好友 / 分组代理。
- `ContactProfileRequestGate` 撤销保存前 profile 读取的写入资格；返回确认后的缓存资料。
- `ContactsBusinessStore` 使用该确认快照，不立即请求可能仍返回旧值的 profile，不让旧回读覆盖刚保存的备注。UID / 邀请码 / 会话轮次隔离、失败保留草稿、失败不修改资料继续保留。
- 已有失败回归证明“保存返回新资料，紧接着 profile 返回旧资料”的覆盖路径已修复；真机实际服务器结果仍需核对。

### 二维码与扫一扫

1. 我的二维码、群二维码均删除右上角三个点。底部保存相册和聊天分享保留；不会从右上角打开系统分享。
2. 底部按钮默认48pt，生成二维码 / 保存过程改为居中 loading Toast；保存结果用“已保存到相册” Toast，不在二维码下方加业务文案。
3. 扫一扫直接进入当前导航页的相机取景，不再先显示“打开摄像头扫码 / 从相册选择 / 粘贴二维码内容”的表单。相册选择保留在取景页底部。
4. 识别 / 业务失败只用 Toast，删除页面内业务错误及“重新扫描”按钮。解析失败 Toast 结束后自动恢复捕获；相机权限或设备错误不反复重启。
5. 扫码仍走真实 SDK 解析和原有用户 / 群流程；退出销毁捕获会话，没有改后端协议。

### 群人数、群设置与成员导航

1. 新建群人数不再被后续0缓存覆盖。`GroupsStore.create` 先接收已确认真实群记录，再回读；`GroupRecord.preservingKnownMemberCount` 和 reload 合并保留已有正数，后续真实正数更新可覆盖。真正消失的群仍移除。
2. `SDKChatClient.updateGroupCache` 读取群详情真实 `memberCount`，写入 SDK 群表；人数实际变化且写库成功时发 `cimToolGroupUpdate`，让通讯录立即重读。SDK 单纯写群表本身不发代理，过去因此要重启后同步才正确。
3. 同人数不重复发代理，避免“群代理 → 权限刷新 → 写库 → 群代理”回查循环；不使用所选好友数加1来伪造服务端人数。创建及详情均缺人数时，仍要等待真实同步。
4. 群设置预览成员和“查看群成员”统一先进入成员列表，对齐 xgd；同步未就绪和普通成员私聊限制继续按真实权限阻断。
5. 成员列表再进入用户资料，保留来源 groupID、角色 / 注销限制；机器人 role3 没有资料跳转，自己可按权限查看。资料沿当前栈直接 push，避免在布尔目标页面内再写 ContactsRoute 值路径造成父页面重排。
6. 成员整行使用 NavigationLink，系统箭头在管理菜单之后的最右侧；“管理”独立点击，不误跳资料。移除成员 sheet 和其它群操作确认对话框不再相互清除状态；移除过程 / 失败 Toast 在 sheet 中显示。
7. 群设置“查找聊天记录”右侧放大镜已移除。
8. 修改群名称右上保存样式及禁用状态修复；提交用 Toast，失败保留输入。群昵称 / 公告编辑保持同类行为。
9. 群设置、群管理、群成员、群头像、群公告列表 / 详情 / 编辑、邀请选人、群二维码、入群审核及相关记录查询的操作 loading 统一 Toast，取消上传等真实操作仍保留。

### 业务反馈统一规则

- 新增 `Common/Components/MessagingStatusToast.swift` 统一 loading 和短反馈；复用现有 AlertToast，不加入新的提示依赖。
- 浅色 Toast：低饱和灰绿 `#E1E9E3`；深色：`#2F3C34`；文字使用 HomeTheme.text，与页面白底可区分。此前白色及反转深绿配色为历史方案，不能恢复。
- loading 直接观察真实请求状态，duration0、不可点击关闭，不通过关闭 Toast 假装取消请求。
- 反馈只响应本次新增结果，3秒关闭；默认不重播 Store 遗留文案。浮层独立定时器，重复结果不会重建页面 / 输入状态。安全退出原因及图片验证码初始失败按需呈现初始提示。
- 通讯录、消息操作、群相关页面、记录 / 媒体 / 转发 / 表情、注册 / 改密 / 邀请码 / 注销等已有操作结果从页面正文移到 Toast。新朋友页遵循上述单独要求；分组管理不显示普通成功文案。
- 聊天发送失败保留失败图标和重试入口；去掉气泡下面的业务错误正文，本轮实时失败事件进入 ChatStore.errorMessage，由聊天页 Toast 显示。历史失败缓存和成功 ACK 后的迟到失败不会重播错误。新发送 / 重试清空旧错误，允许同类失败再次反馈。
- 群公告、消息正文、输入限制、申请状态、权限 / 连接状态、图片占位、消息发送中图标、空态、重试入口和删除前确认属于页面内容或交互，按职责保留。
- 网页验证码才显示异步加载 Toast，图片验证码 / 安全码输入不会被常驻 loading 遮住；验证码失败仍可取消或重试，不修改认证协议。

## 本轮验证证据

生产编译：无签名真机目标 `BUILD SUCCEEDED`，最终日志 `/tmp/ddlNew-final-ui-handoff-build.log`。这是编译验证，没有安装到用户真机。

本次收尾实际执行：

| 命令 | 结果 |
| --- | --- |
| `bash Tests/Groups/run-checks.sh` | 群稳定顺序、人数创建 /0缓存 /后续正数 /删除及会话隔离通过 |
| `bash Tests/Chat/run-group-checks.sh` | 14项群策略检查通过 |
| `bash Tests/Chat/run-settings-checks.sh` | 7项设置检查通过 |
| `bash Tests/Chat/run-member-page-checks.sh` | 9项真实成员分页检查通过 |
| `bash Tests/Contacts/run-business-checks.sh` | 搜索清理、用户不存在空态、备注确认不被旧值覆盖、默认分组及排序通过 |
| `bash Tests/Contacts/run-checks.sh` | 通讯录44项、SDK分页19项、字段 / 部分资料25项通过 |
| `bash Tests/Chat/run-checks.sh` | 33项通过，新增实时失败Toast文案及迟到失败不提示检查 |
| `bash Tests/LoginSecurity/run-checks.sh` | 69项通过 |
| `git diff --check` | 通过 |

群人数先有失败断言“建群成功后列表人数显示0，创建回执为3”，修正后通过。历史测试日志中的32项 Chat 为新增反馈断言之前的快照。

最终生产构建命令：

```sh
xcodebuild -workspace ddlNew.xcworkspace -scheme ddlNew -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /Users/taobotaobo/Library/Developer/Xcode/DerivedData/ddlNew-gouvoiamsobqkuevngdfnxdlbzay \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
```

匿名 UI 宿主：`/tmp/ddlNew-legacy-ui-preview`，运行实际 UIAdapter、AlertToast 与生产视图；数据、SDK和图片下载为匿名夹具。群名称编辑从生产 ChatSettingsView 提取同一结构编译，群成员预览 / 列表 / 资料为生产视图，设置入口外壳为夹具。宿主脚本及 /tmp 日志可能被系统清理，不属于生产依赖。

此前本次对话的匿名检查已覆盖：主题明暗、窄屏 / 大字号 / iPad局部布局、分类 / 未读 / 返回、键盘草稿、默认组、选人全选 / 取消、复制 Toast、添加分组禁用 / 启用、扫码业务失败、二维码相册保存、初始消息 Tab 和底栏 push / 返回。

最后收尾已核对：群成员预览进入列表，成员箭头最右侧，管理菜单独立，资料进入后返回列表；群名称保存禁用 / 启用、加载Toast、失败Toast自动消失且输入保留。移除成员弹窗的状态隔离同时修正，匿名提交实际显示sheet内loading与失败Toast。

截图目录：`/Users/taobotaobo/.codex/visualizations/2026/10/14/01a137f7-e88d-7cf2-abed-77fbe6ac0645/ddlNew-legacy-ui/`。

- `group-members-right-arrow.png`：成员最右侧箭头。
- `group-remove-loading-toast.png` / `group-remove-error-toast.png`：移除sheet内加载及模拟失败Toast。
- `group-member-profile-navigation.png`：成员列表进入生产资料页，夹具没有该成员真实资料，空态不代表服务端失败。
- `group-name-loading-toast.png` / `group-name-error-toast.png` / `group-name-draft-retained.png`：加载、模拟失败及自动消失后保留草稿。
- `group-save-matching-disabled.png` / `group-save-matching-enabled.png`：分组保存状态。
- `qr-save-toast-success.png` / `scanner-failure-toast.png`：匿名二维码实际写模拟器相册、模拟业务失败Toast。
- `tabbar-default-messages.png` / `qr-buttons-48pt.png` / `qr-buttons-large-type.png`：初始Tab和按钮尺寸。

现有 SDK / ObjectMapper / 系统API弃用警告仍有；本次没有升级依赖或清理全部历史警告。

## 真机待验收：不能用构建或夹具替代

本次对话要求的代码改动已完成。以下为真实性验收边界，尚未对用户当前真机和服务器重新执行完整验收：

1. 当前账号保存备注与描述，退出资料回通讯录，不重启即显示新值；分组标签和搜索排序同步。网络失败 / 切换账号时不得覆盖新会话。
2. 真实创建群后返回通讯录，人数与服务器一致，不重启也更新；后续加人 / 减人刷新人数，不误改列表位置。
3. 群设置预览 → 群成员 → 用户资料 → 返回；本人 / 普通成员 / 管理员 / 群主 / 机器人及群私聊限制分别验证；管理菜单不触发资料路由。
4. 群名称 / 群头像 / 群管理 / 公告 / 入群审核的真实成功与失败反馈只有当前页面或 sheet 的 Toast；请求结束消失，失败保留输入，重复同类错误仍可提示。
5. 我的 / 群二维码没有右上角更多菜单；真实相册授权 / 保存、相机识别 / 相册识别、失败后自动继续捕获分别验收。
6. iOS16完整导航、最大辅助字号、VoiceOver和真实弱网恢复仍需走查。已测匿名 iOS26.5 宿主不等价于这些结果。

后续只针对新发现问题继续修正，不重做已经通过的整轮 UI。保持 SDK 为真实数据源、会话身份隔离、服务器确认后更新、不编造接口或人数；未经用户要求不要提交 / 推送，也不要修改线上配置。
