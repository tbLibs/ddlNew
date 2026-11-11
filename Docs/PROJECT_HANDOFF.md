# ddlNew 项目交接文档

## 2026-11-11 聊天滚动时导航与状态栏配色

用户录屏显示约4.6秒起白色背景保留，聊天标题、时间及电量变浅看不清，返回和更多按钮仍在。ChatRoomView原先只声明动态导航背景及可见性，现读取页面colorScheme并显式设置toolbarColorScheme，使导航标题和状态栏按页面浅深色配对，避免依赖滚动时系统自动推断。只调整聊天页，不改变历史分页、消息、输入或共享导航。

完整workspace generic iOS Debug无签名构建exit0／BUILD SUCCEEDED（`/tmp/ddlNew-chat-navigation-color-build.log`），git diff --check通过。临时匿名iOS26.5模拟器宿主提取生产导航背景／配色修饰器和MessagingTheme，程序滚动至第60条后浅深色截图均清晰（`/tmp/ddlNew-chat-navigation-preview/`）；去掉新增配色设置的对照宿主也未复现用户白字现象，因此只作为修改后的展示检查，不能证明真机根因或修复验收。仍需用户重新Run按录屏连续上翻复验。未安装真机、未操作真实消息、未提交推送；保留同期最近表情改动。

## 2026-11-11 最近使用表情按账号持久保存

ChatEmojiPanel此前只用面板内@State保存最近使用，面板关闭销毁后再次创建会恢复为空。新增ChatRecentEmojiHistory，通过UserDefaults按租户和用户UID保存目录中的稳定token；不以会话ID或登录sessionID分隔，同账号跨聊天和重启可恢复，账号／租户互不混用。维持最近7个；按用户后续要求，仅从“全部表情”选择时更新记录并移到最前，点击“最近使用”（包括无记录时的默认7项）只插入、不重排或改写历史。读取过滤失效或重复token；只保存ID，不保存图片或消息内容。

面板出现及身份改变时加载历史，从全部表情成功插入输入框后立即记录。超出1000字符而被拒绝的插入不改变最近使用；无历史仍沿用原默认7项展示。不改贴纸收藏接口、SDK、发送或草稿业务，无新增文案。

Tests/Chat/RecentEmoji包含生产存储的排序／去重／容量／账号租户隔离／损坏记录检查，以及直接编译生产面板的匿名原生UI宿主。旧实现在测试App重启后最近项消失（`/tmp/ddlNew-recent-emoji-baseline.xcresult`）；修复后关闭重建面板及终止重启App均恢复，iPhone17 Pro Max／iOS26.5测试通过（`/tmp/ddlNew-recent-emoji-verified.xcresult`）。初版宿主按钮随面板收起跳动导致开关步骤失败，固定测试入口后复验；不将该宿主问题当生产根因。存储回归及既有表情目录／光标检查通过，完整workspace generic iOS Debug无签名构建exit0／BUILD SUCCEEDED（`/tmp/ddlNew-recent-emoji-build.log`），git diff --check通过。未安装真机、未发送真实消息、未读取首页代码、未提交推送。

后续“点击最近使用不重排”调整：存储回归及git diff --check通过，完整workspace无签名构建exit0／BUILD SUCCEEDED（`/tmp/ddlNew-recent-emoji-order-build.log`）；本次未重跑原生UI测试。

## 2026-11-11 用户资料页关闭横向回弹

用户确认问题发生在保存后的用户资料整页：iPhone 16 Pro Max、iOS 26，填写长备注／描述后横向拖动会松手回弹；iPhone 12未出现。按用户要求保留SwiftUI横向basedOnSize策略，同时显式关闭资料页原生UIScrollView.bouncesHorizontally（iOS17.4起）。ContactRecordDetailView内容内的局部UIViewRepresentable寻找所属滚动容器，在布局及SwiftUI更新后应用开关，离开时恢复原值；不改纵向回弹、共享MessagingScroll或导航手势代理。

新增Tests/Contacts/ProfileLayout匿名原生宿主，提取生产完整资料内容、detail行及两个局部滚动辅助类型，编译生产滚动／卡片／按钮样式和真实UIAdapter缩放。覆盖6种宽度输入、空备注／50字中文备注／50个连续英文字母备注，以及短描述／200字中文／200个连续英文字母／200 UTF-16单元表情，共72组。检查视口和内容宽度（容差0.01点）、长描述换行增高及原生横向关闭／纵向开启。UI拖动检查记录contentOffset.x，满备注加满描述横向拖动保持0。

iPhone 17 Pro Max模拟器／iOS26.5中，改动前满备注及描述未出现padding撑宽（`/tmp/ddlNew-profile-remark-full.xcresult`）；仅加SwiftUI策略仍未关闭原生bouncesHorizontally，对应断言失败（`/tmp/ddlNew-profile-bounce-fixed.xcresult`）。加入局部原生开关后最终两项测试通过（`/tmp/ddlNew-profile-native-fixed.xcresult`）。这些验证了宽度约束和原生开关，不代表已复现或验收用户iPhone16 Pro Max的实际回弹问题；未安装真机。完整workspace generic iOS Debug无签名构建exit0／BUILD SUCCEEDED（`/tmp/ddlNew-profile-horizontal-workspace-build.log`），git diff --check通过。未读取首页源码、未改真实资料或xgd，保留既有聊天焦点及消息标题修改，未提交推送。

## 2026-11-11 连续长按菜单每次同步清焦点与单聊标题限行

用户真机反馈首次长按清焦点，取消后重新输入、第二次长按只隐藏键盘，焦点仍保留。前轮匿名宿主通过并不代表完整页面／真机已解决，且第二次菜单仍打开时缺少焦点断言。本轮补充连续四轮取消测试，同时观察composerFocused和生产UITextView.isFirstResponder。

最终方案移除ChatMessageLongPressDismissal及消息行上的0.1秒窗口手势监听。ChatRoomView改为订阅keyboardWillHideNotification：每次键盘开始隐藏且composerFocused为true时，同步置false并主动resignFirstResponder，不依赖系统菜单内容是否重新触发onAppear。原菜单onAppear作为补充；复制／取消保持失焦，主动点击输入框和引用回复仍能重新编辑，草稿保留。不改菜单权限或业务动作。MessageView的单聊昵称／备注与群聊一样限制一行、尾部省略，保留完整数据及VoiceOver文案。

Tests/Chat/ContextMenuFocus直接提取生产键盘通知处理和contextMenu，编译生产输入器。临时对照宿主只移除键盘通知处理，保留菜单onAppear，第二次菜单仍显示时composerFocused及isFirstResponder均未清除，两项断言失败（`/tmp/ddlNew-focus-menu-only.xcresult`）。保留通知处理后，连续四轮取消测试通过（`/tmp/ddlNew-focus-keyboard.xcresult`），每轮在菜单期间检查两层焦点，关闭后检查键盘不恢复、草稿保留及下一轮可重新编辑。探索用滚动夹具曾在第二次点击输入框阶段失败，症状不同，未把该失败作为根因证据；最终测试仍是匿名组件交互，并非完整ChatRoomView或真机验收。

最终匿名原生回归3/3通过（`/tmp/ddlNew-focus-keyboard-final.xcresult`），包含上述连续四轮取消、复制后保持失焦、引用回复重新输入。既有输入焦点绑定回归及git diff --check通过。完整workspace generic iOS Debug无签名构建exit0／BUILD SUCCEEDED（`/tmp/ddlNew-focus-keyboard-build.log`）。未读取首页源码，未操作真实消息或安装真机，未提交推送。

## 2026-11-11 上传成功后清理临时备份目录

用户提供Ad Hoc导出和上传成功日志，并要求不保留服务器`.upload-<UUID>`目录。upload-adhoc.sh现保留发布过程中的暂存／回退备份，只有正式IPA与清单SHA-256复验均成功后，删除本轮两个previous文件并rmdir本轮目录；成功日志改为“上传临时目录已清理”。失败仍保留现场，不清理其他上传任务的目录；未改IPA或清单的正式路径。

已通过SSH确认用户指定`.upload-bd95a3f8-4d5e-48ad-8cbf-f860c6f50394`只含旧IPA／清单备份，在发布锁保护下删除这两个文件及空目录；删除前后正式IPA与manifest的SHA-256相同。没有重新上传、重新打包或修改下载页面。上传离线检查5/5通过（成功清理、首次发布、清单替换失败回退、传输失败、摘要失败），Bash语法与diff空白检查通过。打包离线回归8/8通过；保留其他功能改动，未提交推送。

## 2026-11-11 好友头像昵称自动刷新与消息列表订阅

用户反馈通讯录和消息列表在好友改头像／昵称后不更新，进入详情后才更新。核对xgd：通讯录通过cimToolUserFriendChange消费SDK好友表更新；聊天页requestUserInfo调用getUserInfo，再更新已有好友并广播。当前源码未发现向所有好友分发独立头像／昵称变更事件的处理链路，不声称具备服务端即时推送能力。新项目ContactsStore已有好友变化订阅，但列表reload只读缓存；SDKConversationsClient仅订阅会话代理，好友表单独变更不会刷新消息列表。新增生产观察注册回归在修复前失败，输出“好友头像昵称已落库，但消息列表没有收到刷新事件”。

SDKConversationsClient现同时注册SDKContactsDelegate，在好友变化、联系人同步完成／失败后重读会话展示字段；退出解除两个代理，generation拒绝排队及旧身份事件。通讯录／消息列表的普通好友可见行新增VisibleContactProfileRefresh，只有前台且AUTH有效才调ContactsStore.refreshVisibleProfile。两处共享每好友30秒间隔、最多4个并发、同UID请求合并及失败退避，离开页面／后台后停止轮询；已经发出的读取最多按既有20秒等待超时结束。这是可见行周期更新，不是保证毫秒级服务端推送；不轮询全量通讯录、不恢复配置接口。

SDKContactsClient通过旧端相同getUserInfo接口读取对方UID，在SDK共用锁与账号／租户／观察轮次／资料版本门内，仅合并已有好友的昵称、拼音、头像和注销状态；不覆盖用户自己的备注、分组、权限或好友关系，不创建缺失好友，未变化不写库广播。静默请求使用beginIfIdle，不抢占详情或备注操作，后来的显式请求可使旧静默响应失效。失败保留旧列表，不反复弹Toast。

生产观察注册、可见资料刷新限流／去重／失败退避／切账号，以及生产SDK请求方法的字段合并／备注保护／旧响应／好友删除／退出检查通过，入口Tests/Contacts/ProfileRefresh。原通讯录44项、SDK分页19项、响应字段、好友行11项与7组业务竞态检查通过；会话排序／Store／操作／预览及在线状态11项回归通过。最终完整workspace generic iOS Debug无签名构建exit0／BUILD SUCCEEDED（`/tmp/ddlNew-friend-profile-final-build.log`），git diff --check通过。未操作真实好友资料或安装真机，未读取首页源码、未修改xgd，保留签到／头像／等待音既有修改，未提交推送。

## 2026-11-11 音视频等待音循环对齐 xgd

核对 xgd 的 NoaIMMessageRemindTool，通话默认使用系统音1004，并在声音播放完成后继续循环；新项目原本同样使用1004，但固定每3秒触发一次。本轮 CallSystemResources 改为 AudioServicesPlaySystemSoundWithCompletion 完成后循环，适用于共用该资源的语音／视频呼叫。每轮等待音持有独立UUID，停止、释放或新通话替换后旧完成回调不再续播；保留现有来电震动节奏、屏幕常亮所有权及通话接通／结束的清理入口。系统正在播放的单次短音自然结束，停止后不再循环；没有新增音频文件或改动RTC／信令边界。

生产资源所有权检查与新增循环／停止后排队回调／替换通话回调隔离检查通过，56项通话协调器生命周期回归通过。完整workspace generic iOS Debug无签名构建exit0／BUILD SUCCEEDED（`/tmp/ddlNew-call-ringtone-build.log`），git diff --check通过。未拨打真实电话或真机试听，未读取首页源码、未修改xgd、未提交推送，保留已有签到和头像修改。

## 2026-11-11 设置账户卡片显示真实头像

设置页原账户卡片固定展示person.crop.circle，未传入登录用户头像。SettingsScreen现观察UserSessionStore与文件节点，沿用我的页RemoteAvatarURL、NetworkImageDownloader、LegacyRemoteImageProcessor及Kingfisher降采样，将头像视图传给SettingsPageContent。保持56尺寸／18圆角；无头像、加载中或失败保留默认人物占位。账号切换、资料头像或文件节点变化随观察源更新；未改退出／注销等业务动作。

完整workspace generic iOS Debug无签名构建exit0／BUILD SUCCEEDED（`/tmp/ddlNew-settings-avatar-build.log`），git diff --check通过。未读取首页源码、未修改用户头像、未安装手机或验收真实图片下载，保留签到相关既有修改，未提交推送。

## 2026-11-11 日历今天与已签到标识

按用户要求，DailySignInCalendar对本地当前年月日显示强调描边、“今天”文字及加粗日期；服务端月签到记录对应日期显示浅色背景和勾选图标，今日已签时同时保留两种状态。增加已签到图例和独立无障碍状态，不只依赖颜色。今天按完整年月匹配并每分钟更新，查看历史月份不误标同日号；星期标题改为负数ID，与日期格ID分开，避免首周日期复用。新文案“今天”通过xcstrings提供简繁英。

匿名原生生产视图测试2/2通过：今日未签、今日已签组合、首周日期存在、切换历史月仅保留记录中的签到标识（`/tmp/ddlNew-signin-calendar.xcresult`），截图附件已核验。三语目录各1668键审计通过；完整workspace generic iOS Debug无签名构建exit0／BUILD SUCCEEDED（`/tmp/ddlNew-signin-calendar-build.log`），git diff --check通过。未读取首页源码、未执行真实签到或覆盖安装手机，保留前轮push／规则／日期修改，未提交推送。

## 2026-11-10 每日签到push、日期与规则对齐

用户依次要求修复签到记录／积分明细点击日期只向前翻月、显示当前日期、规则使用xgd文案、每日签到改为push。两个明细页共用的DailySignInMonthSelector处于List行内，automatic按钮样式让同一行多个按钮一起响应，先发出的上月刷新占据busy，导致右箭头也不能返回本月。原生宿主两个用例均复现失败；改为borderless独立按钮后左右方向回归2/2通过，当前月仍禁止查看未来月份，日期文字不再误触翻月。

签到概览新增当前本地日期／星期，使用系统日期格式和应用locale，每分钟更新；与日历查询月份分开。随机规则完整三条、连签规则完整五条、奖励表“当月连续签到成功天数／奖励积分”直接对齐xgd，并复用旧端三语译文存入xcstrings，填入真实配置金额；不再展示简写条款或追加服务端自定义规则文本。开关关闭时仍保留并展示已有模式／奖励配置，真实签到继续由写接口判定开放状态。

我的每日签到和消息签到助手入口由sheet改为所属导航栈navigationDestination，移除签到内部嵌套NavigationStack及关闭按钮。目的地持有共享Store，真正pop到入口时才close，push记录／积分／规则或从助手进入签到不会关闭Store；AUTH失效仍清理并退出。未读取首页／活动源码、未改首页导航或xgd，既有其他sheet保持。

验证：33项模型／Store、14项SDK适配器回归通过；三语目录各1667键和4项权限说明完整性／占位符／编译运行时检查通过。完整workspace generic iOS Debug无签名构建BUILD SUCCEEDED（`/tmp/ddlNew-sign-in-navigation-build.log`）。月份点击旧版失败报告`/tmp/ddlNew-month-navigation-red.xcresult`，修复2/2通过报告`/tmp/ddlNew-month-navigation-green.xcresult`。匿名原生页面宿主直接编译生产视图与Store，测试不访问真实账号或签到服务，入口见`Tests/DailySignIn/MonthNavigation/README.md`。

原生页面3项分别通过：随机规则与助手push／连签规则见`/tmp/ddlNew-signin-pages.xcresult`；日期与push／记录积分返回／重新进入见`/tmp/ddlNew-signin-push-verified.xcresult`。首轮日期断言忽略LabeledContent的无障碍合并标题而失败，调整为校验完整日期后单独复跑通过，生产代码未为测试修改。截图已检查当前日期、完整规则及奖励表。未覆盖安装手机、未执行真实签到、未提交推送；git diff --check通过。

## 2026-11-10 每日签到积分区间与未开启提示修复

用户打开我的→每日签到出现“签到数据无效，请重试”。真机Xcode临时条件断点捕获生产DailySignInInfo.parse→SignInPayload.integer输入为字符串`100-200`：服务端随机模式的loyalty是今日可领积分展示区间，旧端CandyTalkSignInViewController使用`%@`直接展示，新端误作Int64。已将todayPoints改为展示字符串，保留服务端区间和数字文本；累计积分、天数、记录和真实奖励仍按原整数校验。离线回归先复现相同中文错误，再修复通过；没有把空数据或坏累计值统一当成0。

用户补充xgd点击签到提示“系统未开启签到功能”，要求按该逻辑。核对旧端atOnceSignAction，未签时调用真实签到接口、失败由HUD展示服务端原因。新端移除规则快照对签到按钮的禁用，仍检查当前身份、加载状态和今日已签；点击由写接口决定开放状态，失败原文以Toast展示，保留未签到状态并可再次点击。feedbackRevision确保重复同文案再次提示，失败不写acceptedDay、不伪造积分入账。规则页仍能展示已关闭状态。

验证：31项模型／Store与14项生产SDK适配器检查通过，覆盖真实区间、固定积分、空值／布尔拒绝、累计值严格校验、服务端未开启失败、重复Toast、旧AUTH和取消。完整workspace generic iOS Debug无签名构建exit0、BUILD SUCCEEDED（`/tmp/ddlNew-sign-in-range-verified-build.log`）。现场仅观察读取，没有执行真实签到；本次两个临时断点已删除并确认Xcode仅保留原有Objective-C异常断点，App恢复Running。尚未安装修复包做真机验收，未读取首页源码、未修改xgd、未提交推送。

检查中发现用户Xcode保存目录后已升级为xcstrings 1.1并自动补充纯格式／数字／示例域名及Bundle名称条目。资源审计兼容1.0／1.1，这些无需翻译的条目标记shouldTranslate=false；原1662条三语文案和4项权限说明完整性、占位符及编译产物回归通过，后续维护继续使用xcstrings。目录调整后的终版完整无签名构建同样exit0／BUILD SUCCEEDED（`/tmp/ddlNew-sign-in-final-build.log`），最终App译文逐条比对通过。

## 2026-11-10 多语言迁移至 String Catalog

按用户要求，将应用自有三语资源从六份 `.lproj/*.strings` 合并为 `Resources/Localization/Localizable.xcstrings`（1662键）和 `InfoPlist.xcstrings`（4项权限说明），源语言zh-Hans，保留zh-Hans／zh-Hant／en全部键值，包括1000字符上限Toast。逐条比对迁移前快照完全一致。现有L10n／AppLanguageStore与调用方无需改动；Xcode编译目录生成运行时lproj表，保持应用内语言切换、系统语言映射及英文回退。启动画面仍采用此前固定简体中文资源。

目录条目使用manual提取状态与generatesSymbol=false。首次完整构建发现“聊天记录”和“[聊天记录]”等键自动生成同名Swift符号；已关闭条目符号生成，保留动态L10n查询与全部原键。资源审计已改读xcstrings，校验重复键、三语完整性、占位符、翻译状态和符号设置；源码扫描明确跳过Home／Activities／Club，不从部分扫描判定过期键。运行时回归编译真实目录，逐条核对三语产物，并通过生产L10n检查语言切换、英文回退、插值与缺键回退。维护说明见 `Docs/Localization/README.md`。

验证：目录编译／符号检查、三语资源审计和生产L10n运行时回归通过；完整workspace generic iOS Debug无签名构建exit0、BUILD SUCCEEDED（`/tmp/ddlNew-xcstrings-verified-build.log`），最终App产物三语共4998条译文与目录逐条一致。git diff --check通过。未读取首页源码，未安装真机或进行页面交互验收，未提交推送；保留输入限制及其他已有修改。

## 2026-11-10 聊天输入正文限制1000字符

用户将上一轮1500上限调整为1000，并明确要求输入／粘贴超限Toast提示。`ChatInputLimit`统一按可见字素计数：中文／字母／Unicode组合emoji各1，已识别的内置表情完整标记算1，换行计1；UTF16仍用于UIKit光标和成员片段范围。键盘／粘贴在选区替换时只裁剪新插入内容，保留光标两侧原稿；不拆emoji或内置表情标记。中文输入法markedText期间不裁剪、不发布临时拼音，提交后限制并同步富文本／光标。键盘和粘贴超限通过onLimitExceeded回调统一调用ChatStore.reportInputLimit；Toast使用inputLimitRevision事件计数，相同文案的再次超限仍触发，不因message未变而漏提示。普通删除／未超限输入／未提交拼音不弹超限Toast。

表情面板与两种@成员插入路径超限时拒绝整次插入，并以三语提示“最多可输入1000个字符”，不创建半截成员片段。旧草稿恢复限制正文并核对提及；发送前独立兜底拒绝超限输入，保留草稿，1000整允许发送。收到的消息及历史正文不受此输入限制，保留前轮平衡拼接防栈溢出修复。

当前1000版验证：纯模型长度／选区／组合字素检查、ChatStore发送及成员上限回归、原焦点检查通过。原生UIKit测试3/3、0跳过、TEST SUCCEEDED（`/tmp/ddlNew-input-limit-1000.xcresult`），覆盖999内置表情附件到1000上限、粘贴中间插入／选区替换、重复超限通知、组合期间不通知／提交后通知和删除不通知。三语资源plutil通过。完整workspace generic iOS Debug无签名构建exit0、BUILD SUCCEEDED（`/tmp/ddlNew-input-limit-1000-build.log`），git diff --check通过。1500阶段工作保留并按新要求调整；未提交推送、未覆盖安装手机、未发送真实消息、未读取首页源码。

## 2026-11-10 大量内联表情导致正文渲染栈溢出

用户在群里发送上千表情后闪退。Xcode真机现场为主线程EXC_BAD_ACCESS(code2)，栈深2154层；栈顶`___chkstk_darwin`，重复`Text.resolve / ConcatenatedTextStorage.resolve / Text.Storage.resolve`。`ChatMessageBubble`的正文通过`ChatEmojiText`渲染，旧实现`runs.reduce(Text(""))`逐个用`+`拼接，N个片段形成N层嵌套。这是已捕获的正文渲染栈溢出，不据此推断独立GIF／贴纸下载、发送队列或堆内存问题。

`ChatEmojiText.rendered`改为先生成原有文字／图片Text，再相邻片段逐层合并，拼接深度从O(N)降到O(log N)。保持表情基线偏移、动态字号、图片缓存、正文顺序、换行、未知标记、缺图回退、文字选择和无障碍原文；不截断消息，不限制发送数量，不改SDK或网络协议。该组件由收发正文共用，同样保护收到／再次打开已有长表情消息的渲染。

回归：`Tests/Chat/run-emoji-depth-checks.sh`编译提取生产方法，旧版本1000片段深度1000（预期最多10）失败，修复后空／单项／奇数／1000／5000／10000片段等8组通过；原词典、UTF16光标、增删表情检查通过。新增`Tests/Chat/EmojiRendering`匿名iOS原生测试宿主，直接编译生产视图和词典、打包真实表情图片，强制SwiftUI解析和排版。旧版原生回归在10000图片表情处Crash，xcresult为2通过／1失败（`/tmp/ddlNew-emoji-rendering-baseline-run.xcresult`）；修复后同3项全部通过、0跳过、TEST SUCCEEDED（`/tmp/ddlNew-emoji-rendering-fixed.xcresult`），包含1000／5000／10000表情及混合中文／Unicode／换行／未知标记／辅助字号。高度随数量增加，未用截断绕过测试；极长混合文本排版仍有成本，本轮不声称任意长度均流畅。

完整workspace generic iOS Debug无签名构建exit0、BUILD SUCCEEDED（`/tmp/ddlNew-emoji-balanced-build.log`）；git diff --check通过。原生宿主初次搭建曾遇到AppIcon配置及CGFloat常量推断编译错误，已修正测试夹具后完成上述红／绿验证。未发送真实群消息、未覆盖安装修复包，原真机崩溃现场保留；需重新Run后回到原群确认设备表现。未读取首页代码、未修改xgd、未提交推送，保留既有签到／支付通知隐藏／扫码和打包改动。

## 2026-11-10 扫码添加好友立即提示操作失败

用户确认失败发生在扫到二维码后、进入资料页之前。Xcode连接iPhone捕获真实二维码转换响应：传输status200，业务code90026、message“操作失败”，实际请求路径为`biz/scan/group/readScanContent`。SDK直接把该路径写入TCP请求，并且签名只移除`/biz/`前缀；缺少首个斜杠会使路由与签名接口名都不符合合同。xgd同一常量也缺少斜杠，本轮只修新项目SDK，不修改xgd。

`NoaIMHttpManager+Group.h` 的 `Transform_Qrcode_Content_Url` 补为 `/biz/scan/group/readScanContent`，保留二维码原文、userUid、SDK认证和会话隔离。用户重扫同一码，调试器只替换该次请求路径后，真实服务端业务码由90026变为10000，确认这一变量能消除转换失败。临时断点已删除，App恢复运行；没有记录二维码正文／认证凭据，也未发送好友申请。该真机证据来自运行时路径对照，不代表已把源码修复重新签名安装到设备；最终资料页导航和添加好友申请结果未验收。

新增 `Tests/Contacts/run-qr-route-checks.sh`／`QRRouteChecks.m` 编译提取生产常量、HTTP/TCP分派和签名方法，修复前复现路径及签名失败，修复后6项通过；通讯录业务回归通过（`/tmp/ddlNew-qr-business-checks.log`）。完整workspace generic iOS Debug无签名构建exit0、BUILD SUCCEEDED（`/tmp/ddlNew-qr-route-build.log`）。未读取首页代码，保留每日签到、支付通知隐藏及打包相关既有改动，未提交推送。

后续用户反馈扫码出现“目标服务拒绝连接”。本轮保留路径修复，移除旧请求路径替换／响应断点，仅监听真实业务失败。用户再次扫码后明确确认“这次进入对方资料页了，好了”；该次未捕获业务失败，扫码到资料页由用户真机确认通过，未执行添加好友申请。此前连接拒绝未再次复现，也未取得其错误码和具体失败接口，原因仍未确认，不能据此断言服务端故障已被修复。本轮不再改业务代码，路径／签名6项回归继续通过。清理时发现旧临时断点在Xcode仍有保存，本次通过断点导航器删除最后一个诊断断点，已确认导航器为空、App处于Running；不只凭LLDB删除命令判断清理成功。

## 2026-11-10 隐藏支付通知会话

用户明确暂不接支付功能，并要求支付通知不在列表展示。`ConversationsStore.publishVisibleConversations` 在共用展示边界过滤paymentAssistant；在线同步、离线缓存和角色权限变化统一适用，消息Tab及由本机可见会话计算的角标不计其未读。保留SDK类型／数据库原记录，不新增支付接口；签到助手、单群聊与文件助手既有权限行为保持。

新增生产Store回归先复现旧行为失败，再验证本地缓存／在线同步／文件助手权限变化均不展示支付通知、不计其未读且签到助手保留。会话排序、Store、操作和预览四组检查通过（`/tmp/ddlNew-hide-payment-checks.log`）。完整workspace generic iOS Debug无签名构建exit0、BUILD SUCCEEDED（`/tmp/ddlNew-hide-payment-build.log`），git diff --check通过。未读取或修改首页代码、未操作设备，未提交推送。

## 2026-11-10 xgd每日签到迁移与非首页功能差异盘点

用户要求先列xgd未迁移功能，再接每日签到，并明确整个首页代码排除读取、首页活动签到不处理。本轮新增差异清单 `Docs/XGD_MIGRATION_GAPS_2026-11-10.md`，区分尚未接线、已有底层兼容和此前明确删除／不接入项；支付助手旧端无可达支付流程，不推断真实支付能力。没有读取或修改新项目首页模块源码；xgd只读，原project.pbxproj／Podfile.lock改动保留。当前feature-all-5，打包脚本和已有交接改动保留，不提交推送。

新增 `Features/DailySignIn` 与 `Network/IM/DailySignIn`，我的→每日签到；消息type6→签到助手→每日签到。两个入口使用独立sheet导航，不改首页路由。包含真实签到提交、今日可领／已领积分、累计天数／积分、本月日历、按月签到记录／积分明细、随机／连续签到规则与连签奖励表；App自有文案三语，服务端规则原文保留。复用SDK五接口及userUid/year/month合同，不新建签到数据库，不恢复getSystemConfig。签到助手按旧端每页15条读SDK本机历史，进入锁内清本机提醒未读，不调用单群聊服务端已读接口。

Store与SDK双层按UID／租户／AUTH轮次隔离；未AUTH入口禁用，退出取消等待与清理，旧回包不发布。提交互斥，已受理后回读失败单独提示；同日旧详情不能重新开放签到。月查询完整成功才一起替换标题与数据，失败保留旧快照。奖励由服务器返回，不本地计算入账；成功回执缺少奖励数字不误报提交失败。接口无底层取消句柄，关闭仅停止本端等待与回执消费。

验证：`bash Tests/DailySignIn/run-checks.sh` 23项模型／Store＋12项生产SDK适配器边界检查通过；个人资料21项与会话排序／Store／操作／预览回归通过。签到涉及48个本地化键三语覆盖／占位符／无重复与plutil验证通过（新增37键/语言）。最终完整workspace generic iOS Debug无签名构建exit0、BUILD SUCCEEDED，日志 `/tmp/ddlNew-daily-sign-in-verified-build.log`；git diff --check通过。中间增量曾因SDK非可选导入失败，已按现有项目显式可选桥接修正并完成终版构建；不是忽略失败。构建保留既有SDK头文件、可选值插值等警告，PATH排除sentry-cli，无符号上传。

本轮未操作设备／真实账号，没有执行真实签到或积分写入，也未验收服务端各模式、跨天／时区、真实提醒推送和设备UI。离线检查与编译不等同真实签到入账。实现合同 `Docs/superpowers/specs/2026-11-10-daily-sign-in-design.md`。

## 2026-11-10 Ad Hoc 打包与自动上传：当前交接

脚本已实现，默认在打包成功后上传 IPA 与安装清单。当前仅完成离线流程验证和现有 IPA 的清单生成检查，**尚未通过新脚本实际归档、签名导出或上传服务器**。整理时分支为 `feature-all-5`；脚本、专项说明和测试仍为未跟踪文件，交接文档有未提交修改。未执行提交或推送，后续以实时 Git 状态为准。

### 文件入口

| 文件 | 用途 |
| --- | --- |
| [Scripts/package-adhoc.sh](../Scripts/package-adhoc.sh) | Release 归档、Ad Hoc 导出、清单生成、默认调用上传 |
| [Scripts/upload-adhoc.sh](../Scripts/upload-adhoc.sh) | 上传已有产物、校验摘要、备份和替换服务器文件 |
| [Scripts/ssh-password.exp](../Scripts/ssh-password.exp) | SSH/SCP 密码认证，密码不放进命令行参数 |
| `Scripts/adhoc-upload-config.sh` | 用户要求将密码直接写入此配置脚本，且不排除 Git；文档不复制密码 |
| [Docs/AD_HOC_PACKAGING.md](AD_HOC_PACKAGING.md) | 使用方法、环境要求和发布边界 |
| [Tests/Packaging](../Tests/Packaging) | 打包与上传的隔离流程检查 |

### 常用命令

在仓库根目录执行，以下版本仅为使用示例，不代表已发布：

```bash
# 查看参数，使用 --help 或 -h，不支持 -help
./Scripts/package-adhoc.sh --help

# 指定版本和 Build，成功后自动上传
./Scripts/package-adhoc.sh --version 1.3.1 --build-number 2

# 只打包；不传版本参数则沿用工程配置
./Scripts/package-adhoc.sh --no-upload

# 复用已有归档并导出上传，不能同时指定版本／Build
./Scripts/package-adhoc.sh --archive "/完整路径/ddlNew.xcarchive"

# 上传失败后重试本次产物，无需重新归档
./Scripts/upload-adhoc.sh "/完整路径/本次产物目录"
```

`--build` 是 `--build-number` 的别名；版本接受1至3段数字，Build接受正整数。参数只覆盖本次 xcodebuild 的 `MARKETING_VERSION`／`CURRENT_PROJECT_VERSION`，不修改工程文件。`--output` 必须指定尚不存在的目录；`--allow-provisioning-updates` 显式允许 Xcode 更新签名资源。

### 打包和发布合同

依赖 Xcode、支持 xcode archive/export 的 asc、Python 3、macOS Expect，以及与 Podfile.lock 一致的 Pods。使用 ddlNew.xcworkspace／ddlNew／Release，导出方式 `release-testing`（Ad Hoc），自动签名团队 `DGK6VR7P2D`；测试设备需在对应描述文件中。默认输出为已被 Git 忽略的 `build/adhoc/<唯一目录>/`，包含固定名称 `ddlNew.ipa`、`manifest.plist`、导出配置和日志；新归档另含 `.xcarchive` 与独立 DerivedData。构建限定系统工具 PATH，跳过项目可选 sentry-cli 符号／源码上传，归档保留 dSYM。

清单从本次导出的 IPA 读取真实元数据：`bundle-identifier` 取 CFBundleIdentifier，`bundle-version` 取 CFBundleShortVersionString，`build-version` 取 CFBundleVersion。下载页按用户要求读取 `bundle-version`。

| 项目 | 配置 |
| --- | --- |
| SSH | `root@8.210.96.3:22` |
| 服务器目录 | `/data/static-site/ddlnew/` |
| IPA 地址 | `https://static.xingqitongim.com/ddlnew/ddlNew.ipa` |
| 清单地址 | `https://static.xingqitongim.com/ddlnew/manifest.plist` |
| 图标地址 | 沿用 `https://static.xingqitongim.com/ios/512.png` |

仅上传 IPA 和清单，不上传归档、日志、认证配置或 index.html。文件先传至远端 `.upload-<UUID>/`，两项 SHA-256 均通过后获取发布锁、备份旧文件、依次替换 IPA 和清单，再复验正式文件摘要。旧文件仅在发布过程中临时备份为 `previous-*`；正式文件复验成功后删除备份和本次 `.upload-<UUID>/` 目录，不长期保留历史包。失败时保留本次临时内容，传输／预校验失败不会替换正式文件；每个文件独立 rename，两个文件并非整体原子事务。首次 SSH 接受新主机密钥，已记录密钥变更则拒绝连接；强制中止残留的发布锁需核实无在途发布后处理。

下载页面的修改位于仓库外 `/Users/taobotaobo/Downloads/index.html`，旁边有 `manifest.plist`；页面安装链接与二维码已指向 `/ddlnew/`。这些本地文件修改不代表已部署，上传脚本不包含页面发布。

### 验证记录与后续工作

已通过8项打包检查、3项上传检查，覆盖参数传递／非法值、归档复用、空格路径、失败日志、输出保护、Pods一致性、上传触发、摘要失败与传输失败保留旧文件。归档和网络工具均为隔离替身，未访问真实签名或服务器。Bash语法、`--help`入口及diff空白检查通过；已修复macOS Bash 3.2空数组与set -u的兼容问题。

另用桌面现有真实 IPA 单独执行清单生成，核验 `com.sigua.ddlNewapp`、`bundle-version=1.3.0`、`build-version=1`、目标 URL 及 plutil 格式通过；没有将旧 IPA 当作新脚本的打包成果。

后续实际发布时，需取得新脚本归档／导出日志、服务器两项摘要回执，再检查 HTTPS／CDN 返回文件及符合描述文件要求的设备安装。当前无上述发布证据，不应将离线检查或“脚本已完成”表述为已部署、已安装。

```bash
python3 Tests/Packaging/check_package_adhoc.py
python3 Tests/Packaging/check_upload_adhoc.py
```

## 2026-11-10 启动图取消多语言

用户明确要求 `AppLaunchScreen` 不再配置多语言。保留简体中文文案“叮咚聊／一起发现，一起参与”，将文件移动到 `Resources/AppLaunchScreen.storyboard`；删除简体、繁体、英文目录内的启动storyboard。系统启动入口名仍为AppLaunchScreen，其他页面、验证码及权限说明的多语言保持不变。更新启动资源检查及多语言维护文档。启动资源检查、验证码9组检查、App三语资源审计（各1624键）及git diff --check通过；ibtool独立编译启动storyboard成功，无错误／警告，编译nib不含运行时本地化对象。完整App构建遇到现有Xcode并行构建的build.db锁（`/tmp/ddlNew-launch-single-language-build.log`），未终止他人构建，未将独立资源编译视为完整App构建通过。本轮未安装或运行真机、未提交推送。

## 2026-11-10 删除启动包装视图与启动图语言排查

按用户要求删除 `LaunchWaitingView.swift` 和未引用的 `SplashScreen.swift`。根入口在本地恢复完成前仅以系统背景色及原有本地化进度提示占位，不再手动实例化启动 storyboard；本地入口校验、消息页连接／AUTH恢复及离线列表逻辑不变。系统启动 storyboard 保留，随后更名为 `AppLaunchScreen.storyboard`（见下段）。

SessionRestore 离线检查通过；generic iOS Debug 无签名构建 exit0／BUILD SUCCEEDED（`/tmp/ddlNew-remove-startup-wrappers-build.log`）。没有新增启动阶段网络请求，未提交推送。

用户报告简体中文手机的启动图显示英文。三语资源、对象ID、打包结果及 Scheme 未发现强制英文。独立模拟器 UIKit 宿主加载相同 storyboard，简体／繁体／英文三组文案均匹配（`/tmp/ddlNew-launch-language-results.json`）；该检查只证明运行时资源加载，不等同系统启动快照验收。用户指定的 iPhone／iOS26.6.1 经 Xcode 调试读取，`NSLocale.preferredLanguages = zh-Hans-CN`、`Bundle.main.preferredLocalizations = zh-Hans`，安装包实例化启动 storyboard 的标签为“叮咚聊／一起发现，一起参与”；读取后已恢复运行，没有修改设备语言或清理App数据。用户确认重新构建后仍显示英文。为验证旧启动快照假设，将系统启动资源整体改名为 `AppLaunchScreen`，同步三语 strings、Debug／Release 的 `UILaunchStoryboardName` 和资源检查；不修改文案、不删除App、不清理业务数据。资源审计三语各1624键、启动strings键匹配与验证码9组检查通过。iPhone目标签名构建exit0／BUILD SUCCEEDED（`/tmp/ddlNew-launch-cache-signed-build.log`），codesign验证通过，新包 `UILaunchStoryboardName = AppLaunchScreen`；已覆盖安装至用户指定的 iPhone／iOS26.6.1，随后通过devicectl终止旧进程并冷启动，安装／启动回执分别为 `/tmp/ddlNew-launch-cache-install.json`、`/tmp/ddlNew-launch-cache-launch.json`。用户再次确认仍显示英文，改名方案未解决问题，不能归因于旧快照。

