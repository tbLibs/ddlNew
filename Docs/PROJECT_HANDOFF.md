# ddlNew 项目交接文档

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
→ 五路 DNS 并发解析
→ 节点归一化
→ OSS Auth 竞速
→ Nav Protobuf 响应校验与解密
→ 保存导航、HTTP/TCP 节点和系统配置
→ SDK 配置
→ TCP/ECDH 节点竞速与正式连接
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

五路 DNS 来源同时启动：

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

- `ddlNew.ossNavigation.v1`：ObjectMapper JSON，结构与旧项目 `NoaSsoInfoModel` 的用途对齐，包含导航节点、配置和 `lastLiceseId`。
- `ddlNew.selectedHTTPHost.v1`：当前选中的 HTTP Host。
- `ddlNew.systemConfig.v1`：最新系统配置 ObjectMapper JSON。
- `ddlNew.userInfo.v1`：用户资料，不含密码和 token。
- 用户会话凭据：Keychain `ddlNew.userSession/currentSession.v1`。
- 记住的登录表单：Keychain `ddlNew.rememberedLogin/loginForm.v1`。

读取唯一导航和系统配置时不再按邀请码核对；用户会话凭据仍需核对其所属 `lastLiceseId`，避免跨俱乐部认证。

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
