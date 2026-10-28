import SwiftUI
import Combine

@MainActor final class PresentationClient: ChatClient {
    var cache: [ChatMessageRecord] = []
    var waiting: CheckedContinuation<ChatPage, Error>?
    var callback: ((ChatEvent) -> Void)?
    func cached(context: ChatContext, offset: Int) throws -> [ChatMessageRecord] { cache }
    func history(context: ChatContext, before: String?, offset: Int) async throws -> ChatPage {
        try await withCheckedThrowingContinuation { waiting = $0 }
    }
    func observe(context: ChatContext, onEvent: @escaping @MainActor (ChatEvent) -> Void) { callback = onEvent }
    func stop() {}
    func send(_ message: ChatMessageRecord, context: ChatContext) throws {}
    func permissions(context: ChatContext) throws -> ChatPermission { ChatPermission() }
    func read(_ messages: [ChatMessageRecord], context: ChatContext) async throws {}
    func perform(_ action: ChatMessageAction, message: ChatMessageRecord, context: ChatContext) async throws {}
    func finish(_ page: ChatPage) { let pending = waiting; waiting = nil; pending?.resume(returning: page) }
    func fail() { let pending = waiting; waiting = nil; pending?.resume(throwing: ChatClientError.unavailable("离线")) }
}
@MainActor final class PresentationProxy {
    var targets: [String] = []
    func scrollTo(_ id: String, anchor: UnitPoint) { targets.append(id) }
}
@main struct InitialHistoryPresentationChecks {
    @MainActor static func main() async {
        var failures = 0, checks = 0
        func check(_ condition: Bool, _ label: String) {
            checks += 1
            if !condition { failures += 1; print("FAIL: " + label) }
        }
        let route = ChatRoute(id: "peer", kind: .single, title: "测试", avatarURL: "")
        let context = ChatContext(userUID: "me", tenantID: "test", sessionID: UUID(), route: route)
        let bottom = CGRect(x: 0, y: 485, width: 358, height: 1)
        let outside = CGRect(x: 0, y: 1400, width: 358, height: 1)
        let client = PresentationClient(), proxy = PresentationProxy()
        let store = ChatStore(client: client), screen: PresentationScreen
        screen = PresentationScreen(store: store, route: route)
        client.cache = [message("latest", timestamp: 10)]
        let open = Task { await store.open(context) }
        await waitForRequest(client)
        let cacheLayout = screen.layout(bottom)
        screen.latestLayout = screen.layout(outside); screen.align(proxy)
        check(!screen.initialMessagesReady, "本机缓存未定位时仍隐藏，不能闪现顶部历史")
        screen.latestLayout = cacheLayout; screen.align(proxy)
        check(screen.initialMessagesReady, "缓存已完成底部布局时立即展示，不等待悬挂的网络历史请求")
        check(store.messages.count == 1, "本机缓存仍保留在真实Store，不删除离线数据")
        check(client.waiting != nil && screen.initialMessagesReady, "网络请求仍悬挂时已可阅读缓存")
        check(screen.visibleUpdates == 1, "缓存实际可见后允许可见已读和游戏播放")
        client.callback?(.upsert(message("live", timestamp: 12)))
        check(screen.initialMessagesReady, "首轮补拉中的实时消息不重新遮住已有正文")
        var publications = 0
        let subscription = store.$messages.dropFirst().sink { _ in publications += 1 }
        client.finish(ChatPage(messages: [message("older", timestamp: 1), message("latest", timestamp: 10)], hasMore: true))
        await open.value
        check(publications == 1, "历史整页只发布一次，不逐条刷新正文")
        subscription.cancel()
        let targetsBeforeLayout = proxy.targets.count
        screen.align(proxy)
        check(screen.initialMessagesReady && proxy.targets.count == targetsBeforeLayout, "后台补齐不隐藏正文，旧几何不能触发新批次滚动")
        screen.latestLayout = screen.layout(outside); screen.align(proxy)
        check(screen.initialMessagesReady && proxy.targets.last == "latest", "合并后的正文保持可见，并按新布局无动画定位")
        screen.latestLayout = screen.layout(bottom); screen.align(proxy)
        check(screen.initialMessagesReady && Set(store.messages.map(\.id)) == ["older", "latest", "live"], "最终布局完成后一次展示历史和在途实时消息")
        let more = Task { await store.loadMore() }
        await waitForRequest(client)
        check(screen.initialMessagesReady, "后续下拉分页不重新遮住正文")
        client.finish(ChatPage(messages: [message("oldest", timestamp: 0)], hasMore: false))
        await more.value
        screen.followsInitialLatest = false
        let targets = proxy.targets.count
        screen.latestLayout = screen.layout(outside); screen.align(proxy)
        check(screen.initialMessagesReady && proxy.targets.count == targets, "用户开始翻阅后继续保留阅读位置")
        store.close()
        check(!screen.initialMessagesReady, "关闭会话后撤销首屏就绪状态")

        // 同一末条ID、只补齐较早正文也必须等待新布局，不能仅按lastID放行。
        let sameClient = PresentationClient()
        let same = ChatStore(client: sameClient), sameProxy = PresentationProxy()
        let sameScreen = PresentationScreen(store: same, route: route)
        sameClient.cache = [message("latest", timestamp: 10)]
        let sameOpen = Task { await same.open(context) }
        await waitForRequest(sameClient)
        sameScreen.latestLayout = sameScreen.layout(bottom); sameScreen.align(sameProxy)
        sameClient.finish(ChatPage(messages: [message("older", timestamp: 1), message("latest", timestamp: 10)], hasMore: false))
        await sameOpen.value
        sameScreen.align(sameProxy)
        check(sameScreen.initialMessagesReady && sameScreen.alignedInitialHistoryRevision != same.initialHistoryRevision, "末条ID未变时仍保持可见，但旧几何不能冒充新布局")
        sameScreen.latestLayout = sameScreen.layout(bottom); sameScreen.align(sameProxy)
        check(sameScreen.initialMessagesReady, "同末条历史补齐后由最终布局放行")
        same.close()

        // 网络首轮和本机内容完全相同，不改变布局版本或重新遮住已展示的缓存。
        let unchangedClient = PresentationClient()
        unchangedClient.cache = [message("latest", timestamp: 10)]
        let unchanged = ChatStore(client: unchangedClient)
        let unchangedScreen = PresentationScreen(store: unchanged, route: route)
        let unchangedOpen = Task { await unchanged.open(context) }
        await waitForRequest(unchangedClient)
        unchangedScreen.latestLayout = unchangedScreen.layout(bottom); unchangedScreen.align(PresentationProxy())
        let revision = unchanged.initialHistoryRevision
        unchangedClient.finish(ChatPage(messages: unchangedClient.cache, hasMore: true))
        await unchangedOpen.value
        check(unchanged.initialHistoryRevision == revision && unchangedScreen.initialMessagesReady, "无内容变化的远端回包不遮挡缓存或重复定位")
        unchanged.close()

        let statusClient = PresentationClient()
        statusClient.cache = [message("known", timestamp: 10)]
        let statusStore = ChatStore(client: statusClient)
        let statusScreen = PresentationScreen(store: statusStore, route: route)
        let statusOpen = Task { await statusStore.open(context) }
        await waitForRequest(statusClient)
        statusScreen.latestLayout = statusScreen.layout(bottom); statusScreen.align(PresentationProxy())
        let statusRevision = statusStore.initialHistoryRevision
        var updated = message("known", timestamp: 10)
        updated.localID = "server-local-alias"; updated.readCount = 3; updated.isRead = true
        statusClient.finish(ChatPage(messages: [updated], hasMore: false)); await statusOpen.value
        check(statusStore.initialHistoryRevision == statusRevision && statusScreen.initialMessagesReady,
              "同服务端ID仅本机ID别名和已读变化，不触发新增历史定位")
        check(statusStore.messages.first?.readCount == 3 && statusStore.messages.first?.isRead == true,
              "不重定位仍更新已读数据，不能丢弃状态同步")
        statusClient.callback?(.permissionRefreshFailed("权限查询失败"))
        check(!statusStore.permission.canSend && !statusStore.permission.isChecking && statusStore.messages.count == 1,
              "独立权限失败保留历史并维持发送关闭")
        statusStore.close()

        // 用户已开始翻阅时，后台补齐不能重启首屏遮挡或强制滚动。
        let browsingClient = PresentationClient()
        browsingClient.cache = [message("latest", timestamp: 10)]
        let browsing = ChatStore(client: browsingClient)
        let browsingScreen = PresentationScreen(store: browsing, route: route), browsingProxy = PresentationProxy()
        let browsingOpen = Task { await browsing.open(context) }
        await waitForRequest(browsingClient)
        browsingScreen.latestLayout = browsingScreen.layout(bottom); browsingScreen.align(browsingProxy)
        browsingScreen.followsInitialLatest = false; browsing.isAtBottom = false
        browsingClient.finish(ChatPage(messages: [message("older", timestamp: 1)], hasMore: true))
        await browsingOpen.value
        browsingScreen.latestLayout = browsingScreen.layout(outside); browsingScreen.align(browsingProxy)
        check(browsingScreen.initialMessagesReady && browsingProxy.targets.isEmpty, "后台首轮补齐不打断用户已经开始的翻阅")
        browsing.close()

        let offlineClient = PresentationClient(), offlineProxy = PresentationProxy()
        let offline = ChatStore(client: offlineClient)
        let offlineScreen = PresentationScreen(store: offline, route: route)
        offlineClient.cache = [message("cache", timestamp: 1)]
        let offlineOpen = Task { await offline.open(context) }
        await waitForRequest(offlineClient); offlineClient.fail(); await offlineOpen.value
        offlineScreen.latestLayout = offlineScreen.layout(bottom); offlineScreen.align(offlineProxy)
        check(offlineScreen.initialMessagesReady && offline.messages.count == 1 && offline.errorMessage != nil, "网络失败后仍展示缓存并保留错误反馈")
        offline.close()
        offlineClient.cache = []
        let emptyOpen = Task { await offline.open(context) }
        await waitForRequest(offlineClient)
        check(!offlineScreen.initialMessagesReady, "没有可见缓存时等待首轮结果")
        offlineClient.finish(ChatPage(messages: [], hasMore: false)); await emptyOpen.value
        check(offlineScreen.initialMessagesReady, "真实空会话结束加载后不等待不存在的末条布局")
        offline.close()

        let oldOpen = Task { await offline.open(context) }
        await waitForRequest(offlineClient)
        let oldRequest = offlineClient.waiting; offlineClient.waiting = nil
        offline.close()
        let newOpen = Task { await offline.open(context) }
        await waitForRequest(offlineClient)
        oldRequest?.resume(returning: ChatPage(messages: [message("stale", timestamp: 2)], hasMore: false))
        await oldOpen.value
        check(!offlineScreen.initialMessagesReady && offline.messages.isEmpty, "同会话重新进入后旧请求不能放行新首屏或带回旧正文")
        offlineClient.finish(ChatPage(messages: [], hasMore: false)); await newOpen.value
        check(offlineScreen.initialMessagesReady, "新轮次自己的首轮完成才放行")
        offline.close()
        if failures > 0 { print("首屏历史展示：\(checks - failures)/\(checks)通过"); exit(1) }
        print("首屏历史展示：\(checks)/\(checks)通过")
    }
    @MainActor static func waitForRequest(_ client: PresentationClient) async {
        for _ in 0..<1000 { if client.waiting != nil { return }; await Task.yield() }
        fatalError("历史请求未进入可控等待")
    }
    static func message(_ id: String, timestamp: Int64) -> ChatMessageRecord {
        ChatMessageRecord(localID: id, serverID: id, conversationID: "peer", senderID: "other", senderName: "匿名", text: id, timestamp: timestamp, state: .sent)
    }
}