后续改为 `zh-Hans／zh-Hant／en.lproj/AppLaunchScreen.storyboard` 三份独立资源，文字直接编译进对应nib；删除Base启动版本及三份启动strings，避免系统启动渲染依赖运行时翻译替换。三份布局保持一致，新增 `Tests/Localization/check_launch_resources.py` 校验源文案、布局、可选App产物的入口、资源完整性、无旧strings、无Base回退以及无 `NSLocalizableString`。独立模拟器宿主clean build通过，三语资源加载与编译产物检查通过（`/tmp/ddlNew-launch-embedded-language-results.json`）；该宿主仍不代表目标手机系统启动画面验收。主工程首次遇到用户Xcode并行构建数据库锁，未终止其任务；随后clean签名构建exit0／BUILD SUCCEEDED（`/tmp/ddlNew-launch-embedded-clean-build.log`），最终App产物的三语独立nib、无Base／旧启动strings／运行时翻译对象检查及codesign验证通过。已保留数据覆盖安装并冷启动至指定iPhone（`/tmp/ddlNew-launch-embedded-install.json`、`/tmp/ddlNew-launch-embedded-launch.json`）。用户最初表示没看清，随后回复“好了”并要求结束任务；按用户确认结束，未宣称已取得系统启动图截图。临时LLDB调试退出，不在生产代码中加入启动延迟。不使用Mobile MCP，未提交推送。

## 2026-11-10 简体中文、繁体中文与英文

用户确认全App方案并要求直接实施：参考xgd默认跟随系统、本机保存选择，提供简体中文、繁體中文、English，未支持系统语言回退英文。邀请码页、登录页和设置页新增共享语言入口，选择后按确定应用，取消不保存。AppLanguageStore发布locale，页面显式读取语言环境；不通过根视图id重建、重新登录或SDK重连切换语言，表单输入保留。

新增Foundation的L10n/L10nKey和三语资源，各1624键；已有适用译文复用xgd，新项目文案补齐。覆盖原生界面、错误提示、辅助功能文本、群／通话／消息类型模板和内置活动展示，支持插值参数重排。保持协议值、枚举rawValue、文件名、转发序列化内容及用户／服务端正文原样；内置活动显式标记才翻译，外部数据不翻译。消息页语言变化时只重读本地SDK快照。操作时生成的临时反馈、权限描述或部分历史系统消息展示快照在后续正常生成／读取时更新，不重置会话强刷。

验证码网页注入应用语言并配置阿里云／腾讯语种；四项系统权限说明和启动storyboard新增三语资源。系统启动页和权限弹窗由iOS选取语言，真实第三方验证码挑战尚未联网验收。维护说明与边界见 `Docs/Localization/README.md`，设计记录 `Docs/superpowers/specs/2026-11-10-localization-design.md`。

验证：资源审计1624/语言，缺失／过期／重复／格式错误为0；语言映射／保存／插值检查、验证码9组模拟检查、内置活动23项通过。完整离线首轮122脚本发现7个旧夹具依赖或提取边界失败，修复并逐项复跑，加活动／验证码2入口，最终124/124通过；汇总 `/tmp/ddlNew-localization-checks/final-summary.json`。保留原业务断言；现有业务回归编译真实L10n，活动模型检查隔离翻译边界，真实运行时另有专项与UI验证。

generic iOS Debug无签名构建exit0、BUILD SUCCEEDED，日志 `/tmp/ddlNew-localization-verified-build.log`，安装包已核验三套Localizable／InfoPlist／LaunchScreen资源。iPhone SE3 iOS26.5匿名原生XCTest9/9通过、exit0／TEST SUCCEEDED，报告 `/tmp/ddlNew-localization-ui-final/DerivedData/Logs/Test/Test-AuthAudit-2026.11.10_11-14-54-+0800.xcresult`；简体→英文→繁体即时切换、输入保留、重启偏好恢复、英文注册小屏滚动均通过。截图 `.impeccable/review/localization/`。首轮结果收尾卡住，最终关闭测试诊断收集正常完成；既有注册页键盘Invalid frame dimension警告仍记录，未宣称零警告。

本轮不使用Mobile MCP，不操作实体设备、真实登录或短信／邮件服务，xgd只读，未提交推送。上述为离线与匿名宿主验证，不代表所有页面三语真机逐屏验收。

## 2026-11-10 移除邮箱登录与注册

用户明确不再需要邮箱登录／注册。当前仅保留账号、手机号，登录和注册入口共享两项选择器；删除邮箱身份枚举、邮箱键盘／占位、校验错误和发码提示。接口枚举仍为账号1、手机3，本地 loginMethod/registerMethod 改为5（xgd的账号＋手机组合）。手机号密码／短信验证码登录、短信注册、区号、协议确认及AUTH链路保留。

历史记住密码中的邮箱类型2不再回填，也不会降级成账号类型；旧账号和手机号密码记录继续可用。SDK登录边界拒绝不支持的身份类型。未修改用户资料里的邮箱字段或已有认证会话恢复。

新增回归先复现邮箱入口仍存在及旧邮箱凭据回填，再删除实现。六组离线入口全部exit0，Login32/32、发码、LoginConsent、AccountLifecycle、Verification、SessionRestore；日志 `/tmp/ddlNew-remove-email-*-run-*.sh.log`。generic iOS Debug无签名构建exit0、BUILD SUCCEEDED（`/tmp/ddlNew-remove-email-build.log`）。原生XCTest7项通过，exit0／TEST SUCCEEDED，报告summary Passed，0失败／0跳过。结果 `/tmp/ddlNew-remove-email-ui/DerivedData/Logs/Test/Test-AuthAudit-2026.11.10_10-47-49-+0800.xcresult`，截图 `.impeccable/review/login-methods/account-phone/`；两个页面均仅账号、手机号。既有注册页键盘frame警告仍出现，未扩大本次改动处理。不使用Mobile MCP，未操作真实账号或实体设备，未提交推送。

## 2026-11-10 登录注册对照自测与验证码修复

按用户要求自测 UI、传参与 xgd 逻辑；用户要求停用 Mobile MCP 后，后续交互验证改用原生 XCTest／xcodebuild。独立源码复核发现并修复手机密码登录图片用途（2，账号／邮箱保持0）、第三方验证失败自动回退图文、图片“换一张”入口。刷新清旧答案，刷新中／失败／坏图时禁止提交；初始坏图可刷新恢复，异步结果继续受连接轮次与取消保护。此处纠正下节历史“密码登录保持0”。

六组离线入口通过：Login32/32、发码19项、LoginConsent、AccountLifecycle、Verification、SessionRestore。主 App generic iOS Debug 无签名构建通过（`/tmp/ddlNew-auth-audit-final-build.log`）。独立原生宿主编译生产页面和真实登录／注册 ViewModel，仅隔离外部服务、会话、Keychain、路由、Toast；iPhone SE3／iOS26.5的7项XCTest全部通过，exit0／TEST SUCCEEDED、xcresult summary Passed。结果 `/tmp/ddlNew-auth-audit-ui/DerivedData/Logs/Test/Test-AuthAudit-2026.11.10_10-41-59-+0800.xcresult`，可复现代码 `Tests/LoginUI/`，7张截图 `.impeccable/review/login-methods/audit/`。早期显式resultBundlePath收尾失败，最终默认结果目录已正常完成。

尚非完全对齐：封禁详情查询／解封相关UI未迁移，验证码挑战／发码保留客户端3轮限制；登录页本地配置与项目UI样式是用户明确要求的差异。完整XCTest另记录一条注册页唤起键盘时的Invalid frame dimension警告，未定位来源，截图未见布局破坏。真实短信／邮件、第三方服务、线上注册／登录、AUTH、设备Keychain及VoiceOver未验收；未操作实体设备，未提交推送。完整报告 `Docs/LOGIN_REGISTRATION_PARITY_AUDIT_2026-11-10.md`。

## 2026-11-10 三方式登录注册与原生表单

按用户要求对齐 xgd 的账号、手机号、邮箱登录注册，UI 使用 Impeccable 与 ui-ux-pro-max；本地 `LocalAccountPolicy.loginMethod/registerMethod` 固定为7，不恢复 getSystemConfig 或已经移除的 userSettings 登录字段。xgd 保持只读。登录页仍负责访客连接，已有账号冷启动仍走消息页恢复；认证成功后继续复用原 UserInfo、账号配置与业务激活链路。

`AccountIdentity` 明确接口枚举账号1、邮箱2、手机3。三类密码登录先检查 userExit，再获取新 encryptKey 并加密密码；手机／邮箱 OTP 登录直接提交6位 code，encryptKey/userPw为空。账号注册先检查存在性；手机／邮箱在获取验证码时检查已注册，最终注册携带验证码与加密密码。手机发码按本地图文渠道先验证，邮箱直接发码；复用既有第三方验证回退、连接轮次检查与取消机制，成功后才倒计时60秒。图片用途为注册1／验证码登录2，密码登录保持0。

区号合同以 xgd 从页面到 SDK／TCP 的实际源码为准：登录、注册及存在性预检仅手机发送带 `+` 的区号，另外两类为空；短信／邮箱发码均发送当前带 `+` 区号，默认 `+86`。目录包含 `+1-441` 等带连字符值并原样发出。本地身份键和记住密码记录的区号不带 `+`；手机／邮箱凭据按方式与区号隔离，旧账号记忆格式继续兼容。OTP 不写入记住密码或手动密码安全检查。

登录注册使用项目 HomeTheme 的森林绿浅深色，三方式入口直接可见，手机／邮箱提供密码与验证码切换、可搜索的214项区号目录、显示密码、动态字号与滚动表单。换方式清除密码／验证码，取消或连接更替拒收迟到发码结果；注册页自己呈现验证码弹窗，避免父登录页同时呈现。协议仍默认未勾选，打开链接不代表同意，取消确认不丢表单；注册成功但 AUTH 失败仍只允许返回登录，不能重复注册。

验证：Login（29组）、新增发码（17组）、LoginConsent（含OTP不记密码和手机记忆区号）、AccountLifecycle、Verification、SessionRestore 六个脚本入口通过；带连字符区号及 `+` 参数先复现失败再修复。最终 generic iOS Debug 无签名 workspace 构建 exit0、BUILD SUCCEEDED，日志 `/tmp/ddlNew-login-methods-final-build.log`，PATH排除 sentry-cli；`git diff --check` 通过。独立代码复核及区号专项复核已完成。独立UI复核发现安全验证提示过浅，修正图片验证码／安全码提示色后浅深色复拍，复核将该项评为resolved、ship；此结论仅覆盖修复评分。

匿名 iPhone SE3 iOS26.5 模拟器宿主编译生产 SwiftUI 页面／组件，SDK、会话和主要 ViewModel 使用替身；检查小屏、浅深色、辅助字号、滚动底部，并实际点通手机输入／键盘完成、安全验证提交与60秒倒计时、区号搜索切换、注册嵌套安全验证与取消。截图与限制见 `.impeccable/review/login-methods/README.md`。这些不是真实短信／邮件、账号注册、AUTH、Keychain设备存取或VoiceOver验收；未操作实体设备、真实账号，未提交或推送。实施合同：`Docs/superpowers/plans/2026-11-10-login-methods.md`。

## 2026-11-10 userSettings 账号配置生效与群成员活跃积分同步

用户要求按 xgd 接入剩余字段，并明确需要群成员活跃积分同步、不需要版本检查和日志上传。本节覆盖下方历史“功能接线待确认”的状态。配置唯一远端来源为 `/biz/user/userInfo.userSettings`，不恢复 getSystemConfig；登录前继续本地默认，已删除35项字段不恢复，SDK租户／签名和登录密码规则仍取本地参数。

新增 `AccountSettingsSnapshot` 与 `AccountSettingsStore`：AUTH 成功、业务激活前恢复同账号缓存；后续复用 SessionMaintenance 的资料刷新发布配置，按企业、UID、认证轮次隔离，退出重置，普通断线不清空。UserSettings 记录字段存在性并稀疏序列化；UserProfileCache 在缓存顶层标记版本，旧缓存保留用户资料但不启用无法辨别缺失／空值的旧设置。同供应商部分字段可合并，切换存储供应商时清除旧组，参数不完整禁止新上传，不混用旧桶。

已接入群发送间隔（毫秒，0按xgd回退2000）、普通撤回窗口（分钟，0关闭）、群管理撤回开关、群人数显示、通话总开关／供应商／Zego AppID，以及所有保留的OSS／OBS上传配置。聊天权限和群设置会响应配置刷新；上传主文件与封面使用开始时同一快照；未完成建房回执核对完整配置，现有通话维持其会话快照。`showUserRead` 继续取角色权限，`isEncrypt` 不改变现有协议；Zego AppSign／主备WebSocket在xgd只是赋值，当前直接SDK继续使用AppID与房间token。版本检查／日志上传字段只保留解析，不新增功能。

新增 `SDKGroupActivitySyncCoordinator`：进入群、群资料／设置成员同步完成、当前群配置刷新时，按 `member_active_points_interval`（秒）检查SDK毫秒游标，不新增后台全群轮询。先读取完整成员，再分页取增量积分，写回现有SDK成员表的 `activityScroe`；同群在途去重、失败最短5秒后允许下次触发重试，不阻塞聊天展示。使用服务端校准时间，全部分页及成员写入成功后才推进游标；写库前核验AUTH、企业、UID、认证轮次和数据库身份。原SDK异步写库封装不具备此轮次守卫，故复用其请求接口并在Swift边界统一提交。

独立复核发现成员分页不能按数量少于100提前结束，已先用完整生产协调器加匿名SDK替身复现失败，再改为严格验证 `pages/currentPage`、拒收错页／重复UID／空中间页；全量成员请求不传积分游标，`pageStart=0`对齐xgd。复核确认无剩余重要问题。最终 SessionMaintenance 调度17、Role/Profile37、SDK隔离7、配置14、积分策略13、生产协调器边界9项通过（`/tmp/ddlNew-account-settings-maintenance-reviewed.log`），Calls56项通过；聊天、设置、群发送权限15项、成员分页、媒体、群列表、登录与启动恢复共9入口通过（`/tmp/ddlNew-account-settings-regressions.json`）。无签名generic iOS构建exit0、BUILD SUCCEEDED（`/tmp/ddlNew-account-settings-reviewed-build.log`），PATH排除sentry-cli。未操作真实账号或设备，真实积分接口／通话／云上传仍待联调；未提交推送，xgd未修改。

## 2026-11-10 删除 xgd 无业务消费的25项配置

用户明确要求删除上一轮对照清单中的18项无对应配置字段和7项仅模型声明字段，现已从 `UserSettings` 删除全部25项的属性、注释及JSON映射，当前保留23字段。`showUserRead`、`isEncrypt` 不属于本次删除清单，继续保留；本地认证配置及现有业务行为未变。设计同步缩小字段范围，业务接线仍待确认。

完整往返夹具调整为23键，部分更新的清空检查改用OBS上传域名，数字转换改用群消息间隔，移除已删除systemSecurity对应的专属检查。SessionMaintenance 17项、Role/Profile 36项、SDK请求隔离7项全部通过，日志 `/tmp/ddlNew-settings-pruned-25-checks.log`；23字段注释和映射完整，无被删除属性的业务引用，`git diff --check`通过。未重跑完整App构建、未操作设备、未提交推送。

## 2026-11-10 继续精简 userSettings

按用户要求删除 `projectLogo`、`tenantCode`、`registerInviteCode`、`projectName`、`checkEnglishSymbol`、`captchaVersion` 的模型属性、注释及JSON映射；连同上一轮删除的四项，当前保留48字段。SDK和自建上传仍使用 `LocalSDKSettings.tenantCode`，登录／注册及修改密码仍使用 `LocalAccountPolicy`，不删除本地参数或改变其业务行为。设计同步移除远端租户参数、密码规则和动态签名切换改造，其他功能接线仍待确认。

现有资料往返、部分合并及null保留检查改用仍保留的存储桶／欢迎语字段，SessionMaintenance 17项、Role/Profile 37项及SDK请求隔离7项通过，日志 `/tmp/ddlNew-settings-pruned-six-checks.log`。48/48字段有注释和映射，被删除属性无业务引用，`git diff --check`通过。未重跑完整App构建、未操作设备、未提交推送。

## 2026-11-09 移除 userSettings 的纯登录配置

按用户明确要求，从 `UserSettings` 删除 `loginMethod`、`registerMethod`、`isMustInviteCode`、`captchaChannel` 的属性、注释和映射；当前保留54字段。服务端或旧缓存中残留这四个键会被 ObjectMapper 忽略。登录／注册仍使用 `LocalAccountPolicy`，本地属性、验证码流程和 SDK 初始配置未改动。功能接线设计也移除这四项，其他账号配置接线仍待设计确认。

同步调整完整字段往返检查，SessionMaintenance 17项、Role/Profile 37项及SDK请求隔离7项通过，日志 `/tmp/ddlNew-settings-pruned-checks.log`；54/54字段均有注释与映射，无被删除属性的业务引用，`git diff --check`通过。未重跑完整App构建、未操作设备、未提交推送。

## 2026-11-09 userSettings 字段注释与遗漏补齐

按用户要求，为 `Common/User/UserSettings.swift` 的全部字段补充中文文档注释，涵盖用途、已确认枚举／单位与 xgd 消费情况；未在 xgd 找到消费逻辑的字段明确标注语义边界，不推断额外业务。重新核对用户提供的响应，发现上一轮遗漏 `oss_obs_bucket_name` 与 `oss_config_end_point_jia_su`，现补齐属性及 ObjectMapper 映射，实际完整字段数为58；上节历史“全部56字段”的说法由本节纠正。

回归先以58键夹具复现往返丢字段，再修复并通过 SessionMaintenance 17项、Role/Profile 37项、SDK请求隔离7项，日志 `/tmp/ddlNew-settings-comments-checks.log`；58/58属性都有文档注释、58个JSON键映射完整，`git diff --check` 通过。本轮仅注释和两个字符串字段映射，未重跑完整App构建、未操作设备、未提交推送。

用户另要求以 `/biz/user/userInfo.userSettings` 驱动 xgd 对应配置功能，明确不恢复 getSystemConfig，已确认登录前用本地默认值、登录后应用账号配置。对照设计见 `Docs/superpowers/specs/2026-11-09-user-settings-runtime-design.md`，功能接线仍处于设计待确认阶段，尚未改变当前本地配置消费行为。

## 2026-11-09 用户资料加入完整 userSettings

按用户提供的 `/biz/user/userInfo` 返回结构新增 `Common/User/UserSettings.swift`，覆盖全部56个字段，并由 `UserInfo.userSettings` 持有。沿现有 ObjectMapper 接入登录响应、资料刷新与用户资料 JSON 缓存；旧缓存缺少该字段仍可读取。属性采用 Swift 命名，序列化沿用服务端原键名，包括历史拼写 `android_kepplive_url`、`groupMangerMessageRecallTime` 等。

设置值保持接口的字符串合同，直接下发的布尔值和数字可转成字符串，`systemSecurity` 保留原 JSON 字符串。部分资料刷新逐项合并设置，省略／null 保留已有值，空字符串允许显式清空；不会因单个设置更新丢失其它配置。资料兼容 `userUid`／`userUID`，刷新同时核验两种拼写，拒收不同用户或相互冲突的身份。模型接入不自动覆盖本地 SDK／消息／通话配置，不新增网络请求或配置日志；测试仅包含合成值，不保存用户提供的真实响应。

验证：先复现原模型丢弃 userSettings 的失败，再通过会话维护入口的调度17项、模型／权限37项及SDK会话隔离7项检查，覆盖56字段往返、登录解析、部分更新、旧缓存、布尔数字和UID校验，日志 `/tmp/ddlNew-user-settings-final-checks.log`。无签名 generic iOS workspace 构建 exit0、BUILD SUCCEEDED（`/tmp/ddlNew-user-settings-build.log`），构建 PATH 排除 sentry-cli，git diff --check 通过。未操作设备、提交或推送；真实响应的设备缓存验收尚未执行。

## 2026-11-09 断线仍可点击会话

按用户要求，消息列表行不再因 `isAuthenticated == false` 整行禁用，断线、重连及冷启动恢复期间都可进入聊天页。在线资格只限制列表的置顶、免打扰、未读和删除操作；原有操作忙碌状态仍按会话控制。已登录后断线沿用 ChatRuntime 的稳定身份与 SDK 本地历史读取；冷启动尚未建立聊天身份时仍等待原 AUTH 激活流程，未提前授予发送资格。

聊天 Store 回归通过（`/tmp/ddlNew-offline-chat-checks.log`）；无签名 generic iOS 构建 exit0、BUILD SUCCEEDED（`/tmp/ddlNew-offline-chat-build.log`），构建 PATH 排除 sentry-cli，git diff --check 通过。未操作设备，断线点击的真机交互尚待验证；未提交或推送。

## 2026-11-09 消息列表先展示本地缓存

用户追加要求：App 启动进入消息页即显示已有列表，不等待连接／AUTH 成功。MessageSessionRecovery 在网络可用门禁之前执行一次本地快照读取，因此断网冷启动也能展示上次的会话、草稿、预览及未读数；连接状态独立显示，连接与 AUTH 成功后沿原有同步回调刷新列表。

SDK 增加锁内的临时本地数据库读取入口；只临时设置 UID，不设置 SDK 用户 Token、不发送 AUTH、不配置 Socket 或 MMKV，读取结束清理临时数据库及身份。NoaIMDBTool 使用专用已有库打开路径，不进入正常建库的恢复／删除／重建分支，不执行预览表迁移；没有缓存文件时返回空快照，不创建文件。读取失败可在消息页离线重试，重试与 AUTH 由同一恢复任务串行调度。

ConversationsStore 在同账号恢复 AUTH 和暂时连接失败时保留快照，停止旧观察与读写轮次；AUTH 成功后刷新，不因重试闪成空列表。退出、明确认证拒绝和换号仍清空；旧读取与回调按 generation 拒收。缓存仅用于展示，聊天操作、来电、Push 与其他业务仍受真实 AUTH 门禁保护。本节覆盖原设计“不在 AUTH 前读消息缓存”的边界。

验证：本轮8组相关入口通过，覆盖 Conversations／online、SessionRestore／recovery／local-cache、Login、AccountLifecycle、Push；包含离线先读缓存、认证前保留、同步后替换、临时失败与本地重读保留、退出后的迟到读取拒收。生产 SDK／DB 打开方法提取测试以 WCDB 边界替身模拟失败，并确认临时样本的 DB／WAL／SHM 文件字节不变、无表创建及无缓存目录创建。独立复核确认两项发现（误入旧删库重建路径、离线无法重读）修复后无剩余阻断问题。最终无签名 generic iOS workspace 构建 exit0、BUILD SUCCEEDED，日志 `/tmp/ddlNew-local-conversation-final-build.log`，构建 PATH 排除 sentry-cli；git diff --check 通过。这些不是实际 WCDB 文件或设备冷启动验收，真机离线启动与恢复后更新仍待验证。未操作实体设备、真实账号或 xgd，未提交／推送。


## 2026-11-09 冷启动恢复移到消息页与连接状态对齐

用户批准设计并要求实施；本节覆盖下方历史“启动等待 TCP/ECDH 和 AUTH 后进入主界面”的边界。启动仅校验本地入口与成对账号／企业凭据：无入口显示邀请码，有入口无账号显示登录，有有效缓存先显示默认消息 Tab。启动路由不发 DNS/BIN、TCP 探测、正式连接或 AUTH。登录页出现后幂等准备原访客连接，首次登录／注册及协议确认合同保持。

新增 MessageSessionRecovery，由消息页出现触发、会话服务持有任务。恢复沿现有 DNS1 缓存／主备／BIN与正式连接→本地租户参数→缓存 AUTH；单轮连接入口避免访客无限循环与页面恢复循环并行。切 Tab／进入聊天不取消；无网络／后台暂停新尝试及退避计时，已在途尝试可结束，随后等待可用；SDK已登录重连仍由原所有者执行。暂时失败保留本地展示身份及凭据，明确认证拒绝清理返回登录，本地存储／数据库失败停止自动重试并提供重试入口。恢复UUID、账号、企业、SDK代理generation和真实Socket身份隔离旧回包。冷启动消息页先读取本地会话快照，再后台恢复连接，真实业务、来电与Push仍在AUTH之后激活。

消息页顶部固定状态行按xgd实际代码显示：正在连接…、在线、重连中、连接失败正在重连、网络不可用；无固定次数上限。文本与彩点并用，真实用户AUTH才允许在线；好友头像在线圆点不变。前台可见且已认证时每20秒探测当前正式节点，3秒超时，同一时间一轮，与网络质量择优互斥；失败经新增SDK原子身份／Socket核验入口交回原重连。离页／后台取消探测业务等待与结果资格，底层临时探测仍按自身超时回收。

独立复核发现并修复两项竞态：恢复AUTH取消清理会使同轮主动退出漏删凭据，现恢复catch避让pendingSignOut，由主动退出完成清理；首次恢复超时调用通用Push.close会清除排队点击及未知角标，现临时恢复清理保留尚未激活的Push状态。两项已先以真实LoginSessionService加边界替身复现失败，再通过新回归，复核确认无剩余重要发现。

验证：最终14组专项入口全部exit0，覆盖SessionRestore五入口、Login、AccountLifecycle、Network与ECDH、NetworkQuality、Conversations两入口、Push、SessionMaintenance，汇总 `/tmp/ddlNew-message-final-checks.json`。启动零连接断言先RED后GREEN；恢复幂等、离线、超时、同UID新轮次、本地错误、状态优先级、探测迟到隔离及生产ObjC方法6场景通过。最终无签名generic iOS workspace构建exit0、BUILD SUCCEEDED，日志 `/tmp/ddlNew-message-connection-reviewed-build.log`，构建PATH排除sentry-cli。git diff --check通过。六种状态的生产视图匿名macOS ImageRenderer预览在 `/tmp/ddlNew-message-state-preview/`，已目视核对在线、失败与重试布局；不是iOS触控／辅助字号／VoiceOver验收。

未操作实体设备、真实账号或修改xgd，未提交推送；当前工作区既有首页／我的／网络检测改动保留。真机仍需Run后验收有缓存冷启动、断网与恢复、AUTH期间退出、通知点击后首次恢复超时、切Tab／进入聊天及持续认证恢复；离线与编译不代表这些服务器及设备行为已通过。设计与实施记录：`Docs/superpowers/specs/2026-11-09-message-connection-design.md`、`Docs/superpowers/plans/2026-11-09-message-connection.md`。


2026-11-09 展示微调：按用户要求，“当前企业”移至网络检测滚动内容最上方、状态摘要之前；删除底部“节点地址已脱敏。结果仅代表本轮检测，不代表登录成功或消息已送达。”整段说明及空页尾。节点脱敏逻辑继续保留。本次仅调整展示顺序与文案。

## 2026-11-09 网络检测节点脱敏

按用户要求，当前目标、外网请求、DNS主／备／BIN来源、返回节点、服务器详情和未执行地址统一通过 `NetworkDiagnosticAddress.masked` 展示。IPv4保留首尾段，IPv6仅保留首段；域名每段保留首尾字符（短段全隐藏），端口保留。URL路径统一隐藏，账号／密码／查询参数／片段不展示；无效输入返回星号，不回显原文。可复制Text及无障碍文本均由脱敏字符串构成，页尾标明节点地址已脱敏。真实地址仍用于请求及匹配，检测策略不变。

新增15种地址输入检查，连同原专项共19组通过（`/tmp/ddlNew-address-checks.log`）；最终无签名iOS构建exit0、BUILD SUCCEEDED（`/tmp/ddlNew-address-build.log`），构建PATH排除sentry-cli。匿名模拟器截图同步更新，验证范围仍为展示布局，不代表真实网络或VoiceOver验收。此节覆盖此前完整地址展示的约定；未提交或推送。

## 2026-11-09 网络检测可读性与实际节点展示

按用户选择“结果更易懂、当前步骤和异常更清楚”，使用Impeccable与Superpowers细化已有诊断工作台。移除重复眉题和说明，步骤标题整行可展开；当前步骤、已有结果、全部通过、部分通过、未通过与未执行分别显示，运行期间不提前判断整步最终失败。失败结果自动展开，文字状态与图标并用，地址使用可选择的等宽文本，支持长地址和IPv6换行；浅深色、辅助字号布局及48pt主操作触点保留。装饰步骤图标固定其字号，避免辅助字号溢出圆形标记。

用户追加要求三部分显示节点，现已接线真实本轮数据：设备检查明确为网络接口检查、无远端节点；外网四地址逐次显示实际请求目标、结果、毫秒耗时，成功后后续地址立即标未请求。DNS主／备／BIN显示实际来源地址和返回的全部TCP候选节点；连接服务器显示实际host:port，IPv6保留方括号。正在请求／探测的目标也实时显示。数据仅用于当前页面，未添加公网IP提取或上报；四地址回退、DNS1顺序和正式连接策略不变，不恢复旧五路。

独立复核提出的立即取消后旧Task回填来源，以及外网成功后剩余地址仍显示待检测，两项均复现／修复并补检查。模拟器渲染又发现完成时自动展开未生效，已改为以completed驱动的任务并重新截图验证。专项18组检查通过（`/tmp/ddlNew-clarity-checks-final.log`），覆盖地址传播、IPv6、回退、取消迟到回调、新旧轮次隔离和展示状态。最终无签名iOS构建及截图证据见 `.impeccable/review/network-diagnostics/README.md`。

本轮仅在匿名iPhone SE 375pt模拟器宿主编译实际展示组件、模型和主题，核对准备／运行／部分失败／深色／辅助字号及滚动到底的布局；截图使用示例域名与文档IPv6地址，不代表真实网络结果。没有操作实体设备或真实账号；触控自动化工具未返回可用结果，未完成真实点击、VoiceOver和横屏验收。未提交或推送。

## 2026-11-09 网络检测改为诊断工作台

用户明确放弃xgd同款UI，并选择“诊断工作台：突出当前步骤、结果和耗时”。本节取代下方“网络检测UI对齐xgd”的视觉方案：改为森林绿主题、左对齐状态摘要与卡片内开始／停止／重测操作，下方以纵向三步骤展示设备与外网、获取服务节点、连接服务器。移除页面对原盾牌插画、邀请码胶囊、居中百分比和底部固定按钮的使用。步骤支持就地展开记录与实际毫秒耗时；当前检测步骤自动展开，完成时自动展开含失败记录的步骤；可用服务器与局部检查失败分别说明，未运行来源显示未检测。

保留四地址外网顺序回退、新端DNS1主／备／BIN、独立探测及取消／重试／换号隔离，不恢复旧五路。辅助字号切换纵向操作与步骤标题布局，按钮触点至少44pt，收展动画遵循减少动态效果设置。设计记录见 `Docs/superpowers/specs/2026-11-09-network-diagnostic-workbench.md`。

验证：14组离线诊断／外网检查通过（`/tmp/ddlNew-diagnostic-workbench-checks.log`）；最终generic iOS Debug无签名workspace构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-diagnostic-workbench-build.log`），构建PATH排除sentry-cli，`git diff --check`通过。已目视检查准备态、部分失败但找到可用服务器、深色和辅助字号布局分支的静态组件预览（`/tmp/ddlNew-diagnostic-workbench-preview/`）。预览为macOS ImageRenderer、匿名数据和静态容器，不能替代iOS实际字号缩放、滚动、安全区、触控与VoiceOver验证。本轮未操作设备、未做真实网络验收、未提交或推送。

## 2026-11-09 外网连通性恢复xgd四地址回退

用户指出此前仅请求Google 204与xgd不一致。本次以xgd `checkInternetConnectivityAtIndex:generation:completion:` 为准，顺序尝试 `https://ipinfo.io/json`、`https://ipapi.co/json/`、`https://api.ip.sb/geoip`、`https://www.google.com/generate_204`。任一通过即停止，不要求每次发满四次；全部失败才返回不可达。前三项要求HTTP 2xx和JSON字典内非空字符串country／country_code，最后一项接受200或204。请求超时5秒、资源超时8秒，临时Session禁用缓存／Cookie／凭据；不提取、保存或上报响应中的公网IP。取消后不继续下个地址，迟到成功不可写新轮次。

此节取代上文“仅Google地址”的实现边界；DNS1主／备／BIN与正式连接不受影响。新增五组外网策略检查覆盖四个成功位置、顺序与提前停止、非法字段、HTML、HTTP失败和取消迟到回包，连同既有九组诊断检查全部通过（`/tmp/ddlNew-four-address-checks.log`）。最终generic iOS Debug无签名构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-four-address-build.log`），`git diff --check`通过，构建PATH排除sentry-cli；未对真实地址执行网络验收，未操作设备、未提交或推送。

## 2026-11-09 网络检测UI对齐xgd

按用户追加要求，对照xgd的 `NoaNetworkDetectionTopHeaderView`、`NoaNetworkDetectionView` 和主／子结果Cell重做展示。使用原版88pt状态插画、居中标题／阶段百分比／异常数量、邀请码胶囊、12pt圆角连续分组列表和底部固定44pt蓝紫色按钮；分组默认收起，等待状态不可展开，检测中显示进度指示，完成显示原版成功／失败图标，展开查看结果及耗时。浅深色背景对照原页，小号结果文字的红绿值加深以保证可读性；长文和辅助字号可换行，不复制固定行高裁切。

进入页现为准备态，点击“开始检测”才运行；运行时“退出检测”取消并清空结果回到准备态，完成后“重新检测”。Store只增加展示用阶段进度、完成状态与reset，DNS1主／备／BIN读取、独立ECDH、取消／换号隔离不变，旧五路不恢复。xgd项目只读；关于我们与上一轮活动迁移保留。

验证：检测离线9项通过，新增reset恢复准备态以及完成时100%检查。浅色准备态、异常态及深色匿名组件预览已目视核对，文件在 `/tmp/ddlNew-network-ui-preview/`；预览使用macOS ImageRenderer并将不支持的ScrollView替换为静态容器，不能当作iOS滚动、安全区、触控或VoiceOver验收。最终generic iOS Debug无签名workspace构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-network-ui-final.log`），`git diff --check`通过；构建PATH排除sentry-cli。未操作设备、未提交或推送。

## 2026-11-09 我的新增网络检测与关于我们

按用户确认的方案对照xgd可见功能，新增“我的 → 账户与支持 → 网络检测／关于我们”，使用现有Tab值路由和森林绿主题。保留此前活动／俱乐部迁入首页的工作区修改，未修改xgd。

网络检测读取当前AUTH上下文中的企业邀请码，独立检查设备网络、外网检测地址、DNS1主域／备域／BIN和本轮TCP节点密钥交换；逐项显示耗时和结果，未运行来源标记未检测。某来源全部节点失败继续下一来源，找到可用来源后停止后续来源。复用生产DNS1加载和临时ECDH探测，不使用导航缓存掩盖失败，不保存节点、不切换正式Socket或发起AUTH，不恢复旧五路／OSS Auth或公网IP采集。外网项仅检测Google 204地址，失败文案明确为检测地址不可达，不能据此断言所有外网不可用。SDK临时ECDH无取消句柄：取消立即结束Swift等待并拒绝迟到回执，底层临时探测仍依其4秒超时收口。

页面支持取消和重新检测；离页及ChatRuntime清理取消任务。轮次UUID、Task取消和完整AUTH上下文共同隔离重试、换号及同UID重登。关于页读取实际Bundle图标、版本和build，图标读取失败显示系统兜底；使用本产品现有“使用支持／隐私政策”，不复制xgd域名，不引入Flutter或旧版未显示的更新／评分／日志上传入口。

验证：新增 `Tests/Mine/run-diagnostic-checks.sh` 8项通过（来源失败回退、探测失败回退、成功停止、缓存不参与、源／探测取消、真实Store重试迟到隔离、同UID新AUTH、退出禁止检测）；DNS1原有43项及DoH专项通过。独立只读复核未发现重要问题，按钮44pt实际触点和缺失图标兜底已补正。最终无签名generic iOS Debug workspace构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-mine-support-final.log`），`git diff --check`通过；构建PATH排除sentry-cli。未操作设备或连接真实账号进行检测；小屏／大字号／浅深色实际渲染、VoiceOver、触控及真实网络结果尚待设备验收。未提交或推送。

## 2026-11-09 我的活动与俱乐部迁入首页

按用户要求，将“我的”中的我的报名、候补记录、签到记录、已参加活动及当前俱乐部／更换俱乐部全部迁入首页。首页原“我的户外日程”合并为“我的活动”四项记录，保留独立活动签到入口；原顶部重复俱乐部入口移除，由迁入的薄荷绿俱乐部卡统一承载。活动大厅、推荐活动和公告保留。普通字号活动两列、辅助字号单列，复用原主题与按压反馈、至少44pt点击区域。

`MinePageContent` 仅保留真实个人资料、二维码与账户支持；`MineView` 移除俱乐部切换状态和回调。确认弹框迁至 `ClubHomeView`，仍仅在确认后调用原 `store.signOut(changeClub: true)`；记录和俱乐部详情继续使用首页既有 `ActivityNavigationScope` 值路由，不修改数据、登录或SDK行为。当前俱乐部名称仍为既有演示内容，没有新增服务端接线。

验证：最终无签名 generic iOS Debug workspace 构建 exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-home-migration-build-final.log`），`git diff --check`通过。构建环境排除sentry-cli。已核对首页注册全部迁入值路由、我的页不再含活动和俱乐部入口；本轮未操作设备、未实际更换俱乐部，视觉与触控尚未真机验收。未提交或推送。

## 2026-11-09 xgd 推送完整迁移到 ddlNew

用户确认完整迁移，并明确 xgd 项目代码不得修改。本轮只在 ddlNew 实现；xgd 的 git status 和 git diff HEAD 二进制摘要开工/收尾一致，原有 project.pbxproj、Podfile.lock 修改未动。保留当前 feature-all-5 工作区中既有补发、TLS、MiniApps 和用户签名设置，不提交或推送。

新增 Features/Notifications 与 Network/IM/Notifications：AppDelegate 启动即设置通知中心 delegate，首次真实登录后申请系统权限；APNs Token 与完整 UID/租户/登录轮次任一就绪时协调绑定，回前台可重试，主动退出先停止提醒并尝试解绑。SDK普通消息自动声音通过当前仓库新增的 applicationManagesMessageAlerts 开关交给 Swift 协调器，SDK默认行为及独立通话入口保留；不会复制到 xgd。用户既有 Bundle ID com.sigua.ddlNewapp、entitlement 和后台模式未由本轮改写。

前台消息统一检查总开关、声音/震动偏好、会话免打扰、本人消息、重复消息、可见聊天及音频占用；后台在线消息生成带稳定标识的本地通知。单群聊摘要、好友备注/群内显示名、群公告和好友申请接入真实SDK快照；@其他人显示实际正文，@本人/全体显示提醒，群公告另检查 groupInformStatus。好友hashKey仅标识用户对，短5秒窗口合并重复回调，不能永久阻止后续重新申请。历史回读和更新回调不生成新通知。

设置页新增“通知设置”，三个开关沿用服务器 isNewMsgNotify/isVoiceNotice/isShakeNotice，保存必须收到肯定回执，失败保留已确认设置；缓存按租户/UID区分，迟到回包受登录轮次隔离。推送写操作由 PushRequestLane 等待SDK实际终态后串行，取消Swift任务不能让旧服务器写提前让位；偏好读取先等写入屏障，避免短等待超时引入的乱序。运输超时并不证明服务端未处理，服务端无版本协议时不承诺网络极端情形下绝对操作顺序；解绑失败也不宣称服务器绑定已清除。

