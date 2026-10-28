import Foundation

// 仅替换网络与SDK代理边界；启动、去重、完成、失败和stop均运行生产方法。
@MainActor final class StartupSDK {
    func removeMessageDelegate(_ delegate: NSObject) {}
    func removeGroupDelegate(_ delegate: NSObject) {}
    func removeUserDelegate(_ delegate: NSObject) {}
}
@MainActor final class StartupClient {
    var context: ChatContext?
    var generation = UUID(), groupRefreshRevision = UUID(), muteExpiryRevision = UUID()
    var groupPermissionTask: Task<Void, Never>?
    var groupPermissionRequest: UUID?
    var groupDetail: [String: Any]?, groupMute: [String: Any]?
    var muteExpiryTask: Task<Void, Never>?
    var muteExpiryState = ChatGroupMuteExpiryState()
    var waiting: [UUID: () -> Void] = [:]
    var delegate: NSObject?
    let sdk = StartupSDK()
    var eventHandler: ((ChatEvent) -> Void)?
    var requests: [CheckedContinuation<Void, Error>] = []
    func validate(_ value: ChatContext) throws { if context != value { throw ChatClientError.sessionExpired } }
    func refreshGroup(context: ChatContext) async throws {
        try await withCheckedThrowingContinuation { requests.append($0) }
    }
    func start(_ value: ChatContext) { context = value; startGroupPermissionRefresh(context: value) }
    // PRODUCTION_METHODS
}
@main struct GroupHistoryStartupChecks {
    @MainActor static func main() async {
        var count = 0
        func check(_ value: Bool, _ name: String) { count += 1; precondition(value, name) }
        let group = ChatContext(userUID: "me", tenantID: "test", sessionID: UUID(), route: ChatRoute(id: "g", kind: .group, title: "", avatarURL: ""))
        let single = ChatContext(userUID: "me", tenantID: "test", sessionID: UUID(), route: ChatRoute(id: "u", kind: .single, title: "", avatarURL: ""))
        let client = StartupClient()
        var events: [ChatEvent] = []
        client.eventHandler = { events.append($0) }
        client.start(single)
        check(client.groupPermissionTask == nil, "单聊不查询群权限")
        client.start(group); client.start(group)
        await wait { client.requests.count == 1 }
        check(client.requests.count == 1, "历史分页共享同一在途权限任务")
        let first = client.groupPermissionTask
        client.requests.removeFirst().resume()
        await first?.value
        check(events.count == 1 && client.groupPermissionTask == nil, "成功通知权限变更并释放任务")
        if case .permissionsChanged = events[0] {} else { fatalError("错误成功事件") }

        client.start(group); await wait { client.requests.count == 1 }
        let failed = client.groupPermissionTask
        client.requests.removeFirst().resume(throwing: ChatClientError.unavailable("群资料失败"))
        await failed?.value
        check(events.count == 2, "权限失败独立通知，不依赖历史请求失败")
        if case .permissionRefreshFailed = events[1] {} else { fatalError("错误失败事件") }

        client.start(group); await wait { client.requests.count == 1 }
        let old = client.groupPermissionTask
        let oldRequest = client.requests.removeFirst()
        client.stop()
        check(old?.isCancelled == true && client.groupPermissionTask == nil && client.context == nil, "离开聊天撤销权限任务")
        client.eventHandler = { events.append($0) }
        client.start(group); await wait { client.requests.count == 1 }
        let current = client.groupPermissionTask, currentID = client.groupPermissionRequest
        oldRequest.resume()
        await old?.value
        check(events.count == 2, "同群重进后旧成功不能发布权限")
        check(client.groupPermissionRequest == currentID && client.groupPermissionTask != nil, "旧完成不能清掉新权限任务")
        client.requests.removeFirst().resume(); await current?.value
        check(events.count == 3 && client.groupPermissionTask == nil, "只由新轮次完成自己的权限刷新")
        client.start(group); await wait { client.requests.count == 1 }
        let background = client.groupPermissionTask, backgroundRequest = client.requests.removeFirst()
        let explicit = Task { try await client.refreshPermissions(context: group) }
        await wait { client.requests.count == 1 }
        check(background?.isCancelled == true, "主动核权取消被取代的后台核权")
        client.requests.removeFirst().resume(); try! await explicit.value
        check(events.count == 4, "主动核权成功通知当前权限")
        backgroundRequest.resume(throwing: ChatClientError.unavailable("迟到失败")); await background?.value
        check(events.count == 4, "后台旧失败不能覆盖主动核权成功")
        client.stop()
        print("群历史独立权限启动：\(count)/\(count)通过")
    }
    @MainActor static func wait(_ ready: () -> Bool) async {
        for _ in 0..<1000 { if ready() { return }; await Task.yield() }
        fatalError("权限请求未进入可控等待")
    }
}
