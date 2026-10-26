# 2.5.19 整改记录（2026-10-26）

本次删除 App 与 NoaChatCore 的客户端 IP 采集和上报、废弃的业务系统配置请求，并清理实际进入 Release 二进制的相关依赖。服务器地址发现已按后续要求替换为 DNS1；登录加密与鉴权、缓存恢复和重连继续保留。

## 已删除

- App 的 `PublicIPResolver`、公网查询服务地址、邀请码/重连阶段的查询调用，以及导航请求中的客户端 IP 参数传递和赋值。
- NoaChatCore 的本机网卡 IP 枚举、公网 IP 查询方法、公开声明及登录鉴权上报调用；闲置的 DNS 信息上报入口也已删除。
- Swift 系统配置服务、解密封装、配置模型与缓存、废弃 HTTP 可用性探测器、对应 Moya 目标与路径。
- NoaChatCore 系统配置请求的两层公开入口，及 HTTP/TCP 中该接口专用的签名、响应解密、失败处理分支。普通业务的租户签名与解密保持原逻辑。
- `AlicloudPDNS` 依赖和桥接头导入。其预编译库含有 `DNSGetLocalIP` / `getCurentLocalIP`，停止调用不足以清除二进制中的实现。
- `TBBasicLib` 依赖及随其引入的 Toast-Swift。反汇编定位到主程序里的 `TBBaseManage.deviceIP()` 调用 `getifaddrs`。App 实际只需颜色转换与 Safari 封装，现使用本地小组件，页面颜色值和链接打开方式保持一致。

## DNS1 替换（后续要求）

参考 `origin/feature-message-4` 的 `bc32709d536d4d1a3fbe8af166e1e96eba81e725`，迁入 DNS1 分片解析、来源推进、ECDH 探测、BIN 解密和缓存版本协议。未合入该分支的远程业务系统配置或公网 IP 查询代码。

- 首次连接：`t{邀请码小写}.{主域名}` 的 AAAA → 备用域名（配置非空时）→ 加密 BIN；同一来源内对业务 TCP 节点并发做 ECDH 探测，成功后建立正式连接。
- 当前与参考分支一致，主域名为 `facaifacai99.xyz`，备用域名为空，因此实际是主域名失败后转 BIN。BIN 路径保留邀请码原大小写。
- DNS1 改用直接签名 DoH 查询（阿里解析服务主备共用 5 秒预算），未重新引入 AlicloudPDNS。只携带查询域名、记录类型和鉴权参数，不携带本机地址。
- 删除原五源来源、并发协调实现、TXT/旧 AAAA 解码、A/UDP 地址归一化，以及其 Moya 目标、查询域名与鉴权常量。
- 删除五源耗尽后的旧导航域名、内置 OSS TCP 节点、旧 OSS HTTP 文件请求和旧导航协议请求/解密实现。所有来源失败后返回失败，重试仍使用 DNS1。
- DNS1 缓存使用独立命名空间，只从旧缓存迁移上次成功的邀请码，旧五源节点不会复用。缓存必须重新完成 ECDH 探测；跨企业缓存不可复用。
- 支持只有 TCP 的导航，显式清空旧企业的 HTTP Host；可选 HTTP 元数据保留原协议和路径。已探测标记仅在当前内存连接计划中使用，不写入缓存。

## 保留与兼容性

- 本地固定租户参数、登录密钥接口、密码登录、用户 AUTH、登录态恢复与重连退避保留。
- 网络质量检测实现保留，但 DNS1 不伪造旧导航的 `enableNetworkDetect` 开关，因此不会通过 DNS1 数据启用该后台检测；断线重连独立工作。
- Protobuf 的 `client_ip` / `loginIp` 声明和编号保留；App 与 SDK 不再赋值。旧导航请求构造器现已删除，SDK AUTH 的真实序列化检查确认客户端 IP 字段缺省。
- 服务器地址格式校验、服务器端 IP 封禁错误处理保留。

## 验证结果

| 检查 | 结果 |
| --- | --- |
| AccountLifecycle / Connection / Login / LoginConsent / Network / NetworkQuality / SessionRestore / Verification / DNS1 | 9 组全部通过 |
| DNS1 来源与载荷 | 43 项通过：分片乱序/重复/缺片、非法节点、BIN 解密、缓存失败、主域/备域/BIN 推进、取消及超时 |
| DNS1 DoH | 固定签名样本、备域签名、仅请求服务器 AAAA、记录过滤及错误响应检查通过 |
| DNS1 生产缓存与连接模型 | 20 项集成检查通过；使用真实 Protobuf、ObjectMapper 和缓存实现，隔离网络和 SDK 边界 |
| 缓存失败后刷新导航并恢复登录就绪 | 通过，仍使用本地租户参数，并检查先允许 DNS1 缓存、再强制刷新 |
| 实际 DNS1 / BIN 只读查询 | 使用参考分支测试邀请码：7 条 AAAA，解码出 4 个 TCP 节点；与 BIN 的 4 个 TCP 节点一致。DNS HTTP=0，BIN HTTP=4 |
| SDK AUTH Protobuf 字节 | 与独立字节样本一致，无客户端 IP 字段 |
| iOS Release 编译 | `BUILD SUCCEEDED`，关闭签名，仅本地验证，未上传 Sentry 符号 |
| Release 二进制扫描 | 检查已删除的 IP/配置代码、五源、旧导航实现及依赖残留，结果见 `dns1-binary-scan.log` |
| 工程与差异检查 | `plutil -lint`、`git diff --check` 通过 |