点击复用现有 ActivityNavigationScope 和 ClubStore.selectedTab，真实 AUTH、数据库及Tab导航就绪后消费；已在同会话不重复push，好友申请进入新朋友。payload严格验证类型；无可靠身份或会话未验证时落列表，不把远程标题/ID当访问资格。本地通知包含进程与登录轮次，同进程旧轮次迟到点击拒绝，跨进程冷恢复仍核对账号与租户。角标等待会话和好友申请真实快照，未知初始值不覆盖系统角标；保留当前 ChatStore.open 会话提醒清理和正文已读规则，通知模块不重复发送已读。

验证：Push策略29项、真实协调器13项和真实运输串行器2项通过（含取消、重复回执、请求期间换号、同UID新登录、偏好失败、冷启动等待及旧通知点击）。首次编译暴露SDK头文件显式导入和ObjC非空标注适配问题，均已修正；最终无签名generic iOS Debug workspace build exit0、BUILD SUCCEEDED，日志 /tmp/ddlNew-push-build-verified.log，构建PATH排除sentry-cli，未上传符号。独立代码复核提出的四项问题均已补检查并修复。全量离线脚本112/113通过，/tmp/ddlNew-push-full-qa/summary.json；唯一失败 Tests/MigrationAcceptance/run-log-redaction-checks.sh 为旧日志夹具未声明Socket诊断trace/NoaElapsed/网络状态替身而编译失败，本轮未改该生产Socket诊断或此夹具，不将全套记为全绿。git diff --check通过。

尚未安装或操作真实设备、发送业务消息、访问APNs服务端配置或读取/上传cer私钥。正式离线推送依赖服务端为当前Bundle ID配置正确topic/环境和凭据；前后台/锁屏/杀进程送达、点击与已有弹层、账号切换仍需真机验收。后台声音/震动受iOS系统设置控制，服务端APNs内容和开关需服务器执行；旧payload缺共同消息ID时无法保证系统APNs与本地通知严格跨通道去重。没有新增PushKit/CallKit。设计、计划及真机清单见 Docs/superpowers/specs/2026-11-09-push-notifications-design.md、Docs/superpowers/plans/2026-11-09-push-notifications.md、Docs/superpowers/specs/2026-11-09-push-notifications-qa.md。

## 2026-11-09 我的应用状态动画重接与网址自动补全

用户确认上一版箭头仍跳动、状态变化无动画。旧实现把标题和展开内容放在同一个自适应 List 行，同时清除状态事务的动画；局部按压动画不能解决这一问题。本次增加 `MiniAppsDisclosure` 独立标题行，24pt固定符号框在44pt区域内中心旋转；`MessageView` 持有展开状态，应用内容为其下方独立条件行，稳定ID区分标题／内容。移除清空 animation 的事务，展开／收起实际使用0.25秒状态动画，内容行透明度过渡。

管理／完成实际使用0.22秒状态动画；Grid两种字号布局始终预留角标空间，删除角标淡入淡出及轻微缩放，切换时不再改变图标顶部间距。初次加载由消息页稳定外层的 `.task(id: store identity)` 持有，使展开／收起不再取消列表加载；复核提出的取消重入竞态未经触摸复现，SDK已有取消处理，此处为生命周期收敛；密码、删除、编辑和网页打开链路继续复用原有所有者。

用户追加网址输入无需手动填写协议：`MiniAppWebPolicy.entryURL` 接受裸域名、域名端口及协议相对地址，默认补 HTTPS，已有 HTTP(S)直接使用。Draft校验、SDK保存和Feature打开共用此规则；保存请求提交补全地址，兼容后端已有网址字段。编辑框示例改为 `example.com`。网页内部导航仍调用严格 `url` 校验，不将 javascript/file/data 等协议当作网站。

验证：无协议网址在旧模型回归中先复现失败，再在新模型、URL策略及Feature检查通过；原有MiniApps离线套件通过。匿名模拟器宿主编译真实Disclosure／Panel／Grid，自动驱动展开→管理→完成→收起并录制连续帧；观察到标题／箭头区域固定，内容存在中间展开帧，管理角标出现和消失。宿主只有定时状态驱动与边界替身，不是真实手指操作或服务端验收。录屏 `/tmp/ddlNew-miniapps-state-motion.mov`，关键帧见 `.impeccable/review/miniapps/state-motion/`。最终无签名 generic iOS Debug workspace 构建 exit 0、`BUILD SUCCEEDED`（`/tmp/ddlNew-miniapps-state-url-reviewed.log`）；Feature新增无协议入口及规范化后复用原会话检查通过，`git diff --check` 通过。构建未上传符号，未提交或推送。

2026-11-09 追加：按用户要求移除“我的应用”点击网站时的“正在打开应用”行，不再因该提示增加面板高度；请求期间的重复点击防护、密码验证和失败提示保留。本次仅移除展示行，Swift 语法检查及 diff 空白检查通过，未重跑完整构建。

## 2026-11-09 我的应用局部按压与浮窗松手动画

按用户追加要求，为“我的应用”、管理／完成、刷新／重试及应用网格按钮使用独立 `MiniAppButtonStyle`：按压时透明度和背景色以0.16秒过渡，不改变布局尺寸；展开箭头以0.2秒旋转。消息列表行仍清除外层布局动画，但不再全局禁止子视图动画，展开只在无动画事务中切换，不重新给 List 行高加动画。显式自定义按钮样式继续避免同行操作串联。

浮窗拖动中的位置仍即时更新，松手后仅停靠位置使用0.32秒弹簧过渡；拖动松手不打开列表，独立轻点才打开。系统“减少动态效果”开启时关闭按钮过渡、箭头和贴边动画。没有调整应用接口、密码或删除权限。

消息列表的群名称按追加要求限制为单行，超长尾部省略；原始名称、搜索与无障碍完整摘要保持。单聊名称保留原有行数。

验证：浮窗位置／拖动与点击区分的离线回归通过；含最终群名称单行和禁用态样式的无签名 generic iOS workspace build 为 BUILD SUCCEEDED（`/tmp/ddlNew-miniapps-motion-title-final.log`），`git diff --check` 通过。此前触摸自动化工具不可用的边界仍有效，实际动画观感待真机确认。

## 2026-11-09 我的应用展开、拖动与删除入口交互修正

本轮按用户后续反馈：消息页应用面板展开不再给 List 自适应行高施加动画，应用行事务也关闭动画，避免标题随插入内容上下跳动。浮窗使用单一触摸序列和 `MiniAppFloatingPosition`，拖动时横纵位置跟随位移，松手才贴边；移动超过8pt后，即使拖回原点也不能当作点击，只有独立轻点打开列表。无障碍打开和移动操作保留。

管理模式的删除入口改为应用图标右上角的减号角标，44pt独立触点，无下方“删除”文字；辅助字号也放在图标右上角。Panel 显式使用 borderless 按钮，删除用 plain，禁止同一 List 行的 automatic 按钮行为将管理／完成点击分派给删除。切换管理状态清空待删除项，删除确认仍只由角标触发。

应用密码没有位数限制，开启时只判非空；新增1字符、中文和2048字符的模型检查。核对发现 SDK 保存请求仍裁掉密码首尾空白，现改为与验证、旧密码字段一样传原文，避免创建与验证不一致。

验证：MiniApps 离线套件含跟手位置、松手不打开、拖回原点、轻点、贴边和屏幕边界检查。匿名宿主编译真实 Panel／Grid／Presentation，管理展开状态仅为截图初始化夹具，不是点击测试。Mobile MCP 的 Simulator agent 下载超时，CUA 未提供 Simulator，未完成实际触摸复测；管理→完成无弹框及完整列表展开稳定性仍须真机确认。最终无签名 generic iOS workspace build 为 BUILD SUCCEEDED（`/tmp/ddlNew-miniapps-interactions-final.log`）；`git diff --check` 通过。管理模式角标截图为 `.impeccable/review/miniapps/interaction-delete-corner.png`，已目视确认位置和下方文字移除。

## 2026-11-09 消息页“我的应用”完整功能迁移

用户确认完整移植 xgd 的应用管理、网页和浮窗。当前接手分支 `feature-all-5`，保留原有补发／TLS／登录改动，未提交或推送。

- 消息页搜索与筛选下方新增默认收起的“我的应用”：展开读取真实 SDK 分页（每页50条），支持刷新、加载更多、管理和添加。系统应用不可编辑，删除遵循 `appType / allowUserDelete`；自定义应用支持名称、HTTP(S)网址、相册／相机图标及访问密码，受保护应用先验证再打开或编辑。删除确认、失败重试和编辑草稿保留。
- `MiniAppsStore` 通过 `SDKMiniAppClient` 复用现有列表／详情／新增／修改／删除接口；当前完整认证上下文和请求轮次隔离旧回包。保存／删除从提交到回读一直保持忙碌；服务端已受理但刷新失败明确提示，避免重复创建。图标沿旧端 type104、50KiB、`miniApp/` 目录，复用媒体上传，不生成聊天消息或占用聊天发送配额。
- `MiniAppsFeature` 统一持有 WKWebView、浮窗和呈现状态，主 Tab 提供可拖动贴边入口、浮窗列表、移除及清空。网页支持前进／后退、刷新、失败重试、复制链接、外部浏览器及下载响应确认。最小化保留当前网页实例和历史（最多5个），冷恢复使用 SDK 本地浮窗记录；恢复时重新确认当前应用及密码，不直接信任旧记录。配置入口与浏览子路径分开保存，避免恢复子路径后错误销毁缓存。
- 浮窗数据复用 SDK 表并在记录 ID 加租户命名空间；退出与同 UID 重新认证通过 `ChatRuntime.registerCleanup` 销毁 Store、网页和非持久 WebKit 数据空间。没有新增登录链路或网页原生业务桥，密码仅保留当前操作内存。仅允许无账号口令的 HTTP(S) 链接；冷恢复只恢复同源地址。
- UI 继承 `MessagingTheme / HomeTheme`，原生表单、浅深色、辅助字号列表和独立44pt删除操作。匿名模拟器的手机／iPad 网格、编辑、密码和 AX3 截图确认后修正管理网格顶部对齐；表单说明与输入占位统一使用现有次级文字色，修正浅色低对比；验证密码保留原始空格，与创建输入保持一致。截图与独立审查见 `.impeccable/review/miniapps/`。

验证：`bash Tests/MiniApps/run-checks.sh` 的模型、Store、网页URL及浮窗协调测试通过；涵盖旧分页与删除竞争、上传期间退出、重复提交、密码恢复、同UID换认证和浏览子路径实例复用。`Tests/Chat/run-media-checks.sh`、`run-avatar-checks.sh` 及 `Tests/MigrationAcceptance/run-cloud-policy-checks.sh` 通过。完整 `ddlNew.xcworkspace` / `ddlNew` / Debug / generic iOS 无签名 build 为 `BUILD SUCCEEDED`，日志 `/tmp/ddlNew-miniapps-build-final3.log`。

验收边界：离线测试使用真实业务源码加边界替身，截图为匿名组件宿主，未操作真实账号或设备。服务端增删改／密码回执、真实图标云端上传、相机权限、网页下载及全 App 浮窗实际操作仍需账号与真机验收，不将编译和夹具检查当作这些结果。详细范围与计划见 `Docs/superpowers/specs/2026-11-09-my-apps-design.md`、`Docs/superpowers/plans/2026-11-09-my-apps.md`。

## 2026-11-09 补发 TLS 失败切换 DNS1 HTTP 候选与跨文件会话隔离

本轮真机控制台确认 `/biz/message/pushMsg` 在首选 HTTP 节点握手返回 -1200，因此没有可供弹框展示的业务文案。只读手机导航缓存确认 DNS1 元数据实际有 4 个 HTTP 候选，旧 `ossRacingModel.httpArr` 为空；现有 HTTP 周期择优读取旧字段且合并版本开关未开启。对候选执行不带账号或消息的探测：首选节点失败，其他候选可以返回 HTTP 401；这仅证明 HTTP 运输可达，不代表已收到真实宵禁响应。

保留 xgd 的 HTTP protobuf 补发与拒绝文案通知。`OSSConnectionPlan` 现在携带 DNS1 的真实 HTTP 候选，首次连接和刷新导航时同步给 SDK。消息补发捕获本轮候选；仅当前 HTTP 尝试返回 -1200 时，依次尝试其他 HTTPS 候选（去重、最多 16 次含首节点，共用原 60 秒截止）。不推算 TCP 端口、不改全局 API Host、不增加宵禁查询、不用登录旧文案推算状态；收到业务回包后仍按原流程展示服务端文案。每个 HTTP 尝试有独立标识，旧尝试的重复回执、已成功 ACK 和已退出会话不能启动下个候选或覆盖终态。

指定 HTTP 节点的请求仍保留原始消息载荷、账号头和路径签名，使用本次 request 的 ZTID；没有改动证书策略或 TCP 编码器。退出隔离另复现一项实际缺陷：`NoaIMRequestSessionFence.h` 内 static 关联键在 Socket 实现和请求分类两个编译单元里地址不同，退出失效不能覆盖消息回调。关联键改为运行时统一键，跨编译单元回归先在旧代码复现迟到提示，再验证修复。

验证覆盖 TLS 后取得 96305 原文通知、候选耗尽、去重、无降级、旧候选快照、重复回执、有效 ACK 优先、请求 URL/载荷/签名及跨文件退出隔离。补发专项、DNS1 集成（28 项）、会话恢复、会话维护专项通过；无签名 generic iOS Debug 构建成功（`/tmp/ddlNew-push-final-build.log`）。本轮只读检查真机，未向真实聊天发送测试消息、未覆盖安装。真机的实际拒绝回包及弹框仍需用修复包重发复验；候选切换不保证服务端一定返回 96305。

## 2026-11-09 宵禁弹框按 xgd 补齐 HTTP 拒绝原文

用户明确要求发送失败提示对齐 xgd：通用失败继续使用原始 protobuf 调用 HTTP `/biz/message/pushMsg`，收到正数错误码及有效文案时，经 `IMMessagePushRejected` 展示服务端原文。宵禁拒绝复用登录的 `curfewMessage` 和“提示／我知道了”弹框，发送失败不额外查询登录宵禁接口，也不缓存登录时的宵禁文案来推断当前状态。当前登录查询路径与 xgd 源码均为 `/auth/account/curfew`。

本轮发现并修复的差异：新端在 pushMsg 收到 HTTP 4xx/5xx 时传递空文案，xgd 会从响应字典或 AFNetworking 保存的原始响应体读取 `message`。已移植其解析和类型检查；空值、HTML 或非字典 JSON 不产生伪造提示，TLS 等无业务响应的失败保持原分类。

生产 HTTP 分支与 Socket 回调组合测试先在旧实现复现通知缺失，再验证字典/原始 JSON 中的宵禁文案可到达弹框通知。补发专项、会话恢复专项及无签名 generic iOS Debug 构建通过（构建日志 `/tmp/ddlNew-curfew-xgd-build.log`）。会话回归验证登录和发送共用提示状态、关闭后再次拒绝可重新展示、无额外宵禁查询及退出隔离。真机是否收到业务拒绝响应与弹框显示仍待复验；此前观察到的 TLS -1200 本身没有宵禁文案，本次解析修复不代表该节点的 TLS 已恢复。

## 2026-11-09 修复补发转 TCP 引入的请求头崩溃

Xcode 真机停在 LingIMTcpRequestModel.m 原第 397 行，Thread 17 抛出 `-[__NSFrozenDictionaryM setObject:forKeyedSubscript:]: unrecognized selector`。configHttpHeaderWithFullUrl 实际返回字典 copy，上一轮新增的 protobuf Content-Type 写入对不可变对象执行修改，直接造成崩溃。原离线夹具返回 mutable 字典，未覆盖这一运行时差异。

按用户要求逐段对照 xgd，MessagePushMsg 已恢复老端固定 HTTP 的实现，撤销上一轮在通用 TCP 请求编码器中新增的 protobuf 分支调整。通用发送失败补发、原消息载荷、拒绝回包提示、同轮去重和会话隔离继续生效。新增生产入口回归在旧实现复现走错 TCP 通道，修复后 8 种配置/连接/认证组合均只调用 HTTP，并保持原始二进制和服务端拒绝回调。

此节取代下文“已认证连接可用时补发走 TCP”的实现描述。此前真机 HTTP TLS -1200 是另一项已观察到的连通性问题，恢复 HTTP 本身不能证明该节点已能返回拒绝文案。修复包真机重发及实际 HTTP 响应待验。


## 2026-11-09 通用发送失败补发与 TLS 超时误分类

只读 Xcode 真机控制台确认消息补发已调用，但 HTTPS 握手连续返回 NSURLErrorSecureConnectionFailed（-1200），未取得业务拒绝响应。旧分类把此错误归为 Timeout，导致“发送超时，可重新发送”。新增末尾 SDK 枚举值 16 表示安全连接失败，UI 映射为“消息补发安全连接失败，请稍后重试”，历史枚举值保留。

按用户明确要求，pushMsg 是通用消息补发。对照 xgd 接入 trackChatMessage，TCP 密钥/认证未就绪、帧构建失败、提交时 Socket 断开、等待 ACK 超时、无效 ACK 均进入共用补发；有外网时尝试接口，无网络仍明确失败，同轮只提交一次。当前配置使用 HTTP 转 TCP，且已认证连接可用时，补发沿用该通道的 bytesBody；失去认证或连接时沿用 HTTP 补发。二进制请求跳过 JSON 序列化并明确 protobuf Content-Type，普通 JSON 请求行为保留。

生产方法离线回归覆盖通用失败入口、原始载荷、通道选择、服务器拒绝码/文案、ACK 优先及会话隔离。真机修复版是否收到 pushMsg 的实际拒绝响应仍待复验。


## 2026-11-09 宵禁发送拒绝提示对齐 xgd

对照老端 NoaIMSocketManagerTool 和 AppDelegate，聊天消息收到带本地消息 ID、缺少有效服务器消息 ID 的 ACK 时，立即复用原始 protobuf 调用 SDK 的 MessagePushMsg，实际路径沿用老端 `/biz/message/pushMsg`。超时后的补发复用同一个入口，同轮仅提交一次；补发期间已有超时检查不再重发 TCP。服务端失败码继续映射消息失败原因，96305 映射服务器拒绝；正数错误码附带非空文案时通过 IMMessagePushRejected 发布原文，登录会话接收后复用现有提示弹窗。

发送任务绑定已有 SDK 请求会话标识，退出及同 UID 重登后旧补发回执失效；有效 TCP ACK 和新重试也会撤销旧补发回调。观察者绑定登录轮次及 UID，退出清理，迟到通知不能覆盖下一账号提示。没有本地推算宵禁时段，真实结果以服务端为准。

新增生产方法提取测试覆盖异常 ACK 立即补发、同轮去重、96305 失败分类与原文通知、有效 ACK 优先以及同 UID 重登隔离；会话恢复、聊天基础、SDK 消息协议回归通过。真实宵禁账号发送、服务端返回和真机弹窗待验。


## 2026-11-03 登录成功后的宵禁提示

手动登录、注册后自动登录和缓存恢复共用 LoginSessionService 的 AUTH 成功入口，每轮会话在这里发起一次空参数 POST `/account/curfew`，由 SDK Auth 模块沿用现有 HTTP 或 HTTP 转 TCP 通道。首页进入不等待该接口返回。当前登录轮次和 UID 匹配且业务码为 96305、message 含非空白字符时，主界面弹窗展示服务端原文，点击“我知道了”关闭。清理会话时清除待展示消息。普通掉线重连不重新发起检查。

会话恢复离线测试覆盖 AUTH 失败、成功入口请求次数、其他错误、空消息、资料刷新、关闭提示和同 UID 重登后的迟到回包；注册流程回归通过。真实服务端回包及真机弹窗待验。

补充回归复现：旧账号的退出接口尚未返回时，已经通过 AUTH 的新账号收到 96305 却未显示。退出任务现绑定发起退出的登录轮次，仅屏蔽该轮次的提示。同一轮次的并发退出继续复用请求，迟到的旧回包无法覆盖新提示。无签名 iOS Debug 构建通过。本轮全量离线脚本 105/106 通过，日志脱敏测试夹具在编译既有 Socket 掉线日志时缺少 trace 和 NoaElapsed 等符号。

## 2026-11-03 登录后重连选点日志

真机 Debug 在 Xcode 筛选 `[IM掉线]`，按 `sdkRound` 串联一轮 SDK 选点。先看 `reconnect_cache` 的缓存候选总数（最多探测前 16 项），无缓存胜者且允许刷新时出现 `reconnect_refresh`。`dns1_plan` 列出本轮配置的来源顺序；逐项看 `dns1_source` 的读取、解析候选数、来源读取或解码失败、全体探测失败或首个 ECDH 成功。`reconnect_selection` 是业务层的选点结果，SDK 接受空结果时的 `reconnect_no_winner` 带原因及是否有旧地址；SDK 自身兜底也走此入口。正式连接与 AUTH 结果继续查 Socket 日志。新日志只记录阶段、轮次、来源类型、计数和原因码。

DNS1、DoH、导航集成、网络重连和 7 项 ECDH 回调离线回归通过。Debug 夹具已验证同轮主域探测全败、备域读取或解码失败、BIN 成功的日志顺序。真实掉线后的回退原因及最终 AUTH 恢复待真机复验。

## 2026-11-03 首次掉线与检查账号超时诊断

真机运行 Debug 包，Xcode 控制台筛选 `[IM掉线]`。每条正式 Socket 有独立的临时 connection 标识。从 authenticated 开始找同标识的第一条 disconnected（postAuth=1）或 local_close（如质量切换会主动移除旧代理）。对照前后的 network_path、app_background / app_foreground。断线快照保留 closeRequest、NSError 域和码、底层错误域和码、网络状态、App 状态与心跳信息。pingSubmitAgeSec 是距最近一次提交心跳写入的秒数，pongAgeSec 是距解析最近一次 PONG 的秒数，-1 表示本轮未观察到。closeRequest=none 表示未记录本地主动关闭。即便错误域和码表明远端关闭，具体关闭策略仍须核对网关／服务端同时间日志。

检查账号通过 TCP 发出时，按同一 traceId 串联 account_check_schedule、account_check_write_submit、account_check_response 或 account_check_timeout。写入提交阶段可以通过 connection 联查掉线。SDK 在进入发送调度前启动 15 秒计时器，当前重试上限 0；本地超时以 code=0 回调。提交写入不能证明服务端收到了请求。以上新增日志仅 Debug，未记录账号、Token、请求参数或消息内容。

## 2026-11-03 修复登录后 ECDH 回调中断重连

Xcode 控制台记录到首次 AUTH 成功，随后 Socket 断开。连续两次重连均回退旧节点，TCP 接通后在 ECDH 期间再次断开。SDK 排好下一次 4 秒退避后，又收到 ECDH 失败并执行 explicit_disconnect，取消了该次重连。首次掉线原因和探测回退原因仍未确定。

每次正式连接现在单独创建 Socket 和密钥管理器。异步生成密钥的回调和握手超时都在 Socket 代理所在的主队列核对本轮 Socket、连接和握手状态。当前握手失败时仅断开该 Socket，由原断线代理清理并安排重连；过期回调直接返回。

离线测试先在旧实现复现迟到回调触发全局断开，修复后 7 个 ECDH 回调场景通过（`Tests/Network/run-ecdh-callback-checks.sh`）。既有网络重连和质量检测回归通过，workspace 无签名 generic iOS Debug 构建成功。修复版真机长时间运行后的自动重连与 AUTH 恢复待验。

## 2026-11-03 消息列表左滑删除与标记未读

对照 xgd 的 `sessionDeleteWith:` 和 `sessionUpdateReadedStatusWith:isClear:`，两项操作按 SDK 成功回调更新本地会话，允许空载荷及非布尔成功数据，显式数值 false 或失败回调仍报错。标记未读优先提交最新正文 SID，清除未读沿用原计数边界。删除确认绑定选中的会话；回执到达时分别核对会话 SID、正文 SID 和会话时间，期间进新消息则保留会话，否则只删会话、不删聊天记录。生产操作方法离线回归涵盖空字典标记、空回执删除、两份 SID 原本不同及删除期间进新消息。实际服务端回包、真机左滑效果待验。

## 2026-11-03 移除群发助手

App 已删除群发助手页面、菜单与导航、角色权限项、历史及收件人管理、专用发送和 SDK 适配层，原临时版本开关同步删除。SDK 会话适配器读取旧缓存时跳过类型 3，普通单聊、群聊、文件助手沿用原映射。底层 IM SDK 保留服务端协议兼容；下文 10 月 23 日接线记录仅为历史。

## 2026-11-03 单聊设置增加投诉入口

单聊“聊天设置 → 投诉与支持”打开现有用户投诉表单，目标为对方 UID。从群成员资料发起单聊时传递来源群 ID，沿用提交时的群访问校验。本人及文件助手不显示用户投诉入口。聊天设置 14 项及投诉专项离线检查通过，无签名 iOS Debug 构建通过，真机提交待验。

## 2026-11-03 注册页协议确认

账号注册页与登录页共用《隐私政策》和《使用支持》的勾选及阅读入口。每次打开注册页默认未勾选，阅读网页不会自动同意。未勾选点“注册并登录”先弹提示，取消保留表单且不发请求，“同意并继续”勾选后提交本次注册。注册成功但 AUTH 失败时仍可直接返回登录。此行为更新了 10 月 19 日记录中的注册页边界。

注册与登录协议离线检查通过，通用 iOS 设备目标无签名 Debug 构建通过，真机交互待验。

## 2026-10-28 我的页面个人头像与昵称编辑

当前分支 `feature-message-4`，开工 HEAD `e52ff45`，保留前序聊天、资料页等未提交改动。按用户要求只读参考 xgd 的 `NoaUserInfoViewController`、`NoaChangeUserInfoViewController`、`NoaFileUploadTools`。我的头像与昵称可点击打开“编辑个人资料”，头像/昵称可改，账号只读；沿用当前森林绿、UIAdapter 和原生导航。未新增修改账号功能。

头像使用原生单图相册/拍照与方形编辑，输出200×200 JPEG、最多50KiB；用户取消选图不上传。上传复用现有媒体运输、STS与XOR包装，新增内部个人头像类型103（非聊天wire类型），云目录 `avatar/`、Minio `/zim/avatar/`，不套用聊天发送配额、不生成聊天消息。工程Debug/Release补充 `NSPhotoLibraryUsageDescription`，相机用途文案包含头像。

昵称编辑以当前资料初始化草稿，过滤英文单引号及右单引号、去首尾空白，空白/未变化/超过30个UTF-16单位/提交中禁用保存；不截断中文输入法组词或Unicode字符。复用SDK `userNicknameChangeWith`、`userAvatarChangeWith` 的真实受理接口。成功后合并进唯一 `UserSessionStore` 并持久化，昵称同时调用 `configNewUserNickName`；我的/设置及本人聊天头像原有观察随之更新。失败保留草稿和旧头像，不立即拉取可能尚未更新的资料覆盖保存结果。

`OwnProfileStore` 与 `SDKOwnProfileClient` 使用本次UID、租户、AUTH轮次，上传和修改接口前后复核；页面关闭、根退出/换号取消等待，迟到回执不写新账号。临时裁剪文件由上传操作接管，完成/失败/取消清理。`UserSessionStore.profileRevision` 与维护请求起点版本比较，拒绝早于主动保存发起的旧资料回包；后续正常维护仍可接受跨端新资料，角色刷新继续执行。

验证：生产Store21项、SDK方法边界16项、生产维护时序3项、Minio目录/配额7项通过；云策略扩展后19项、媒体包装与四供应商签名、既有维护17项/角色资料21项/SDK请求隔离7项回归通过。维护旧实现已用相同夹具复现覆盖新资料（`/tmp/ddlNew-mine-refresh-before.log`），新实现通过。SDK/维护测试仅替换网络与系统边界，不连接真实账号。首轮与终版workspace无签名generic iOS Debug构建均exit0、`BUILD SUCCEEDED`（终版`/tmp/ddlNew-mine-profile-final-build.log`）；终版已修正本轮弱引用警告，实际App Info.plist已核验相册读取与相机头像用途文案。构建环境排除sentry-cli，未上传符号或源码。只读代码复核未发现范围内可确认的阻断问题；`git diff --check`通过。

本轮未操作设备、未上传真实头像或提交真实昵称、未提交/推送。真机仍需重新Run验收：我的头像/昵称入口、相册/相机首次授权与拒绝、方形裁剪取消/确认、头像上传失败、昵称中文/emoji/长度限制、成功返回及我的/设置/本人聊天更新、重启持久化和账号切换。实现计划 `superpowers/plans/2026-10-28-mine-profile.md`，专项入口 `Tests/Mine/run-*.sh`。

## 2026-10-27 用户暂停消息列表返回偏移；移除资料页菜单重复入口

当前分支`feature-message-4`，HEAD `e52ff45`。此前聊天历史/状态3/撤回占位及名片等修正仍在工作区，未提交/推送。

### 消息列表首次返回偏移：用户明确不再修改

用户反馈消息列表滚到最底部露出群发助手，进入任意聊天再返回，群发助手向下偏移；补充确认“只偏移一次，后续位置稳定”。随后用户明确说“**不改这个问题了**”，本问题已停止，后续不要自行继续实施。

已完成只读源码检查和临时匿名模拟器验证。匿名宿主沿用生产列表、行布局、Store与相同的TabView/NavigationStack组合，以无后端假数据替换登录/头像等边界。iOS27模拟器测到第一次返回时内容高度和行高度不变，底部adjustedContentInset由83临时降至34，contentOffset同步减少49；底栏恢复83后offset没有回补，复现末行下移。仅给首页添加`.toolbar(.visible, for: .tabBar)`的临时试验仍有同样偏移，不能作为有效修复。

后续“仅记录离开前已贴底、待底栏恢复后无动画还原”的候选实现只写在`/tmp/ddlNew-message-scroll-host/`，尚未完成运行验证时用户叫停，**没有复制到正式源码**。`MessageView.swift`、`ConversationsStore.swift`、`ActivityNavigationScope.swift`均没有本轮生产改动；没有安装/操作真实账号设备。临时宿主与日志位置`/tmp/ddlNew-message-scroll-host/`（`before.log`、`fixed.log`）；不要将临时方案或匿名测量当作生产修复/真机验收。

### 用户资料右上角菜单：已移除“备注与描述”

用户另行明确要求删除用户资料右上角菜单中的“备注与描述”。已仅移除`ContactRecordDetailView.swift`菜单内对应Button。资料正文“备注”“描述”两行仍使用原编辑sheet，编辑功能保留；其它菜单及用户先前“投诉与支持”的位置改动保留。

此单行UI修改已源码核对并通过`git diff --check`；未为该菜单删除单独重新构建或真机点击验证，不能沿用前面撤回修复的构建当作本次菜单改动的构建证据。本轮只更新交接并保留菜单修改，不继续处理列表偏移，不提交/推送。

2026-10-28 编译修复：当前工作区缺失 `ContactRecordDetailView` 的 `@State private var editing = false`，但正文备注/描述按钮、编辑 sheet 及 Toast 条件仍引用该状态，导致找不到 `editing` / `$editing` 和视图类型检查超时。仅补回状态声明，右上角菜单仍不显示“备注与描述”，原有静默加载及投诉入口调整保留。修复后 workspace 无签名 generic iOS Debug 构建 exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-contact-editing-build.log`），通讯录业务离线检查通过（`/tmp/ddlNew-contact-editing-business-checks.log`），`git diff --check`通过。构建环境排除 sentry-cli；未操作设备、未提交/推送，编辑弹窗真机交互未在本轮复验。

## 2026-10-27 撤回占位首屏缺失、补拉后才出现

用户提供`/Users/taobotaobo/Downloads/ScreenRecording_10-27-2026 13-44-05_1.MP4`（7.858秒），反馈已有撤回消息的聊天首次内容少一部分，随后才插入“消息已撤回”。已用AVFoundation抽帧查看进群/单聊过程，当前帧与拼图在`/tmp/ddlNew-recall-recording/`。只读Xcode控制台确认重复进入群聊`rawRemoteStatus=[1:42,2:18,3:3]`、`cached=24`、最终`visible=42`；单聊`cached=19`、最终`visible=22`并有3条原始状态2，差额与撤回原条一致。

根因是SDK原本正常历史查询只读取状态1，排除了已持久化的状态2。已有`ChatRecallCache`只能在本地页包含type8撤回控制条时补回原条；新端历史处理可只保存状态2的原条而不另存控制条，因此不能保证首屏占位完整。这与上节状态3误映射是两个独立问题，不能用恢复状态3展示解决。

新增SDK只读聊天时间线查询`toolGetChatMessageTimelineWith`与DB查询`getChatMessageTimelineWith`，在同一SQL分页窗口读取状态1/2，仍按sendTime及serviceMsgID降序取100条并反转给Swift。`SDKChatClient.cached`统一使用该查询，使首屏、网络后回读、离线及更早分页包含撤回占位，offset仍对应真实查询窗口；原正常历史查询、搜索、媒体和会话摘要路径未扩大范围。已删除0、服务端删除3及其他未知状态仍被排除。已有控制条的去重回填保留，没有增加等待网络、Toast或隐藏列表过程，也没有数据迁移/修改消息状态。

回归新增单聊/群聊连续两次进入时网络返回前显示撤回占位、返回前后ID序列不变、离线仍显示，以及205条正常/撤回交错记录跨100条分页不重不漏。修复前78/94（16项失败，`/tmp/ddlNew-recall-first-page-red.log`），修复后94/94（`/tmp/ddlNew-recall-first-page-green.log`）。测试提取生产cached/history/Store、生产Mapper状态表达式和真实DB查询的状态谓词，避免只测另写的过滤逻辑；SDK数据库/运输仍是夹具，不能等同真机执行。首屏25项、撤回缓存5项、语义13项和聊天基础回归通过。未安装/操控设备、未提交/推送；修复后真机首屏仍待用户重新Run验证。

最终workspace无签名generic iOS Debug构建exit0、BUILD SUCCEEDED（`/tmp/ddlNew-recall-first-page-build.log`），真实SDK Objective-C/Objective-C++新增查询和Swift调用均编译通过；git diff --check通过。构建排除sentry-cli，未上传符号或源码。

## 2026-10-27 用户确认进群不再闪现；补充状态3协议线索

用户明确反馈“现在聊天不闪现了”，这是修复后用户侧实际进群反馈；没有据此扩大为全机型/全部聊天场景验收。本轮未再修改生产逻辑。

进一步检索状态定义发现此前只看消息模型字段注释（0删除/1正常/2撤回）不够完整：本仓库和xgd的`NoaIMSDKManager+ChatMessage.h` / `NoaIMHttpManager+Message.h` 的recallMessage接口参数说明、xgd `NoaChatViewController.m` 撤回请求处均注明服务端消息状态“1正常、2撤回、3删除”。这为服务端status3属于删除状态提供了现有接口文档依据，但历史响应模型注释仍写0删除，协议说明存在不一致；未访问服务端实现/操作审计，不能断言这13条由谁、何时、以单向或双向方式删除。此前“状态3没有找到定义”应以本节补充为准。当前展示修复不依赖猜测删除发起者，也没有发删除请求或改写服务器状态。

## 2026-10-27 确认服务端状态3被误映射为正常，并修复重复进群补入闪现

用户再次Run进入测试群001，Xcode实际日志为`rawRemoteStatus=[0:1,1:46,3:13] preservedLocalToRemoteStatus=[]`，回读缺少的13条仍为状态3（11图、2视频），SDK写入/主键诊断均为0。至此排除上节“本地3被较新ACK保护”的假设：本次13条原始状态3来自服务端，新端`ChatMessageStatus(rawValue:) ?? .normal`将它们误当正常，直接合并的远端内容把页面从46条补到59条。xgd的SDK历史查询仅返回`messageStatus == 1`，不存在这个错误的正常状态兜底。

修复：未知SDK状态映射成客户端`.unavailable`，不推断状态3的服务端业务含义；聊天Store各发布路径和气泡可见性统一排除不可用状态，引用不再展示其原媒体正文。SDK仍保留原始状态3，不改成正常或删除，不操作真实聊天数据。正常状态1的图片、写库失败但已有效收到的图片、页外正常历史仍按原规则保留；正常与撤回占位既有行为不变。后续服务端真正恢复状态1时可重新落库/显示，不屏蔽消息ID。

移除临时cacheAudit主键计数与逐条诊断回读，只保留不含身份/正文的DEBUG分页与原始状态分布，避免再次用归一化后的统计误判。没有增加等待、Toast、透明度切换或额外网络请求。

回归使用从生产Mapper抽取的真实状态表达式和生产history/ChatStore方法，SDK边界夹具保留原始整数状态，复现60条的真实分布并连续进入两次。修复前70/78（8项失败，`/tmp/ddlNew-status3-red.log`），修复后78/78；覆盖首屏/补拉均46条、不改写原始3、不可用引用不泄露正文、后续恢复正常仍显示，以及既有正常图片不丢。另有首屏25项、语义13项、预览失效12项、撤回缓存5项、聊天基础与SDK消息协议回归通过。相关日志`/tmp/ddlNew-status3-run-*.log`。这是离线回归，修复版真机视觉尚未再次验收；未安装/操控设备、未提交/推送。

最终DEBUG分支同样78/78通过（`/tmp/ddlNew-status3-debug-checks.log`），日志证明原始分布不变时最终visible保持46。workspace无签名generic iOS Debug构建exit0、BUILD SUCCEEDED（`/tmp/ddlNew-status3-fix-build.log`），git diff --check通过；构建排除sentry-cli，未上传符号或源码。

## 2026-10-27 真机诊断定位到SDK原始状态3

用户重新Run并进入测试群001后，Xcode控制台实际输出：`writeFailures=0 emptyPrimaryKeys=0 changedPrimaryKeys=0 duplicatePrimaryKeys=0`，`missingNormal=13 missingImages=11 readbackStatus=[3:13]`，缓存仍46条、Swift显示59条。因此不是此次SDK写库返回失败或空/重复主键；13条消息实际保存在库中，但状态3被SDK的`messageStatus == 1`查询排除。

进一步核对发现上一版`remoteStatus`统计的是Swift映射后的枚举，`SDKChatMessageMapper.record`对0/1/2以外的原始状态全部兜底`.normal`，所以`remoteStatus=[0:1,1:59]`不能证明服务端原始状态是1。尚需区分“服务端返回3而Swift误展示”与“服务端返回1但本地3被保留”。本轮补上DEBUG转换前`rawRemoteStatus`与策略保留的`preservedLocalToRemoteStatus`聚合统计，不输出身份或正文，不改展示/落库规则。

本地另用临时夹具复现一种可能路径：本地3映射成normal且时间比服务端新，会被keepCurrent的较新ACK保护，首次显示但第二次仍从缓存缺图；该夹具有6项失败，保存于`/tmp/ddlNew-raw-status-hypothesis-checks.swift`和`/tmp/ddlNew-raw-status-red.log`。这只是可复现分支，不是该真机13条的确定根因，未据此修改生产逻辑，也未把假设用例留为仓库失败测试。旧端历史回写使用服务器模型，仅保留本地翻译和小幅时间差，没有把未知状态转为正常后参与缓存保护。

新增诊断的DEBUG历史检查60/60通过，日志`/tmp/ddlNew-raw-cache-diagnostic-checks.log`；workspace无签名generic iOS Debug构建exit0、BUILD SUCCEEDED（`/tmp/ddlNew-raw-cache-diagnostic-build.log`），git diff --check通过。构建排除sentry-cli，未上传符号或源码。需要用户再Run一次读取原始状态后选择修复；设备操作仍由用户完成，未提交/推送。

## 2026-10-27 录屏确认首屏反复补齐，缓存持久化仍待定位

用户提供 `/Users/taobotaobo/Downloads/ScreenRecording_10-27-2026 11-25-08_1.MP4`，4.355秒。使用本机AVFoundation抽帧检查：约2.5～2.9秒进入页面先出现语音/视频与末尾“T”，约3秒图片补入后把较早语音挤出视口；末尾位置基本稳定。这份录屏主要证明缓存与补拉内容不一致，不能继续笼统归因为首次滚动到顶部。分析帧在 `/tmp/ddlNew-chat-recording/`，未修改原录屏。

通过CUA只读查看Xcode既有控制台并筛选 `[ChatHistory]`，未操作手机或重启App。多次进入重复出现 `rows=60 mapped=60 cached=46`、`remoteStatus=[0:1,1:59]`、`localStatusConflicts=13`、`mappedStatus=[0:1,1:59]`、`mappedType=[0:39,1:14,2:4,4:3]`、`finish received=60 visible=59 offset=46`。真实日志将问题收窄到本机回读与远端正常记录相差13条，且状态校正未稳定保留到下次首屏；目前尚不能区分SDK写入失败、主键问题或回读排除，不能宣称根因已修复。

本轮仅在 `SDKChatClient.history` 增加待诊断完成后移除的DEBUG计数：写入失败数、空/变化/重复主键数、未进入缓存的正常消息/图片数、按服务端ID再次读取的状态分布及缓存类型分布。没有输出UID、群ID、消息ID、聊天正文或媒体地址，没有更改历史返回内容、加载策略或任何消息状态规则。Xcode控制台当前保留 `[ChatHistory]` 筛选，用户重新Run并进群后可直接读取新增 `cacheAudit` 两行，无需用户复制敏感日志。

带DEBUG诊断分支的生产历史离线检查60/60通过（`/tmp/ddlNew-cache-diagnostic-checks.log`），workspace无签名generic iOS Debug构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-recording-cache-diagnostic-build.log`），`git diff --check`通过。构建环境排除sentry-cli，未上传符号或源码。当前需要新包的一次真实进群日志才能选择修复；未安装/运行设备、未提交/推送，不能把诊断构建当作闪现问题已解决。

