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

## 二进制中仍有的必要网络能力

扫描仍在 CocoaAsyncSocket、LiveKit、WebRTC、ZegoExpressEngine 四个通信 framework 中发现 `_getifaddrs`。

已核对开源实现：CocoaAsyncSocket 用于指定接口的 Socket 地址选择，LiveKit 用于监听网络接口/地址变化。WebRTC、Zego 的预编译实现本次只确认符号存在，未完成内部所有调用与数据用途的核查。不能据此向审核声明“整个安装包完全不存在 IP 相关代码”。这些依赖仍为现有通信功能保留；必要时向供应商获取用途说明，或另行评估替换。

本次检查证明特定废弃实现已从本地 Release 产物移除，不代替审核结论、网络抓包或服务端验证。未执行带真实账号的设备登录、断网恢复及音视频通话；尚未核验服务端在所有场景下对缺省 IP 字段的处理。未生成已签名提交包，也未上传 App Store Connect。

## 复查方式

源码及二进制回归检查：

```sh
python3 Tests/AppReview/check-removal.py
python3 Tests/AppReview/check-removal.py /path/to/ddlNew.app
```

协议和 DNS1 检查：

```sh
bash Tests/AppReview/run-protocol-checks.sh
bash Tests/DNS1/run-checks.sh
bash Tests/DNS1/run-integration-checks.sh
# 可选的真实只读检查，需传测试邀请码：
bash Tests/DNS1/run-live-checks.sh TEST_INVITATION
```

DNS1 最终编译、二进制与回归日志使用 `dns1-` 前缀；本次日志位于 `build/AppReviewCheck/verification/`；本地未签名产物位于 `build/AppReviewCheck/Build/Products/Release-iphoneos/ddlNew.app`。实际重新归档、导出 IPA 后应对该提交包再次扫描，并完成设备登录和重连验收。
