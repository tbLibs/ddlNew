# xgd → ddlNew 功能差异清单（2026-11-10）

本轮以实时 `feature-all-5` 源码、xgd 的 `xgd` 分支源码及既有迁移台账交叉核对。范围为非首页业务；遵照用户要求，不读取或修改 `ddlNew/Features/Home`，也不检查首页活动、俱乐部及其数据实现。以下是源码功能覆盖，不是逐项服务端／设备验收。

## 尚未迁移或仅有底层兼容

| 功能 | xgd 依据 | ddlNew 状态 |
| --- | --- | --- |
| 每日签到／日历／签到记录／积分明细／规则／签到助手 | `Tab/CandyTalkSignInViewController.m`、`Modules/MineModule/Controllers/SignIn`、`Modules/Session/Controllers/NoaSignInMessageViewController.m` | 本轮前仅有SDK与type6占位；本轮实现见下节 |
| 我的团队、团队详情／邀请及团队建群 | `Modules/Team`、`Modules/NoaTeamInviteModule`；旧台账C-035 | 新端普通群管理已存在，团队业务仍缺独立页面与接线 |
| 我的收藏、消息收藏、保存链接 | `NoaMyCollectionViewController`；CHAT-026 | 当前聊天明确不展示收藏链接标签；不可把已有贴纸收藏当作消息收藏 |
| 翻译管理／默认语言／消息翻译／字符额度账号管理 | `NoaTranslate*`、`CharacterManager`；CHAT-027 | App界面三语已接；翻译服务、额度／扣费及管理页面仍未接 |
| 修改密码、手势图案锁、设备安全码管理、信任设备 | `NoaSafeSettingViewController`、ChangePassword、GestureLock、DeviceSafeCode、`NoaTrustedDeviceViewController` | 登录验证已有安全码等挑战；设置页的配置／修改／设备管理未迁移 |
| 隐私设置：是否展示离线时长 | `NoaPrivacySettingViewController` 的 `userSetShowOffLineStatusWith` | 设置页只有隐私政策链接，无此账号开关 |
| 手动清理图片／视频等缓存 | `NoaSystemSettingViewController` | 新端有生命周期自动清理与聊天清历史；未提供旧版系统设置的手动清理缓存入口 |
| 封禁详情及解封相关页面 | `LOGIN_REGISTRATION_PARITY_AUDIT_2026-11-10.md` | 新端有账号／设备／IP封禁提示，详情查询及解封UI未迁移 |
| 发送新位置 | CHAT-016；`ChatLocationDetailView` | 仅历史位置查看，不申请定位或发送新位置 |
| 定时自动删除（关闭／1／7／30天） | CHAT-029 | 未接配置入口和新业务流程 |
| 群机器人列表及活跃等级设置／展示 | CHAT-047 | 群成员活跃积分增量同步已接；不等于机器人及等级UI已迁移 |
| 表情商城及其他游戏 | CHAT-014；`ChatSticker` | 基础表情、已有收藏／已用贴纸、骰子和猜拳已接；商城及其他新游戏未接 |
| 加密／阅后即焚的新消息发起 | CHAT-049及迁移交接 | 历史消息兼容不代表新消息发送能力已开放 |
| 双击消息Tab循环定位未读 | M-025 | 尚无旧版等价交互 |

旧端路径以上均相对于 `/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk`。历史台账中的音视频、推送、黑名单、投诉、我的应用等缺口已被后续源码覆盖，不继续当作未迁移项。

## 明确排除与需进一步确认的项目

- 群发助手：此前明确删除，不自动恢复。
- 邮箱登录／注册：此前明确移除，账号和手机保留。
- 版本检查、日志上传：此前明确不接入。
- 旧五路导航／OSS Auth、远程getSystemConfig：已有明确的新架构边界，不以“对齐”为由恢复。
- 支付助手：两端都有类型痕迹，旧端有过滤方法但当前调用情况需另核对，且没有点击支付分支；不能据此断言存在可迁移的交易业务（M-023）。用户本轮后续明确暂不接支付并隐藏支付通知，新端已在共用会话展示边界过滤，不计入可见列表的未读数。
- 设备／服务端未验收的已实现功能与“源码未移植”分开记录；本清单不是对所有隐藏开关、运营开关和后端能力的穷尽认证。

## 本轮每日签到接入

- `Features/DailySignIn`：独立SwiftUI页面与Store；“我的 → 每日签到”，消息type6 → 签到助手 → 每日签到。页面使用独立sheet导航，不改首页路由。
- `Network/IM/DailySignIn/SDKDailySignInClient`：复用 `imSignInRecordWithSign`、`imSignInWithInfo/Record/IntergralDetail/Rule`；参数为userUid及月记录的year/month。
- 字段沿旧端：isSignIn、loyalty、signTotalDay、signTotalLoyalty、monthTotalDay；signInRecords／totalLoyalty；integralRecordVos／gainIntegral／useIntegral；signInSwitch／signMode／连签奖励JSON。
- 记录按月切换，积分操作类型9签到、18扣减、19清除；规则支持随机与连签。提醒分页读SDK本机历史，每页15条，进入清本机提醒计数。
- 绑定UID／租户／AUTH轮次；退出清理，拒收旧回执；重复点击互斥，签到受理后刷新失败单独提示，同日迟到旧状态不能重新开放提交。
- 复用既有主题与三语资源，不引入新库、不修改xgd，不处理首页活动签到。

验证结果与限制见 `PROJECT_HANDOFF.md` 本轮章节。