## 2026-10-27 修复首屏过滤导致图片消息缺失的回归

用户反馈“测试群001”中原先可见的两张本人图片在上轮改动后整条消失。检查确认上一轮新增的 `initialPage/pageUpdates` 过滤有漏消息缺陷：仅保留本地回读页及请求前本地页已知ID的远端结果，导致本地100条窗口之外、或SDK写库/回读未返回的有效远端消息被直接排除。此前分页检查错误地把“丢弃页外有效远端消息”当作正确行为，未覆盖图片缺失场景。本节撤销下节“首屏只按本地最新页裁剪”的实现与验收结论。

已移除这层过滤与额外的首轮缓存读取，恢复本地回读和本轮有效远端结果的双ID去重合并。映射前的账号/会话检查、请求期间删除保护、状态校正及实时消息合并继续生效；保留本地优先展示、群权限独立刷新、整页一次发布、已显示正文不重新隐藏等前述修正。没有针对图片放宽删除规则，也未在真实聊天上执行删除、清库或补写数据。

新增单聊/群聊两张本人图片被本地100条窗口挤出、SDK写库失败回读缺失、资源路径保留和双ID去重检查；修复前生产历史链路50/60通过，图片等10项失败（`/tmp/ddlNew-missing-images-red.log`）。修复后历史60/60通过，首屏25项、首屏定位11项、消息定位Store12项/布局12项及聊天基础回归通过，汇总 `/tmp/ddlNew-missing-images-results.json`。此为匿名夹具对真实SDK适配方法的回归证据；没有读取测试群001两条实际记录，不能据此声称已确认其服务器状态或真机恢复，仍需重新Run复验。设备操作继续暂停，未提交/推送。

最终workspace无签名generic iOS Debug构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-missing-images-build.log`），`git diff --check`通过；构建环境排除sentry-cli，未上传符号或源码。

## 2026-10-27 按 xgd 完整历史加载链路对齐

用户指出前两轮仍未完整对齐，随后明确要求对齐。重新沿 xgd `NoaChatViewController.requestHistoryList` 追到 SDK `messageGetHistoryRecordWith` / `messageRequestHistoryRecordWith`：无游标时先回调本机100条，再独立同步服务端第一页并落库回读，仅发现本地/服务端双ID均未知的消息才再次通知列表；页面增量合并、同步计算行高后无动画对齐，已经展示的正文不重新隐藏。旧端的群资料查询不作为历史请求的前置条件。本节取代前两节关于补齐时重新隐藏和群资料串行等待的实现边界。

新端继续使用当前SwiftUI/Store和带身份校验的SDK请求，不直接调用可能在旧账号回调中写库的旧helper。`SDKChatClient` 将群资料/禁言改为聊天持有的独立任务，历史请求不等待其结果；重复分页共享在途权限查询，权限事件可使旧任务失效，关闭/同群重进隔离迟到回调。主动操作的新核权取消后台旧核权，防止旧失败覆盖新成功。权限未确认仍禁止发送/上传，但不当成已经确认的禁言提示；失败独立反馈，消息正文不受影响。

首轮远端数据落库后回读本机最新页，移除将页外远端旧条额外灌进当前列表的行为；原先已显示消息的撤回/删除/已读等校正仍返回，保留新端已有的状态同步与期间变更保护。`ChatStore` 以本机ID/服务端ID判断新增消息，只有新增才增加首屏定位版本；同ID状态变化仍更新对应消息，不重启首屏定位。`ChatRoomView` 仅首次展示前等待有效布局，后续增量补齐保持正文可见，使用对应批次布局无动画对齐，用户翻阅后停止初始跟随。后续分页合同保持原实现，没有恢复旧HUD或固定延时。

验证：新断言先复现群资料失败阻塞历史、后台补齐隐藏正文、同ID状态更新重启定位以及首屏灌入页外旧记录，红灯日志 `/tmp/ddlNew-xgd-history-client-red.log`、`/tmp/ddlNew-xgd-history-presentation-red.log`、`/tmp/ddlNew-xgd-history-window-red.log`。修复后首屏25项、历史分页52项、首屏定位11项、消息定位Store12项/布局12项、滚动16项、群发送权限14项、已读SDK集成8项及聊天基础回归通过，9个脚本汇总 `/tmp/ddlNew-xgd-alignment-results.json`；独立权限任务追加主动核权覆盖后最终11/11通过（`/tmp/ddlNew-xgd-group-startup-final.log`）。设备操作继续暂停，未提交/推送；这些是生产代码的离线时序与SDK边界检查，实际设备首屏耗时、无动画定位及后台补齐时的视觉稳定性仍需重新Run验收。

最终workspace无签名generic iOS Debug构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-xgd-history-alignment-final-build.log`），`git diff --check`通过；本轮SDKChatClient无新增编译警告，既有SDK桥接头警告保留。构建环境排除sentry-cli，未上传符号或源码。

## 2026-10-27 聊天首屏显示速度修正

用户实测上一轮已不闪历史，但正文出现太慢。原因是上一轮将整个首屏绑定到网络历史请求结束；群聊历史还先等待群详情。此节取代下节“必须等待首轮补拉后显示”的方案。再次对照 xgd 本地先展示、远端增量合并的流程，新端本地可见缓存读出后即生成首屏布局版本，定位到底部就显示，远端请求继续后台执行。无可见缓存时仍等待首轮结果；不新增延迟或loading Toast。

`initialHistoryRevision` 区分本机和远端补齐后的首屏快照；末尾几何携带同一批消息捕获的版本，页面记录已对齐版本。补齐导致内容变化时只等待该批次的布局及无动画底部定位，不允许旧布局放行新正文；内容完全相同不增加版本、不重新遮挡。用户已经开始翻阅时不重启首屏遮挡或强制定位。历史页继续逐条执行既有合并/撤回/迟到回调保护，但整页只发布一次消息数组，减少重复界面更新。关闭重进继续隔离旧请求。

验证：网络请求悬挂时缓存已定位却仍不可见的新增检查先失败（`/tmp/ddlNew-fast-history-red.log`），修复后首屏时序22/22通过（`/tmp/ddlNew-fast-history-green.log`），包含缓存立即显示、旧几何拒绝、后台整页一次发布、无变化回包、在途实时消息、用户翻阅、空缓存与关闭重进。首屏定位11项、历史分页47项、消息定位Store12项/布局12项、滚动16项及聊天基础回归通过，汇总 `/tmp/ddlNew-fast-history-results.json`；workspace无签名generic iOS Debug构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-fast-history-build.log`），`git diff --check`通过。构建环境排除sentry-cli，未上传符号或源码。设备操作继续暂停，未提交或推送，真实设备耗时和后台补齐瞬间的视觉表现待重新Run验收；离线检查证明本机首屏不再等待网络，不代表测得真机毫秒数。

## 2026-10-27 聊天首屏缓存闪现修复

用户反馈进入聊天先闪现少量历史，再显示补齐后的消息。源码时序复现：`ChatStore.open` 先发布本地缓存、随后异步拉取首轮历史；少量缓存的底部已在视口内时，`ChatRoomView` 会提前设置 `didInitialScroll` 并展示正文，后续合并历史时仍保持可见。只检查末条ID也不足以区分补拉前后的布局，因为补齐较早消息时末条ID可能不变。

按用户要求只读对照 xgd `NoaChatViewController` 的 `dealChatMessageHistoryWith:offset:`、`scrollInitialHistoryToBottom` 和 `alignInitialHistoryToBottomIfNeeded`：旧端合并消息、计算行高后刷新，并在布局回调无动画对齐底部。新端新增 `ChatStore.hasLoadedInitialHistory`，首轮请求结束（含失败回退）后才允许显示正文，关闭会话重置，后续分页不重置；回调仍校验当前generation和context。末尾布局快照同时携带与该批消息一起捕获的首轮完成状态，避免旧缓存布局提前放行；完成新布局和底部定位后再显示正文、更新可见已读和游戏播放。空会话无需等待不存在的末条；首轮失败保留缓存和原有错误反馈。没有新增固定延迟、loading Toast或网络请求，正文等待沿用现有首轮请求及超时边界；慢网络下可能需要等待该请求结束。

验证：新增真实 `ChatStore` 加生产视图放行/定位逻辑的离线时序检查，修复前8/16通过、修复后16/16通过，覆盖缓存、在途实时消息、同末条ID补历史、新布局、分页、离线、空会话和关闭重进后的迟到回调。首屏定位、历史分页、消息定位、滚动性能和聊天基础检查也全部通过，共6个脚本exit0，汇总 `/tmp/ddlNew-first-screen-results.json`。workspace无签名generic iOS Debug构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-initial-history-build.log`）；构建环境排除sentry-cli，既有SDK警告保留。Mobile MCP继续暂停，未做设备视觉验收、未提交或推送；需重新Run验证首次/再次进入、长历史、弱网及搜索定位进入的实际画面。

## 2026-10-27 聊天名片气泡与 xgd 对齐

用户随后要求点击用户进入资料页不显示loading Toast：`ContactRecordDetailView` 的资料读取和黑名单查询改为静默加载，主动提交操作的loading、业务失败/结果和复制反馈保留；共用资料页的各入口一致生效。该调整无签名generic iOS workspace构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-profile-silent-loading-build.log`），`git diff --check`通过；未操作设备。

按用户要求只读对照 xgd `NoaMessageCardCell`、`NoaMessageModel.calculateNameCardMessage`、`NoaMessageContentBaseCell` 和聊天名片点击方法。原新端已映射 `cardUserId/cardNickName/cardHeadPicUrl`，但气泡落入普通文字分支，只显示“[名片] 昵称”。新增 `ChatContactCardContent`：40点圆形头像、昵称、分隔线与“个人名片”，正文最大230点加左右各10点留白、默认高度85点；窄窗可收缩，辅助字号可换行增高。收发名片均使用中性卡片底色，沿用项目浅深色、森林绿细节和 UIAdapter；本人名片定位描边改用强调色，避免白色描边融入卡片。

整卡使用显式按钮接原 `activateMessage`，依据名片UID打开用户资料，不使用发送者UID或来源群；发送者外侧头像仍打开作者资料。名片头像使用消息快照中的被推荐用户头像，并复用当前文件Host、Kingfisher和旧格式图片处理器；缺失/失败显示默认头像。缺少名片UID的卡片禁用资料按钮。原资料推荐入口、真实推荐接口、接收人选择及删除/引用/撤回权限保持既有实现，没有新增聊天底栏名片入口。

验证：名片/消息可见性11项、资料导航12项、消息操作10项通过，日志 `/tmp/ddlNew-contact-card-parity.log`、`/tmp/ddlNew-contact-card-navigation.log`、`/tmp/ddlNew-contact-card-actions.log`。生产卡片布局经macOS ImageRenderer替换网络头像边界后检查收发、320pt长昵称、深色、宽屏和空昵称；这是静态布局证据，不代表真实iOS Dynamic Type、下载、VoiceOver或点击验收。预览在 `/tmp/ddlNew-contact-card-preview/`。最终workspace无签名generic iOS构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-contact-card-final-build.log`），既有SDK umbrella/桥接头警告保留；本轮三个Swift文件无新增编译警告，`git diff --check`通过。Mobile MCP继续暂停，未安装或操作设备、未发送真实名片、未提交或推送；重新Run后需验证收发名片外观、整卡进入对应用户、返回原聊天位置和长按菜单。

## 2026-10-26 清理未使用的腾讯播放器依赖

按用户要求移除 `Player_SwiftPM`：删除应用 target 的 Frameworks 链接项、package product、远程包引用，并由 Xcode 重新解析 `Package.resolved`。仅移除腾讯播放器，剩余24个包的版本及revision保持不变。应用与自有SDK未发现腾讯播放器导入、初始化、播放或动态调用；聊天视频仍使用 `ChatPhotoBrowserPlayback` 的系统 `AVPlayer` 和 `ChatPhotoBrowserVideoCell` 的 `AVPlayerViewController`。

验证：依赖解析、工程格式检查、视频播放专项11/11及 `git diff --check` 通过。独立目录的无签名generic iOS Release构建exit0、`BUILD SUCCEEDED`，日志 `/tmp/ddlNew-tencent-removal-release.log`；产物 `/tmp/ddlNew-tencent-removal-release/Build/Products/Release-iphoneos/ddlNew.app` 全包文件名、23个Mach-O的动态链接和字符串扫描均无腾讯播放器相关命中，确认没有 `TXLiteAVSDK_Player`、`TXFFmpeg`、`TXSoundTouch`，结果 `/tmp/ddlNew-tencent-removal-scan.json`。Release包也未包含仅Debug使用的WoodPecker；既有SDK桥接头警告保留。构建环境排除sentry-cli，未上传符号或源码。此证据为本地Release build，不是签名Archive/提交IPA或真机播放验收，也不代表其他SDK的IP检测/远程配置问题或整项2.5.19审核已通过。保留用户已有 `Info.plist` 修改及期间出现的Sentry空traits工程配置，未操作设备、未提交或推送。

收尾时HEAD已前进到 `b0974d8`，腾讯播放器移除及同期工程/Info.plist改动已包含在该提交；本助手未执行commit/push。当前仅最终验证结果的交接文档补充待提交。

## 2026-10-26 消息分支移植本地配置与DNS1单一路径

将 `feature-IMSDK-2` 的 `bcbf948`、`2ebfd50` 语义移植到 `feature-message-4`，保留消息分支的群聊、附件上传、音视频通话、资料/角色维护、HTTP Host发布和身份/取消隔离。以本节取代10月22日五路兜底与历史系统配置刷新说明。

用户提供的guest两次及authenticated一次日志15字段一致。已写入 `Configuration/LocalMessagingSettings.swift`：群发送间隔1000ms、本人撤回5分钟、群管理员撤回他人关闭、普通成员查看人数受限（角色showGroupPersonNum豁免保留）、通话开启、供应商Zego、AppID40878197；存储选阿里云，桶u260711-2，Endpoint为https://oss-accelerate.aliyuncs.com，区域cn-hongkong。华为OBS四项原值也保留供本地切换使用，当前不参与阿里路由；既有上传实现会将HTTP上传域名升级HTTPS。没有写入appSign、secret、Token或临时STS凭据。上传临时资格与通话房间Token仍由原服务端业务流程获取。

`LocalAccountPolicy` 和 `LocalSDKSettings` 沿用源提交固定值，登录/注册/改密均使用本地规则；正式TCP/ECDH成功后应用本地tenantCode才宣布登录就绪。登录协议UI与ViewModel共用一个同意状态，确认继续与消息分支Toast保持。系统配置请求/模型/缓存依赖、SDK相关入口和临时 `[LocalConfigExport]` 日志删除。登录后会话维护继续刷新真实用户资料、角色权限及密码安全，不再刷新配置；AUTH成功且轮次核验后先配置本地通话再订阅来电，退出清除通话所属身份。

导航只保留DNS1缓存、t主域、备域及BIN；阿里DNS SDK改为源提交的签名DoH请求，移除五路、旧OSS Auth/HTTP降级、业务IP采集与DNS报告，以及TBBasicLib/AlicloudPDNS依赖。已登录业务重连截止35秒，SDK兜底40秒。保留当前分支的本轮已探测节点交接、HTTP Host观察和回调归属验证；TCP-only不推算HTTP。旧缓存不复用节点，但保存新导航时独立保留已成功的邀请码入口，避免升级后的正式握手失败导致入口丢失。

验证：最终无签名generic iOS workspace构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-local-config-final-build.log`），仍有既有SDK桥接头missing submodule警告。离线全套101组首轮98组通过，3组因已删除配置接口/解析器的测试依赖失败；适配后针对失败项与新增覆盖复测，最终101/101通过，保留首轮与复测证据（`/tmp/ddlNew-local-config-qa/final-summary.json`）。DNS1真实Protobuf/ObjectMapper集成26项、通话状态54项、群发送策略12项、云路由/权限16项通过；覆盖升级旧source只保留成功入口、未归属HTTP回调拒绝、固定Zego初始化/清理、1秒间隔与实际阿里桶路由。静态移除扫描及App/NoaChatCore产物入口扫描通过，`git diff --check`通过。完整Debug包扫描在既有仅Debug使用的WoodPeckeriOS中命中getIPAddresses，不能据此宣称全包或Release扫描已通过；未改动该调试工具。未操作设备、未真实发消息/上传/通话，未提交或推送。下一步由用户重新Run验收冷启动/换企业/登录恢复、断线重连、撤回/群人数、阿里上传及Zego通话。

用户另外要求给桌面 `getSystemConfig.md` 加注释：原15字段和值保留，已改为带JSONC代码块的说明文档，并另存 `getSystemConfig.jsonc`；这些是仓库外文档。

## 2026-10-23 我的入口精简与设置页重设计

用户要求删除“我的”主页面的“隐私与安全”功能：已移除入口、分隔线、回调、页面状态与说明弹层接线，并同步HTML设计稿；账户与支持分组保留黑名单、投诉与支持。

用户随后明确要求设置页直接按已确认森林绿风格实施。`SettingsScreen` 改为可滚动卡片布局，新 `SettingsPageContent` 仅负责展示：薄荷绿当前账户卡、隐私与支持、账户管理及独立退出按钮。顶部直接观察 `UserSessionStore.currentUser` 的真实昵称/账号，清除演示昵称、会员卡号及旧活动账号来源；缺昵称回退真实账号，退出不保留旧身份。使用 HomeTheme 浅深色、语义字体及 UIAdapter 几何适配，辅助字号账户卡纵向，长文本可换行增高。

设置中的“隐私政策”和“使用支持”继续打开原 `LegalDocumentScreen`；注销进入原 `DeleteAccountScreen`，退出仍先确认再调用既有 `store.signOut()`，完成按钮继续关闭设置。未新增接口、未修改注销/退出业务流程，也未执行真实退出或注销。

验证：最终无签名 generic iOS workspace 构建 exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-settings-redesign-build.log`），`git diff --check`通过。生产展示组件经macOS宿主适配渲染浅深色、375pt长文本、辅助布局及宽屏（`/tmp/ddlNew-settings-native-preview/`）；此证据不等同iOS真实Dynamic Type、VoiceOver、导航/弹层或触控验收。Mobile MCP继续暂停，未操作设备、未提交或推送，保留所有同期改动。重新Run后需验收设置打开/关闭、资料刷新、政策/支持弹层、注销入口返回及退出取消行为。

## 2026-10-23 群发助手接线与完整流程

按用户要求只读对照 xgd `Modules/Session/Controllers/MassMessage` 下的历史、新建、选人和收件人页面，补齐消息列表系统会话 `100001` 的导航，并在消息页加号菜单提供受角色权限控制的群发入口。本节更新此前群发助手尚未接入的功能边界。Agency Agents 的 UI Designer 按用户指定的 `ui-ux-pro-max` 完成历史、新建、好友/群聊混选、收件人/失败名单四个原生 SwiftUI 页面，沿用项目森林绿与现有导航、头像、媒体预览组件。

新增 `Features/MassMessage` 的模型与三个状态层，以及 `Network/IM/MassMessage` 的 SDK 适配。支持15条分页历史、文本/图片/视频/文件、16个UTF-16单位的备注标签、好友与群聊混选、附件预览、查看收件人和失败原因、再次发送及删除记录。再次发送复用旧任务的 labelId；新建先创建收件人标签再发送，发送失败保留草稿及已创建标签，重试不重复创建。沿用 SDK 六个现有群发接口、旧端 mtype/body 字段和媒体上传链路；服务端受理后请求既有会话同步。没有修改 xgd 或 SDK Objective-C 源码。

历史可查看，新建和再次发送按 `groupHairAssistant` 权限校验，发送前各阶段复核当前 AUTH、用户及权限；退出、切账号、取消与迟到回调均有隔离。分页失败不推进页码，列表按任务ID去重，删除成功才移除并避免在途旧页复活；好友和群聊使用带类型的复合ID。附件准备和上传支持取消及临时文件清理，关闭页面不会承诺撤回服务端已受理的群发。会话摘要复用 SDK 已有 `<uid>-MassMessage` MMKV 缓存，不新增第二份持久化来源；删除最后可见记录且仍有分页时重新查询最新任务。

验证：`Tests/MassMessage/run-checks.sh` 26项、`run-sdk-checks.sh` 10项通过，涵盖字段解析、分页重试、去重、删除、失败保稿、标签复用、防重复提交、权限撤销、切账号、取消及迟到回调；日志 `/tmp/ddlNew-mass-message-checks.log`、`/tmp/ddlNew-mass-message-sdk-checks.log`。会话状态回归、会话在线/摘要11项及聊天媒体回归通过，日志 `/tmp/ddlNew-mass-conversations.log`、`/tmp/ddlNew-mass-online.log`、`/tmp/ddlNew-mass-media.log`。最终 workspace 无签名 generic iOS 构建 exit0、`BUILD SUCCEEDED`，日志 `/tmp/ddlNew-mass-message-final-build.log`；`git diff --check`通过。

Mobile MCP继续暂停，未安装或操作设备、未进行真实群发或上传。界面完成源码和构建检查，尚未做设备渲染或 VoiceOver 验收；重新Run后需用测试账号验证入口、好友/群聊混选、四种消息发送、失败原因、再次发送/删除、附件预览及切账号表现。保留同期“我的”页、设计稿和工程/SPM改动，未提交或推送。

## 2026-10-23 我的整页重设计落地

用户审阅 Agency Agents UI Designer 的 [可浏览设计稿](design/mine-redesign-2026-10-23.html) 与 [方案和实施规格](design/mine-redesign-2026-10-23.md) 后明确要求实施。已按自然留白方向重做整个“我的”页：72pt圆角头像与真实昵称/账号、账号复制和我的二维码、四类活动两列入口、薄荷绿俱乐部卡、账户与支持分组。沿用首页 HomeTheme 浅深色；长文本可换行，辅助字号身份纵向、活动单列，主要触点至少44pt。移除活动演示计数，俱乐部仍沿用现有“远山户外”内容，不将其当作登录资料。

`MineView` 保持会话、文件Host与弹层状态所有权，新增 `MinePageContent` 只负责展示和已有值路由。保留下节真实资料接线与UID头像隔离，不新增请求或缓存；复制读取当前会话账号并给出居中提示，二维码复用 `ContactsPageRoute` 和既有共享业务Store。活动、俱乐部、切换确认、隐私、黑名单、投诉、设置及原生导航/底栏路由继续原流程。设置子页不在本次重设计范围内。

验证：workspace 无签名 generic iOS 构建 exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-mine-redesign-build.log`）；会话维护17项、角色/资料26项、SDK会话隔离7项通过（`/tmp/ddlNew-mine-redesign-maintenance.log`）；`git diff --check`通过。真实展示组件经 macOS ImageRenderer 与主题/几何适配渲染浅色、深色、375pt长文本、辅助布局分支及宽屏五张静态图（`/tmp/ddlNew-mine-native-preview/`），原设计师复核未发现裁切、重叠或阻断性拥挤。该宿主渲染不等同真实iOS字号、导航栏/底栏安全区或交互验收。

Mobile MCP继续暂停，未操作设备、未提交或推送，保留同期群发、消息、工程/SPM改动。重新Run后仍需验收真实头像加载、资料刷新/切账号、复制/二维码和各入口返回、最大辅助字号与VoiceOver。

## 2026-10-23 我的顶部接入登录用户资料

按用户要求只读对照 xgd `CandyTallkMineViewController.updateUI` 与 `NoaMineInfoView.setMineModel`：顶部昵称、账号和头像分别读取登录资料 `nickname`、`userName`、`avatar`。`MineView` 原先使用 `ClubStore` 的演示会员名称、俱乐部账号描述和 `MemberAvatar` 账号缩写；现直接观察 `UserSessionStore.currentUser`，复用既有登录保存、缓存恢复和会话维护资料刷新，不新增请求或第二份用户缓存。缺昵称回退真实账号，资料清空时显示未登录；不再回退演示会员信息。

头像复用 Kingfisher、`RemoteAvatarURL`、项目下载器和旧格式图片处理器，支持完整地址及当前文件 Host 下的相对路径；观察文件节点变化，缺失或加载失败显示默认头像。头像视图按当前 UID 隔离，切换账号或退出时重建。首次接线保留原顶部卡片，随后整页样式由上节重设计替换；本节记录资料来源与头像处理边界。

验证：会话维护17项、角色/资料26项、SDK请求会话隔离7项，以及通讯录44项、SDK分页19项及字段合并检查通过，日志 `/tmp/ddlNew-mine-profile-maintenance.log`、`/tmp/ddlNew-mine-profile-contacts.log`。workspace 无签名 generic iOS 构建 exit0、`BUILD SUCCEEDED`，日志 `/tmp/ddlNew-mine-profile-build.log`；`git diff --check`通过。Mobile MCP继续暂停；真实账号头像下载、资料刷新及切账号后的画面待重新Run验收。保留既有工程/SPM修改，未修改旧项目、未提交或推送。

## 2026-10-22 DNS1 耗尽后使用旧五路导航兜底

按用户要求只读对照 xgd `NoaUrlHostManager.startDNS1WithNetworkQualityTrigger`、`raceDNS1ReconnectWithCompletion` 与 `docs/dns1-navigation.md`：DNS1 主域、备域和 BIN 的获取/解析/全部 TCP 探测都失败后，进入独立的旧五路入口；取消或非法邀请码不触发兜底，DNS1 成功不请求旧来源。本节取代10月17日“开启DNS1时旧五路不参与”的边界。

`OSSNodeRaceCoordinator.race` 统一承接邀请码、冷启动/访客恢复和已登录导航刷新。DNS1 抛出来源耗尽后继续原 ALIDNS、腾讯AAAA、Cloudflare TXT/AAAA、阿里DoH TXT 五路并发 OSS Auth；保留既有 Resolver、缓存/内置导航地址、加密OSS HTTP文件的后续降级及旧导航30秒总截止。冷启动/重连只将同企业、当前配置版本、来源为DNS1的缓存作为原生TCP候选；上次五路结果不抢在DNS1之前使用。保留现有轮次、身份和取消守卫。新端目前没有旧端的独立网络诊断页面；已有网络质量刷新共用统一导航入口，是否运行继续由实际导航开关决定。

最新导航仍保存到现有固定缓存key，不新增第二份企业数据源。`OSSNavigationStore`、`OSSConnectionBootstrap`按实际获胜来源验证/准备：DNS1允许TCP-only且校验版本，旧五路沿原HTTP+TCP合同，保留其服务端检测开关与HTTP优选配置。旧节点不冒充DNS1缓存；HTTP回调只接受当前企业/导航提供的地址。升级仍只从旧key迁移成功邀请码，不直接恢复旧key中的节点。

已登录重连使用`IMReconnectNodes`携带本轮实际已探测节点，只有DNS1本轮首胜可省略重复临时ECDH；五路拿到的是导航结果，必须继续业务TCP/ECDH探测，不能仅按全局DNS1开关选第一项。正式Socket、systemConfig及AUTH仍沿原所有权。重连业务截止在DNS1启用时为85秒，SDK竞速兜底为90秒，覆盖缓存、主/备/BIN、旧导航和TCP探测；旧导航关闭DNS1时业务截止仍55秒。底层正式Socket连接超时未改。

验证：新增统一入口五路兜底检查先复现DNS1耗尽直接抛错（`/tmp/ddlNew-dns1-fallback-red.log`），终版10项通过（`/tmp/ddlNew-dns1-fallback-final-checks.log`）；真实Protobuf/ObjectMapper缓存与连接准备集成32项通过，包含旧来源往返、原HTTP/TCP准备、旧缓存不冒充DNS1及HTTP回调归属。重连专项覆盖旧五路首个TCP不可达/后续节点胜出、全不可达与非法探测凭据、取消/超时/旧会话隔离。DNS1协议39项及上述专项、系统配置运输、网络质量、会话恢复和维护共8组离线入口均exit0，汇总`/tmp/ddlNew-dns1-fallback-qa/summary.json`（统一轮的兜底检查8项，追加缓存参数/预先取消后终版单独复验10项）。无签名generic iOS workspace构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-dns1-fallback-build.log`）；`git diff --check`通过。

旧项目只读，Mobile MCP继续暂停；本轮不安装/操作设备、不提交或推送。真实DNS1故障环境下五路连接、冷启动及已登录断线恢复需重新Run验收；离线替身与构建不代表真实服务器链路已通过。

## 2026-10-21 离线好友呼叫与旧端错误提示对齐

按用户确认对齐 xgd `NoaMediaCallManager.callRequestWith`、`NoaCallManager.requestSingleCallWith` 和 `NoaNetResultCode.plist`：好友在线标识不作为本地拦截依据，由服务端决定是否受理。新端单聊语音/视频现仅在创建请求成功后建立可展示通话、打开呼叫页和响铃；请求等待期间停留原聊天，busy阻止重复创建。失败保留原页并由既有全局Toast提示；群创建失败继续保留选人页。

`SDKCallClient` 在原20秒运输等待/取消机制内保留业务错误码和文案，通过 `CallError.server` 向协调器传递；旧端910004映射“用户不在线”、910001映射“对方正在通话中”，同时保留相关通话/注销/拉黑映射，未知码优先使用非空服务端文案，否则显示通用失败。身份校验发生在业务结果解包之前，旧账号错误不能弹到新账号。

创建等待使用独立 pendingCreation 记录，不提前制造 session/浮窗；提前到达的接听/成员通知按请求身份暂存，受理后按房间ID消费，已收到终态的房间不会弹出。取消后迟到成功继续在原认证身份下补偿取消，退出/切账号不以新身份发送补偿。仍由服务端通知收口未应答，本轮未增加客户端呼叫倒计时，原30秒媒体连接超时保留。

验证：新增等待期间不弹页/不响铃检查先复现失败；现协调器51项通过（`/tmp/ddlNew-call-offline-state-green.log`），覆盖两供应商语音/视频拒绝、重复点击、提前接听、取消和身份失效。真实SDK请求方法+原运输等待器的边界回归修复前1/9、修复后9/9通过（`/tmp/ddlNew-call-offline-request-green.log`），包含离线/忙线/拉黑、未知错误、首次回执及旧身份错误隔离；其余五个Calls脚本（协议、映射、系统资源、视频、浮窗）均通过。无签名generic iOS workspace构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-call-offline-build.log`），`git diff --check`通过。Mobile MCP保持暂停，未操作设备、未修改旧项目、未提交/推送；真实离线账号请求与提示、在线接通及服务端未应答仍待重新Run双端复验。保留同期聊天历史等修改。

## 2026-10-21 真实历史日志与 xgd 首屏状态对齐

用户重新Run并下拉后要求读取Xcode日志，随后强调xgd进入聊天就自动加载且正文没有缺口。本轮从Xcode控制台读取到多组 `[ChatHistory] start older=true` 后均为 `failed cancelled=true contextChanged=false`，offset反复停在12、1、3等值，未出现对应response/finish。首屏则确实发起并返回：一组rows=58、mapped=58、cached=1、received=58、visible=1；另有rows=63/75。这证明新端已有首屏自动请求，但下拉等待被取消且返回/展示数量存在差异；原日志将Task取消与CancellationError合并输出，不能仅凭它确定所有取消来源，也不能从数量直接认定哪些具体消息被删除。

对照旧端 `NoaChatViewController.viewDidLoad/requestHistoryList` → SDK `messageGetHistoryRecordWith/messageRequestHistoryRecordWith`：进入即读本机、请求第一页、按服务端状态回写，再回读展示。旧 `LIMMergeLocalFieldsBeforeHistoryUpsert` 保留翻译与小时间差，不把本机旧0/2状态永久压过服务端正常状态；新端 `ChatHistoryCachePolicy`、SDK历史回写以及UI合并原先都无条件保留旧非正常状态，且请求前快照只读取status1，旧状态无法被服务端校正。新增单/群用例复现“三条消息中间一条本机残留删除、服务端均正常，进入仍只显示两条”。本节取代以前历史合并中“旧墓碑永久优先”的过宽策略。

已改：进入自动同步入口继续沿用；SDK新增只读 `toolGetChatMessageHistoryIncludingInactiveWith` / DB对应分页方法作为请求前版本快照，包含所有状态，正常展示查询仍仅status1，不改表结构、不清库。服务端状态可校正请求前已存在且期间未变更的旧缓存；请求期间新删除/撤回、物理删除、编辑及旧账号结果继续保护。`ChatPage.restoredServerIDs`将受校验的状态恢复传给Store，避免SDK已恢复而UI旧记录仍隐藏；实时变更版本优先。Debug额外记录remoteStatus、mappedStatus、mappedType、本机状态冲突数量，均不含正文或身份ID。

下拉改由 `ChatStore.refreshHistory` 持有独立Task，刷新控件外层Task取消不再中断网络等待；重复刷新共享在途任务，真正close/clear同步取消。页面等待其完成后仅在原上下文仍可见时恢复锚点，不再因刷新控件自身取消而跳过定位。测试使用生产SDKChatRequestWaiter替代原先不可取消的continuation替身，并从真实refreshable抽取调用入口；取消场景先35/36复现失败，再修复。首屏旧状态用例另先39/41失败，再修复；请求期间删除、仍为服务端删除、退出/清空迟到隔离一并覆盖。正常正文不依赖人工下拉来应用这次状态校正。终版专项47/47通过（`/tmp/ddlNew-history-authoritative-green.log`）；语义13项、Chat Store回归、SDK消息/黑名单回归、定位Store12项及布局12项通过。最终无签名generic iOS workspace构建exit0、BUILD SUCCEEDED（`/tmp/ddlNew-history-authoritative-build.log`），范围内diff检查通过。

Mobile MCP保持暂停，未安装或操作设备、未修改xgd、未提交或推送；Xcode临时日志筛选已恢复。真实用户缺失条目的状态来源仍需修复版首屏日志复验，不把离线用例当作逐条真实历史完整性证明；用户无需下拉即可触发首屏状态校正。

## 2026-10-21 历史下拉复查：空页重试与重复页

用户复验反馈单聊和群聊均会转圈但无法拉出更早历史，已有正文之间也有缺口。只读再次核对旧 xgd `NoaChatViewController.headerRefreshData/requestHistoryList`：每次手动下拉均查询，空页只 endRefreshing，不永久禁用入口。新端页面和 Store 双重 hasMore 守卫会在一次空页后直接拒绝后续手动请求；同时本机100条而远端短页20条时，游标尚处于已显示区间，一次只查一页会连续数次仅得到重复消息。连续隐藏控制页也有相同行为。

现页面移除手动下拉的 hasMore 拦截，Store允许重新查询空页；一次手势跨过无新增可见正文但游标/偏移有进展的页，出现新增正文、空页、无进展、取消或上下文变化即停止，每次最多5页，下次手势接续。hasMore继续供自动定位结束判断使用。保留旧端协议 sMsgId/isThanMsgId=1/pageNumber=1、SDK缓存回读及分页锚点，不改旧项目。Debug新增 `[ChatHistory]` 的请求开始、返回条数、映射/缓存条数、可见条数、分页进展及失败/取消诊断，不输出正文或身份ID。

新增空页恢复和连续隐藏页检查先复现29/33通过；修复后追加本机100条/远端20条重复页场景，终版35/35通过（`/tmp/ddlNew-history-retry-green.log`）。Chat Store既有回归、定位Store12项/布局12项、滚动16项通过。初次重复运行专项时遇到本轮继续编辑Store导致Swift输入文件变化，固定源码后重跑exit0。最终无签名generic iOS workspace构建exit0、BUILD SUCCEEDED（`/tmp/ddlNew-history-retry-build.log`），全仓diff检查通过。用户当前消息中间缺失的具体原因尚未获得真实分页响应证据，不把这些离线修复当作真实历史完整性验收。已只读查看Xcode现有控制台，未找到可用历史响应；临时筛选已恢复。Mobile MCP保持暂停，未操作设备、未重新安装、未提交或推送。新代码需重新Run后在同一单/群聊复现，以诊断计数继续定位返回/过滤/展示边界。

## 2026-10-21 进入聊天后清除会话未读

用户反馈消息列表有未读，进入聊天再返回仍不消失，并明确要求按旧 xgd 修改。上一轮只定位未修改；本轮对照 `CandyTalkHomeViewController.cellClickAction/sessionUpdateReadedStatusWith`：旧端进入单/群聊立即清本机 `sessionUnreadCount`，同步 `conversationReadedStatus(readTag=0, latestSMsgId)`，记录 `clearReadNumSMsgIdDictKey` 供重连使用。新端之前只清手动 readTag，正文扣减又只接受本 AUTH 实时 receive 成员，因此启动/重启同步的初始正数即使正文已读也不能归零。以下实现取代本文10月14日“打开仅清本机手动 readTag”的历史策略。

`ChatStore.open` 在注册观察后、缓存和历史加载前同步调用 `ChatClient.clearConversationUnread`。真实 `SDKChatClient` 在身份校验和 SDK 锁内清会话计数及手动标记，写库成功才更新 Runtime 计数边界，再按旧端协议立即提交服务端请求；同上下文重复 open 不再次清除。读取当前会话最新 SID，缺失时回退最新消息；非空边界复用旧 SDK 的 MMKV key，并更新 SDK 当前同步快照，保留其它会话条目。会话库写入触发现有列表和 Tab 角标刷新；快速返回不依赖正文两秒批次。接口成功回调不回写旧会话模型，因此不额外清除请求后新到消息；失败只向仍有效的当前聊天报告，重进即便本机已经为零也再次同步。无会话不制造记录，旧账号/旧页面迟到回执隔离。

本次清除仅针对会话提醒，正文可见批量 read、语音实际播放后 read 继续原流程，没有把全部历史正文/语音标成已读。SDK 原有506跨端通知仍按其协议整会话清零（通知无消息边界），此处未修改其行为；离线测试验证本轮请求回执和本机计数边界，不代表真实跨端通知竞态已验收。

验证：生产 Store 开页接线与生产 SDK 清读方法分别先复现失败（`/tmp/ddlNew-unread-entry-store-red.log`、`/tmp/ddlNew-unread-entry-sdk-red.log`）；追加重连边界测试也先失败（`/tmp/ddlNew-unread-boundary-red.log`）。修正后入口21项、既有计数8项及 Chat Store 回归通过，涵盖单/群启动初始未读、手动标记、协议参数、语音正文分离、快速返回、请求间新消息、保存失败、空成功/明确拒绝、身份失效和持久化边界。最终无签名 generic iOS workspace 构建 exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-unread-entry-final-build.log`），本轮生产文件无新增编译警告；统一离线入口 96/96 组通过，exit0，逐组耗时合计 408.37 秒，汇总 `/tmp/ddlNew-20261021-unread-entry-qa/summary.json`；全仓 `git diff --check` 通过。

