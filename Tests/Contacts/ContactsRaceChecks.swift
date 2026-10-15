import Foundation
import Combine

@MainActor final class ContactsRaceClient: ContactBusinessClient {
    var change: (@MainActor () -> Void)?
    var heldOperation: ContactBusinessOperation?
    var continuation: CheckedContinuation<ContactBusinessResponse, Error>?
    var unreadWrites: [Int] = []
    var appReads = 0
    var response = ContactBusinessResponse()
    var handler: ((ContactBusinessOperation) -> ContactBusinessResponse)?
    /// 控制指定请求停顿，以复现真实代理与网络响应交错。
    func request(_ operation: ContactBusinessOperation, identity: ContactsIdentity) async throws -> ContactBusinessResponse {
        if case .applications = operation { appReads += 1 }
        if heldOperation == operation { heldOperation = nil; return try await withCheckedThrowingContinuation { continuation = $0 } }
        return handler?(operation) ?? response
    }
    /// 保留事件入口，测试中直接模拟SDK代理。
    func observe(_ onChange: @escaping @MainActor () -> Void) { change = onChange }
    /// 注入客户端无真实SDK资源。
    func reset() {}
    func updateUnreadCount(_ count: Int, identity: ContactsIdentity) { unreadWrites.append(count) }
}

