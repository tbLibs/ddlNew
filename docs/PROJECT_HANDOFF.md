# ddlNew 交接（feature-IMSDK-2）

## 当前基线与边界

本文件在本次修改前不存在；这里只记录当前分支已核对的实现，不代表其他分支的历史状态。基线提交为 `6b7c65393d33e82d1279ac98eb365eac88c76b65`。以源码和当前 Git 状态为准，工程入口为 `ddlNew.xcworkspace`。

用户原有的 `ddlNew.xcodeproj/project.pbxproj` 和 `ddlNew.xcworkspace/xcshareddata/swiftpm/Package.resolved` 修改必须保留。

## 2026-10-26：裁剪未使用的通话 SDK 与配置请求

本节覆盖下方历史记录中关于系统配置残留、翻译同步和通话依赖的旧描述。本次起点为 `feature-IMSDK-2` 的 `2ebfd50`；保留用户原有 Sentry package 的空 `traits` 设置。

- App 和 NoaChatCore 两个 target 移除 LiveKit、ZegoExpressEngine，依赖锁同步移除 WebRTC、Promises、swift-log；其余 17 个 SPM pin 的版本与 revision 不变。
- 删除通话引擎封装、22 个呼叫/房间/心跳请求、SDK 转发入口、通话 delegate、循环铃声与震动控制。旧 `NoaIMSDKManager+Call` 拆除，只留下 `+CallRecords`：接收其他设备/历史消息中的通话记录并写入原会话和消息存储，不发起/接听通话、不创建引擎、不请求房间凭据。
- 保留 Protobuf 字段编号及现有消息/会话数据库字段。记录兼容处理保留原有单聊结束、其他设备接听、群聊开始/结束记录的筛选规则；不处理通话中的参与者通知。
- 删除角色配置、角色功能权限列表、群活跃等级配置、签到规则、翻译通道、用户翻译配置读取/上传和远程登录方式，共 8 个请求的路径、HTTP/TCP 实现和 SDK 声明/转发。
- 会话同步完成后原本会自动请求用户翻译配置；已删除两个自动调用点、同步实现及专用队列。普通联系人/群组/会话同步、未读统计和同步时间持久化保留。
- 登录/注册、密钥交换、验证码/安全码验证、用户 AUTH、账号会话恢复、租户签名、TCP 收发与重连、DNS1 节点发现保留。服务端授权校验未绕过。
- 已重新 `pod install --no-repo-update`，解决切分支后本地 Pods 与 lock 不一致；Pod 版本不变，仅 Podfile 注释对应 checksum 更新。

验证：9 组现有离线回归（Connection、Login、AccountLifecycle、SessionRestore、Network、NetworkQuality、Verification、LoginConsent、DNS1）及真实 AUTH Protobuf 字节检查全部通过。新增 `python3 Tests/AppReview/check-call-records.py` 编译生产记录筛选方法，112 个消息事件组合通过。依赖/配置移除检查扩展到两个工程、依赖锁及 Release Mach-O。

全新目录无签名 Release 构建成功：`/tmp/ddlNew-sdk-trim-release/Build/Products/Release-iphoneos/ddlNew.app`，日志 `/tmp/ddlNew-sdk-trim-release.log`；整理后的最终构建也通过，日志 `/tmp/ddlNew-sdk-trim-release-final.log`。二进制扫描结果和限制见 `Docs/AppReview-2.5.19-remediation.md`。尚未进行真机登录/消息收发/断网恢复、签名归档或上传；本地构建不能代表审核通过。

## 2026-10-23：固定 tenantCode，停用系统配置接口

当前要求：用户已提供 tenantCode，固定在 `ddlNew/Configuration/LocalSDKSettings.swift`，不再调用 `/biz/system/v2/getSystemConfig`，不读取历史系统配置。此前“接口只提供 tenantCode”的方案已替换。

### 启动、登录与 SDK 边界

- `SystemConfigService.swift` 请求实现整体注释，不参与编译。已移除 `TenantCredentials` 临时响应模型和协调器的异步取值依赖。
- 首次连接、缓存启动和访客重连统一执行：TCP/ECDH 成功 → 核对连接轮次及 Socket 状态 → 将 `LocalSDKSettings.tenantCode` 写入 SDK → 保存可用入口 → 登录就绪。
- 配置接口不可用不再影响连接。断线、取消、过期连接仍不能进入就绪状态；用户 AUTH 所有权与会话隔离保留。
- 切换邀请码仍使用同一个本地固定 tenantCode，不从服务端覆盖，不回退读取历史缓存。
- `IMSDKConnectionAdapter.applyTenantCode` 只写入协议参数，SDK 重置时仍清空旧值。
- 保留用户要求的 `#if DEBUG` 日志：成功写入 SDK 后打印 `[SDK租户] tenantCode=<本地固定值>`，Release 不包含该打印。