Mobile MCP继续暂停，未安装或操作设备、未提交或推送；保留同期历史分页、通话和媒体改动。需要重新 Run 新包验证消息列表及底栏角标、进入后立即返回、冷启动已有未读、断网/重连及真实服务端同步。

## 2026-10-21 视频通话远端画面绑定修正

用户反馈视频通话看不到对方摄像头。对照 xgd `Zego/Manager/NoaCallManager.onRoomStreamUpdate` 与 `Zego/Controllers/NoaCallSingleVC`：旧端新增视频流后默认允许画布显示，立即绑定远端流，摄像头设备事件再修正开关。新端原先把新增流固定标为 cameraEnabled=false，页面因此不创建画布，先以 nil canvas 播放；若没有后续设备状态回调就一直只有声音。锁定 Zego 3.5.0 头文件明确 nil canvas 仅播放音频，且自定义采集/CDN不提供摄像头状态回调。此为源码及离线复现的差异，未抓取用户当前通话的供应商和实际网络流量。

`ZegoCallEngine` 现对视频新增流默认建立画布资格，按 streamID 保存明确的摄像头状态（含早于成员映射到达的关闭），重复通知不重置已知开关；替换流停止旧播放器并重用当前画布，旧流迟到删除不能清空当前视频。语音通话仍不显示摄像头。`CallVideoSurface` 直接观察协调器发布状态，确保 LiveKit 订阅/重订阅及轨道替换引发重新绑定；容器复用原渲染视图，缩小释放画布但保留媒体连接，恢复再绑定。LiveKit 自动订阅与房间配置已核对，继续沿用与旧端相同的配置，没有升级或替换第三方库。

新增 `Tests/Calls/run-video-checks.sh` 编译生产 Zego 流/摄像头回调及视频容器方法，SDK/UIView边界使用替身。修复前11/17通过，修复后17/17通过（`/tmp/ddlNew-call-video-green.log`），覆盖无设备回调时画布建立、早到关闭、重复通知、流替换/迟到删除、错误房间/旧引擎隔离、语音限制、缩小恢复、LiveKit轨道重绑与清理；现有协调器35项及浮窗10项通过。无签名 generic iOS workspace 构建 exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-call-video-build.log`），`git diff --check`通过。Mobile MCP保持暂停，尚未验证真实服务器拉流、解码或新旧端双向摄像头画面；重新Run后需两端验证首次接通、对方摄像头开关、大小窗交换及缩小恢复。未提交/推送，保留同期聊天历史分页等修改。

## 2026-10-21 聊天下拉历史与旧端分页对齐

用户反馈进入聊天后下拉拿不到历史，要求对照 xgd。只读核对旧端 `NoaChatViewController.requestHistoryList/headerRefreshData` 及 `NoaIMSDKManager+ChatMessage.messageGetHistoryRecordWith`：旧端云端补拉后回读 SDK 本机历史，网络失败仍尝试本机分页；新端只合并远端映射结果，且 `rows.count < 100` 即关闭 `hasMore`，页面与 Store 随后直接拦截下拉。本机超过100条但服务端空页、服务端实际返回短页以及断网翻阅均可用生产历史方法和真实 Store 离线复现，不据此声称已抓到用户当前服务器响应。

`SDKChatClient.history` 现沿原接口补拉并落库后回读 SDK 同偏移缓存，与远端状态归并；非空短页继续游标分页，远端空页且本机不足100条才结束。运输失败在身份、取消及内容 revision 校验后回读本机，成功回退仍保留远端重试，无本机数据时继续报错。`ChatPage` 额外携带原始远端游标和本机下一偏移，`ChatStore` 不再用过滤后的可见消息数推算进度；整页控制条不会反复请求同一页，置顶/引用定位可跨过隐藏页，关闭与清历史清除分页状态。页面现有下拉、静默加载、失败 Toast 与补页锚点逻辑保留，没有修改旧项目。

新增 `Tests/Chat/run-history-pagination-checks.sh`，提取真实 SDK 历史/缓存/快照方法并运行真实 ChatStore，仅 SDK 库、运输和认证边界使用匿名替身。最初9/21通过，确认缓存遗漏、短页提前结束和断网不补本机；修正后21/21通过。追加控制消息页先复现23/27通过，保留原始游标/偏移后27/27通过，覆盖单/群聊、本机150条、实际20条短页、100/101边界、隐藏控制页、网络失败/非法响应及退出后迟到隔离。生产 Store、定位Store12项/布局12项、滚动16项、首次定位11项、撤回缓存5项、语义12项、视口7项与SDK消息归并专项通过。终版无签名generic iOS workspace构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-history-pagination-final-build.log`），本轮三个生产文件无新增编译警告。统一离线入口95/95组通过，exit0，逐组耗时合计422.73秒，汇总 `/tmp/ddlNew-20261021-history-pagination-qa/summary.json`；SDK缓存替身另按真实方法反转为页内时间正序后，专项终版仍27/27通过（`/tmp/ddlNew-history-pagination-final-checks.log`）。全仓 `git diff --check` 通过。

Mobile MCP继续暂停，本轮未安装/操作设备、未提交或推送，既有通话、媒体及用户其它工作区改动保留。重新 Run 后需在同一单/群聊拉到消息顶部下拉，核对超过100条连续补页、补页阅读位置、断网本机翻阅及恢复联网后的历史；真实服务器页长、权限与 SwiftUI 手势表现仍待对应设备验收。

## 2026-10-21 通话缩小浮窗的控制器层级崩溃

用户真机反馈视频通话点击左上角缩小立即崩溃，UIKit 报浮窗宿主应无 parent，但实际 parent 为 `CallPresentationController`。源码确认 `syncBubble` 将 `UIHostingController<CallFloatingView>` 声明为零尺寸锚点的 child，却把宿主视图直接加入 `UIWindow`，两套层级不一致。现移除浮窗的 addChild/didMove 以及对应移除 child 调用，继续作为当前场景窗口浮层，由 `bubble` 强引用宿主；恢复、通话结束或锚点卸载时移除视图并释放宿主。拖动、安全区限制、全局浮层和原通话会话保留。

新增 `Tests/Calls/run-presentation-checks.sh` 编译生产浮窗同步、拖动与边界方法，用 UIKit 边界替身检查窗口层级契约、宿主持有/释放、重复缩小恢复、位置保留、锚点暂离与卸载。修改前8/10通过，两个层级契约检查失败；修正后10/10通过（`/tmp/ddlNew-call-minimize-green.log`）。现有通话协调器35/35通过（`/tmp/ddlNew-call-minimize-state.log`）。iOS workspace 无签名 generic iOS 构建 exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-call-minimize-build.log`），`git diff --check`通过。离线替身不能代替 UIKit 真机运行；Mobile MCP 继续暂停，重新 Run 后的视频/语音缩小、浮窗拖动、恢复和结束清理待设备复验。未提交或推送，保留其他工作区改动。

## 2026-10-20 语音与视频通话迁移

用户明确要求产品经理先对照 xgd 整理需求，再开发底部入口、单聊/群聊语音视频、通话页及应用内来电，继续使用旧端同样三方库。需求与旧源码依据见 [通话迁移需求](CALL_MIGRATION_REQUIREMENTS_2026-10-20.md)，实施分工见 [实施计划](superpowers/plans/2026-10-20-calls.md)。当前代码实现和离线验证已完成，真实新旧端双向音画与来电验收待设备联调；Mobile MCP 继续暂停。

本轮新增 `Features/Calls` 和 `Network/IM/Calls`。`CallCoordinator` 绑定 UID、邀请码、AUTH 轮次和当前通话 UUID/hash/callId；AUTH 成功即注册全局 SDK 来电代理，先于联系人/会话异步读库，退出在 SDK reset 前关闭。`SystemConfigService` 与 `SessionMaintenanceCoordinator` 将已通过当前节点归属检查的配置送入内存 `CallConfigurationStore`，仅解析通话开关、供应商和 Zego appID，不保存 appSign、服务端 secret 或房间 token。当前通话保存配置快照，刷新配置不切换正在使用的引擎。

信令复用 NoaChatCore 两套现有接口；媒体使用原有 SPM LiveKit 1.0.8、ZegoExpressEngine 3.5.0，版本未升级。LiveKit 采用每通独立 `Room`，避免旧 SDK 包装打印 token 和单例房间串轮次；新端直接调用 Promise API，故补充显式链接现有锁定的 Promises 2.4.1 产品。Zego 使用真实引擎登录、确认加入、推拉流及10秒心跳。两媒体引擎共用停流/销毁等待，跨供应商重拨也要等上一通释放。铃声、屏幕常亮、摄像头、代理、心跳和视频画布随终态清理；后台停视频，前台按用户原开关恢复。

聊天底部新增“视频通话”“语音通话”，按系统开关、会话类型和群角色显示，动作提交前重新校验。群先选择真实成员，创建失败保留选择；已有群通话通过顶部人数/头像提示明确加入，通话内可追加邀请。全局 `CallPresentation` 锚定当前场景窗口，覆盖已有媒体/设置弹层；单聊支持真实大小视频交换，群显示成员状态/视频网格，最小化为可拖动浮窗并保留房间、时长和画面偏好。底层 modal 异步消失时会重新核对实际呈现，避免通话仍在但页面丢失。错误沿用居中 Toast。

来电或呼出在媒体接管前执行 `ChatRuntime.prepareForCall`，通过已注册清理动作停止独立视频播放器、语音播放和未发送录音，保留附件上传。通话中录音、语音播放和视频播放不能抢占音频会话。SDK 已落库的通话消息经 `ChatCallSummary` 展示取消、拒绝、未应答、时长及群发起/结束；LiveKit 读取 `sMsgType=504/customEvent.type=101或103`，102不产生历史行，Zego读取type20及netCall字段，不另插结束消息。

验证：最终无签名 generic iOS workspace 构建 `BUILD SUCCEEDED`，日志 `/tmp/ddlNew-calls-build-final.log`；本轮 Calls 源码无新增编译警告。统一离线脚本首轮91项中88项通过，两个测试夹具补充通话边界、一项同期源码变动导致的编译检查重跑后通过；加上随后新增的两个 Calls 专项，最终汇总93/93，证据 `/tmp/ddlNew-calls-regression/final-summary.json`。其中真实协调器35项，另有请求合同、响应映射、系统资源、历史文案和媒体互斥检查。先复现再修复了建房前收到终态、旧accept任务串新房间、旧系统中断影响新通话等问题；独立产品/SDK复核发现的问题已修正。离线测试替代系统权限/网络/媒体边界，不代表实际通话接通。

待设备按需求文档 QA-CALL-01 至12验收：两供应商各自新→旧、旧→新单聊语音视频；至少三账号群选人/部分接听/追加邀请/已有房间加入；拒绝/取消/未应答/其他设备接听；静音、免提、蓝牙、前后摄像头、浮窗恢复；已有媒体弹层来电、后台/锁屏及弱网重连。未新增 CallKit/PushKit，进程被杀后的 VoIP 唤醒不在已确认的旧端应用内链路范围。工作区保留同期图片失败重传修改；本轮未提交或推送。

## 2026-10-20 图片发送失败保留原条与重传

用户反馈图片发送超时后气泡直接消失。只读对照 xgd `NoaMessageSendTask.sendMessage` 与 `NoaMessageSendHander.ZMessageReSendWithFailMsg`：旧端上传不完整时将原消息标为失败并写回消息库，重试沿用原本地ID和本机原件。新端 `ChatMediaStore` 原先在上传/入队失败时调用discard删除占位，`ChatMediaComposer`随后删除临时图片；本轮覆盖下方10月16日“失败移除占位、未实现失败气泡重试”的历史边界。

图片/视频上传失败及上传完成但SDK入队抛错时，现保留本地预览、结束菊花并显示既有红色失败按钮。用户随后明确取消失败Toast：图片/视频上传、SDK入队或ACK超时失败仅更新气泡与红色重试按钮，不重复弹Toast；准备失败、权限与缺原件等操作校验继续原有提示。原件/视频封面由独立 `ChatUploads` 应用目录持有，排除备份；失败记录复用SDK消息表与localImgName/localVideoName/localVideoCover字段保存，采用应用目录相对路径，远端resource/thumbnail不写本机路径。重进聊天从本人失败记录恢复；未上传完整时重新上传，同localID继续SDK队列，已有完整云地址时直接重入队；最终成功仍以ACK为准。首次上传主动取消仍移除尚未入队占位；取消重传保留原失败条，重复点击、权限变化、缺原件、清历史和旧身份迟到结果受守卫隔离。成功入队、本机删除及当前记录清历史释放对应原件。

新增失败保留回归先复现旧删除分支，追加真实Store/上传器与实际文件检查覆盖字节保留、重进缓存、同ID重传、再次失败、SDK入队失败、重复点击、权限、取消、缺文件、删除、清历史和ACK；另先复现旧失败缓存刷新覆盖正在重传状态，修正后专项通过。新增SDK保存/恢复方法提取检查覆盖图片/视频独立原件封面、相对路径/越界、用户归属、成功/删除保护和写库失败；该边界替身不等于真实WCDB进程重启验收。追加不弹Toast回归先复现旧提示分支，修正后验证图片上传失败、SDK超时和入队失败不发布Toast。两个专项日志 `/tmp/ddlNew-media-failure-green.log`、`/tmp/ddlNew-media-persistence-green.log`，云目录/配额15项通过。最终统一离线89/91组通过（`/tmp/ddlNew-20261020-media-failure-final-qa/summary.json`）；未通过的`Tests/Chat/run-photo-browser-checks.sh`及`run-voice-recorder-checks.sh`均因同期通话新增calls/CallCoordinator缺少离线替身而编译失败，本轮图片/持久化及云策略入口通过。首轮修改期间产生的cloud-policy单文件编译依赖已通过拆分新协议/文件所有权模型修正，游戏脚本读到在写源码的失败也在终版通过；不将全套描述为全绿。

构建过程：首轮被同期通话代码编译错误阻断，后续源码编译完成但LiveKit通话相关Promises符号链接失败；终版无签名generic iOS workspace构建exit65，日志`/tmp/ddlNew-20261020-media-failure-terminal-build.log`，本轮图片修复文件编译完成且无新增警告，失败为LiveKitCallEngine对Promises.Promise的then/catch未定义符号，未确认完整BUILD SUCCEEDED。范围内diff检查通过。没有修改通话实现或撤销同期工作区改动。Mobile MCP继续暂停，未安装/操作设备、未发送真实业务消息；弱网图片/视频失败后的红标、退出重进、点击重传及双端实收仍待重新Run真机验收。未提交/推送。

后续按用户要求取消图片/视频发送失败Toast：上传失败、SDK入队失败与ACK超时均保留失败气泡和重试按钮。媒体、Chat Store及SDK保存/恢复三个专项通过；本次无签名generic iOS workspace构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-20261020-media-no-toast-build.log`），覆盖前述构建失败的当前状态；不等于真机弱网与双端重传已验收。未提交/推送。

## 2026-10-19 预览右上分享无响应

用户反馈图片预览右上更多菜单内点击分享无响应。当前使用嵌在条件Menu内容中的ShareLink，实际预览由独立UIHostingController呈现；本轮将分享改为普通Button生成当前文件快照，`.sheet(item:)`固定挂在 `ChatPhotoBrowserView` 根部，再通过 `ChatPhotoBrowserShareSheet: UIViewControllerRepresentable` 承载 UIActivityViewController。菜单收起或预览Store因后台清空file，都不会移除分享请求与呈现入口；图片、视频使用同一原文件URL，仍由用户在系统面板选择目标，不自动发送。

分享前复核当前消息、文件、AUTH上下文、撤回/删除及allowSharing，缓存丢失给出提示；UUID隔离过期完成回调，取消/完成清理请求，系统错误显示Toast。预览关闭或当前消息失效清空分享请求；合并记录仍禁用分享。保留已修正的透明呈现、scenePhase显式传递与下拉关闭，不改动语音/文件详情中的分享。

验证：新增提取真实分享/完成方法的10项检查，覆盖文件快照、去重、Store关闭后快照保留、过期回调、取消/失败反馈、合并记录禁分享、撤回、错消息及缓存丢失；浏览器合计50/50通过（`/tmp/ddlNew-browser-share-checks.log`）。无签名 generic iOS workspace构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-20261019-browser-share-build.log`），本轮分享文件无新增编译警告，范围内diff检查通过。Mobile MCP继续暂停，未弹出或操作真实系统分享目标；离线检查验证请求生命周期，不能证明系统面板已实际呈现或文件已外发，真机点击分享/取消/再次分享待复验。未提交/推送，保留其他工作区改动。

## 2026-10-19 聊天语音样式与按住发送对齐 xgd

用户要求语音消息样式和录音发送交互按旧 xgd 调整。只读对照 `NoaMessageVoiceCell`、`NoaAudioPlayAnimationView`、`NoaMessageModel.calculateVoiceMessage` 和 `NoaChatInputVoiceView` / `NoaChatInputView`：语音气泡改为播放/暂停图标、固定幅度波形、向上取整秒数，本人/对方左右镜像，长度随时长增加（旧端110～210点含气泡留白），对方未读显示6点红点。复用旧端四个播放图标资源并按当前森林绿主题着色；进度读取真实AVAudioPlayer时间，仅当前播放行刷新，减少动态效果时不做连续进度动画。

录音面板改为100点圆形麦克风和“按住说话”，按下开始、按钮区域内松开发送、移出后松开取消、移回继续发送；状态卡显示真实音量、秒数及“上滑取消发送”/“松开取消发送”。删除原点按开始/停止/确认发送的草稿阶段。不足1秒或1024字节拒绝发送，录满60秒自动交付一次，上传与SDK ACK仍由既有发送链路确认；保持当前AAC/m4a录制与既有媒体封装，没有迁移旧端PCM→MP3转码。旁白双击开始/再次双击发送，并提供取消动作；尚未实际VoiceOver走查。

新增 `ChatVoiceRecordButton` 用UIControl保留触摸区域进入/退出与系统取消语义；`ChatVoicePressState`消费一次结束事件。授权期间松手、切面板、失去发送权限、离页、后台、编码失败和系统中断均取消未交付录音。复核发现的“60秒delegate结束后、SwiftUI onChange前松手会删除文件”竞态已改为同一MainActor回调内直接消费并交付，不等待界面刷新，旧轮次/随后松手不能重复发送。录音与播放各自维护音频会话所有权，空闲取消不停止另一方，播放失败/中断/完成/关闭都释放。

聊天点击语音现在直接在气泡中播放，同条再点停止、切条取消旧下载及播放；复用 `ChatMediaPreviewStore` 的下载、解包、缓存、AUTH、删除/撤回和清历史失效规则。开始录音、离页、后台、进入多选或打开其他媒体会停播；只有播放器真正开始播放才调用现有 `markVisible(voicePlayed: true)`，不以下载或可见替代已读。文件详情及合并记录内现有附件入口保留。

验证：新增录音器、按住状态/播放切换、音频失败/中断三个离线入口均通过；录音测试先复现不足1秒仍可交付，音频测试先复现play返回false后的会话泄漏。组合测试覆盖60秒同步交付后的松手不重发，另覆盖权限迟到、取消删文件、上下限/非法时长、切条及AUTH/删除后的迟到下载。既有媒体、预览失效12项、下载/解包取消、浏览器路由/资源40项通过；输入模式/焦点、Chat Store、头像16项与Runtime离群8项通过。最终无签名 generic iOS workspace构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-20261019-voice-final-build.log`），本轮Chat文件无新增编译警告，范围内diff检查通过；只读代码复核未发现剩余阻断问题。

Mobile MCP继续暂停，未申请本机麦克风权限、未安装或操作设备、未发送真实业务消息；真实触摸、录音音质、系统音频路由、旁白及双端送达/收听仍需真机复验。未提交/推送，保留已有图片预览、登录和邀请码改动。本节覆盖历史交接中“语音显式确认发送”和“聊天语音打开详情”的描述。

## 2026-10-19 透明呈现后的打开黑屏回归

用户报告上一轮透明呈现改动后点击图片直接黑屏。定位到新建 UIKit UIHostingController 未传入源 SwiftUI 场景的 scenePhase：新 SwiftUI EnvironmentValues 实测默认值为 background，而 `ChatPhotoBrowserView.loadCurrent` 对非 active 直接返回、图片 Cell 的 isForeground=false 会清空图像。同时呈现控制器在请求ID未变时只保留原rootView，不能同步回前台。因此黑底已呈现，下载/图片显示仍被后台守卫拦截。未通过设备日志确认具体一次黑屏，以下为代码与边界回归证据。

在页面内的 `ChatPhotoBrowserPresentation` 读取源场景环境，显式传给 `ChatPhotoBrowserView`（必填参数，无默认后台兜底）；同身份的既有Hosting同步更新rootView，包括开场动画中，保持SwiftUI状态身份及既有容器，避免重新弹层。图片加载、视频停播与前后台清理继续使用真实源场景状态，未移除后台守卫，保留透明背景与下拉退出方案。

新增提取真实updateUIViewController方法的场景传递检查；修复前首次前台、恢复前台及两个状态同步检查失败（16/20），修复后20/20通过。默认环境值用本机SwiftUI直接查询为background；不将这个查询当作iOS真机画面复现。同期语音点击改为原地播放，画廊路由测试补齐对应语音边界替身，不改动语音生产代码。浏览器回归40/40通过，包含同期语音路由检查；无签名 generic iOS workspace 构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-20261019-browser-scene-phase-retry-build.log`），本轮预览代码无新增编译警告，范围内diff检查通过。首轮构建遇到同期build.db占用，未中止其他构建，等待后重试成功。Mobile MCP继续暂停，真机首次点击、后台回来、下拉取消/退出待复验，不提交/推送。

## 2026-10-19 下拉退出的黑色背景与 SwiftUI Demo 对照

用户反馈图片下拉退出仍露出黑色遮罩，并要求对照 PhotoBrowser 的 SwiftUI Demo。核对本机锁定4.2.0的 `Demo-SwiftUI/Demo/ContentView.swift`、`PhotoBannerView.swift`、`PhotoBrowserPresenter.swift`、`BrowserSettingsView.swift` 及库呈现/手势源码：Demo 的 UIViewControllerRepresentable 用于嵌入式 Banner；全屏点击通过 Presenter 调用 `browser.present(from:)`，库设置 `.overFullScreen`，默认淡入淡出。先前把嵌入式浏览器放入 SwiftUI fullScreenCover 并叠加 `Color.black` 和 `.background(.black)`，导致库下拉仅改变自身 backgroundColor 的 alpha，外层黑底仍遮住聊天。这是代码层确认的遮挡链路，未操作设备复现画面。

删除两层 SwiftUI 固定黑底。新增 `ChatPhotoBrowserPresentation`，从当前 SwiftUI 页面内的 UIViewControllerRepresentable 锚点呈现透明 UIHostingController，使用与 Demo 相同的 `.overFullScreen` 覆盖方式、系统 crossDissolve 统一淡出，底下聊天保留；兼容最低 iOS16，不依赖16.4才提供的 presentationBackground。当前是承载现有 SwiftUI 业务页面的适配，并非原封不动调用 Demo Presenter：保存/分享、下载/撤回生命周期仍由 SwiftUI 负责，黑底和拖拽由库独占。没有查找全局顶层窗口或修改包源码。聊天与合并记录都改走该入口，关闭回写原绑定；右上更多保留，未恢复左上箭头。

呈现控制器串行处理开关，开场途中关闭、退出途中重开、父页面卸载都在转场完成后收敛，避免重复覆盖或遗留透明容器。新增 `Tests/Chat/run-photo-browser-presentation-checks.sh`，编译实际控制器并替换 UIKit 边界，覆盖透明/overFullScreen配置、开关竞态和卸载清理13项；浏览器39项、播放器10项检查通过。无签名 generic iOS workspace构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-20261019-browser-backdrop-build.log`）；范围内diff检查通过。上述离线测试不验证UIKit真实合成或动画，Mobile MCP继续暂停，慢拖露出聊天、取消回弹、完成下拉和快速重开仍待真机复验。未提交/推送，保留其他工作区改动。

## 2026-10-19 清理旧预览实现与关闭箭头

按用户要求清理旧图片/视频预览代码，当前只保留 JXPhotoBrowser 入口。原 `ChatMediaGalleryView` 的 TabView 分页和 `ChatMediaZoomView` 自写缩放已被库替代；本轮进一步删除 `ChatMediaDetailView` 遗留的 VideoPlayer 分支、播放器状态及清理逻辑，并将 QuickLook 严格限定为文件消息。详情页现在只服务语音和文件，图片/视频/贴纸统一由聊天及合并记录的 `ChatPhotoBrowserView` 打开。

SwiftUI 页面和快照改名为 `ChatPhotoBrowserView`、`ChatPhotoBrowserRequest`；库桥接、图片/视频 Cell、加载预备和播放管理统一收敛到 `Features/Chat/Media/PhotoBrowser/`。删除旧 `ChatMediaGallery*` 文件名与类型，原独立视频视图合并为视频 Cell 内的私有 AVKit 渲染适配。仍在使用的下载解密、三页缓存、首帧封面与播放器生命周期能力迁入新模块，未删除这些业务能力；共用 `ChatMediaPreviewStore` 继续服务新浏览器及文件/语音。

预览工具栏删除左上角关闭箭头，仅保留原右上角三个点菜单；关闭沿用库的下拉手势和辅助功能 escape。合并记录原本禁用保存/分享，继续不显示菜单。测试入口同步改为 `Tests/Chat/run-photo-browser-checks.sh` 和 `run-photo-browser-playback-checks.sh`。

验证：浏览器路由/桥接/资源39项、播放器10项、预览失效12项，以及下载/解包取消、重试和文件清理检查通过。无签名 generic iOS workspace 构建 exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-20261019-browser-cleanup-build.log`），本轮聊天代码无新增编译警告，范围内 `git diff --check` 通过。Mobile MCP继续暂停，未安装或操作设备，实际手势与视频流畅度待真机复验；未提交或推送，保留其他工作区改动。本节覆盖下方历史章节中的旧类型名及左上角关闭入口描述。

## 2026-10-19 JXPhotoBrowser SwiftUI 预览迁移

用户要求把现有图片/视频预览替换为已添加的 JXPhotoBrowser，并明确采用 SwiftUI 接入。核对本机 SPM 锁定的4.2.0源码、`Demo-SwiftUI/PhotoBannerView`、`PhotoBrowserPresenter`及官方视频 Cell 示例：库核心为 UIKit，SwiftUI采用桥接，视频是自定义 Cell 扩展而非包内独立播放器产品。按该方式新增 `ChatPhotoBrowser: UIViewControllerRepresentable`，原 `ChatMediaGalleryView` 继续由 SwiftUI `fullScreenCover` 持有状态、工具栏、保存/分享、错误反馈与生命周期。未从全局窗口寻找控制器，也未修改依赖源码或版本。

原 TabView 分页和自写 `ChatMediaZoomView` 已移除，图片使用库的 `JXZoomImageCell` 承担捏合、双击及下拉手势；薄适配 Cell 通过已有 Kingfisher 处理器显示解包文件，GIF仍用 AnimatedImageView，离屏停动画并取消加载，复用/失效时清除请求身份，防止迟到图片写回。视频按 `JXPhotoBrowserCellProtocol` 进入同一浏览器，Cell承载SwiftUI视频内容与系统播放控制，复用三页播放器和首帧封面逻辑。库负责全部水平分页和下拉关闭，关闭动作回写SwiftUI，关闭动画期间暂停声音但保留画面，消失后统一释放。

库页码通过不可见 Overlay 桥接到消息ID，等页码落定后启动当前视频；重复布局通知不重新加载，快滑过期回调和卸载后回调丢弃。补入本机历史时按消息ID恢复位置，只有媒体列表身份变化才调用库的reloadData；下载完成或播放状态变化只刷新可见Cell，避免整页重载。保留初始点击定位、图片/视频混排、贴纸独立预览、合并记录不分享/不混入会话历史、原文件保存/分享、三页预备、撤回/删除、后台及AUTH清理。

验证：画廊、SwiftUI桥接页码/回调、资源生命周期39项和播放器10项检查通过，原预览失效12项、下载/解包取消及文件清理通过；最终无签名 generic iOS workspace 构建 exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-20261019-jx-swiftui-final-build.log`），本轮桥接和Cell无新增编译警告；本轮范围 `git diff --check`通过。全仓此前 `OriginalInvitationCodeView.swift` 第42行行尾空格未在本轮处理。专项日志 `/tmp/ddlNew-jx-gallery-checks.log`、`/tmp/ddlNew-jx-playback-checks.log`。Mobile MCP按此前约定继续暂停，未安装或操作设备，真机GIF、视频控制、慢拖/拖到一半取消、快滑、下拉关闭和保存分享需要重新Run复验，离线回归不代表手势或帧率已验收。未提交/推送，保留已有依赖、登录和邀请码改动；当前预览实现以本节为准。

## 2026-10-19 通过 SPM 添加 JXPhotoBrowser

按用户指定的 `https://github.com/JiongXing/PhotoBrowser.git` 添加 Swift Package，应用 target `ddlNew` 引入并链接 `JXPhotoBrowser` 产品，版本规则为 4.2.0 起、下一个主版本之前。workspace 的 `Package.resolved` 已由 Xcode 解析并锁定 4.2.0（`0a09aa30ffddfbae30195e3d8c2814a5a5f321f3`），原有 26 个依赖的版本与 revision 均保持不变。该发布版最低 iOS 15，兼容当前应用 iOS 16 目标。

本轮仅接入依赖，现有聊天预览仍走 `ChatMediaGalleryView`，尚未迁移到 JXPhotoBrowser，也未增加 SwiftUI 桥接或视频 Cell。既有聊天、登录及邀请码工作区改动保留，不提交/推送，Mobile MCP 继续暂停。

验证：SPM 解析成功、工程文件格式及应用 target 产品/链接关系检查通过；无签名 generic iOS workspace 构建正在执行，结果待补。解析日志 `/tmp/ddlNew-20261019-photobrowser-resolve-system.log`，构建日志 `/tmp/ddlNew-20261019-photobrowser-build.log`。

## 2026-10-19 多视频预览翻页停顿与闪帧

用户已确认上一轮图片预览与聊天页闪色修复有效，继续反馈多个视频左右切换时停顿、闪一下。代码检查发现翻页、加载当前页、开始播放三处重复销毁旧播放器并清空 AVPlayerItem，播放界面只在选中页挂载，且新播放器尚未出首帧就撤掉封面。生产播放管理器替换系统边界后，保留旧页画面、音频会话连续性、往返复用及统一释放四项初测均失败。

`ChatMediaGalleryPlayback` 改为随三页资源窗口缓存暂停的播放器；选中时才播放，翻页仅暂停并保留旧页画面，连续视频沿用一次音频会话，进入图片归还音频但保留邻页画面，退出/后台统一清理。`ChatMediaGalleryResources` 同时提前下载、解包相邻视频并准备播放器，退出窗口、重试及关闭时释放，最多保留当前与左右各一页；迟到下载继续受任务取消、上下文和 Store 身份守卫约束。视频下载和播放策略以本节为准。

新增 `ChatMediaGalleryVideoView` 桥接 AVPlayerViewController，保留系统播放控制；每页挂载独立稳定的播放器，非当前页关闭交互。封面只在系统 `isReadyForDisplay` 表示首帧已准备好后移除，使用实际画面就绪信号而非固定延时。已预备失败的视频选中时仍显示重试反馈，旧页迟到失败不能停掉新页。

验证：生产播放管理器专项10/10项、画廊生产方法与资源窗口30/30项通过；原预览失效12项、下载/解包取消及文件清理通过。最终无签名 generic iOS workspace 构建 exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-20261019-video-gallery-final-build.log`），本轮媒体文件无新增编译警告，修改范围 `git diff --check`通过。专项日志为 `/tmp/ddlNew-video-playback-final.log` 与 `/tmp/ddlNew-video-gallery-final.log`；全仓仍有此前 `OriginalInvitationCodeView.swift` 第42行行尾空格，未在本轮改动。Mobile MCP继续暂停，未操作或安装设备；新版本多视频慢拖、拖一半取消、快速往返、首帧遮罩与实际流畅度仍需真机复验。未提交/推送，保留此前图片预览、登录和邀请码改动。

## 2026-10-19 媒体预览闪色与翻页中途缺图

用户录屏 `ScreenRecording_10-19-2026 14-00-03_1.MP4` 按50毫秒抽帧：2.85～2.90秒聊天页短暂变深色，2.95秒恢复浅色后全屏预览滑入；7.4秒附近翻页一侧为空黑，只有另一页图片移动。原画廊使用 `.preferredColorScheme(.dark)`，同时只有 `currentID` 对应页挂载原图，翻页立即 `preview.close()` 清空文件；邻页依赖缩略图。后者已用生产 `select` 提取回归复现失败，不能用之前17项生命周期检查当作滑动视觉已验收。

预览深色改为局部 `.environment(\.colorScheme, .dark)`，避免外观偏好向呈现容器传播。新增 `ChatMediaGalleryResources`，按消息ID保留当前与左右各一页，图片下载、解包及本地解码在开始滑动前主动准备，不依赖 TabView 邻页出现；邻页被选中复用同一 Store 和文件，退出三页窗口才取消释放。每个 Store 继续注册原 Runtime 删除/撤回失效机制，后台、关闭、AUTH或会话失效取消整个窗口；迟到翻页不能在后台重启准备。视频只在选中时下载播放，离开立即停播，未完成的视频下载取消；已完成的邻页视频文件可复用。

静态图片通过共用 Kingfisher 处理器后台解码，预览长边最多2048像素、缓存仅内存且120秒过期；GIF保留动画，非当前页停动图并重置缩放。下载原文件、保存和分享仍使用完整文件。当前与邻页最多三份活跃预览，Kingfisher自身的可复用内存缓存不计为活跃页面，也不宣称整个进程只保留三张位图。

验证：画廊生产方法与资源窗口专项24/24项通过（`/tmp/ddlNew-gallery-paging-final.log`）；原预览失效12项、下载/解包取消与文件清理、首屏定位11项通过。最终无签名 generic iOS workspace构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-20261019-gallery-final-build.log`），本轮文件无新增编译警告、`git diff --check`通过。录屏抽帧保存在 `/tmp/ddlNew-gallery-recording/`，未修改原视频。Mobile MCP继续暂停；新包实际闪色消失、慢拖/撤回拖动、快速往返、GIF/视频切换和放大手势需重新Run复验，离线检查不等同真机帧率。未提交或推送，保留既有登录、邀请码及工程改动。

## 2026-10-19 登录协议勾选迁移

按用户要求对照 xgd `NoaLoginAccountManagerView` 与 `ProtocolPolicyView`：真实 `LoginView` 增加默认未勾选的协议复选框，隐私政策和使用支持分别打开现有在线网页，阅读不自动勾选。未勾选点击登录时先显示提示，取消不发起登录；“同意并继续”勾选后执行原账号登录。勾选只在当前页面生命周期内保留，不随记住密码持久化。登录页既有账号文案修改保留。

真实 `AccountRegistrationView` 删除协议勾选、网页入口和浏览器状态；`AccountRegistrationInput` 删除同意字段、校验及对应错误，既有注册检查同步更新。注册仍按原流程注册并完成 AUTH，注册入口不额外增加协议拦截；缓存会话恢复保持原行为。

验证：账号注册专项通过，账号登录 26/26 项通过；无签名 generic iOS workspace 构建 exit 0、`BUILD SUCCEEDED`（`/tmp/ddlNew-20261019-login-consent-build.log`），本轮文件 `git diff --check` 通过。全仓检查仍有原有 `OriginalInvitationCodeView.swift` 第42行行尾空格，未改动该文件。Mobile MCP 保持暂停，实际弹窗、勾选和网页返回交互待真机复验；不提交或推送。

## 2026-10-17 APP DNS1 原生 TCP 连接流程迁移

本轮按 xgd 已确认的新流程迁移：APP 仅查询 `t{小写邀请码}.{mainDomain/backupDomain}`，不查询 Web 的 w 前缀。首次连接依次尝试主域、备域（配置非空时）、BIN；启动恢复和已登录重连先探测同企业的新缓存，再进入这三个来源。每个来源拿到原生 TCP 后并发进行真实 ECDH 探测，全部失败才进入下一来源；首胜交现有 SDK 建立正式 Socket，正式 ECDH 后通过 TCP 获取 systemConfig，配置有效才保存可恢复入口，用户 AUTH 成功才进主界面。旧五路 DNS、OSS Auth 和旧降级实现当时保留且未参与新链路；此边界已由2026-10-22章节更新为DNS1耗尽后自动兜底。

新增 `Network/DNS1`：AAAA 两字节大端索引 + 十四字节内容，首索引仅允许0/1，排序、重复冲突和缺片校验；接受 TCP CSV 或含 tcp 的 JSON。BIN 使用原大小写邀请码的 MD5 十六进制字符串，经既有 SHA1/AES-128-ECB/PKCS7 解密，支持原始密文和 Base64 包装。DNS 请求及 BIN 下载最多5秒，单来源 TCP 探测最多4秒；取消结束业务等待，忽略无取消句柄的 SDK 迟到回调。新流程不调用旧导航服务，也不调用 getTcpConnectionList。

缓存使用独立 `ddlNew.dns1Navigation.v2`，绑定邀请码并校验主域、备域及 BIN 模板的版本摘要。为复用现有 ObjectMapper 存储，新载荷在内存转为本地 Protobuf 容器，`meta.navVersion` 标识 DNS1 版本，`meta.traceID` 在该本地版本保存可选 HTTP URL 数组；这不是服务端旧导航响应。旧缓存只迁移上次成功的邀请码，不恢复旧节点。已探测首胜仅放在当轮内存连接方案，磁盘恢复不能继承成功状态；旧 SDK 配置接口忽略空 Host，因此显式清空 API Host，防止串用前一企业。

