import Foundation

@MainActor final class CallCoordinator {
    static let shared = CallCoordinator()
    var userUID: String?
    var sessionID: UUID?
    func activate(userUID: String, tenantID: String, sessionID: UUID) { self.userUID = userUID; self.sessionID = sessionID }
    func close() { userUID = nil; sessionID = nil }
}
@MainActor final class CallConfigurationStore {
    static let shared = CallConfigurationStore()
    var tenantID: String?
    func configure(tenantID: String) { self.tenantID = tenantID }
    var clearCount = 0
    func clear() { clearCount += 1 }
}

struct SDKGlobalSearchClient {}
@MainActor final class GlobalSearchStore {
    var userUID: String?
    /// 搜索客户端不在编排测试中访问数据库。
    init(client: SDKGlobalSearchClient) {}
    /// 根登录轮次建立搜索身份。
    func prepare(userUID: String) { self.userUID = userUID }
    /// 退出清除即使同UID重登也不能保留的结果身份。
    func reset() { userUID = nil }
}

@MainActor final class ContactsBusinessStore {
    static let shared = ContactsBusinessStore()
    var identity: String?
    var reloadCount = 0
    /// 记录AUTH前取得的业务身份。
    func prepare(userUID: String, license: String) { identity = userUID }
    /// 替身只记录读取次数，不访问业务服务器。
    func reload() async { reloadCount += 1 }
    /// 登出立即撤销业务身份。
    func reset() { identity = nil }
}
@MainActor final class GroupsStore {
    static let shared = GroupsStore()
    var identity: String?
    /// 记录根登录所有者绑定的用户。
    func prepare(userUID: String, license: String) { identity = userUID }
    /// 群缓存加载由单独的生产Store测试验证。
    func reload() async {}
    /// 登出撤销群操作身份。
    func reset() { identity = nil }
}
@MainActor final class ChatRuntime {
    static let shared = ChatRuntime()
    var userUID: String?
    var sessionID: UUID?
    /// 记录只有AUTH成功后才能取得的聊天资格。
    func activate(userUID: String, tenantID: String, sessionID: UUID) { self.userUID = userUID; self.sessionID = sessionID }
    /// 无论清凭据是否成功，都先撤销聊天资格。
    func close() { userUID = nil; sessionID = nil }
}