最初构建发现本地 Pods 与锁文件不同步，仍引用已不在当前分支中的 EncryptLib；重新安装当前锁定依赖后解决。最终依赖变化是删除上述两项库及 TBBasicLib 独有传递依赖，没有升级其余版本。

## 2026-10-26 后续裁剪：未接入的通话能力和配置请求

基于 `feature-IMSDK-2` / `2ebfd50` 实施。此节覆盖之前关于保留通话依赖的结论。

- 两个 target 均移除 LiveKit、ZegoExpressEngine；WebRTC、Promises、swift-log 随依赖图退出，其余 17 个 SPM pin 未升级。
- 删除引擎封装、22 个通话请求、SDK 转发和通话回调代理、通话铃声循环。`NoaIMSDKManager+CallRecords` 仅保留被动历史记录入库，不调用房间或媒体引擎。原消息协议与数据库字段保留兼容。
- 删除 8 个未使用配置请求：`/biz/system/getRoleConfig`、`/biz/user/getUserRoleAuthorityList`、`/biz/group/activity/config/get`、`/biz/signInRecord/signConfig`、`/biz/translate/channelConfig`、`/biz/userTranslate/all`、`/biz/userTranslate/uploadConfig`、`/auth/account/getLoginTypes`。路径、声明、HTTP/TCP 实现及 SDK 转发均删除。
- 翻译配置之前还会在 SDK 会话同步结束后自动拉取；两个调用点、同步方法、专用队列也已删除。联系人、群组、会话、消息收发与未读计数保持原流程。
- 认证相关的密钥、注册/登录、验证码、安全码、用户 AUTH 与服务端鉴权保留；本地固定账号策略和 DNS1 连接发现保留。角色功能配置列表不是登录 AUTH，删除该接口不绕过服务端权限校验。

本次验证：9 组现有离线回归及 AUTH Protobuf 字节检查通过；新增历史记录筛选检查 112 个事件组合通过。`pod install --no-repo-update` 后 Manifest 与 lock 一致，Pod 版本不变。全新目录无签名 Release 构建成功，产物 `/tmp/ddlNew-sdk-trim-release/Build/Products/Release-iphoneos/ddlNew.app`，构建日志 `/tmp/ddlNew-sdk-trim-release.log`；最终复核构建日志 `/tmp/ddlNew-sdk-trim-release-final.log` 也为 `BUILD SUCCEEDED`。Release 中 15 个 Mach-O 全量扫描未发现已移除通话依赖、信令请求或上述配置入口；扫描日志 `/tmp/ddlNew-sdk-trim-binary-scan.log`。构建没有上传 Sentry 符号。

## 二进制中仍有的必要网络能力

本次 Release 扫描只在 CocoaAsyncSocket 中发现 `_getifaddrs`；其用途是指定网络接口时选择 Socket 地址。LiveKit、WebRTC、Zego 已不在本次构建包内。不能向审核声明“整个安装包完全不存在 IP 相关代码”。

DNS1 仍通过远程 AAAA/BIN 获取连接服务器的 TCP/HTTP 节点，并做 ECDH 可用性探测；它不是客户端 IP 查询，也不解析页面开关或登录功能规则，但仍应向审核说明服务器发现用途。

本次检查证明特定废弃实现已从本地 Release 产物移除，不代替审核结论、网络抓包或服务端验证。未执行带真实账号的设备登录、断网恢复及消息收发；尚未核验服务端在所有场景下对缺省 IP 字段的处理。未生成已签名提交包，也未上传 App Store Connect。

## 复查方式

源码及二进制回归检查：

```sh
python3 Tests/AppReview/check-removal.py
python3 Tests/AppReview/check-removal.py /path/to/ddlNew.app
```

协议和 DNS1 检查：

```sh
bash Tests/AppReview/run-protocol-checks.sh
python3 Tests/AppReview/check-call-records.py
bash Tests/DNS1/run-checks.sh
bash Tests/DNS1/run-integration-checks.sh
# 可选的真实只读检查，需传测试邀请码：
bash Tests/DNS1/run-live-checks.sh TEST_INVITATION
```

前一轮 DNS1 编译、二进制与回归日志使用 `dns1-` 前缀；本次日志位于 `build/AppReviewCheck/verification/`；本地未签名产物位于 `build/AppReviewCheck/Build/Products/Release-iphoneos/ddlNew.app`。实际重新归档、导出 IPA 后应对该提交包再次扫描，并完成设备登录和重连验收。