`OSSConnectionPlan` 的 HTTP/文件/上传地址现在可空。空 Host 的系统配置缓存必须匹配邀请码；业务请求继续走 SDK TCP。完整云附件 URL 可以直接预览，无 Host 的相对文件地址不能推算；Minio 私有上传缺少显式 HTTP 地址时返回明确错误，第三方 OSS 上传仍按系统配置走原供应商流程。HTTP 不是连接前置条件，不查询 w 地址补 HTTP，也不从 TCP 端口猜 HTTP。网络质量及 HTTP 优选不凭空添加旧导航开关。

源码入口：`DNS1NodeRaceCoordinator.swift`、`DNS1SourceRace.swift`、`DNS1Payload.swift`、`DNS1CallbackWaiter.swift`；现有 `OSSNodeRaceCoordinator` 新分支统一承接邀请码和登录后刷新，`IMConnectionCoordinator` 新分支承接冷启动/访客恢复。原 generation、登录身份、取消、AUTH 与维护归属守卫保持。

验证：DNS1 协议/来源/取消39项通过，生产适配与真实 Protobuf/ObjectMapper 缓存25项通过（网络 SDK 使用匿名边界）；覆盖升级只迁移入口、不使用旧节点、跨企业隔离、空 HTTP 配置归属、即时首胜不落盘及旧 HTTP 回调隔离。统一81组初跑79组通过，附件下载及启动恢复两组因测试替身仍使用旧参数形状编译失败，更新替身并增加 TCP-only 附件场景后专项复跑通过；后新增缓存集成入口也通过，当前82个入口已分批验证，未把它描述为一次82组全量运行。原网络重连、系统配置（含 TCP-only）、会话恢复与附件取消/下载专项均通过。

只读真实接口检查：t1000 返回7条AAAA，生产解码为4个TCP、0个HTTP；BIN生产解密得到相同4个TCP和4个HTTP。未发送账号登录或业务写请求。最终无签名 generic iOS workspace 构建 exit0、BUILD SUCCEEDED（`/tmp/ddlNew-dns1-release-check-build.log`），`git diff --check` 通过；保留既有SDK umbrella及静态库调试路径警告。验证入口为 `Tests/DNS1/run-checks.sh`、`run-integration-checks.sh` 和显式联网的 `check-live.py`；过程日志与夹具均在临时目录，没有新增调试数据文档。

Mobile MCP继续暂停，本轮未操作或安装设备、未提交/推送。真机邀请码1000、冷启动AUTH恢复、断线重连及相对资源/私有上传仍需对应服务器与设备验收，不把接口解析、匿名SDK边界或无签名构建作为真实登录/双端消息验收。


## 2026-10-16 聊天图片视频全屏预览

用户要求参考旧项目的图片、视频预览并评估复用三方库。只读对照 xgd `NoaChatViewController.imageVideoBrowserWith:`：旧端使用源码内置的 **KNPhotoBrowser**，混排本机缓存的图片视频，定位点击条，黑底全屏、左右分页、图片缩放、下拉退出、右上角更多；关闭页码和长按，视频先下载后自动播放。其 UIKit 库可以桥接 SwiftUI，但旧端版本已接入 SDWebImage、FSPlayer、旧资源路径、语言工具和解密管理器，不能原样直接接到新项目；这次按用户给出的备选方案使用 SwiftUI `TabView`，没有新增预览库依赖。

新增 `ChatMediaGallery`、`ChatMediaGalleryView`、`ChatMediaZoomView` 与 `ChatMediaGalleryPlayback`。聊天图片/视频改为 `fullScreenCover`，保留打开聊天的 Store；进入后按稳定消息 ID 定位，时间正序混排，并复用 `SDKChatHistorySearchClient` 补齐本机全部图片视频缓存，不额外拉远端历史。当前页才挂载原图解码和播放器，邻页只展示已有缩略图。图片支持 GIF、捏合、双击、放大后平移，未放大时下滑关闭；不显示系统文件预览标题和底部常驻分享条。关闭入口在左上，右上菜单保存到相册或系统分享；相册用途说明同步包含图片视频。

下载和 XOR/AES 解包复用原 `ChatMediaPreviewStore`，原有身份、取消、删除/撤回失效及临时文件清理不变。切页先停播/取消下载，再改变当前 ID，避免新页缓存命中后被旧页关闭回调覆盖。前后台、会话关闭和 AUTH 退出停止视频，迟到下载不能开始播放；保存授权等待后复核身份和原条，避免系统授权短暂切非活跃导致保存被静默放弃。文件和语音继续原详情；贴纸单独全屏，合并记录内仅浏览该记录媒体且不开放保存/分享，不混入整个会话缓存。

验证：新增画廊专项先复现旧入口缺失（3/10通过），实现后10/10通过；追加真实生产翻页/加载方法的生命周期提取检查，并复现“尚未开始即被取消的旧任务关闭新页播放器”（16/17通过），将取消判断移到任何清理副作用之前后终版17/17通过。覆盖快速翻页、任务取消、非前台及AUTH退出的迟到播放隔离，日志 `/tmp/ddlNew-gallery-final-green.log`。夹具只替代网络、系统播放器与AUTH边界，不代表真实视频或手势已验收。首轮 workspace 构建遇到同期消息列表引用的新 `MessagingOnlineIndicator` 尚未进入该次构建文件快照，随后文件已出现在工作区；未改动该同期组件，等待共享构建结束后重试成功。最终无签名 generic iOS workspace 构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-20261016-media-gallery-complete-build.log`），本轮新增文件无编译警告，`git diff --check`通过。统一离线回归80/80组exit0，逐组耗时合计463.49秒，结果 `/tmp/ddlNew-20261016-media-gallery-qa/summary.json`；全量中的画廊专项为16项快照，追加取消入口修正后单独复验终版17/17通过。

Mobile MCP继续暂停，不操作或安装设备，不提交/推送；原有聊天、在线标识与工程/SPM改动保留。重新Run后待验：图/视频左右连续翻页、GIF、横竖图捏合/双击/长图拖动、缩放后不误关闭、视频自动播放/快滑/后台停播、关闭返回原聊天位置、首次相册授权后保存、合并记录无分享菜单，以及浏览中远端撤回/清历史后停止播放和下载。实际视觉、系统手势、Photos写入及双端媒体结果不能由离线或编译代替。


## 2026-10-16 消息与通讯录在线标识尺寸、位置统一

用户反馈消息页16点圆点偏大、通讯录8点偏小，并要求位置参考旧端后统一。只读核对 xgd：`NoaSessionCell` 位于头像右下，`NoaContactListTableCell` 位于右上；本轮两页统一采用消息页的头像右下角，直径12点、1点内边框，均经UIAdapter缩放。新增共用 `MessagingOnlineIndicator`，使用既有在线绿和自适应页面底色，两处调用同一组件。在线状态、注销隐藏及辅助功能规则保持原实现；本节取代下一节16点展示尺寸的历史描述。

专项验证：会话在线10/10、通讯录生产44项/SDK分页19项/字段合并检查通过；无签名generic iOS workspace构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-20261016-online-indicator-size-build.log`），本轮三个UI文件无编译警告，`git diff --check`通过。Mobile MCP继续暂停，未安装或操作设备，真实视觉待重新Run；不提交/推送，既有聊天及会话在线数据改动保留。

## 2026-10-16 消息列表好友在线标识

用户要求消息列表参考旧项目标识在线用户。只读对照 xgd `NoaSessionCell.setupUI/setModel`：仅单聊读取 `LingIMFriendModel.onlineStatus`，在线时在50点头像右下角显示16点绿色圆点及1点边框，离线/无好友记录/其他会话隐藏。新项目原 `ConversationRecord` 没有在线字段，因此虽然通讯录已有真实在线状态，会话行仍无法显示。

本轮给会话快照新增默认false的 `isOnline`；`SDKConversationsClient` 在原头像读取边界共用同一好友记录，只有单聊好友明确在线且未注销才设为true。`MessageView` 沿旧端头像右下角16点圆点呈现，使用已有 `MessagingTheme.online` 与自适应底色边框、UIAdapter缩放，整行VoiceOver追加“在线”。状态更新复用现有 SDK 在线通知→好友库写入→`SDKContactsDelegate`→`ContactsStore`→`TabbarView.onChange`→会话缓存重读；不增加在线轮询、网络接口、全局状态或订阅。下线后圆点消失，置顶、未读、摘要与排序保持原规则。

新增 `Tests/Conversations/run-online-checks.sh` 提取真实会话映射及整行辅助功能方法，并运行真实 `ConversationsStore`。原实现4项失败（`/tmp/ddlNew-conversation-online-red.log`），修正后10/10通过（`/tmp/ddlNew-conversation-online-green.log`），覆盖在线、下线/再次上线、群聊、缺好友、注销、未读排序及切账号。会话排序/Store/操作/预览回归通过；最终统一离线79/79组通过、exit0，逐项耗时合计366.08秒（`/tmp/ddlNew-20261016-conversation-online-qa/summary.json`）。无签名generic iOS workspace构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-20261016-conversation-online-build.log`），本轮修改文件无新增编译警告，`git diff --check`通过。

Mobile MCP继续暂停，本轮未操作设备、不提交/推送，保留既有聊天改动。重新Run后需在消息页对照真实好友上下线，核对圆点实时出现/消失、浅深色及置顶同时显示；真实服务端在线通知与真机视觉不以离线检查替代。

## 2026-10-16 单聊拉黑拒收即时更新发送失败

用户报告：拉黑好友后发送，当前页只有“已拉黑”系统提示，原消息仍像成功，退出重进才出现红色感叹号。只读对照 xgd `NoaIMSDKManager+ServiceMessage.toolDealReceiveServiceMessageForUserFriendBlack` 与 `NoaChatViewController.cimToolChatMessageUpdate`：106通知携带好友ID、原消息本地ID和拉黑方向，SDK先插系统提示，再把原条落库为失败并更新UI。新项目同一SDK已做失败落库，但 `ChatMessageMerge` 无条件保护既有 `.sent`，把后到的失败更新覆盖回成功；重新进入读取库中失败才生效。

修正：`SDKChatDelegate` 从106通知发布明确的拉黑拒收事件，核对单聊、收件人、好友ID、非空原消息ID与方向1/2；`ChatStore` 只更新当前单聊里本人对应的正文。`ChatMessageMerge` 让该业务拒收覆盖传输ACK，并保留拒收原因，SDK随后的普通失败、旧发送中/成功快照及迟到ACK不能恢复成功。主动重试清除本次拒收标记，解除拉黑后仍可沿SDK重发并由新ACK确认；普通网络超时仍不能回退正常成功消息。系统“已拉黑”/对方拒收提示和既有气泡失败图标、重试沿用旧端流程，没有把黑名单本地状态当成服务端投递结果，也没有改SDK持久化、发送协议或输入权限。

离线检查已用提取的真实 `SDKChatDelegate.publish`、真实 `ChatStore` 与生产归并复现原缺陷（`/tmp/ddlNew-blacklist-send-red.log`），修正后通过。扩展覆盖ACK/拒收错序、SDK原条失败更新、历史旧成功回读、同ID主动重试、普通网络失败保护、9种正文类型、其他好友/收件人/群/未知ID隔离与关闭后迟到回调。最终统一离线78/78组通过、exit0，逐项耗时合计466.86秒（`/tmp/ddlNew-20261016-blacklist-send-qa/summary.json`），专项结果见该目录的 `Tests-Chat-run-sdk-message-parity-checks.sh.log`。最终无签名generic iOS workspace编译exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-20261016-blacklist-send-final-build.log`）；首轮构建发现的新纯值判断属性并发隔离警告已补 `nonisolated`，终版本轮修改文件无新增编译警告，`git diff --check`通过。

Mobile MCP继续暂停，本轮不操作设备、不提交或推送，保留此前媒体/撤回/滚动等工作区修改。重新Run后待验：本人拉黑后连续发送、对方拉黑后发送，系统提示出现时原气泡立即带红色感叹号且不显示已读；重进状态一致；解除拉黑后点失败重试及普通单聊成功。服务器拒收和解除后真实投递仍须双端确认，离线与编译不能替代。

## 2026-10-16 连续翻阅消息的可见性刷新隔离

用户反馈上轮调整后仍不够丝滑，确认使用 Xcode Run 调试版。继续按 SwiftUI 性能审查技能检查源码，未恢复 Mobile MCP。发现上一轮测试只覆盖相同可见集合内的 9 点小幅移动：实际连续翻阅时，每跨过一条消息都会写 `ChatRoomView.@State visibleMessageIDs`，用于游戏动画的可见资格因此让整个聊天根视图参与更新，普通文字也受影响。新增跨消息边界的生产回调提取测试先失败：240 次回调产生 240 次页面状态写入。

修复把可见集合移入页面持有但不观察的 `ChatScrollGeometry` 引用对象。真实已读仍即时使用同一集合；只有 `ChatVisibleGameStickerBubble` 订阅自己消息 ID 对应的布尔可见性，`removeDuplicates` 阻止其他文字进出视口刷新该游戏行。懒加载新建游戏行立即接收当前资格，离屏/重置撤销资格，前后台与减少动态效果逻辑保留。普通文字、输入区和整个列表不再观察该集合。未修改 SDK、消息收发或列表容器；同期工作区出现的黑名单拒收修正原样保留。

验证：扩展滚动专项 16 项全部通过；同集合 240 次和跨边界 240 次回调均为零页面状态写入，后者从修改前的 240 次降至 0；游戏行初始不可见、其他文字变化不重复发布、迟订阅立即获知可见、离屏撤销资格均验证通过。首屏/发送回底部 11 项、定位 Store/布局各 12 项、输入焦点与游戏结果/动画归并检查通过。这里统计的是提取的生产回调中的页面状态写入，不能等同于真实 SwiftUI body 次数或帧率。

构建：首次因默认 DerivedData 的 `build.db` 被另一构建占用而失败，未中断对方构建；尝试独立目录时需要重新准备依赖，随后确认原目录已释放锁，终止本轮自己的独立构建并复用已有缓存。最终无签名 generic iOS workspace 构建 exit 0、`BUILD SUCCEEDED`，日志 `/tmp/ddlNew-20261016-scroll-visibility-final-build.log`，`git diff --check` 通过。专项先失败/后通过日志为 `/tmp/ddlNew-scroll-boundary-red.log`、`/tmp/ddlNew-scroll-boundary-final.log`。

验收仍需重新 Run 同一普通文字会话并连续上下翻阅，确认首屏、屏外置顶/引用定位、发送回底部以及游戏离屏/返回行为。若仍卡顿，下一步用真机 Product → Profile 的 SwiftUI/Time Profiler 记录同一会话 15–30 秒滑动；同时保留 Debug Run 与 Release Profile 对照，不能把“调试版”直接当作已证实的唯一原因。本轮未安装/操作设备，未提交或推送，未声明真机流畅度已达标。

## 2026-10-16 普通文字聊天滚动性能续修

用户再次报告聊天上下滑动严重掉帧，并确认普通文字也卡顿。本轮继续暂停 Mobile MCP，不操作设备。此前 10 月 15 日的几何状态降频修复仍在；本轮发现它未覆盖的源码开销：正文用普通 `VStack` 同时创建所有已加载消息行，行内重复构造 `NSDataDetector`、157 项表情词典及正则；没有引用的普通消息也调用 `referenceSummary("")` 扫描整份历史；一批已读完成后逐条归并、排序并发布消息快照。此外，群改名修复直接观察整个会话 Store，会话预览/未读变化也使聊天根视图失效。这些是已确认的代码工作量，尚未取得真机 Time Profiler 或掉帧轨迹，不能据此给出各项卡顿占比。

本轮修改：

- `ChatRoomView` 消息行改为 `LazyVStack`，保持稳定消息 ID、相邻日期判断与原间距；末尾定位标记位于懒加载区域之外，继续提供内容底部几何。置顶/引用定位先按 ID 使目标参与布局，拿到行坐标后才消费请求；发送成功回底部也等待实际底部进入视口才结束请求。首屏、下拉分页和键盘逻辑保留，真实可变行高的滚动表现仍待设备验收。
- `ChatMessageBubble` 复用链接识别器；`ChatEmojiCatalog` 复用生产词典和正则，普通文字直接生成原文片段，不进行词典构造或正则匹配；未知标记、Unicode、UTF16 光标和删除语义继续保留。
- `ChatStore` 空引用 ID 立即返回；一个可见已读批次只归并、排序及发布一次消息快照，原身份/清历史/语音播放资格守卫保留。
- 群名更新改为订阅会话数据后比较当前群名，仅名称变化才写页面状态，其他会话与未读/预览变化不触发标题状态更新。群改名即时显示继续有效。

验证：新增真实 `ChatStore.$messages` 订阅断言，修改前“一批可见已读只发布一次消息快照”失败，修改后通过。名称专项 24 项（含同群名连续 100 次输入零状态写入）、首次/发送定位 11 项、定位 Store 12 项与布局 12 项、滚动回调 11 项、视口 7 项、Chat Store 与表情/光标检查均通过。滚动回调继续保持同可见集合 240 次几何回调零页面状态写入和零重复已读调用。最终无签名 generic iOS workspace 编译 `BUILD SUCCEEDED`，日志 `/tmp/ddlNew-20261016-chat-scroll-final-build.log`，`git diff --check` 通过。

离线文字开销对比：在同一 Mac 上，以 HEAD 的旧源码和修改后的真实表情解析/链接检测方法分别编译同一未优化宿主，唯一资源边界替换为实际 `ChatEmojiCatalog.plist` 路径。1000 条普通文字（中文/换行/Unicode emoji）合计约 310ms → 24ms；1000 条含旧表情与 URL 的混合文字约 288ms → 28ms，两组输出计数一致。脚本、提取源码与日志在 `/tmp/ddlNew-scroll-benchmark/`，已读失败复现在 `/tmp/ddlNew-scroll-store-red.log`，修复后在 `/tmp/ddlNew-scroll-store-green.log`。这是单次宿主微基准，**不代表真机帧率、SwiftUI 实际布局耗时或整体加速倍数**。

接手验收：重新 Run 新包，在同一普通文字会话连续上下滑动；加载多页后复验日期、下拉锚点和位置保持；从屏外置顶/引用跳转、发送各类消息后回底部、展开/收起键盘、设置返回群名同步；混合媒体检查动图离屏停止与重新出现。若仍明显掉帧，采集该真机 Release 配置的 Animation Hitches/Time Profiler，并与相同历史量、相同滑动动作比较。本轮未安装、未声明真机已流畅，未提交或推送，既有媒体/相机/撤回样式改动保留。

## 2026-10-16 群改名后聊天导航标题同步

现象：从消息列表进入群聊，经右上角设置修改群名，再返回聊天页仍显示旧群名，退出到消息列表后重新进入才更新。根因是 `ChatRoomView.chatTitle` 对群聊只读取进入时的 `ChatRoute.title` 快照，未观察实时会话数据。SDK 的 `changeGroupNameWith` 已在成功后写入会话名称并发出会话更新，设置页保存后的详情重载也会更新会话缓存，数据链路本身已有刷新信号。

修复：`ChatRoomView` 订阅登录会话持有的 `ConversationsStore`，群标题按当前群 ID 和 `.group` 类型读取最新会话名称，原生导航标题和自定义 principal 标题共用此值；数据暂缺或名称为空时回退路由名称，再回退群 ID。后续滚动性能修复收窄为仅群名变化时更新局部状态，避免整个会话 Store 的预览/未读刷新重建聊天页。单聊仍按通讯录备注/昵称取标题。参考 xgd `NoaChatViewController` 取得群资料后更新 `topView.chatName` 的行为，沿用当前共享数据流，不新增改名通知或额外网络请求。

离线验证：在现有 `run-contact-name-checks.sh` 中提取真实生产 `chatTitle`，新增群名更新、其他群隔离、同 ID 单聊隔离及空值回退共 6 项。修改前两个群名更新断言失败，修改后名称专项 23 项通过；聊天设置专项 14 项、会话排序/Store/操作/预览检查全部通过。无签名 generic iOS workspace 构建 exit 0、`BUILD SUCCEEDED`（`/tmp/ddlNew-20261016-group-title-build.log`），`git diff --check` 通过。

设备验收待办：重新 Run 后按“消息列表 → 群聊 → 右上角设置 → 修改群名称 → 返回群聊”确认标题为新名称，连续再改一次验证仍可更新，同时确认单聊备注标题正常。Mobile MCP 按用户要求继续暂停；本轮未安装或进行真机操作，未提交、未推送，保留工作区此前聊天改动。

## 2026-10-16 图片与视频上传前后气泡样式

后续按用户要求移除聊天输入框上方的“取消上传”按钮行，上传时仅在媒体气泡旁显示菊花，输入区不再因该行出现而增高。退出页面及会话失效时的上传取消和临时占位清理继续执行。

聊天“拍摄”入口改用 `fullScreenCover` 全屏呈现原生相机，并铺满屏幕安全区；拍摄结果和取消继续通过原有相机代理返回聊天页。相机展示状态由聊天页持有，全屏覆盖触发离开回调时保留会话和在途附件；会话失效时关闭相机。

底部“更多”菜单按用户要求移除，相册、拍摄、文件改为三等分；该菜单内的原图开关和收起键盘按钮随之移除，图片沿用默认准备方式。

上述输入区和相机调整的焦点同步专项、首屏定位10项检查通过，最终无签名 generic iOS workspace 构建 `BUILD SUCCEEDED`（`/tmp/ddlNew-20261016-chat-toolbar-final-build.log`），`git diff --check`通过。Mobile MCP保持暂停，全屏相机的实际拍摄和返回待真机复验。

按 xgd `NoaChatViewController` 的本地先展示流程，图片/视频在上传开始前以临时文件或视频封面插入当前聊天列表，使用同一个 `localID` 在上传完成后接入 SDK 发送队列；ACK 仍是发送成功依据。上传及等待 ACK 时，16 点系统菊花位于本人媒体气泡左侧；取消、上传失败或入队失败会移除临时占位，上传失败继续用 Toast 提示。权限在插入占位前和正式发送前各复核一次；迟到取消只可删除仍处于上传中的占位。

图片、视频在本地和远端状态均按旧端 170 点长边和非对称圆角展示；视频封面使用 xgd 的居中播放图标、左下视频标识与时长。GIF 完成后仍按原动画处理，但沿用相同媒体尺寸。临时路径仅用于页面预览，不进入 SDK 消息体；完成后释放上传临时文件。离线验证：`Tests/Chat/run-media-checks.sh` 7 项、`Tests/MigrationAcceptance/run-media-checks.sh` 6 项、`Tests/Chat/run-checks.sh`、消息可见性 11 项、动作 10 项均通过；最终无签名 generic iOS 构建见 `/tmp/ddlNew-20261016-media-preview-final-build.log`。Mobile MCP 继续暂停，尚未在真机上核对网络上传中的菊花、封面切换及双端接收；上传失败目前以移除占位加 Toast 处理，未实现旧端失败气泡内重试。

## 2026-10-16 聊天气泡缺失头像与消息列表统一

用户要求对方未设置头像时，聊天气泡使用消息列表的单聊默认头像。`ChatMessageBubble`原先使用灰白的`person.crop.circle.fill`，现改为消息列表`MessageView`的`person.fill`、森林绿强调色、薄荷底色与圆形边框，并按40点气泡头像缩放图标。远端头像URL、本人资料优先级及消息映射规则未变；下载失败时同样显示该占位。头像专项16/16通过；无签名generic iOS workspace构建`BUILD SUCCEEDED`（`/tmp/ddlNew-20261016-chat-avatar-placeholder-build.log`）。Mobile MCP按用户要求继续暂停，真机视觉仍待重新Run验收。

## 2026-10-16 群聊撤回占位首屏稳定

用户报告群聊进入时撤回提示稍后才出现并造成页面抖动。对照xgd：SDK把撤回控制条写入缓存，同时把原消息标为status2；新页首次读取缓存时直接过滤type8控制条，仅远端历史返回后补标原条，因此本机已知撤回可能晚于首屏出现。`SDKChatClient.cached`现读取同页控制条的目标ID，在发布首屏快照前用本机原条标记撤回；原条不在当前100条时，以原条撤回占位替换隐藏控制条，保持分页条数与原条身份，避免随后远端历史再插入。原条缺失、已删除或属于其他会话时不虚构占位；原有实时撤回、远端回读和引用失效规则保留。纯生产归并方法专项先RED后5/5通过（`Tests/Chat/run-recall-cache-checks.sh`）；Chat Store专项、SDK消息专项46项与消息可见性11项均通过，最终无签名generic iOS workspace构建`BUILD SUCCEEDED`（`/tmp/ddlNew-20261016-recall-cache-build.log`）。真实SDK本机缓存内容及页面动画仍需重新Run验收。Mobile MCP继续暂停。

## 2026-10-16 单聊气泡昵称回退

用户澄清单聊接收消息的气泡上方原本就不显示对方名字，并要求撤回本轮显示改动。核对 xgd `NoaMessageContentBaseCell` 后确认旧端只在群聊显示发送者昵称；当前 `ChatRoomView` 已恢复仅群聊传入 `showsSenderName`，`ChatMessageBubble` 恢复原条件渲染。导航栏和好友备注/昵称映射未改变。回退后无签名 generic iOS workspace 构建 `BUILD SUCCEEDED`（`/tmp/ddlNew-20261016-single-sender-name-revert-build.log`）。

用户随后要求发送消息的已读状态采用旧项目样式，不再显示 `1/1已读`。旧端 `NoaMsgReadProgressView` 在本人成功发送、`showUserRead` 允许时，于气泡左下侧显示 16 点状态：未读空心圆、部分已读圆环与扇形进度、全部已读圈内对勾；通话消息不显示。当前 `ChatMessageBubble` 改为相同形状和位置，复用 xgd 的空心圆/对勾资源，使用现有绿色主题着色；部分已读比例按 SDK 人数夹到 0...1，人数仅作为辅助功能标签。发送中/失败、收到消息及无权限不显示状态。已读权限专项 59 项通过，终版无签名 generic iOS workspace 构建 `BUILD SUCCEEDED`（`/tmp/ddlNew-20261016-read-style-build.log`）。Mobile MCP 按用户要求暂停，本轮未进行真机视觉验收，也未提交或推送；此前聊天功能修复保留。

## 2026-10-15 聊天模块旧端对照轮次

用户扩大范围要求按旧项目 xgd 对聊天模块做全功能对照，并允许 Mobile MCP。本轮已修复发送成功回最新、当前会话逐条转发回最新、发送中/失败本机删除、删除权限兼容和群管理员/群主撤回窗口差异；完整交接、验证范围和未迁移依赖见[聊天旧端对照交接](CHAT_LEGACY_PARITY_HANDOFF_2026-10-15.md)。验证：42/42 Chat离线入口、16/16 MigrationAcceptance、连接iPhone目的地 Xcode `BUILD SUCCEEDED`、`git diff --check`通过。Mobile MCP只读查看已有安装版聊天页和置顶入口；未发送测试消息，未安装本轮包，故代码行为仍需QA群和双端进行设备验收。不提交、不推送。

## 2026-10-15 通讯录启动角标与置顶消息主动定位

用户报告启动进入Tab后通讯录红角标短暂出现后消失，以及点击聊天置顶无法定位，并明确要求参考旧xgd。只读对照旧端`NoaChatViewController.groupTopMessageViewDidClickView/groupTopMessageLocation`、`ZGroupTopMessageListViewController.locationButtonAction`和`AppDelegate+DB.updateFriendApplyCountFromService`：置顶正文直接定位、独立列表按钮打开全部置顶；列表先返回聊天再定位，取消首次末尾对齐，本机历史补齐后居中；删除/撤回目标提示找不到。通讯录采用SDK申请未读计数与真实同步记录，不以历史申请列表条数推算未读。

接手工作区已有通讯录角标窄修及`startupBadge`回归，保留并复验：`ContactsBusinessStore.updateUnread`在首次真实未读快照前不猜测数量或写入SDK；真实零不闪角标，真实非零正常展示，同AUTH临时刷新失败保留确认计数，切账号首次失败不沿用旧计数。专项通过（`/tmp/ddlNew-startup-badge-green.log`）。同期资料导航、黑名单刷新及暂存表情资源目录整理均保留。

聊天顶部正文现直接发起定位，右侧条数/列表按钮独立打开置顶列表；从置顶/历史搜索弹层选择后记录目标与会话，在实际`onDismiss`后定位，取消或旧会话选择不执行。`ChatStore`以独立定位revision支持重复点击同一条，先从SDK固定100条本地历史补齐，远端hasMore=false不影响本机已存目标；需要远端补页时等待已有历史请求。仅正常且可展示消息可命中，补页已带回目标但首条未变也可成功；关闭、清历史、后续定位及任务取消使旧请求失效。页面取消首屏和延迟底部跟随，目标行有实际布局且页面可见才居中消费请求；引用定位共用这一滚动链路。

新增`Tests/Chat/run-location-checks.sh`执行真实Store和提取的生产入口/弹层/布局方法，外部SDK及滚动执行用匿名边界替代。重复定位、入口差异、本地历史、布局前时序、在途历史、撤回目标、补页首条不变分别先RED再GREEN；终版Store12项与布局12项通过（`/tmp/ddlNew-location-final-green.log`）。独立只读复核确认三处追加问题补修后未发现剩余阻断。首次全套75/76组通过，失败项为滚动性能测试提取器缺少proxy绑定，已修测试边界；生产几何状态/批量已读逻辑保持。终版统一离线76/76组exit0，逐项耗时合计254.60秒，结果`/tmp/ddlNew-pin-location-final-qa-results/summary.json`。终版无签名generic iOS workspace构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-20261015-pin-location-final-build.log`），本轮聊天文件无新增编译警告，`git diff --check`通过。

追加定位框对比修正：用户真机报告本人绿色气泡与原绿色定位框同色。`ChatMessageBubble`现对本人非视觉媒体气泡使用`onPrimaryAction`反差色（浅色白、深色深绿），3pt内描边向内缩2pt并保留气泡外沿；对方及透明媒体继续使用主题强调色。现有色板计算的浅/深对比为7.87:1、7.71:1。仅样式变更，不新增行为测试或重复全套回归；无签名generic iOS workspace构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-20261015-location-outline-build.log`），该气泡文件无新增编译警告，`git diff --check`通过。真实定位框视觉仍待重新Run复验。

发送成功后回到最新消息：用户要求聊天文字、图片、视频、文件和语音发送成功后自动定位到末条。统一采用SDK带服务端消息ID的`.ack`作为成功边界（附件上传完成/入队不当作消息发送成功），`ChatStore`仅对当前会话的本人消息确认后递增`sendSuccessRevision`；`ChatRoomView`收到后取消旧定位/延迟跟随，设置回到最新意图，并在末条实际布局可用时滚动到底部、清除新消息计数。发送失败不触发；文本、附件、录音、游戏等最终进入同一SDK ACK入口。构建与完整对照轮次的最终验证已记录在本文件顶部及专项交接文档。

Mobile MCP继续暂停，本轮未操作设备、未提交/推送。离线与构建不代表真实SwiftUI滚动、弹层返回或键盘收起动画已验收；重新Run后需复验：冷启动通讯录零/非零未读、顶部正文直达旧消息、列表定位后返回、滑离后重复点同一条、较早消息/下拉补页中点击、键盘已展开时定位及已撤回目标的失败Toast。源码与实时Git优先。

## 2026-10-15 聊天资料发消息路由与刷新黑名单状态

用户报告单聊/群聊经右上角设置进入用户资料后，点击发消息再次进入资料，并要求兼顾通讯录。原资料按钮使用`NavigationLink(value: ChatRoute)`，与设置、成员资料的布尔/直接目标导航混用。现在聊天直属设置/资料/新聊天使用统一`ChatDetailDestination`，最近的`ChatRoomView`通过`contactChatNavigation`接管所有后代资料页的发送入口：按kind+UID匹配同会话时清除直属子树返回原聊天；其他好友整体替换子树为对应单聊，保留sourceGroupID，原聊天Store保留以便返回。未修改外层Tab的NavigationPath或增加第二个NavigationStack。

通讯录等无聊天祖先的资料页使用本页`requestedChat`直接目标push单聊，返回清理目标，支持再次进入；通讯录搜索、分组与列表状态不由这次动作重置。原好友关系、注销、黑名单及来源群访问门禁保持。资料按钮、直属目标和环境动作分别位于`ContactRecordDetailView`、`ChatRoomView`、`ChatDetailDestination`和`ContactChatNavigationAction`。

用户随后报告下拉刷新后发消息禁用、菜单要求重新确认黑名单。已用真实`ContactsBusinessStore`离线复现：`loadBlackState`在请求前删除已确认键，失败后一直nil，资料按钮按未知状态禁用。窄修为刷新期间保留本AUTH上次确认的false/true，成功再替换；失败仍提示错误，首次从未确认失败继续未知。身份/读取revision、写操作与权威全量名单的失效守卫不变，不将未知或损坏响应默认成未拉黑。

路由专项先按旧值路由的外层path追加边界复现8项合同失败，修改后提取实际导航/资料发送方法和系统目标关闭setter，终版12项通过（`/tmp/ddlNew-profile-navigation-final-green.log`）。黑名单刷新专项先RED（`/tmp/ddlNew-blacklist-refresh-red.log`），修改后刷新期间、临时失败、首次未知、已拉黑与既有迟到隔离检查通过（`/tmp/ddlNew-blacklist-refresh-green.log`）。路由版统一75/75组exit0、251.23秒及无签名generic iOS workspace构建exit0；追加黑名单修正后的终版统一75/75组exit0、260.80秒（`/tmp/ddlNew-profile-navigation-blacklist-qa-results/summary.json`），终版无签名generic iOS workspace构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-20261015-profile-navigation-blacklist-build.log`）。本轮文件无新增编译警告，`git diff --check`通过。

路由及追加黑名单修正均经独立只读复核，未发现源码可证实的阻断问题。离线动作/NavigationPath检查不覆盖实际SwiftUI多级清栈、环境传播、返回动画或真实黑名单服务；Mobile MCP仍暂停，本轮未操作设备。本轮不提交/推送，保留同期表情资源目录整理及既有交接改动。真机需重Run复验：单聊设置→好友资料→发消息返回原聊天；群预览/完整成员名单→资料→发消息打开对应单聊并返回原群；通讯录资料→聊天→返回资料→再次发消息；资料下拉刷新在正常/失败网络下的按钮和黑名单菜单状态。

## 2026-10-15 普通文字聊天滚动性能窄修

用户反馈真机聊天上下滑动明显掉帧，页面基本为普通文字。源码及生产回调提取复现确认两处高频工作：每次几何变化都写回聊天页`messageFrames/latestLayout`状态，并为全部可见消息逐条创建已读任务；每行日期判断重新过滤全部可见历史并线性查找前一条。100条匿名消息、可见集合不变的240次拖动/几何回调产生960次状态写入与1200次`markVisible`调用；100行日期展示额外读取完整快照199次。这是离线工作量证据，不是真机重绘次数或帧率测量。

`ChatScrollGeometry`现在只保存命令式定位需要的原始坐标，不逐像素发布状态；展示只观察实际可见ID集合，集合变化/消息资格补齐时单批重查已读。手势结束再补查一次，保留上报失败后在同一视口内再次滑动的重试入口；前后台、子页恢复与Store原有批处理规则保留，异步任务核对会话上下文。消息渲染一次取得过滤快照，以稳定消息ID列举，并直接比较相邻记录的日期。首屏实际底部定位、下拉分页、搜索定位、语音实际播放才已读和游戏可见资格保持原边界；本轮没有改消息容器的懒加载策略。

新增`Tests/Chat/run-scroll-performance-checks.sh`提取生产几何/手势/可见回调与日期方法，分别先RED再GREEN；终版11项通过，同集合240次回调的状态写入/重复已读调用均为0，日期额外完整快照读取为0。专项日志`/tmp/ddlNew-scroll-performance-final-green.log`，初始复现`/tmp/ddlNew-scroll-performance-red.log`、日期复现`/tmp/ddlNew-scroll-dates-red.log`、重试入口复现`/tmp/ddlNew-scroll-read-retry-red.log`。统一离线74/74组exit0，逐入口耗时合计502.62秒，结果`/tmp/ddlNew-scroll-performance-qa-results/summary.json`。独立只读复核未发现本轮阻断问题；专项使用匿名Store边界，不代表实际SDK失败恢复、SwiftUI绘制或真机滚动验收。

首轮无签名generic iOS workspace构建exit0、`BUILD SUCCEEDED`；后续终版增量两次遇到共享`build.db`占用，改用独立DerivedData后终版构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-20261015-chat-scroll-performance-isolated-build.log`），本轮聊天文件无新增编译警告，`git diff --check`通过。收尾时检测到HEAD已前进为`ff3c5ef`，本轮源码及测试已包含在该提交，当前仅本交接文档待提交；本助手未执行commit/push，未回退同期聊天或Sentry等改动。Mobile MCP继续暂停，本轮未操作设备。用户需重新Run，在同一普通文字会话上下滑动、下拉补页、打开/收起键盘及返回聊天复测；若仍卡顿，下一步采集对应真机Time Profiler/动画卡顿轨迹，不能把本轮离线工作量减少当作实际帧率已达标。

## 2026-10-15 Affff进入时输入区下移：视频定位与目标页底栏配置

用户提供`ScreenRecording_10-15-2026 16-09-28_1.MP4`，补充其他好友没有同样抖动。只读用AVFoundation按50毫秒抽帧：Affff两次push在3.25→3.30秒及9.35→9.40秒均先显示系统Tab栏，再隐藏；消息内容和输入区一起下移，输入区内部结构未变化。视频中的测试群进入未出现同样过程。此证据指向导航底部安全区改变，不能直接认定Affff历史消息或图片造成输入框高度改变；为何该会话稳定触发、其它好友不触发，尚无运行时布局日志证明。

当前`ActivityNavigationScope`只在导航栈外根据path动态设置Tab栏显隐；`ChatRoomView`现也静态声明`.toolbar(.hidden, for: .tabBar)`，把隐藏意图附在聊天目标页，供push准备时使用，避免只依赖外层路径变化。保留根路径显隐与返回规则。旧xgd的`NoaNavigationController.pushViewController`同样在super push前设置`hidesBottomBarWhenPushed`。未加入联系人特判、固定底部偏移、延迟显示或修改输入框高度。