@main struct ContactsRaceChecks {
    /// 每一轮选择单个复现场景，红绿流程不会被前一个断言遮住。
    @MainActor static func main() async throws {
        let scenario = CommandLine.arguments.dropFirst().first ?? "reload"
        let client = ContactsRaceClient(), prefs = UserDefaults(suiteName: "contacts.races.\(UUID())")!
        let store = ContactsBusinessStore(client: client, preferences: prefs)
        store.prepare(userUID: "self", license: "club")
        switch scenario {
        case "reload":
            client.heldOperation = .applications(page: 1)
            let load = Task { await store.reload() }
            while client.continuation == nil { await Task.yield() }
            client.change?()
            await Task.yield(); await Task.yield()
            client.continuation?.resume(returning: ContactBusinessResponse())
            await load.value
            assert(client.appReads == 2, "加载期间的SDK变化必须补读一次")
        case "pagination":
            client.response.hasMore = true
            await store.reload()
            client.heldOperation = .applications(page: 2)
            let load = Task { await store.loadMoreApplications() }
            while client.continuation == nil { await Task.yield() }
            client.change?()
            await Task.yield(); await Task.yield()
            client.continuation?.resume(returning: ContactBusinessResponse())
            await load.value
            assert(client.appReads == 3, "分页期间的SDK变化必须重读首页")
        case "unread":
            let incoming = FriendApplicationRecord(id: "h-1", hashKey: "h", sendTime: "1", fromUID: "peer", targetUID: "self", fromNickname: "对方", targetNickname: "自己", status: 0)
            client.response.applications = [incoming]
            client.heldOperation = .unreadApplications
            let load = Task { await store.reload() }
            while client.continuation == nil { await Task.yield() }
            store.markVisible(incoming)
            client.continuation?.resume(returning: ContactBusinessResponse(unreadVersions: ["h": "v1"]))
            await load.value
            assert(store.unreadCount == 0, "先看见再拿到首次版本不得复活未读")
            client.response.unreadVersions = ["h": "v2"]
            await store.reload()
            assert(store.unreadCount == 1, "后来改变的版本仍须显示未读")
        case "startupBadge":
            let historical = FriendApplicationRecord(id: "old-1", hashKey: "old", sendTime: "1", fromUID: "peer", targetUID: "self", fromNickname: "对方", targetNickname: "自己", status: 1)
            client.response.applications = [historical]
            client.heldOperation = .unreadApplications
            var published: [Int] = []
            let observation = store.$unreadCount.sink { published.append($0) }
            let loading = Task { await store.reload() }
            while client.continuation == nil { await Task.yield() }
            print("未读接口尚未返回时的角标发布：\(published)，SDK写入：\(client.unreadWrites)")
            precondition(store.unreadCount == 0 && !published.contains(where: { $0 > 0 }), "历史申请不能在真实未读结果之前闪出红色角标")
            precondition(client.unreadWrites.isEmpty, "未确认的历史申请数量不能提前写入SDK未读数")
            client.continuation?.resume(returning: ContactBusinessResponse(unreadVersions: [:]))
            client.continuation = nil
            await loading.value
            precondition(store.unreadCount == 0 && !published.contains(where: { $0 > 0 }), "真实未读为零时整段启动过程不闪角标")
            client.response.unreadVersions = ["real-new": "v1"]
            await store.reload()
            precondition(store.unreadCount == 1 && client.unreadWrites.last == 1, "真实未读确认后正常发布角标与SDK计数")
            client.heldOperation = .unreadApplications
            let refreshing = Task { await store.reload() }
            while client.continuation == nil { await Task.yield() }
            client.continuation?.resume(throwing: URLError(.notConnectedToInternet)); client.continuation = nil
            await refreshing.value
            precondition(store.unreadCount == 1, "刷新临时失败保留同AUTH已确认未读，不按申请列表重算")
            store.prepare(userUID: "other", license: "club")
            client.unreadWrites = []; published = []
            client.heldOperation = .unreadApplications
            let firstFailed = Task { await store.reload() }
            while client.continuation == nil { await Task.yield() }
            client.continuation?.resume(throwing: URLError(.notConnectedToInternet)); client.continuation = nil
            await firstFailed.value
            precondition(store.unreadCount == 0 && !published.contains(where: { $0 > 0 }) && client.unreadWrites.isEmpty, "新账号首次未读读取失败不复用旧计数或猜测申请未读")
            client.response.unreadVersions = ["actual": "v1"]
            await store.reload()
            precondition(store.unreadCount == 1, "首次读取失败后重试仍能展示真实未读")
            observation.cancel()
        case "friend":
            client.response.profile = ContactRecord(id: "peer", nickname: "陌生人")
            _ = await store.loadProfile("peer")
            assert(!store.friendIDs.contains("peer"))
            store.reconcileContacts([ContactRecord(id: "peer", nickname: "新好友")])
            assert(store.friendIDs.contains("peer"), "真实新增好友必须立即更新已打开资料的关系")
            assert(store.profiles["peer"]?.nickname == "新好友")
        case "search":
            client.heldOperation = .search("first")
            let first = Task { await store.search("first") }
            while client.continuation == nil { await Task.yield() }
            let old = client.continuation
            client.continuation = nil; client.heldOperation = .search("second")
            let second = Task { await store.search("second") }
            while client.continuation == nil { await Task.yield() }
            assert(store.isSearching && store.searchResults.isEmpty)
            old?.resume(returning: ContactBusinessResponse(contacts: [ContactRecord(id: "old")]))
            await first.value
            assert(store.isSearching && store.searchResults.isEmpty, "旧响应不能关闭新请求等待")
            client.continuation?.resume(returning: ContactBusinessResponse(contacts: [ContactRecord(id: "new")]))
            await second.value
            assert(!store.isSearching && store.searchResults.map(\.id) == ["new"])
            await store.search("")
            assert(!store.isSearching && store.searchResults.isEmpty && store.errorMessage == nil)
        case "groupNickname":
            client.handler = { operation in
                switch operation {
                case .groupAccess: return ContactBusinessResponse(canAccessProfile: true)
                case .profile: return ContactBusinessResponse(profile: ContactRecord(id: "peer", nickname: "通用昵称"))
                case .groupNickname(let groupID, _): return ContactBusinessResponse(groupNickname: groupID == "one" ? "群一昵称" : "群二昵称")
                default: return ContactBusinessResponse()
                }
            }
            _ = await store.loadProfile("peer", sourceGroupID: "one")
            _ = await store.loadProfile("peer", sourceGroupID: "two")
            assert(store.groupNickname(in: "one", for: "peer") == "群一昵称")
            assert(store.groupNickname(in: "two", for: "peer") == "群二昵称")
            assert(store.profiles["peer"]?.nickname == "通用昵称", "群昵称不能污染全局昵称")
            store.prepare(userUID: "other", license: "club")
            assert(store.groupNickname(in: "one", for: "peer") == nil)
        default: fatalError("未知场景")
        }
        print("PASS Contacts race \(scenario)")
    }
}
