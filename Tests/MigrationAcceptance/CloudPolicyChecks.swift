// Created by taobo on 2026/10/13.
import Foundation

struct ChatContext {}
struct CloudPolicyRole {
    var allowed = false
    var configurationData: [String: String] = [:]
    /// 离线权限固定，只有生产checkPermission负责判断类型差异。
    func allows(_ key: String) -> Bool { allowed }
}
@MainActor final class UserRoleAuthorityStore { static let shared = UserRoleAuthorityStore(); var current: CloudPolicyRole? }

@main struct CloudPolicyChecks {
    @MainActor static var count = 0
    /// 原样提取生产URL/配额/目录逻辑，替代身份形状不连接云供应商。
    @MainActor static func main() throws {
        let policy = ProductionCloudPolicy()
        let (localUpload, localDownload) = try policy.configuredURLs(key: "chat/test/image/a.jpg")
        check(localUpload.absoluteString == "https://u260711-2.oss-accelerate.aliyuncs.com/chat/test/image/a.jpg" && localDownload == localUpload, "本地阿里路由使用实际桶与加速域名，忽略OBS备用值")
        let avatar = ChatAttachment(file: URL(fileURLWithPath: "/tmp/qa-avatar.jpg"), type: 101, name: "../匿名群头像.jpg", bytes: 1024)
        UserRoleAuthorityStore.shared.current = nil
        try policy.checkPermission(avatar)
        check(true, "CHAT-034 群头像101不依赖聊天发送配额")
        let avatarKey = policy.objectKey(avatar)
        check(avatarKey.hasPrefix("avatar_group/") && !avatarKey.contains("../") && !avatarKey.hasPrefix("chat/"), "CHAT-034 101目录沿旧avatar_group并净化文件名")
        let evidence = ChatAttachment(file: avatar.file, type: 102, name: "证据.jpg", bytes: 1024)
        try policy.checkPermission(evidence)
        check(policy.objectKey(evidence).hasPrefix("universal/"), "投诉证据使用通用目录且不依赖聊天发送权限")
        let empty = ChatAttachment(file: avatar.file, type: 101, name: avatar.name, bytes: 0)
        check(rejects { try policy.checkPermission(empty) }, "CHAT-034 空群头像不可绕过字节守卫")
        let chat = ChatAttachment(file: avatar.file, type: 1, name: "匿名照片.jpg", bytes: 1024)
        check(rejects { try policy.checkPermission(chat) }, "CHAT-012 普通照片无权限仍拒绝")
        UserRoleAuthorityStore.shared.current = CloudPolicyRole(allowed: true, configurationData: ["upImageVideoFile": String(Int64.max)])
        check(rejects { try policy.checkPermission(chat) }, "CHAT-012 角色MB配额溢出拒绝")
        for type in [1,2,4,5] {
            let item = ChatAttachment(file: avatar.file, type: type, name: "匿名文件.bin", bytes: 1024)
            let directory = [1:"/image/",2:"/shortvideo/",4:"/voice/mp3/",5:"/file/"][type]!
            check(policy.objectKey(item).hasPrefix("chat/") && policy.objectKey(item).contains(directory), "CHAT-012/013 聊天类型\(type)保持旧目录")
        }
        let upgraded = try policy.objectURL(endpoint: "http://storage.example.invalid:80", bucket: "qa-bucket", key: avatarKey, customDomain: false)
        check(upgraded.scheme == "https" && upgraded.port == nil && upgraded.host == "qa-bucket.storage.example.invalid", "CHAT-012 HTTP配置升级HTTPS并移除80端口")
        let custom = try policy.objectURL(endpoint: "https://images.example.invalid", bucket: "qa-bucket", key: avatarKey, customDomain: true)
        check(custom.host == "images.example.invalid", "CHAT-034 OBS自定义域名不追加桶前缀")
        let prefixed = try policy.objectURL(endpoint: "qa-bucket.storage.example.invalid", bucket: "qa-bucket", key: "chat/中文?#.jpg", customDomain: false)
        check(prefixed.scheme == "https" && prefixed.host == "qa-bucket.storage.example.invalid" && prefixed.query == nil && prefixed.fragment == nil, "CHAT-013 不重复桶前缀且中文文件名不变查询")
        check(rejects { _ = try policy.objectURL(endpoint: "https://user@storage.example.invalid", bucket: "qa-bucket", key: "a", customDomain: false) }, "CHAT-013 拒绝携带用户信息的节点")
        check(rejects { _ = try policy.objectURL(endpoint: "https://storage.example.invalid?x=1", bucket: "qa-bucket", key: "a", customDomain: false) }, "CHAT-013 拒绝混入查询的节点")
        print("Independent cloud policy: \(count)/\(count) passed")
    }
    /// 抛错才证明异常配置被拒绝。
    static func rejects(_ work: () throws -> Void) -> Bool { do { try work(); return false } catch { return true } }
    /// 输出场景结论，不打印云节点签名或临时凭据。
    @MainActor static func check(_ result: Bool, _ label: String) { guard result else { print("FAIL \(label)"); exit(1) }; count += 1; print("PASS \(label)") }
}