首次定位9项与视口7项离线检查exit0；无签名generic iOS workspace构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-20261015-chat-tabbar-layout-build.log`），独立只读复核未发现阻断问题。本轮没有操作设备，真机Affff连续进入、其它好友/群对照、返回消息页底栏以及键盘仍待用户Run复验，不能把配置改动或离线检查等同视觉问题已消失；既有聊天与Sentry改动保留，不提交/推送。

## 2026-10-15 进入聊天首屏直接定位最新消息

用户报告每次进入先显示旧位置再跳到最新，并要求参考旧端。只读核对xgd `scrollInitialHistoryToBottom / alignInitialHistoryToBottomIfNeeded`：行高完成后无动画对齐，首屏分批/视口变化继续跟随，用户拖动后停止。新端原先在收到末条ID时提前将`didInitialScroll`置true，再等350毫秒滚动，导致旧位置先被展示。

现在`ChatLatestPreference`同时传回实际底部区域与末条身份；首次对齐在当前批次布局回调中直接执行，不经过350毫秒键盘合并任务。底部进入实际视口才放行正文展示/点击/辅助功能与可见已读、游戏播放资格；用户拖动、下拉或显式搜索/引用定位后停止首屏跟随。新聊天上下文重置，子页往返保留原上下文与用户浏览状态；首屏空列表不加加载浮层，沿用上一节静默规则。

新增生产回调提取专项先复现4项失败、修正后8项通过（`/tmp/ddlNew-initial-position-red.log`、`/tmp/ddlNew-initial-position-green.log`）。独立复核发现首次尚未就绪时进入子页，返回可能缺少几何事件；补为Reader内部恢复可见后主动调用`resumeChat`重试，已翻历史则不抢位置。新增该场景先RED，终版9项通过（`/tmp/ddlNew-initial-position-resume-red.log`、`/tmp/ddlNew-initial-position-final-green.log`），独立复核确认问题关闭。

Chat Store回归、视口7项、成员请求15场景exit0，无签名generic iOS workspace首轮及补修后构建均exit0、`BUILD SUCCEEDED`，终版日志`/tmp/ddlNew-20261015-chat-initial-position-final-build.log`；`git diff --check`通过。离线边界只替代滚动执行与Store接口，不代表真实SwiftUI绘制、首屏无闪动或设备手势已验收。未操作设备、未重跑统一入口，不提交/推送；同期Sentry及前序聊天改动保留。

## 2026-10-15 更早消息改为下拉、聊天加载静默

用户要求正常进入聊天不显示“加载更早消息”或“正在加载聊天记录”，仅下拉加载更早记录；随后明确只取消加载Toast，失败提示保留。`ChatRoomView`移除顶部分页按钮及记录加载Toast，首屏缓存/最新一页同步静默执行；更早分页通过`ScrollView.refreshable`调用原`loadMore`，无更多或正在加载时不重复请求。补页前取消待执行的底部跟随，只有当前会话实际新增更早消息且原首条仍存在时恢复阅读锚点；失败、无新增或会话已变化不强制滚动。搜索/引用的显式定位继续沿原逻辑。

聊天输入区上传加载Toast同时移除，内嵌贴纸加载不弹Toast；失败反馈仍使用现有业务Toast。独立贴纸页保留自身加载反馈。本轮Chat Store回归、视口7项、输入面板专项exit0，无签名generic iOS workspace两次构建均exit0、`BUILD SUCCEEDED`，终版日志`/tmp/ddlNew-20261015-chat-silent-loading-build.log`，前轮下拉版本日志`/tmp/ddlNew-20261015-chat-pull-history-build.log`；`git diff --check`通过。未操作设备，真实下拉手势/分页后的阅读位置及无首次加载浮层仍待用户Run复验；未重跑72组统一入口，不提交/推送。本节取代下一节关于聊天加载Toast的过程描述。

## 2026-10-15 聊天业务提示改为Toast

用户报告接口提示出现/消失导致聊天内容抖动。`ChatRoomView`移除消息视口上方的发送权限文案行，确认后的权限限制与业务错误合并到现有居中短Toast；加载期间沿用已有loading Toast，避免请求未结束时重复提示权限。发送禁用规则、真实消息/系统消息、群公告、置顶和分页动作保持原实现。权限59项与输入面板专项exit0，无签名generic iOS workspace构建exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-20261015-chat-toast-build.log`），`git diff --check`通过。本轮仅展示修正，未重新执行72组统一入口、未操作设备；实际请求结束时的滚动稳定性仍待用户Run复验。不提交/推送，前序头像及其它工作区改动保留。

## 最新统一交接：2026-10-15 聊天输入、群发送与默认游戏

用户要求改完整理交接，当前统一入口为[最新聊天交接](SESSION_HANDOFF_2026-10-15_CHAT_INPUT_GAMES.md)，包含实现、真实响应证据、源码/验证入口、设备待验和新会话续接文字。实际基线仍以Git为准，本轮不提交/推送，Mobile MCP继续暂停，旧xgd只读。

已根据用户提供的`userInGroup=true / isGroupForbid缺省 / isGroupChat=false`修正群发送校验：仅缺省个人禁言按旧端未禁言处理，null/非法值及不明确在群/全禁仍拒绝；最新禁言接口覆盖旧群缓存的全禁状态。UIKit输入焦点改为普通State/Binding，默认石头剪刀布/骰子已接旧资源、type21真实字段及3秒动画。用户批准这两个默认游戏发送，覆盖CHAT-014对应暂缓子范围；商城和其它能力不扩大。同期头像改动原样保留。

最终统一离线72/72组exit0（347.34秒），无签名generic iOS workspace构建锁释放后重试exit0、`BUILD SUCCEEDED`，独立复核通过；逐项日志和过程失败边界见最新交接第5节。所有真实键盘、游戏双端、群发送及头像显示仍待用户Run/设备授权恢复后的对应验收，不把字段日志、模型回归或动画当作服务器成功。

## 2026-10-15 聊天头像默认值回退修正

用户报告单聊对方偶发显示默认头像，以及自己发消息后头像变默认。源码与离线复现确认两条路径：`SDKChatMessageMapper` 用好友/成员缓存中的空串覆盖消息 `fromIcon`；本地发送中的 `ChatMessageRecord.avatarURL` 尚未填充，而气泡只读消息快照。现在缓存头像非空才覆盖消息资源，注销状态仍明确清空；本人气泡沿旧端读取当前 `UserSessionStore` 资料，核对发送者UID，并观察资料变化，缺资料或账号不匹配才保留消息头像。未改发送协议、图片缓存、文件Host或好友数据库。

新增 `Tests/Chat/run-avatar-checks.sh` 提取生产映射与气泡实际资源表达式执行，SDK数据库/登录资料使用匿名离线边界；先复现5项失败，修正后16/16通过（`/tmp/ddlNew-avatar-red.log`、`/tmp/ddlNew-avatar-green.log`）。统一离线72/72组exit0，耗时合计370.76秒（`/tmp/ddlNew-avatar-qa-results/summary.json`）；无签名generic iOS workspace构建首次遇到同期build.db占用，释放后重试exit0、`BUILD SUCCEEDED`（`/tmp/ddlNew-20261015-avatar-build-retry.log`），头像相关文件无新增编译警告；独立只读复核无阻断问题，`git diff --check`通过。未操作设备，真实单聊进入/发送/历史刷新及远端图片下载仍待重新Run验证；保留同期聊天布局、游戏表情等工作区改动，不提交/推送。

## 2026-10-15 输入后键盘修正与权限诊断（过程快照，已由上方统一交接取代）

用户报告任意聊天输入一个字符键盘即收起。基础表情富文本输入改用UITextView后，聊天焦点仍由未绑定`.focused`控件的FocusState拥有，每次正文更新会按该值同步first responder。现窄修为ChatRoom的普通`@State Bool`经两个`Binding<Bool>`传给UIKit；原生表单的FocusState不改，主动切面板/取消成员选择/禁言时的焦点规则保留。焦点专项提取生产绑定类型、updateUIView及begin/end代理执行，旧类型RED、新实现GREEN；权限53项及成员请求15场景通过，独立只读复核通过。无签名generic iOS workspace构建exit0、`BUILD SUCCEEDED`，`/tmp/ddlNew-20261015-composer-focus-permission-build.log`。尚待用户重新Run确认真实系统键盘，不能以匿名形状回归替代。

另一用户报告：群聊键盘/相册/拍摄全部置灰，顶部“正在确认群发送权限”，Toast“消息响应无效，请重试”。源码定位至群详情/禁言快照未通过严格校验的路径；旧端对缺失禁言字段默认0，新端不能据无字段日志直接放行。当前没有真实三字段值，不宣称该发送阻断已修复。DEBUG新增`[ChatGroupPermission]`单行，只输出detail.userInGroup、mute.isGroupForbid/isGroupChat的true/false/missing/null/invalid，不输出原始响应/身份/凭据；已请用户Run后回传此行。用户提供的既有日志仅传输/帧长度，无法确认字段合同。独立复核另标记详情/缓存全群禁言与最新禁言接口做OR的旧值覆盖风险（对应“当前已被禁言”，不等同当前故障），尚未混入本轮修正。

Mobile MCP继续暂停，未操作设备或真实测试数据；只读查询现有Mac进程系统日志未找到业务字段。当前代码和文档保留工作区，不提交/推送。上一节68/68为前一版本历史快照；本轮仅运行焦点、权限、成员请求专项及workspace构建。

## 2026-10-15 导航栏、基础表情与群聊@继续对齐（阶段快照）

四个实际Tab根页及活动/签到相关重复页头已统一使用原生导航栏和`.toolbar {}`，保留原导航所有者、业务动作、首页/我的森林绿与UIAdapter。顶部`safeAreaInset`仅剩群申请业务筛选，底部输入/提交条保持安全区；未接入App的Original原型不作业务页面改造。范围及构建证据见[系统导航栏迁移记录](NAVIGATION_TOOLBAR_MIGRATION_2026-10-15.md)。

表情按钮默认打开旧xgd的157个基础图片表情，按`[微笑]`等旧文本标记插入、复制和发送，真实SDK贴纸保留独立标签。群聊底部@按钮已移除，实际键入@才加载真实完整群成员，可搜索并在光标处插入对应UID；取消保留普通@，普通成员禁私聊限制沿用。用户最新要求工具栏等分，相册/拍摄/文件/更多改成四等分居中布局，覆盖之前横向滚动与常驻群@的历史描述。

独立复核修正特殊昵称含@时的UID错位，以及成员请求迟到后覆盖子页/表情面板的弹层和焦点问题；复核确认关闭。新增生产方法离线场景覆盖上述迟到成功/失败、取消、草稿/身份变化，详见[聊天布局追加记录](CHAT_LAYOUT_ALIGNMENT_2026-10-15.md)。Mobile MCP继续暂停，未操作设备或真实成员数据，不提交/推送。最终统一离线68/68组exit0（351.63秒），无签名generic iOS workspace构建exit0、`BUILD SUCCEEDED`，日志见追加记录；源码/离线检查不代替中文输入法、系统键盘、弹层动画或双端服务器验收。

## 2026-10-15 聊天页交互布局继续对齐

用户批准整体按xgd调整聊天输入、内嵌表情/录音、引用、多选底栏、消息行与群公告入口；保留森林绿、UIAdapter及真实SDK。并窄修“聊天设置—查看好友资料”：由外层值路由改为设置页既有资料子导航，携带UID/来源群并保留设置Store。源码、验证及设备待验边界见[本轮聊天布局记录](CHAT_LAYOUT_ALIGNMENT_2026-10-15.md)。Mobile MCP继续暂停，不自动提交/推送；此前举报/黑名单、图标及媒体解包取消改动保留。

统一离线66/66组exit0（逐脚本耗时合计300.47秒），独立复核补修后输入模式/设置/视口/操作专项复跑通过，最终无签名generic iOS workspace构建exit0、`BUILD SUCCEEDED`。未操作设备；真实好友资料进入/返回、键盘/录音/相册、大字号及服务器转发删除仍按本轮记录待验，不能用源码和编译替代。

## 2026-10-15 追加系统投诉与黑名单（当前）

用户批准迁移旧xgd的拉黑和举报，明确“仅系统投诉，不含邀请码/IP域名”；UI按用户指定ui-ux-pro-max设计，保持森林绿、UIAdapter与中文业务注释。好友资料更多可加入/移出黑名单，“我的”有真实黑名单、移出及资料入口；好友资料、群设置与“我的”分别提交用户、群、通用系统投诉。演示举报/拉黑仍删除，当前为独立真实SDK接入。

统一离线65/65组exit0（逐脚本耗时合计236.06秒），最终投诉专项复跑及无签名generic iOS workspace构建通过。未进行服务器/设备功能验收，Mobile MCP继续暂停，没有改用其他工具操作设备。真实拉黑阻断/解除恢复、证据图各供应商与投诉受理/审核仍待验，不能以构建、匿名夹具或Toast代替。

