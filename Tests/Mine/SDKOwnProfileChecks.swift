import Foundation

typealias LingIMSuccessCallback = (Any?, String?) -> Void
typealias LingIMFailureCallback = (Int, String?, String?) -> Void
enum ChatClientError: Error { case unavailable(String) }
@MainActor final class ChatRuntime {
    static let shared = ChatRuntime()
    var current: ChatContext?
    func isCurrent(_ context: ChatContext) -> Bool { current == context }
}
@MainActor final class OSSConnectionBootstrap {
    struct Plan { let lastLiceseId: String }
    static let shared = OSSConnectionBootstrap()
    var current: Plan? = Plan(lastLiceseId: "t")
}
@MainActor final class UserSessionStore {
    struct User { let userUID: String }
    static let shared = UserSessionStore()
    var currentUser: User? = User(userUID: "a")
    var fields: [String: Any] = [:]
    func updateProfile(_ values: [String: Any], userUID: String, lastLiceseId: String) throws { fields.merge(values) { _, new in new } }
}
@MainActor final class SDKChatMediaClient {
    static var attachment: ChatAttachment?
    func upload(_ attachment: ChatAttachment, context: ChatContext, progress: @escaping @MainActor (Double) -> Void) async throws -> ChatUploadedAttachment {
        Self.attachment = attachment
        return ChatUploadedAttachment(resource: "https://example.invalid/avatar/a.jpg", thumbnail: "")
    }
    func cancel() {}
}
@MainActor final class NoaIMSDKManager {
    static let shared = NoaIMSDKManager()
    static func sharedTool() -> NoaIMSDKManager { shared }
    var uid = "a"
    var ready = true
    var success: LingIMSuccessCallback?
    var failure: LingIMFailureCallback?
    var params: NSDictionary = [:]
    var endpoint = ""
    var nickname = ""
    func myUserID() -> String { uid }
    func isUserDatabaseReady() -> Bool { ready }
    func configNewUserNickName(_ name: String) { nickname = name }
    func userNicknameChange(with params: NSMutableDictionary, onSuccess: @escaping LingIMSuccessCallback, onFailure: @escaping LingIMFailureCallback) {
        self.params = params; endpoint = "nickname"; success = onSuccess; failure = onFailure
    }
    func userAvatarChange(with params: NSMutableDictionary, onSuccess: @escaping LingIMSuccessCallback, onFailure: @escaping LingIMFailureCallback) {
        self.params = params; endpoint = "avatar"; success = onSuccess; failure = onFailure
    }
}

@main struct SDKOwnProfileChecks {
    @MainActor static func main() async throws {
        var count = 0
        func check(_ value: Bool, _ title: String) { precondition(value, title); count += 1 }
        let ctx = ChatContext(userUID: "a", tenantID: "t", sessionID: UUID(), route: ChatRoute(id: "a", kind: .single, title: "", avatarURL: ""))
        ChatRuntime.shared.current = ctx
        let sdk = NoaIMSDKManager.shared
        let client = SDKOwnProfileClient()
        func start(_ change: OwnProfileChange) async -> Task<Bool, Never> {
            sdk.success = nil
            let task = Task { do { try await client.save(change, context: ctx); return true } catch { return false } }
            while sdk.success == nil { await Task.yield() }
            return task
        }
        let nickname = await start(.nickname("新昵称🙂"))
        check(sdk.endpoint == "nickname" && sdk.params["userUid"] as? String == "a" && sdk.params["nickname"] as? String == "新昵称🙂", "真实SDK昵称参数")
        check(UserSessionStore.shared.fields.isEmpty, "未受理不发布资料")
        sdk.success?(nil, nil)
        check(await nickname.value, "旧端空成功回执接受")
        try client.apply(.nickname("新昵称🙂"), context: ctx)
        check(UserSessionStore.shared.fields["nickname"] as? String == "新昵称🙂" && sdk.nickname == "新昵称🙂", "缓存和SDK昵称同步")
        let avatar = await start(.avatar("/zim/avatar/a.jpg"))
        check(sdk.endpoint == "avatar" && sdk.params["avatar"] as? String == "/zim/avatar/a.jpg", "真实SDK头像参数")
        sdk.success?(NSNumber(value: true), nil)
        check(await avatar.value, "头像受理")
        try client.apply(.avatar("/zim/avatar/a.jpg"), context: ctx)
        check(UserSessionStore.shared.fields["avatar"] as? String == "/zim/avatar/a.jpg", "头像持久化调用")
        for response: Any in [NSNumber(value: false), "false", "0"] {
            let rejected = await start(.nickname("拒绝"))
            sdk.success?(response, nil)
            check(!(await rejected.value), "明确否定回执拒绝")
        }
        let failed = await start(.nickname("失败")); sdk.failure?(500, "稍后重试", nil)
        check(!(await failed.value), "错误回执失败")
        let stale = await start(.nickname("旧认证"))
        ChatRuntime.shared.current = ChatContext(userUID: "a", tenantID: "t", sessionID: UUID(), route: ctx.route)
        sdk.success?(true, nil)
        check(!(await stale.value), "同UID重登拒绝旧回执")
        do { try client.apply(.nickname("错误"), context: ctx); preconditionFailure("旧身份不能写缓存") } catch { count += 1 }
        ChatRuntime.shared.current = ctx
        let canceled = await start(.nickname("已取消")); client.cancel(); sdk.success?(true, nil)
        check(!(await canceled.value), "取消后SDK迟到回执不成功")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        defer { try? FileManager.default.removeItem(at: file) }
        try Data(repeating: 1, count: 1024).write(to: file)
        let resource = try await client.upload(file, context: ctx)
        check(resource == "https://example.invalid/avatar/a.jpg" && SDKChatMediaClient.attachment?.type == 103, "复用上传器并选择个人头像类型")
        let large = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        defer { try? FileManager.default.removeItem(at: large) }
        try Data(repeating: 1, count: 50 * 1024 + 1).write(to: large)
        do { _ = try await client.upload(large, context: ctx); preconditionFailure("超大头像不可上传") } catch { count += 1 }
        print("个人资料生产SDK边界检查 \(count)/\(count) 通过")
    }
}
