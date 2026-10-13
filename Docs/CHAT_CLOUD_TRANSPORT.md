# 聊天媒体存储接入说明

本轮保留旧端的五种供应商字段和对象目录，不新增云 SDK。临时 STS 经现有 SDK 请求和解密，仅保存在上传调用内存中；配置缓存只保存供应商、桶和路由。

## 合同与依据

- Minio：`/public-key/getKey`、`/file/upload`、`/file/multi/getId`、`/file/multi/upload`、`/file/multi/complete`；超过 100 MiB 使用 50 MiB 分片，来自 xgd `NoaFileUploadTask`。
- 阿里云：沿旧 SDK 的 OSS V1 鉴权，包含临时 Token 与合法子资源：[官方协议](https://www.alibabacloud.com/help/zh/oss/developer-reference/include-signatures-in-the-authorization-header)。
- AWS：S3 Signature V4，绑定真实文件 SHA256 与请求头：[官方协议及已知测试向量](https://docs.aws.amazon.com/AmazonS3/latest/developerguide/sig-v4-header-based-auth.html)。
- 腾讯云：COS SHA1 请求签名，查询参数名称小写规范化：[官方协议](https://cloud.tencent.com/document/product/436/7778)。
- 华为云：OBS Header 鉴权及 STS Token：[官方协议](https://support.huaweicloud.com/intl/en-us/api-obs/obs_04_0010.html)。
- 非 Minio 对象目录沿旧端 `chat/yyyyMMdd/image|shortvideo|voice/mp3|file/`。云端确认 HTTP 成功才生成资源 URI；消息最终状态仍等待真实聊天 ACK。
- 群头像使用独立 `avatar_group/`（Minio为`/zim/avatar_group/`），内部类型101只用于上传，不发送聊天消息；沿旧端`NoaGroupSetBasicInfoVC.m`的`isEncrypt:YES`进行默认媒体包装。群设置在上传前后检查实时群角色1/2，不套用聊天附件权限与配额。公用图片处理器在头像/媒体解析前解除旧包装，再执行缩图。
- 上传与下载兼容旧 XOR 包装和历史 AES v2 包装。较短文件保留原格式，避免 XOR 尾部包装键覆盖头部。AES 解码明确检查密文块长度及 PKCS7 尾部。

## 验证边界

`Tests/MediaTransport/run-checks.sh` 验证旧格式及公开虚构密钥的 AWS 完整签名向量；独立 `Tests/MigrationAcceptance/run-transport-checks.sh` 验证损坏输入、取消、期限、请求绑定、子资源及 STS 禁止序列化。

离线签名验证不证明部署桶的实际策略、地域配置或 STS 授权成功。非 Minio 当前采用流式单对象 PUT，超出供应商单对象 PUT 限制会明确失败；未实现四套云 SDK 的断点续传和跨进程恢复。必须使用专用账号和部署存储配置完成上传、另一端下载、失败重试及取消联调，才可标记对应服务验收通过。

云供应商配置中的 HTTP Origin 会升级为 HTTPS，并使用系统证书验证；80端口改为默认HTTPS端口。OBS自定义域名与各供应商节点必须实际支持HTTPS。Minio沿当前项目导航节点的独立证书策略。