分支仍为`feature-message-4 / ecf1b89`，改动保留工作区，不提交/推送；此前媒体解包取消修正保留。工程文件同期新增的空inputPaths/outputPaths四行原样保留。C-020/C-021由暂缓改为批准，当前范围105/116项，整体暂缓11项；下文103/13均为历史快照。详见[举报与拉黑迁移记录](SAFETY_REPORT_BLOCK_MIGRATION_2026-10-15.md)与[统一交接第11节](SESSION_HANDOFF_2026-10-15_OVERNIGHT_MESSAGES_CONTACTS.md#11-2026-10-15追加系统投诉与黑名单)。

## 2026-10-15 后续离线延续（Mobile MCP 暂停）

本轮接手实时基线为 `feature-message-4 / ecf1b89`，工作区干净；EncryptLib 与上轮交接已提交，以下 `4a75da8`、未提交等描述保留为历史快照。用户随后要求暂停 Mobile MCP，本轮未调用或改用其他工具操作设备。

媒体未完成分支新增离线复现：下载完成后的解包期间取消加载，旧 `ChatMediaPreviewStore` 仍发布附件；独立解包任务也未随页面关闭或原条删除取消。现在保留解包任务句柄，将加载取消与 `close()` 传入真实流式解包，发布前再核对取消/轮次，并清理下载临时文件。媒体格式、发送协议、森林绿主题和 UIAdapter 不变。

专项加载回归与既有预览失效12项通过；统一离线63/63组exit0（265.92秒），无签名generic iOS workspace构建 `BUILD SUCCEEDED`，详见[统一交接第10节](SESSION_HANDOFF_2026-10-15_OVERNIGHT_MESSAGES_CONTACTS.md#10-2026-10-15后续离线延续mobile-mcp暂停)。本轮不提交或推送；仅新增离线证据，不将真实媒体/后台/弱网及多端验收改为通过。

## 当前交接入口（2026-10-15 整理）

继续昨晚消息、通讯录与群聊工作时，完整阅读[昨晚统一交接](SESSION_HANDOFF_2026-10-15_OVERNIGHT_MESSAGES_CONTACTS.md)，再按其中源码入口和未完成项推进。该文档整合已实现行为、真实/离线验证边界、设备与数据恢复、后续优先级和新聊天接续提示。

本次整理开始时实时 Git 为 `feature-message-4 / 4a75da8 fix:修复bug`，工作区干净；昨晚84个路径变更已包含在该后续提交中。本助手未执行commit/push。本次整理仅新增/更新交接文档和安全证据摘要，未重新构建或操作设备。凌晨的未提交状态、运行版本和临时目录内容均为历史快照，后续先核对实时 Git 和设备。

整理过程中另出现Podfile、Podfile.lock、工程文件和EncryptLib/同期改动，已原样保留，当前不再是全仓干净；详情见新交接第2节，接手先复核。

## 昨晚阶段记录（截至 2026-10-15 01:20）

2026-10-15 01:17收尾：当前feature-message-4 / 6252ab8，后续改动保留工作区，未自动commit/push。xgd旧Mac已实际启动、核对同服务器及真实身份，完成角色徽标、成员行直达、独立移除入口和公告只读界面对照；旧App已Stop，临时Per-User DerivedData恢复Default，旧仓库干净。最终62/62组离线（311.43秒）与签名build通过，真机保数据覆盖安装成功；完整116项逐项状态见[验收台账](CONTACTS_MESSAGES_PARITY_QA_2026-10-14.md)。

删除持久化修正已真机闭环：AUTH latest写回前保护真实SDK库status0/2，删除必须确认SDK写入成功；新条实际删除→终止重启→AUTH→会话仍无原文→搜索空通过，未删对照仍在。A此前复活的自建DELETE_2230也已主动重新删除，B保留原条。

群公告删除后返回公告列表已在最终无诊断包真机通过；服务器失败仍留当前页。备注即时同步、双端Unicode/换行实收及双方1/1已读、B主动撤回只有一个占位均通过。A23:08标记仍是普通文本，最后Mac主动撤回菜单未打开，未冒充第二方向主动撤回通过。

文件联调补修已真实闭环：STS成功回执的data.credentials按真实合同映射，临时凭据不缓存/序列化；137字节QA文件A真实发送、B下载/系统预览与字节SHA一致。文件wire补稳定前缀，最后01:12新消息两端保留完整原名；Mac和真机只读详情关闭均回聊天。仅手动未读/已读接受SDK明确空成功回执，明确false及未知非空仍拒绝，最终真机标记/筛选/清除不再误报Toast。合并转发2条真实实收、作者/原时间/正文通过。完整建群人数、实际移除/转让/解散及三角色矩阵未验，需可恢复测试群及第三个可控身份；媒体全类型/供应商、弱网重连/同账号多端仍有未完成分支。首页/我的森林绿保持，临时诊断已移除。以下早期历史快照不代替最新验收台账。

更新时间：2026-10-15

消息 / 通讯录 / 群聊最新交接入口：[昨晚统一交接](SESSION_HANDOFF_2026-10-15_OVERNIGHT_MESSAGES_CONTACTS.md)。[10月14日会话记录](SESSION_HANDOFF_2026-10-14_MESSAGES_CONTACTS_UI.md)保留设计迭代和历史过程；当前完成度及下一步采用新交接与逐项验收台账。

本文供新的 Codex 对话接手项目。先执行“接手检查”，再根据任务读取对应源码；不要只凭本文修改代码，因为分支和工作区可能已经变化。

## 接手检查

1. 使用 `/Users/taobotaobo/Desktop/ddlNew/ddlNew.xcworkspace`，不要用 `ddlNew.xcodeproj` 单独构建。
2. 执行 `git branch --show-current`、`git status --short` 和 `git log -5 --oneline`，保护用户已有改动。
3. 阅读根目录 `README.md`，它记录当前目录职责和通讯录边界。
4. 涉及消息、通讯录与群聊旧逻辑时，只读参考 `/Users/taobotaobo/Desktop/xgd`，按新交接的文件入口定位，不直接复制旧项目文件覆盖新实现。
5. 修改业务代码后执行相关离线检查和workspace构建，按验收层级记录结果。当前统一离线入口为 `python3 Tests/MigrationAcceptance/run-all-checks.py`，昨晚最终62组；具体命令和真实设备边界见新交接。仅整理文档不重复构建业务代码。

## Git 快照

记录时状态：

- 当前分支：`feature-message-4`
- 当前提交：`f975457 feat：修复警告`
- 远端：`origin` → `git@github-second:tbLibs/ddlNew.git`
- 工作区：干净
- 现有里程碑分支：
  - `feature-login-1`
  - `feature-IMSDK-2`
  - `feature-contacts-3`
  - `feature-message-4`

以上只是 2026-09-30 的快照，新对话必须重新检查。

## 当前完成度

已经跑通的主链路：

```text
邀请码
→ APP t 域 DNS1（主域 → 备域 → BIN）
→ 解出原生 TCP，逐来源 ECDH 竞速；全部失败进入旧五路导航/OSS兜底
→ 保存新版本节点缓存（HTTP 可选）
→ SDK 配置与正式 TCP/ECDH 连接
→ 获取 systemConfig
→ 登录页
→ 检查账号是否存在
→ 获取登录加密密钥并加密密码
→ 发送账号登录请求
→ 保存用户资料和凭据
→ SDK 用户配置与用户数据库就绪
→ 等待用户 AUTH ACK
→ 进入四栏主界面
```

应用重启时先显示与 LaunchScreen 一致的等待页并恢复邀请码连接。连接失败停止启动恢复并返回邀请码页，保留上次入口；连接成功后读取同一俱乐部的成对资料、Token 和设备凭据，AUTH 成功才进入主界面。没有缓存会话或用户认证失败时显示登录页；暂时超时保留凭据，明确失效才删除。AUTH 成功但根路由尚未接收结果的取消窗口会撤销运行时会话，避免下一次恢复被残留所有权阻塞。

## 启动与路由

入口文件：

- `ddlNew/App/ddlNewApp.swift`
- `ddlNew/App/Startup/AppStartupCoordinator.swift`
- `ddlNew/App/Routing/AppSessionRouter.swift`
- `ddlNew/App/Routing/RouterTool.swift`

根路由只有三种业务页面：邀请码、登录、主界面。缓存恢复期间 `hasRestoredLocalEntry == false`，继续展示 `LaunchWaitingView`，不提前创建登录页。

重要约束：

- 本地有用户资料或 token 不代表登录成功。
- 账号登录 HTTP/TCP 请求返回成功也不代表登录成功。
- 必须收到 SDK 用户 AUTH ACK，并确认连接轮次、用户 UID、数据库状态仍一致，才允许进入主界面和请求后续业务数据。
- 已登录后的临时断网保留凭据，由 SDK 重连；启动连接失败回邀请码页，启动 AUTH 超时回登录页，均不删除有效缓存。明确的账号失效才清理缓存。
- “更换俱乐部”清除启动入口和当前会话，再回到邀请码页。

## DNS、OSS 与导航

核心文件：

- `ddlNew/Network/DNS/HostNodeRaceManager.swift`
- `ddlNew/Network/DNS/DNSHostNormalizer.swift`
- `ddlNew/Network/DNS/DNSUDPResolver.swift`
- `ddlNew/Network/OSS/OSSNodeRaceCoordinator.swift`
- `ddlNew/Network/OSS/OSSAuthRequestBuilder.swift`
- `ddlNew/Network/OSS/OSSAuthTCPClient.swift`
- `ddlNew/Network/OSS/OSSAuthResponseDecoder.swift`
- `ddlNew/Network/OSS/OSSNavigationStore.swift`
- `ddlNew/Network/OSS/OSSConnectionBootstrap.swift`
- `ddlNew/Protocols/Nav/nav.proto`
- `ddlNew/Protocols/Nav/Nav.pb.swift`

以下旧实现现作为 DNS1 来源全部耗尽后的兜底；入口与缓存边界见本页 2026-10-22 章节。

旧五路 DNS 来源同时启动：

1. 阿里 HTTPDNS SDK AAAA：`ALIDNS`
2. 腾讯 DoH AAAA：`TENCENT_AAAA`
3. Cloudflare DoH TXT：`CF_TXT`
4. Cloudflare DoH AAAA：`CF_AAAA`
5. 阿里 DoH TXT：`ALI_DOH_TXT`

每一路先解析并归一化候选节点，再按该路候选顺序尝试 OSS Auth。第一个通过请求、响应校验和解密的节点获胜，其他任务取消。DNS 最先返回不等于最终获胜。

域名归一化优先使用 `CocoaAsyncSocket` 的 UDP DNS 实现；DoH/系统结果和已是 IP 的节点走统一去重、Host/Port 规范化逻辑。

`Nav.pb.swift` 是由 `nav.proto`、`protoc` 和 `protoc-gen-swift` 生成的文件。协议变化时修改 `.proto` 后重新生成，不手工改生成代码。

## SDK、TCP/ECDH 与系统配置

核心文件：

- `ddlNew/Network/IM/IMConnectionCoordinator.swift`
- `ddlNew/Network/IM/IMSDKConnectionAdapter.swift`
- `ddlNew/Network/IM/IMHandshakeWaiter.swift`
- `ddlNew/Network/SystemConfig/SystemConfigService.swift`
- `ddlNew/Network/SystemConfig/SystemConfigRecord.swift`
- `ddlNew/Network/SystemConfig/SystemConfigStore.swift`
- `ddlNew/Network/NetworkPath.swift`

连接顺序固定为：

1. 清理并等待旧 Socket 完成释放。
2. 配置 API、邀请码、SSO 信息和组织标识。
3. 并发探测 TCP 候选，首个完成真实 ECDH 的节点获胜。
4. 对获胜节点建立正式 Socket 并再次完成 ECDH。
5. 获取并解析 `systemConfig`。
6. 应用 tenantCode、captchaChannel 等 SDK 配置。
7. 整条链路成功后才把 `lastLiceseId` 标记为可恢复入口。

所有服务器业务 Path 放在 `ddlNew/Network/NetworkPath.swift`。`systemConfig` 当前路径为 `/biz/system/v2/getSystemConfig`。

系统配置兼容旧服务端混合类型：字符串、数字和布尔值可能互相混用，解析层负责归一化，ViewModel 不直接猜类型。

## 登录、用户会话与 AUTH

核心文件：

- `ddlNew/Features/Login/ViewModels/LoginViewModel.swift`
- `ddlNew/Features/Login/Services/AccountLoginService.swift`
- `ddlNew/Features/Login/Services/LoginSessionService.swift`
- `ddlNew/Network/IM/SDK/SDKAccountLoginClient.swift`
- `ddlNew/Network/IM/IMUserAuthenticationService.swift`
- `ddlNew/Network/IM/IMUserAuthenticationDelegate.swift`
- `ddlNew/Common/User/UserSessionStore.swift`
- `ddlNew/Common/User/UserCredentialStore.swift`
- `ddlNew/Common/Database/UserDatabaseManager.swift`

登录请求复用 SDK 已有的验签、解密和 HTTP 转 TCP 通道：

1. 检查账号是否存在，不存在时返回对应业务提示，再获取一次性 `encryptKey`。
2. 使用 `LXChatEncrypt.method4(encryptKey + password)` 加密密码。
3. 发送账号登录请求。
4. 用 ObjectMapper 映射响应。
5. 保存用户资料、token、deviceSecret 和登录上下文。
6. 配置 SDK 用户并初始化用户数据库。
7. 注册连接和用户代理，发送 AUTH。
8. 等待 AUTH ACK 成功回调。

登录页“记住密码”默认开启。密码和会话凭据分别保存在不同 Keychain 项中；用户资料和非敏感状态存 AppStorage。缓存启动不会重新发送账号密码请求，而是使用保存的用户资料、token 和设备凭据恢复 AUTH。

不要在项目文档或提交信息中记录测试密码、token、deviceSecret、Sentry token 或其他运行时认证数据。

## 本地持久化

固定 key 定义在 `ddlNew/Configuration/Const.swift`，当前策略是每类数据只有一份，不按邀请码拼接 key：

- `ddlNew.dns1Navigation.v2`：当前导航与成功入口，允许DNS1及本轮五路兜底结果；按来源验证，DNS1另校验企业及配置版本。
- `ddlNew.ossNavigation.v1`：保留的旧导航缓存，升级仅迁移成功入口的邀请码，不使用其节点。
- `ddlNew.selectedHTTPHost.v1`：当前选中的 HTTP Host。
- `ddlNew.systemConfig.v1`：最新系统配置 ObjectMapper JSON。
- `ddlNew.userInfo.v1`：用户资料，不含密码和 token。
- 用户会话凭据：Keychain `ddlNew.userSession/currentSession.v1`。
- 记住的登录表单：Keychain `ddlNew.rememberedLogin/loginForm.v1`。

DNS1 恢复候选必须匹配邀请码与当前配置版本；系统配置读取传入所属邀请码，尤其空 HTTP 不可跨企业复用；用户会话凭据继续核对 `lastLiceseId`。

`Const.swift` 当前还承载旧协议所需的 DNS/OSS 常量。不要在日志、文档或回答中展开这些值。若以后治理密钥，应设计安全注入和迁移方案，不要只移动明文位置。

## 主界面与功能状态

主界面：`ddlNew/Features/Tabbar/Views/TabbarView.swift`

四个 Tab：

| Tab | 当前状态 |
| --- | --- |
| 首页 | 已重新设计；活动和俱乐部入口在首页；主要展示数据仍是本地演示数据 |
| 消息 | P0 真实会话只读列表已接 SDK 数据库与同步代理：本地搜索、未读筛选、置顶/免打扰/草稿/预览/未读、Tab 角标；真实聊天与列表操作尚未接入 |
| 通讯录 | 已接 SDK 好友数据库、同步代理、排序搜索、资料详情和真实头像 |
| 我的 | UI 已迁移；退出登录、更换俱乐部和基础设置可用，业务接口仍需逐项接入 |

活动导航统一由 `ActivityNavigationScope` 注入，避免二级页面缺失 `ActivityNavigation` 环境对象。旧的 `Main` 和 `OldVersion` 目录保持删除；演示页面以 `OriginalHomeView`、`OriginalInvitationCodeView`、`OriginalLoginView`、`OriginalMessagesView`、`OriginalContactsView` 保留在各功能目录中，不接真实主入口。用户确认保留的演示注册存储放在 `Features/Login/Services/LocalCredentialStore.swift`。演示拉黑与举报已按用户最新要求删除，包括入口、页面、本地状态和模型。真实会话和通讯录仍使用各自的 SDK Store。

网络图片使用 Kingfisher。通讯录和消息页头像统一通过 `RemoteAvatarURL` 处理完整 HTTP(S) 地址、OSS 相对路径和中文路径；相对路径使用当前文件 Host。SDK 的 `cimUserUpdateHttpNode` 回调会同步更新 API／文件／上传 Host，主界面观察 Host 变化以重新生成图片 URL。图片仅对当前文件 Host 使用项目现有的临时证书策略，其他 Host 仍按系统规则校验。

## 通讯录实现边界

核心文件：

- `ddlNew/Features/Contacts/Services/ContactsStore.swift`
- `ddlNew/Network/IM/Contacts/SDKContactsClient.swift`
- `ddlNew/Network/IM/Contacts/SDKContactsDelegate.swift`
- `ddlNew/Features/Contacts/Views/ContactsView.swift`

AUTH 前注册 SDK 用户代理，AUTH 后读取 SDK 本地好友数据库。SDK 同步完成、好友变化和备注变化会触发刷新；迟到回调通过用户 UID 与 generation 隔离。排序规则沿用旧项目：系统账号过滤、备注优先、拼音首字母分组、已注销账号置后。

头像取 SDK 好友记录 `friend.avatar`；已注销账号不请求远端图片。通讯录列表和资料页共用当前文件 Host 与同一个头像组件。

尚未完成：好友申请、修改备注 UI、从好友详情发起真实聊天。

## 消息会话实现边界

核心文件：`ddlNew/Features/Message/Models/ConversationRecord.swift`、`Services/ConversationsStore.swift`、`Views/MessageView.swift`，以及 `ddlNew/Network/IM/Conversations/SDKConversationsClient.swift`、`SDKConversationsDelegate.swift`。

AUTH 前注册会话代理，AUTH 后读取 SDK 本地会话库；SDK 分页代理先于数据库写入，因此同步完成后才做完整重读。首轮同步中的最新消息按旧项目做法写入 SDK 消息表，使预览可从缓存恢复；实时会话变化触发合并刷新。只显示 `sessionStatus == 1` 且属于已知类型的会话，置顶优先、组内按最新消息时间倒序，按会话 ID 去重。Tab 角标来自真实可见会话未读数，免打扰不计入，手动标记未读计 1。登出或切换账号时通过 UID 与 generation 清空并隔离状态。

单聊头像按旧项目优先读取好友库最新 `friend.avatar`，好友记录缺失时使用 `sessionAvatar`；群聊与其他会话使用 `sessionAvatar`。好友列表变化后重新读取会话快照，避免先同步会话时继续显示旧头像。

消息页已移除 `ClubCommunity` 演示会话、假全部已读和跳往演示 `ChatScreen` 的入口。当前 P0 只读：列表行尚不能打开真实聊天；搜索只匹配已加载的会话名称和预览，不是消息历史全文搜索。当前 P0 已按角色 isShowFileAssistant 过滤系统单聊账号 100002，权限变化同步重算列表和角标，允许后从保留快照恢复；通知类会话按 SDK 类型显示，具体入口待后续实现。

## 下一步建议

1. P1：接真实单聊/群聊聊天页，先完成历史消息分页、实时收消息、发送文本与发送状态，再加入已读回执、失败重试和撤回。聊天入口可用后再开放列表行点击及标记已读。
2. P1：接会话置顶、免打扰、标记未读/已读、删除等列表操作；服务端请求成功后以 SDK 缓存回读为准。
3. P2：迁移旧项目全局搜索、文件助手权限控制、群发/系统/签到等特殊会话入口，再接好友申请、群资料、活动服务端数据和“我的”业务接口。

## 代码与依赖约定

- Swift/SwiftUI 代码按功能分目录，一个主要类型一个文件。
- 新 Swift 文件顶部使用项目现有四行文件头，`Created by taobo on` 日期用创建当天日期。
- 需要解释业务原因和异步边界时使用中文注释；明显代码不添加无意义注释。
- Moya 响应映射使用 ObjectMapper 和项目已有扩展，不使用 HandyJSON。
- 服务器 Path 放 `NetworkPath.swift`，固定 key 和全局服务常量放 `Const.swift`。
- 应用状态持久化使用 `@AppStorage`；结构化 JSON 使用 ObjectMapper；密码、token 和设备凭据使用 Keychain。
- 网络图片使用 Kingfisher。
- 项目包含 SwiftProtobuf；旧 SDK 的 Objective-C Protobuf 仍由 CocoaPods 提供，两者服务不同代码路径。
- `CandyTalkPro.xcodeproj` 是 `ddlNew` 的显式依赖，模块名为 `NoaChatCore`。
- `libLXChatEncrypt.a` 同时存在于应用和 SDK 各自需要的位置，避免随意删除或移动。
- CocoaPods、SPM 依赖和 vendored SDK 警告优先通过升级依赖解决，不直接改生成文件或 checkout。

## 警告处理现状

提交 `f975457` 已清理项目自身可安全修复的警告，包括：

- SwiftUI 弃用导航 API。
- 无效库／框架搜索路径。
- Sentry 脚本阶段依赖分析提示。
- SDK 内格式字符串、枚举转换、未使用变量、数组常量和缺失方法实现。
- 旧归档 API。

明确保留：

- `umbrella header for module 'NoaChatCore' does not include header ...`，用户要求不要处理此类警告。
- WCDB 的同类 umbrella header 警告。
- `UICKeyChainStore` 的旧安全 API 警告；替换会改变认证 UI 和 Keychain 可访问级别，需要单独设计迁移。
- LiveKit、WebRTC、Zego、Protobuf、ObjectMapper 等第三方依赖警告。
- 预编译静态产物携带的旧机器 ModuleCache 调试路径警告；需用源代码重新构建对应产物才能根治。

不要通过修改 `NoaChatCore.h` 或批量调整 Public Headers 来消除 umbrella 警告。

## 验证命令

全量真机构建，不需要签名：

```bash
xcodebuild \
  -workspace ddlNew.xcworkspace \
  -scheme ddlNew \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /Users/taobotaobo/Library/Developer/Xcode/DerivedData/ddlNew-gouvoiamsobqkuevngdfnxdlbzay \
  -disableAutomaticPackageResolution \
  CODE_SIGNING_ALLOWED=NO \
  clean build
```

2026-09-30 最近一次结果：

- 全量 clean build：`BUILD SUCCEEDED`
- `git diff --check`：通过
- 消息 P0 离线校验：`sh Tests/Conversations/run-checks.sh`，置顶排序、去重、免打扰角标口径和切账号后的 Store 状态隔离通过。新增会话代码的无签名真机目标构建通过；真实账号同步仍需真机验收。
- 头像链路修正后再次执行无签名真机目标 `clean build` 和最终增量 `build`，均为 `BUILD SUCCEEDED`；`git diff --check` 通过。

通讯录离线脚本已从 `feature-contacts-3` 恢复，并增加 OSS 路径、中文编码与无文件 Host 的头像用例。当前可执行 `sh Tests/Contacts/run-checks.sh`；生产逻辑 43 项、SDK 分页 19 项通过。真实 OSS 图片下载、节点切换和证书行为仍需真机登录验收。

模拟器不能完成依赖 `LXChatEncrypt` 的真实系统配置签名和完整登录链路；端到端 DNS、OSS、TCP/ECDH、登录和 AUTH 验证应使用真机。

## 本次会话完成的阶段

本会话从网络层迁移开始，依次完成或确认了：

1. Moya、RxSwift 与 ObjectMapper 响应映射。
2. 五路 DNS、UDP 归一化和 OSS 并发竞速。
3. Nav Protobuf、OSS Auth TCP 客户端、响应校验解密和导航缓存。
4. SDK 配置、TCP/ECDH 正式连接、系统配置获取和证书策略。
5. 登录请求加密、用户会话保存、数据库初始化和 AUTH ACK 判定。
6. AUTH 成功进入主界面及缓存启动自动恢复。
7. 首页重设计、四栏结构、登录记住密码和基础路由修复。
8. SDK 真实通讯录接入、Kingfisher 头像和离线验证。
9. 项目结构整理、依赖迁移与本轮安全警告清理。

新对话应以当前源码和 Git 历史为准，把本文当作导航和决策记录，而不是替代代码检查。

## 2026-10-12 分支合并记录

本次将 `feature-IMSDK-2`（`6b7c653`）合入 `feature-message-4`（合并前 `0c25315`）。用户确认：

- Sentry 使用 `feature-IMSDK-2` 配置；文档不记录 DSN 或认证信息。
- 合并时保留旧演示注册、拉黑和举报逻辑，按现有目录拆分迁入；其后用户要求删除演示拉黑与举报，见下节。
- 隐私政策与使用支持采用在线页面，删除本地 HTML 与开源许可入口。

合并后的登录增强包括账号预检查、验证码、安全码、真实账号注册和缓存 AUTH 恢复；手机号/邮箱登录、验证码登录和找回密码暂缓。注册成功后复用会话编排，AUTH 前订阅通讯录和消息，AUTH 后读 SDK 数据库，并再次核对会话所有权。

登录后断线竞速、导航兜底和网络质量检测统一管理。巡检受导航 `enableNetworkDetect` 控制，仅在已 AUTH 且前台运行，30 秒巡检，使用临时 TCP/ECDH 完整握手 RTT 比较节点，切换有 60 秒冷却；退出、后台和 SDK 断线竞速会取消业务等待并隔离迟到回调。临时探测 Socket 无 SDK 取消句柄，最长约 10 秒自行回收。

验证入口增加 `Tests/Login`、`AccountLifecycle`、`SessionRestore`、`Network`、`NetworkQuality`、`Verification` 中的 `run-checks.sh`；合并仍应保留执行既有 `Tests/Contacts` 与 `Tests/Conversations`。离线检查和构建不代替真机账号注册、验证码、自动恢复、弱网切换与消息同步验收。

本次合并验证：无签名真机目标 `clean build` 为 `BUILD SUCCEEDED`；上述八组离线检查全部通过，通讯录生产逻辑 43 项、SDK 分页 19 项、登录 25 项通过。构建前执行 `pod install --deployment --no-repo-update` 同步本地安装记录，未升级锁定依赖；CocoaPods 对工程空数组的自动改写已还原。`git diff --check` 通过。合并提交与最终工作区状态以 `git log -1`、`git status` 为准。

## 2026-10-12 删除演示拉黑与举报

按用户最新要求，删除“我的”黑名单与举报记录入口、演示好友拉黑操作、聊天举报弹窗和相关模型、快照字段、Store 方法、消息/联系人过滤及发送限制。旧快照中多余字段由 Codable 解码时忽略，不影响账号与活动记录恢复。保留其他演示流程及真实 SDK 通讯录、消息和登录逻辑。同步移除对应 UI 用例和注销说明；当前工作区的 `html/privacy.html`、`html/support.html` 已删除。在线页面未发布更新，现有在线文案需要后续独立更新。

本次删除验证：无签名真机目标全量 `clean build` 为 `BUILD SUCCEEDED`，通讯录离线逻辑 43 项与 SDK 分页 19 项通过，消息排序和 ConversationsStore 检查通过。应用源码与 UI 用例中已无演示拉黑/举报引用；`git diff --check` 通过。

## 2026-10-12 导航弃用 API 修复

`OriginalContactsView` 和 `OriginalMessagesView` 的隐藏 `NavigationLink(isActive:)` 改为 `navigationDestination(isPresented:)`，沿用所在 `NavigationStack` 及已有选中会话状态。弹出聊天后由系统重置呈现绑定，支持再次打开聊天。其他有效的 `NavigationLink(value:)` 与直接指定目标页面的写法继续使用。

本轮全量无签名真机目标 `clean build` 为 `BUILD SUCCEEDED`，构建日志中的两处 `NavigationLink(isActive:)` 弃用警告已消除，`git diff --check` 通过。


## 2026-10-13 网络与登录维护补齐

需求见 `Docs/NETWORK_LOGIN_REQUIREMENTS.md`；实施与验收计划见 `Docs/superpowers/plans/2026-10-13-network-login-maintenance.md`。开发使用 Superpowers，安全页面和状态接线同时按 swiftui-pro 复核，保留 iOS 16 最低版本和现有 ObservableObject 架构。

- 前台恢复：在同一登录会话从后台返回时调用 SDK `verifyConnectionOnForeground`；由 SDK 的现有 PING、超时和重连处理断链，普通断线保留用户凭据。
- 会话维护：首次 AUTH 后立即刷新系统配置、本人资料和角色权限；前台随机 180～480 秒执行，访客只刷新系统配置。前台恢复、HTTP Host 切换及 AUTH 恢复可触发合并刷新；后台暂停。应用配置只更新 SDK 租户/验证码，避免重建用户、数据库或 Socket。
- 资料与权限：部分资料合并到当前 UID 快照，保留 Token/deviceSecret；主页观察资料变化。角色配置独立缓存，绑定 UID 和邀请码；兼容数字/字符串布尔值，保留 configData/authorityKey。缺失图片视频上传权限默认开启、其他一般权限关闭、翻译空值默认开启；条目结构/值非法关闭，不能误用缺省允许。
- 主动退出：复用真实 `authUserLogoutWith`，当前 UID/Token 快照最多等 2 秒，失败仍清理本地。Swift 并发退出去重，旧会话回调不得清理新用户；SDK `clearMyUserInfo` 同时撤销排队请求会话归属并清队列，旧 logout/Token 刷新请求不能随下一 AUTH 重发。
- 特殊错误：账号、设备、IP 封禁、白名单、密码错误等待、注销和强制下线使用明确文案，原因保留到登录页。维护接口明确封禁同样按当前会话轮次撤销身份；普通网络失败保持会话。白名单仅展示验证过的服务端真实 IP，日志不输出密码、Token 或密钥。
- HTTP 独立优选：旧 JSON 导航保留 `is_merge_version` 和 `ping_interval_second`，默认 300 秒；Protobuf 导航无该旧开关时不擅自启用。真实 GET `/zlcpig`，2 秒超时；成功次数和平均 RTT 排序，仅选择本轮成功节点，60 秒冷却。同步 SDK API/SSO 和 API/文件/上传 Host；账号/邀请码/导航版本及递增 Host revision 隔离旧结果，包括 A→B→A 交错。
- 密码安全：复用真实强度检查、原密码检查和本人密码重置。手动登录密码短暂用于密钥加密，缓存 AUTH 仅 UID 检查；临时失败前台/周期重试。强制状态只能改密成功或明确退出解除，后续非强制检查不降级；最小 UID/邀请码要求以 ObjectMapper + AppStorage 持久化，重启和暂时恢复失败保持阻断。修改成功清除记住的旧密码并退出重新登录，不假设新 Token。已提交重置在后台保留有界回执等待，成功后前台退出；输入和明文立即释放。

任务在停止、进入后台、退出、换账号和同邀请码重新导航时通过会话轮次/Host/导航版本使迟到结果失效；明确封禁回调另按 UID/邀请码/会话轮次核对，即使后台也能撤销原会话。固定品牌展示和动态 Sentry/Logan 配置未纳入；手机号/邮箱登录、验证码登录、找回密码、直连/扫码/代理仍暂缓。

本轮验证：11 组离线脚本全部通过；登录 26 项、安全 69 项、维护 17 项、角色/资料 19 项、SDK 请求会话隔离 7 项，通讯录 43 项和 SDK 分页 19 项通过；消息补充文件助手开关及角标恢复验证。独立审查发现的五类问题已修复并复核关闭。最终无签名真机目标 `clean build` 为 `BUILD SUCCEEDED`，`git diff --check` 通过；现有 SDK/导航并发与 ObjectMapper 警告仍存在。完整日志 `/tmp/ddlNew-session-maintenance-final-clean.log`。

真实服务器响应、前台半开连接、强制改密 UI、退出请求与节点优选尚未真机联调，按需求文档清单验收。变更保留在 `feature-message-4` 工作区，未提交/推送；本轮不更改在线服务配置。


## 2026-10-13 通讯录与消息需求盘点（仅文档）

用户要求先对照旧项目 `xgd` 整理详细移植需求，本轮不开发。旧代码基线为 `xgd / 5e45f3f` 当前工作树，新代码基线为 `feature-message-4 / 78876ca` 当前工作树；源码可达与 SDK 方法存在不等于旧 App 运行或服务端支持已验证。

- [需求总纲](CONTACTS_MESSAGE_MIGRATION_REQUIREMENTS.md)：范围、现状差距、需求与验收索引、依赖、建议优先级以及待取舍／联调问题。
- [通讯录详细需求](CONTACTS_MIGRATION_REQUIREMENTS.md)：好友、业务分组、群聊、搜索、新朋友、资料与关系操作、业务二维码和关联助手入口。
- [消息与关联聊天详细需求](MESSAGE_MIGRATION_REQUIREMENTS.md)：会话列表、会话操作、历史／收发／消息操作、单群聊详情、群管理与特殊会话，以及旧新 SDK 接口差异。

需求中的建议优先级、扩展功能和验收案例等待用户审阅，不能据此自动开发、恢复演示逻辑或声称真机验收通过。原有主链路和代码完成度不变；后续开发另按用户确认的需求 ID 划定范围。

文档收尾核对：正式需求共116项（C38/M29/CHAT49），专项232项与公共21项合计253项验收设计，15项待确认。三份文档823处本地链接、文件存在、行号、锚点与代码块校验通过，需求ID唯一且总纲索引完整；`git diff --check` 通过。任务开始以来非文档文件摘要比对无变化。本轮未构建、未执行业务测试或真实后端请求，验收设计尚未执行。


## 2026-10-13 通讯录与消息迁移开发（继续验收）

**用户已在新窗口授权继续并要求自主收尾，当前进度以[迁移交接文档](CONTACTS_MESSAGE_MIGRATION_HANDOFF_2026-10-13.md)及测试报告“继续验收记录”为准。** 接手HEAD为`a3233e6`（`4c8f593`之后仅文档），工作区当时干净。最新三项修正已独立复核，补修媒体失效提示、真实成员分页items解析、前台/页面恢复已读及清历史读批次隔离；成员9项、Chat32项、Viewport7项通过；UI/日志快照41/41及签名clean build通过；后续新增精确搜索旧userUID兼容、只传userName及坏页报错窄修，最新42/42入口exit0，127.88秒及签名增量build通过。固定yield的登录安全测试曾偶发失败，仅改测试等可观察退出状态后全量通过，生产登录未改。两端同包最新群文本已实收，原始ACK身份字段取得；真实已读计数、其它业务/媒体及公共严格验收未齐条件已逐项记录，不作发布GO。运行中Mac已锁屏，工具不能继续该端UI；没有绕过锁屏。SDK诊断日志泄漏已在13文件日志边界修复，180匿名可执行检查及独立反向回归通过，非日志业务保持一致；终版iPhone覆盖安装/冷启动/账号B核验完成，Mac因锁屏未运行后续UI/日志版本，不能将此前群正文子证据冒报为终版双端完整验收。终版B搜索ceshi001已真实返回A cs123，检索缺陷闭环。最后发现单聊SDK好友status不持久化导致正常DB行默认0被禁发，仅数据库缓存资格适配0/1，缺行/注销/未知状态与来源群仍拒绝，6项及独立复核通过；最终43/43入口exit0（110秒）及签名build成功；真实单聊Unicode/换行已入列表并在首屏时序修正版返页实见1份，手机终版b4562836…已安装冷启动，详见测试报告RES-19/20。21项公共严格台账已补齐；指定iPad默认字号键盘布局宿主局部Passed，完整宽窗/VoiceOver仍未齐。仍只使用A/B和“有魄力”，不清既有历史、不自动提交/推送，第三身份和同账号双设备等缺前提项不能伪报通过。

以下为较早开发过程快照，28个入口、正在修复等描述不能代替上述最新交接状态。

用户已授权按产品需求开发，范围见 `Docs/CONTACTS_MESSAGE_DEVELOPMENT_SCOPE.md`：116项正式需求中103项明确建议纳入、13项整体暂缓，贴纸、位置、全读及加密等按批准子范围执行。实施计划 `Docs/superpowers/plans/2026-10-13-contacts-message-development.md`。本节取代上一节“仅文档”的当前进度描述，历史记录保留。

- 使用 Superpowers 分工、失败测试与独立审查，SwiftUI 配合 swiftui-pro；iOS16与Swift5保持，每个新增/修改方法中文注释。基线 `feature-message-4 / 78876ca`，不自动提交或推送。用户单独调整的工程Mac/沙盒配置保留。
- 好友业务、分组、群列表和选人、二维码放在各Feature；SDK请求和代理在 `Network/IM`，根 `LoginSessionService` 统一绑定UID、邀请码和认证轮次，退出关闭业务Store及ChatRuntime。根Tab用稳定ID路由进入真实聊天。
- 会话列表接真实置顶/免打扰/未读/删除，删除会话保留历史；文件助手仅置顶与删除。全局搜索读真实好友、群和消息库并按目标消息ID定位。群申请10条分页、批量逐结果，群通知用系统会话最新serviceMsgID上报chatType5已读；等待期间新通知保留未读。
- Chat核心、媒体、消息操作、群设置正在收尾；ACK以ackMsgId绑定发送消息，Socket sessionId不能当聊天UID。云媒体沿用旧STS和对象目录，凭据只留内存，上传HTTP回执与聊天ACK分离；旧XOR/AES媒体格式兼容、四供应商签名离线对抗验证，细节见 `Docs/CHAT_CLOUD_TRANSPORT.md`。
- 独立审查发现申请加载事件丢失、迟到未读快照、好友关系同步、损坏资料写库、群内昵称、选人失败及UI反馈问题，正在逐项修复复测。设计复核见 `Docs/CONTACTS_MESSAGE_UI_REVIEW.md`，逐需求验收见 `Docs/CONTACTS_MESSAGE_TEST_REPORT.md`。

验证当前只确认离线及隔离宿主的局部证据；最近QA汇总28个离线入口通过，云媒体86项对抗断言通过。本轮有签名真机目标clean build已通过，日志`/tmp/ddlNew-contacts-message-final-clean.log`；独立聊天审查随后发现7项缺陷与3项已批准子能力遗漏，修复后的重新构建和复测仍在进行。用户已提供两端专用测试身份，源码/文档/脚本/日志不保存真实密码。最初mobile只发现模拟器，随后devicectl确认两台手机连接并安装签名App。用户明确实际已登录端为名叫iPhone的真机及My Mac，另一台手机仅安装不能记为登录。真机UI改用隔离的本地go-ios/WDA端口8101，避免与模拟器8100混用；My Mac辅助功能由用户开启。独立QA正在核对身份及专用群内实际行为，登录的用户确认不等于收发/群管理验收。


## 2026-10-14 消息与通讯录 UI / 交互对齐 xgd

用户要求消息、通讯录及全部关联页面按 xgd 老项目风格调整，并明确要求交互对照旧项目、使用既有 UIAdapter 做屏幕适配。覆盖30个在用页面文件及通用/专属组件；页面清单、旧源码参考和验证边界见 [UI对齐记录](MESSAGING_UI_ALIGNMENT_2026-10-14.md)。

- 主界面改中性白灰、圆形头像、紧凑标题和平铺列表；品牌色按用户后续要求与首页／我的底栏保持一致，统一复用 `HomeTheme.forest`。通讯录保留权限控制的新朋友/文件助手/群助手卡片、好友/分组/群聊点击分类、字母定位和真实搜索。深色配色独立定义，UIAdapter几何缩放与系统DynamicType分开处理。
- 所有真实二级页面统一导航、资料与表单、确认与失败反馈；账号行点二维码/长按复制、备注整行编辑、可见分组删除/排序、群成员网格/独立名称编辑、公告管理与审核、转发确认及筛选保留选择、文件主动下载/取消等按旧项目交互调整。
- 聊天输入区常驻工具并可收拢、表情/资料入口明确；辅助字号时工具独立一行，键盘收起保留草稿。消息、资料与群来源仍使用真实身份/权限边界，不移动SDK、启动或登录所有权。
- 公告详情编辑已修正为使用当前展示的最新正文/置顶，并以item sheet携带公告身份和独立草稿，避免首次误进发布模式；子页/弹窗返回保留已加载名单和详情。

全量无签名真机目标clean build与六组相关离线入口通过；匿名宿主已验证主列表/聊天的窄屏、最大辅助字号、深色与iPad局部布局，以及分类/未读/返回/键盘草稿和公告编辑快照。全部二级页面尚未逐页VoiceOver/最大字号真机走查，真实相机、媒体与后端操作仍需联调，不将宿主截图记为消息送达或真实群操作通过。补修后的最终增量build成功，日志`/tmp/ddlNew-legacy-ui-final-rechecked-build.log`；公告匿名回归确认ID/新正文/置顶传参、失败保稿及取消返回详情。收尾结果见UI对齐记录。变更留在 feature-message-4 工作区，未提交/推送；用户已有未跟踪评审文档未改。


### 后续主题色修正

用户明确要求保留首页／我的主题色。接手 `feature-message-4 / 89cc7a4`，工作区干净；消息与通讯录的强调、实色按钮、发送气泡统一直接复用 `HomeTheme.forest`，底栏统一森林绿，不再随Tab切换成紫蓝色。头像衬底与边框复用首页主题；深色浅绿按钮／气泡使用深绿前景保证对比。布局、UIAdapter适配及业务交互保持现有实现。

本次无签名真机目标全量 `clean build` 成功，日志 `/tmp/ddlNew-theme-alignment-clean-build.log`；匿名浅色通讯录与深色聊天预览检查通过，主按钮／气泡文字对比浅色7.87:1、深色7.71:1；`git diff --check` 通过。最新图片见UI对齐记录，首轮紫蓝图片已标注为历史预览。主题色修正未提交／推送。

### 通讯录默认分组与资料交互修正

- 对照 xgd 的 `NoaFriendGroupSectionHeaderView`、`NoaFriendGroupManagerCell` 和 `NoaFriendManageVC`，空分组名显示“默认分组”。新客户端此前直接显示SDK空名称；现在统一使用 `FriendBusinessGroup.displayName`，通讯录分组、管理／重命名初值、移动分组和选人页面均复用。空名与纯空白名有兜底，非空名称和默认组重命名保留；原始名称、分组ID、成员及不可删除限制不变。
- 新朋友加载、好友备注保存使用既有 AlertToast loading浮层，移除列表／表单内ProgressView；保存按钮固定显示“保存”。Toast直接观察Store的加载／提交状态，请求结束自动关闭；重复提交禁用和失败保留草稿沿用现有行为。
- 资料页备注、描述两行均带右箭头，打开同一份“备注与描述”编辑页；箭头与内容间距统一为6.zoom，移除嵌套行内边距造成的额外空白。资料底部不再展示“账号已复制”或操作成功文案，复制功能与错误提示保留。

默认分组回归先复现空名失败，修复后 `Tests/Contacts/run-business-checks.sh` 通过；`Tests/Contacts/run-checks.sh` 全部通过（43项生产逻辑、19项SDK分页、25项字段合并）。全量无签名真机目标clean build通过，日志 `/tmp/ddlNew-default-group-name-clean-build.log`。匿名宿主实际确认空名称显示“默认分组”、新朋友Toast出现／请求结束消失，以及备注保存Toast、禁重复提交、模拟失败关闭Toast并保留输入；宿主不访问真实后端。改动未提交／推送，森林绿主题修正保留。

包含最后的资料箭头和底部文案修正的增量build成功，日志 `/tmp/ddlNew-default-group-toast-final-build.log`；`git diff --check` 通过。

### 群聊返回列表顺序稳定

用户反馈通讯录群聊列表进入聊天后返回，该群自动移到末尾。旧版 `NoaGroupListVC` 直接展示SDK群名单；新聊天进入时刷新群详情，`SDKChatClient.updateGroupCache` 调用SDK的替换写入，而群表查询没有显式排序，因此下一次读取数据库行顺序变化。`GroupsStore.reload` 现在按稳定群ID合并：已有群沿用当前列表位置但更新为最新资料，已退出群移除，新群按本轮SDK顺序追加；账号／俱乐部切换或退出清空顺序，不增加第二份持久化群库，也不冻结权限或成员数据。

`Tests/Groups/run-checks.sh` 回归先复现A/B/C在打开A后变成B/C/A，修复后通过；同时验证名称／头像／角色／人数更新、增删和去重，以及切账号后采用新账号列表顺序。日志 `/tmp/ddlNew-group-order-red.log`、`/tmp/ddlNew-group-order-green.log`。

最终无签名真机目标build成功，日志 `/tmp/ddlNew-contacts-final-group-order-build.log`；`git diff --check` 通过。真实账号的反复进入／返回仍需真机走查，当前结论为生产Store离线回归和构建通过。

### 创建群聊分组标签间距

选人页的分组名称改用紧凑普通标题行，移除原生Section标题的额外顶部留白，分组标签下方padding从16.zoom缩为8.zoom；“选择本组好友”使用整行按钮和显式行内边距，保留至少44pt点击区域及原有UID选择、数量限制和预选保护。默认分组名称继续显示，不用空标题占位。匿名生产视图对比确认标签下方到分组标题的空白从37pt缩为7pt；不涉及真实建群请求。

匿名选人宿主确认分组全选7人、取消恢复0人，最终build通过，日志 `/tmp/ddlNew-contacts-final-picker-build.log`；`git diff --check` 通过。

### 用户资料复制账号Toast

用户后续要求复制账号给Toast反馈。`ContactRecordDetailView` 在写入剪贴板后显示既有AlertToast的居中短提示“账号已复制”，2秒自动关闭；顶部HUD因反馈看不到改为居中，资料底部继续不追加成功文案。

无签名真机目标build成功，日志 `/tmp/ddlNew-profile-copy-toast-build.log`；`git diff --check` 通过，改动未提交／推送。

### Toast对比与移动／添加分组

复制提示、新朋友加载、备注保存、移动分组和分组名称保存统一使用 `MessagingTheme.toastBackground`／`toastText`，复用首页文字／表面色反转浮层明暗：浅色页面深绿底浅色字，深色页面浅色底深绿字，避免白色Toast融入白色页面。移动分组加载和移动提交不再插入列表ProgressView；打开添加分组子sheet时父页暂停自己的Toast，防止双重提示。

添加／重命名分组的保存按钮始终显示，使用清晰的禁用背景和文字色，名称为空／纯空白、未更改或提交中禁用；有效名称后启用。提交改用Toast，失败保留输入；sheet最小高度和键盘出现时按钮仍可见。匿名生产视图已确认居中复制Toast、移动页加载Toast、添加页空名称与空格禁用／有效名称启用，以及提交时只有一个Toast。

浅／深色复制Toast已截图确认可辨，添加分组模拟失败关闭Toast、保留名称并恢复保存。无签名真机目标build成功，日志 `/tmp/ddlNew-contacts-toast-contrast-build.log`；`git diff --check` 通过。匿名宿主不访问真实后端，改动未提交／推送。

### 按导航路径控制Tab底栏

按用户指定的 `.toolbar(path.isEmpty ? .visible : .hidden, for: .tabBar)` 方式，`ActivityNavigationScope` 现在使用实际绑定NavigationStack的 `navigation.path` 统一控制底栏，四个Tab继续独立持有路径。移除聊天页、MessagingPageChrome以及旧ClubDetailChrome的固定隐藏指令；ClubDetailChrome已无职责，移除文件及使用点。

消息行点击、消息／通讯录建群后的跳转改用 `ActivityNavigation.open` 将ChatRoute追加到实际路径，首页签到入口使用ActivityRoute值路由，避免根页面布尔／直接目标push未计入路径、底栏误显。二级页仍沿已有栈跳转，SDK与聊天Store所有权保持原实现；没有启用RouterTool内未接当前主界面的历史路径，也没有增加第二份导航状态。

无签名真机目标build通过，日志 `/tmp/ddlNew-tabbar-path-build.log`。匿名宿主运行生产TabbarView、ActivityNavigationScope以及消息／通讯录／资料页面，SDK、首页／我的内容及聊天正文替换为夹具；已操作四个Tab根页面到二级页面再返回，确认根页面显示、push隐藏、返回恢复。消息点击的路径深度确认为1。此为导航验收，不代表真实聊天收发／建群通过；`git diff --check` 通过，未提交／推送。

### Toast柔和配色与新朋友行修正

使用ui-ux-pro-max的颜色对比建议，将共享Toast底色更新为低饱和灰绿：浅色#E1E9E3、深色#2F3C34，文字使用HomeTheme.text。覆盖复制、新朋友加载、备注保存、移动分组和分组名称保存；首页／我的品牌主题色继续保留。文字与底色对比约10.07:1和10.45:1，替代先前较突兀的反转配色。

新朋友页按用户最新要求移除业务成功和错误文案的列表行，也不以Toast提示这些文案；Store仍保存真实结果状态，页面保留加载Toast与cell内“已添加”“等待验证”等申请状态。NavigationLink包住整行，系统右箭头位于申请操作按钮之后的最右侧，大字体时操作按钮仍换至下一行。

### 添加好友、二维码、按钮与通讯录同步补充

- 添加好友进入／离开时清空搜索结果，进入时重置输入和提示；`clearSearch()`撤销搜索轮次，迟到请求不能恢复历史用户，资料缓存保留。精确搜索的服务器“用户不存在”作为无结果显示空态，其他网络／格式错误保留。
- 我的二维码移除右上角更多菜单，底部保存相册／聊天分享保留。新增`MessagingActionButtonStyle`控制整体最小高度48pt，替换二维码、资料操作、备注保存、新朋友申请、相册扫码、聊天附件／群公告／发送／头像／位置／转发以及注销页中叠加系统内边距的按钮；分组保存也统一48pt，大字体可自然增高。已有52pt登录／首页按钮没有同类叠加问题。
- 扫一扫直接在当前导航页创建相机，移除相机fullScreenCover及入口表单；相册选择保留在取景页底部，失败可重新扫描，退出销毁捕获会话。识别结果继续由真实SDK转换和原有用户／群流程处理。
- 备注保存成功后等待ContactsStore读取SDK缓存，再更新资料关系快照、关闭编辑器；保存及回读期间保持Toast和禁用。读取中遇到显式刷新追加一次读取，避免复用保存前旧快照，账号轮次隔离保留。
- 分组管理去掉成功文案和列表ProgressView，读取／更新改居中Toast，名称编辑sheet出现时父页暂停Toast。前后移动与拖动共用`moveGroup(id:toIndex:)`，提交目标分组真实ugOrder，移除首尾加减1；首尾菜单边界禁用，原位／非法位置不提交。

离线回归已复现保存回读复用旧快照并修复，Contacts检查44项、SDK分页19项、字段合并25项通过。Business检查涵盖搜索清空／迟到隔离／再次搜索、用户不存在空态与网络错误，以及非连续排序值10／30／70的前后和拖动目标及边界。最终无签名真机目标build通过，日志`/tmp/ddlNew-contacts-final-all-build.log`。

匿名宿主运行生产页面已确认：二维码导航没有更多按钮，底部保存／分享实测48pt，大字体改纵向排列；新朋友按钮48pt、系统箭头在整行最右侧、按钮点击独立提交；添加好友首次进入不显示夹具旧搜索，无结果展示空态；分组管理加载只呈现居中灰绿Toast，添加分组行缩小；扫码直接取景而不呈现入口表单。浅／深色Toast均已截图检查。宿主使用模拟数据，未验证真机相机识别及服务端修改／排序最终结果；改动未提交／推送。

### 消息默认Tab、统一保存样式与二维码Toast

ClubStore首次创建及登录准备／退出／注销后的Tab默认统一为消息。分组名称保存按钮与备注保存复用MessagingActionButtonStyle，可提交为首页森林绿／对应前景，禁用统一降低透明度；消息编辑、群名称／群昵称和公告编辑的保存入口也复用此样式，保留各自校验和禁用条件。

二维码保存过程与结果均改居中Toast，移除图片下面的保存文案和进度行；匿名模拟器实际保存夹具二维码后确认“已保存到相册”Toast。扫码读取／业务结果改Toast，删除页面内错误／业务结果以及所有“重新扫描”入口；相机解析失败的Toast结束后自动恢复捕获，相机权限／设备错误不反复重启。相册入口保留在取景页底部。

### 备注保存确认直接更新SDK缓存

用户再次反馈刷新后仍显示旧值。离线客户端复现：服务器保存确认返回新资料，原perform紧接着读取profile时仍返回旧资料，会覆盖新值；单纯补读本地缓存不能解决这一覆盖路径。

SDKContactsBusinessClient在备注保存成功回执后、当前身份验证及SDK共用锁内更新真实好友模型的remarks／descRemark／remarksPinyin／showName，调用toolUpdateMyFriend触发已有好友与分组代理，并返回已更新缓存快照。ContactProfileRequestGate撤销保存前读取的写入资格。ContactsBusinessStore使用该确认快照，不再立即发送可能返回旧值的profile读取，同时撤销保存前的Store资料轮次；缓存写入失败返回错误并保留编辑稿。随后仍读取通讯录缓存、更新资料关系并关闭编辑页，未另建好友数据源。

Business回归新增保存确认后旧资料不能覆盖以及失败不能修改资料，修复前已复现失败、修复后通过。Contacts44项、SDK分页19项、字段合并25项继续通过。全量无签名真机目标build通过，日志`/tmp/ddlNew-remark-confirmed-cache-build.log`；真机当前账号修改结果尚未再次核对。

匿名生产视图进一步确认分组保存空输入禁用／有效名称启用，颜色与备注保存共用同一样式，键盘出现仍可操作；二维码保存结果Toast实际出现，扫码通过相册读取夹具二维码后模拟业务失败仅显示Toast且无重新扫描按钮。主Tab匿名预览初始选中消息。预览Store和SDK为夹具，不代表真机备注同步或相机业务识别已通过。


### 群人数、群成员导航与全局操作Toast收尾

- 新建群先合并服务器确认记录，reload保留已知正数，0缓存不覆盖有效人数，后续真实正数仍更新。SDKChatClient将群详情memberCount写回群表，并且仅人数变化且写库成功时发群更新代理，让通讯录刷新；相同人数不通知，避免权限刷新回查循环。没有用选择人数推算服务端人数。
- xgd群设置成员预览和查看成员先到名单，名单再到资料；同步未就绪、私聊限制、注销和机器人限制保留，自己的资料可按权限查看。名单资料沿当前栈直接push，修正布尔导航目标内混入值路径导致父目标重排。整行系统箭头在管理菜单之后最右侧，管理独立响应。移除sheet与确认dialog的状态清理互不干扰。
- 群二维码右上角更多菜单删除。群名称与公告的导航栏保存恢复紧凑文字样式、44pt触点和启用 / 禁用色；保存Toast、失败草稿保留。群设置查找聊天记录右侧放大镜删除。
- MessagingStatusToast复用AlertToast与灰绿配色，loading观察真实请求，短反馈独立3秒计时、默认不重播旧结果。群设置、管理、成员、头像、公告、选人、二维码、入群审核及相关聊天 / 搜索 / 媒体 / 转发操作统一接入。其它既有注册、改密、邀请码和注销等操作结果同步移出正文。新朋友页继续遵循单独要求，不弹全局业务结果Toast；分组管理不显示普通成功提示。内容、连接 / 权限状态、校验说明、失败标记、重试和确认入口保留。
- 聊天实时发送失败进入ChatStore.errorMessage，由聊天页Toast显示，气泡下不再追加业务错误正文；保留失败图标和重试。历史失败和成功ACK之后的迟到失败不会弹提示；发送 / 重试清旧错允许重复提示。验证码loading仅网页验证显示，不遮住图片 / 安全码输入。

收尾验证：Groups、Group policy14项、Settings7项、Member page9项、ContactsBusiness通过；Contacts44项、SDK分页19项、字段合并25项、Chat33项及LoginSecurity69项通过。最终无签名真机目标build为BUILD SUCCEEDED，日志`/tmp/ddlNew-final-ui-handoff-build.log`；git diff --check通过。匿名生产成员视图确认预览进名单、资料正确push与返回、箭头最右侧及管理菜单独立；群名称加载 / 失败Toast均实际出现，消失后保留输入。全部代码保留工作区未提交 / 推送，用户另行改动LocalCredentialStore保留。真实群人数、备注缓存与服务端、角色导航和二维码相机仍需真机验收，不能将匿名夹具当作完成证据。完整需求与交接见上方会话文档。

### 群设置成员头像直接打开资料（后续用户要求）

2026-10-14接手实时分支为 `feature-message-4`、HEAD `39bfae9`，工作区干净；此前交接的未提交修正已包含在该后续提交中，本助手未提交或推送。

用户要求点击群成员直接进入详情，不再经过一遍成员列表。当前完整名单已直接跳资料，问题入口为群设置成员预览绑定了打开名单动作。预览现传递所点成员 UID 和来源群 ID，直接打开 `ContactRecordDetailView`；返回回到群设置。设置 Store 将资料导航计为子页，避免 push 时关闭快照与观察。“查看群成员”继续打开完整名单，同步、私聊权限、注销及机器人限制保留。此要求取代上节关于“预览先到名单”的历史行为。

群策略14项、设置7项、成员分页9项离线检查通过；全量无签名真机目标 clean build 为 `BUILD SUCCEEDED`，日志 `/tmp/ddlNew-member-direct-profile-clean-build.log`，`git diff --check` 通过。用户明确暂不使用 Mobile MCP，后续未再调用；本轮未安装新包，真机实际跳转、备注同步、新建群人数与 Toast 服务器结果仍待验收。改动保留工作区，不自动提交或推送。

### 群设置移除成员与角色标签补齐

按用户要求只读对照xgd独立移除页，修正减号入口仍打开普通名单的问题。新增 `ChatGroupRemovalView`：搜索、UID多选、完成人数、确认sheet中的删除所选成员全部已发消息选项；失败保留选择，真实受理后返回群设置Toast。共用现有Settings Store和SDK `.remove`，没有新增接口、群库或推算人数；进入子页保留设置Store。候选与提交共用当前权限，过滤本人 / 群主 / 注销 / 机器人和非下级角色；同步未完成、重复UID和超500人不能提交，权限变化撤销失效选择，SDK提交前再次拉取服务器权限。

预览、完整名单、移除和确认名单统一显示 `ChatGroupMemberRoleBadge`，真实role2为群主、role1为管理员，保留首页森林绿和既有UIAdapter。前一轮头像直达资料改动保留，普通名单管理菜单仍可单个移除。

群策略17项、多选12项、设置10项、成员分页9项、Chat33项及Groups检查通过；测试覆盖移除失败保留、批量UID / 删除消息选项、成功回读名单 / 人数和降权 / 上限。无签名真机目标全量clean build成功（`/tmp/ddlNew-group-removal-clean-build.log`），最终增量build成功（`/tmp/ddlNew-group-removal-final-build.log`），`git diff --check`通过。未调用Mobile MCP、未在真实服务器群中执行移除；工作区改动未提交 / 推送，真实成功 / 失败Toast和不同角色权限仍待真机验收。

### 群公告正文与置顶字段修复

用户反馈发布后没有正文且关闭置顶仍显示置顶。只读核对xgd的 `NoaGroupNoteModel`、列表数据Handle、公告编辑和详情页：写入字段为 `noticeContent / isTop / isSendMsg`，响应字段为 `content / topStatus / noticeCreateNickname / createTime`；`status`是正常/删除状态。新客户端之前误将写入字段当读取字段，并用正常status1兜底置顶。请求的isTop开关原本已正确，不据此声称服务器把普通公告实际改成了置顶。

新增共用 `ChatGroupNoticePayload` 修正列表、详情及聊天顶部的响应映射，兼容原有别名但以xgd响应字段为准，不再以status判断置顶；正文保留Unicode/换行，大整数ID和毫秒时间兼容数字/字符串，坏页报错而非空白或静默吞行。发布/编辑仍独立提交isTop与isSendMsg，删除只提交身份与公告ID。

公告Store通过 `ChatNoticesClient` 注入现有SDK，保持Runtime会话所有权。保存受理后回读首屏，回读失败保留现有列表并提示下拉重试，不重复发布；详情成功同步列表，编辑/删除使用当前正文和置顶值，保存或退出后旧详情请求失效。页面增加下拉/重新加载入口，保存Toast在编辑sheet关闭后展示，写操作仅群主/管理员可见；聊天从公告sheet或群设置返回会主动重读真实置顶公告。

离线公告响应15项、公告Store12项通过；回归先复现content读错和保存后刷新失败清空列表，再修复。Chat33项、Settings10项及群策略17项/移除选择12项继续通过。无签名真机目标clean build成功（`/tmp/ddlNew-notice-contract-clean-build.log`）；增量第一次遇到build.db锁，未终止其他构建，重试成功（`/tmp/ddlNew-notice-contract-final-retry-build.log`）。随后窄修新增的Optional公告Equatable隔离警告，公告响应15项再次通过，终版增量build成功（`/tmp/ddlNew-notice-contract-warning-fixed-build.log`），`git diff --check`通过。未调用Mobile MCP、未创建/编辑真实服务器公告，既有群移除和头像资料路由改动保留，未提交/推送。

### 公告详情删除确认不再延迟到返回列表

用户反馈详情点击删除没反应，返回列表才弹确认框。原因是详情回调只设置父列表的confirmDelete，而confirmationDialog挂在不可见的列表页。详情现在持有自己的删除快照和确认框，点击即在当前详情确认；取消或离开清理该页状态，确认后与列表长按共用deleteNotice和既有真实Store/SDK删除、失败反馈及成功返回。详情不再设置列表的弹框状态，避免返回后二次提示。

公告响应15项和Store12项离线检查通过；本次无签名真机目标clean build为BUILD SUCCEEDED（`/tmp/ddlNew-notice-delete-dialog-clean-build.log`），`git diff --check`通过。保留已有字段、置顶、成员移除和路由修正，未使用Mobile MCP、未执行真实服务器删除，未提交/推送；弹框与取消/确认的真机表现仍待复验。

收尾实时检查发现HEAD已前进至 `6252ab8`（`fix：修改通讯录模块的bug`），上述生产修正保留在当前源码，工作区只余两份交接文档修改。本助手没有执行commit/push；此前未提交状态为过程快照。


## 2026-10-14 晚间：全模块对齐继续执行

用户授权恢复 Mobile MCP，在 Mac Designed for iPhone 与真机使用 A/B 测试账号对照 xgd，自行决定常规测试问题，不自动提交/推送。已完整阅读两份交接文档，当前分支 feature-message-4，开工 HEAD 6252ab8；用户既有修改保留。

本轮代码进度：公告删除受理即发布返回事件，详情导航不再依附被删除的列表行；编辑页当前确认删除，先关 sheet 再返回列表，失败保稿留页。公告时间与 xgd 一致 yyyy/MM/dd HH:mm；管理角色读取只依赖群 info，写前核权保留，角色回执乱序隔离。资料好友申请成功 Toast 和本认证轮次等待状态；等待以申请稳定版本识别终态，展示昵称/头像变动不能解除等待。入群申请展示邀请双方真实 UID、头像、角色及群名，严格混合类型页解析，坏页保留旧列表及通知未读。业务二维码已验证结果直接导航资料/已加入群；返回重建相机。

消息修正：全局搜索过滤删除/撤回原文及非法会话身份；名片点击直接资料；转发专用编码保留合并原时间、清引用、@转普通可见文本，回执缓存保留媒体/贴纸/坐标尺寸；预检后重读原消息状态。系统展示摘要与旧通知开关/静默/定向对象策略共用；刷新型不插空气泡，置顶独立revision回读。可见正文只扣实际成功转读的身份，计数写失败保留待补扣状态。**打开会话仅清本机手动 readTag，不自动发 conversationReadedStatus：SDK对应服务端事件会整会话清零且没有消息边界字段，不能把该API当只清提醒。跨端自动手动标记清除仍未验收。** 禁言结束时间只安排真实权限重查；失败不本地解禁，身份轮次/截止任务取消隔离。

退出/解散使用现有公开 NoaIMHttpManager 运输接口，服务端受理后在 SDK 锁和身份守卫内清群/历史/会话，避免 SDK包装先自行处理迟到旧账号回执。Runtime 发布带完整认证上下文的关闭事件，先退设置再退聊天，防动画中重open。后续服务端会话清理失败提示“群操作已受理…”而不误报退出失败；尚未对既有群执行退出/解散测试。

验证记录持续写入 [全量对齐验收台账](CONTACTS_MESSAGES_PARITY_QA_2026-10-14.md)，覆盖116项原需求及13项既有暂缓项。脚本曾有旧备注验收fake无限等待，已按确认保存合同修复并加5秒截止；更新fixture过程中全套抓到一项编译失败，后续需最终稳定复跑，不计全部通过。聚焦匿名检查不能代替真实SDK/服务器。

Mac当前真实App已收到真机B发来的 QA_20261014_B2A_1840 中文/emoji/第二行，并发出A2B1850；双向接收、已读及最终代码复验继续。真机18:58覆盖安装签名build成功（/tmp/ddlNew-parity-final-device-build.log），保留数据，install回执保存在 /tmp/ddlNew-parity-device-install.json；debug dylib SHA256 ae33417a430ce59d6782b68180d9ba652f32a1e3eea29b9e4891073d0cd400a2。交叉复核后仍在窄修，不把此过程构建当最终全部验收。真机普通公告1856已发布，正文和第二行可读，未自动置顶；最新删除返回/Toast待覆盖版本复验。既有公告未改动/删除，原备注Affff临时改为QA1014_A_备注🙂用于同步检查，验收后须恢复。


晚间19:14实际复验补充：54/54稳定离线脚本通过（260.56秒）与签名build/覆盖安装成功只是过程证据。真机确认A2B1850完整实收；1840发送条已读人数仍0/1，继续检查。公告编辑页确认删除后仍停留，Toast直到手动返回列表出现；列表摘要字面省略号会覆盖保存后的详情和再次编辑草稿。已继续修可见页受理callback返回和真实完整详情准备；19:13 QA1856条仍显示在列表，正在核对ID/版本，不宣称服务器消失。详见全量验收台账，不自动commit/push。


19:35真机公告删除返回已闭环：编辑真实14后confirm即自动回列表，服务器首屏只有原11/7，自建QA消失。诊断另证实编辑13回执新14；按xgd保存回公告列表避免旧ID操作。保留全文/真实详情编辑已复验。临时身份日志将移除，过滤证据见 /tmp/ddlNew-parity-evidence/notice-id-lifecycle.log。另补type13真实三段已读协议，51项离线通过，最终新marker实读人数继续。

21:xx补充：公告最新无诊断包普通发布→置顶→取消置顶→编辑删除已真机闭环，保存和删除均自动回列表；全文中文/emoji/换行保留，QA项回查消失，原公告保留。读计数新增AUTH范围SDK观察和成员epoch，保留未知初始正数/进程结束/SDK506无边界全清限制；最终59/59离线与签名build通过。真机又确认备注恢复时排序新而好友行视觉旧，最小展示identity修正构建通过，即时同步仍待末包复验。详情以全量验收台账最新章节为准，工作区保留、不提交推送。
