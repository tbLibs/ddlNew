import Foundation

@MainActor final class SDKSessionMaintenanceClient {
    static var pending: CheckedContinuation<String, Error>?
    func profile(userUID: String, onRejected: @escaping @MainActor (Int, String) -> Void) async throws -> String {
        try await withCheckedThrowingContinuation { Self.pending = $0 }
    }
    func roleAuthority(userUID: String, onRejected: @escaping @MainActor (Int, String) -> Void) async throws -> String { "{}" }
}
struct UserRoleAuthority { func allows(_ key: String) -> Bool { false } }
struct Mapper<T> { func map(JSONString: String) -> UserRoleAuthority? { UserRoleAuthority() } }
@MainActor final class UserRoleAuthorityStore {
    static let shared = UserRoleAuthorityStore()
    var current: UserRoleAuthority?
    var updates = 0
    func prepare(userUID: String, lastLiceseId: String) {}
    func reset() {}
    func update(_ value: UserRoleAuthority, userUID: String, lastLiceseId: String) { current = value; updates += 1 }
}
@MainActor final class LoginSessionService {
    static let shared = LoginSessionService()
    var maintenanceSessionID: UUID? = UUID()
    var conversations = Conversations()
    struct Conversations { func setFileAssistantVisible(_ value: Bool) {} }
    func handleMaintenanceRejection(code: Int, message: String, userUID: String, lastLiceseId: String, sessionID: UUID) {}
}
@MainActor final class IMUserAuthenticationService {
    static let shared = IMUserAuthenticationService()
    var isAuthenticated = true
}
@MainActor final class OSSConnectionBootstrap {
    static let shared = OSSConnectionBootstrap()
    struct Plan { let lastLiceseId = "t"; let apiHost = "example.invalid" }
    var current: Plan? = Plan()
}
@MainActor final class OSSNavigationStore {
    static let shared = OSSNavigationStore()
    struct Navigation { let lastLiceseId = "t"; let savedAt = 1 }
    func load() throws -> Navigation? { Navigation() }
}
@MainActor final class UserSessionStore {
    static let shared = UserSessionStore()
    struct User { let userUID = "a" }
    var currentUser: User? = User()
    var profileRevision = UUID()
    var nickname = "原昵称"
    var avatar = "old.jpg"
    func updateProfile(_ fields: [String: Any], userUID: String, lastLiceseId: String) throws {
        if let name = fields["nickname"] as? String { nickname = name }
        if let path = fields["avatar"] as? String { avatar = path }
        profileRevision = UUID()
    }
}
@MainActor final class LoginSecurityCoordinator {
    static let shared = LoginSecurityCoordinator()
    func refreshIfNeeded() {}
}

@main struct ProfileRefreshChecks {
    @MainActor static func main() async throws {
        let coordinator = SessionMaintenanceCoordinator.shared
        let session = UserSessionStore.shared
        coordinator.start(userUID: "a", lastLiceseId: "t")
        while SDKSessionMaintenanceClient.pending == nil { await Task.yield() }
        try session.updateProfile(["nickname": "新昵称", "avatar": "new.jpg"], userUID: "a", lastLiceseId: "t")
        SDKSessionMaintenanceClient.pending?.resume(returning: "{\"nickname\":\"旧昵称\",\"avatar\":\"old.jpg\"}")
        SDKSessionMaintenanceClient.pending = nil
        while UserRoleAuthorityStore.shared.updates == 0 { await Task.yield() }
        precondition(session.nickname == "新昵称" && session.avatar == "new.jpg", "先发起的维护读取不能覆盖已保存资料")
        coordinator.refreshNow()
        while SDKSessionMaintenanceClient.pending == nil { await Task.yield() }
        SDKSessionMaintenanceClient.pending?.resume(returning: "{\"nickname\":\"跨端新昵称\",\"avatar\":\"remote.jpg\"}")
        SDKSessionMaintenanceClient.pending = nil
        while UserRoleAuthorityStore.shared.updates < 2 { await Task.yield() }
        precondition(session.nickname == "跨端新昵称" && session.avatar == "remote.jpg", "后续正常维护仍接受资料更新")
        coordinator.refreshNow()
        while SDKSessionMaintenanceClient.pending == nil { await Task.yield() }
        coordinator.stop()
        SDKSessionMaintenanceClient.pending?.resume(returning: "{\"nickname\":\"退出后的旧资料\"}")
        SDKSessionMaintenanceClient.pending = nil
        // 给已恢复的生产任务一次调度机会；stop的generation守卫应同步失效。
        for _ in 0..<10 { await Task.yield() }
        precondition(session.nickname == "跨端新昵称", "退出后拒绝迟到维护回执")
        print("生产资料维护时序检查 3/3 通过")
    }
}