### 固定功能规则

`LocalAccountPolicy` 固定账号密码登录、开放账号注册、图文验证码渠道 2、无需额外注册邀请码、密码不强制符号（仍要求 6～16 位字母和数字）。注册入口固定展示，不受远程配置影响。

“额外注册邀请码”与选择服务器的入口邀请码不同。服务端业务错误触发的验证码及设备安全码验证仍保留，客户端没有绕过后端认证。

原系统配置模型、存储工具、接口枚举和 SDK 对接口路径的签名/解密分支仍在仓库，但没有活动的配置请求调用链。DNS/OSS 导航和其他业务请求仍保留，本次改动不等于删除所有远程网络通信。

### 验证

连接回归先将旧取值接口设为不可用，旧实现失败为 `remoteConfigUnavailable`；移除依赖后通过。当前连接检查编译真实协调器与本地参数，不编译或替换任何系统配置服务，验证固定值传入 SDK、断线、过期连接、AUTH 所有权、缓存重连和切换邀请码。

已通过以下离线脚本，SDK/导航边界使用替身：

- `bash Tests/Connection/run-checks.sh`
- `bash Tests/Login/run-checks.sh`（26/26）
- `bash Tests/AccountLifecycle/run-checks.sh`
- `bash Tests/SessionRestore/run-checks.sh`
- `bash Tests/Network/run-checks.sh`
- `bash Tests/NetworkQuality/run-checks.sh`
- `bash Tests/Verification/run-checks.sh`

整工程无签名 Debug 构建命令：

```sh
xcodebuild -workspace ddlNew.xcworkspace -scheme ddlNew -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /Users/taobotaobo/Library/Developer/Xcode/DerivedData/ddlNew-gouvoiamsobqkuevngdfnxdlbzay -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
```

当前版本无签名 Debug 整工程构建通过（exit 0，`BUILD SUCCEEDED`），日志为 `/tmp/ddlNew-local-tenant-build.log`。尚未真机验证本地值的实际验签与登录结果，未归档或上传 App Store。

## 登录页隐私政策与用户手册同意（2026-10-23）

- 登录表单增加默认未勾选的同意框和独立的《隐私政策》《用户手册》阅读入口。打开文档不会自动勾选，也不将同意状态写入偏好或 Keychain。
- 用户最新要求：未勾选时仍可点击登录。弹窗提供“取消勾选”和“确认勾选”；取消保持未勾选且不发送请求，确认将同意状态置为 true 并立即用当前表单调用原登录方法。提示明确说明确认代表同意并继续登录。
- 登录按钮仅在正在请求或已登录时禁用；空表单也可点击并优先提示勾选。勾选后账号/密码为空仍由原登录服务校验并拒绝，不跳过输入校验。
- `LoginViewModel.login` 在调用登录服务之前校验同意状态并发布弹窗状态。勾选后仍执行原登录 → 会话 → AUTH → 路由流程；取消勾选再次拦截。新登录页面与更换俱乐部后恢复未勾选。
- 用户手册入口暂沿用现有 `usageSupportURLString`（support.html）。目前未确认其在线内容是否为用户期望的正式手册；如有专用地址，应替换此链接。
- 新增 `Tests/LoginConsent/run-checks.sh`，编译真实 LoginViewModel 验证未同意时不发送请求、不创建会话、不跳转且弹窗提示；同意后正常登录，取消勾选重新拦截，并检查新页面/更换俱乐部的状态重置。两个回归分别在缺少同意校验、仅展示行内错误的旧实现上失败，最终均通过。
- 原 7 组离线检查及新增同意校验检查均通过；包含最终弹窗交互的无签名 Debug 整工程构建通过（exit 0，`BUILD SUCCEEDED`），日志为 `/tmp/ddlNew-login-consent-final-build.log`。未运行依赖真实导航/登录的 UI 自动化，未真机验证点击与网页展示。

### 同意弹窗双选项补充验证

`LoginView` 的确认按钮执行与已验证的 ViewModel 同意后登录路径相同的操作，取消按钮保持未勾选。`Tests/LoginConsent/run-checks.sh` 已再次通过；本次 UI 修改后的无签名 Debug 整工程构建通过（exit 0，`BUILD SUCCEEDED`），日志 `/tmp/ddlNew-consent-confirm-build.log`。未进行真机弹窗点击验收。
