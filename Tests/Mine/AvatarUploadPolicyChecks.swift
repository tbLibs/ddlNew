import Foundation
struct ChatContext {}
enum ChatClientError: Error { case unavailable(String), permission(String) }
struct Role { let configurationData: [String: String] = [:]; func allows(_ key: String) -> Bool { false } }
@MainActor final class UserRoleAuthorityStore { static let shared = UserRoleAuthorityStore(); let current: Role? = nil }
@main struct AvatarUploadPolicyChecks {
    @MainActor static func main() throws {
        let policy = Policy()
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data([1,2,3]).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        precondition(policy.bucketName(type: 103) == "/zim/avatar/", "Minio个人头像目录")
        precondition(policy.bucketName(type: 101) == "/zim/avatar_group/", "群头像目录保持")
        try policy.checkPermission(ChatAttachment(file: file, type: 103, name: "avatar.jpg", bytes: 50 * 1024))
        for size: Int64 in [0, -1, 50 * 1024 + 1] {
            do { try policy.checkPermission(ChatAttachment(file: file, type: 103, name: "avatar.jpg", bytes: size)); preconditionFailure("非法字节不可上传") } catch {}
        }
        try FileManager.default.removeItem(at: file)
        do { try policy.checkPermission(ChatAttachment(file: file, type: 103, name: "avatar.jpg", bytes: 1024)); preconditionFailure("缺失文件不可上传") } catch {}
        print("生产Minio头像目录及配额检查 7/7 通过")
    }
}
