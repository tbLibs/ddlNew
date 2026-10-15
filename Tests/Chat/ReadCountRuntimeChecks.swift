import Foundation
@main struct ReadCountRuntimeChecks {
    /// 使用生产ChatRuntime验证全AUTH观察入口、页面关闭重开及同UID旧AUTH隔离。
    @MainActor static func main() {
        let runtime = ChatRuntime.shared
        runtime.activate(userUID: "A", tenantID: "club", sessionID: UUID())
        let route = ChatRoute(id: "g", kind: .group, title: "群", avatarURL: "")
        let context = runtime.context(for: route)!
        let observer = SDKChatUnreadObserver.current!
        observer.emit(.counter(ChatReadCountSnapshot(id: "g", kind: .group, count: 1, latestID: "10")))
        let clearing = runtime.beginReadCountClear(context: context, count: 1, boundaryID: "10")!
        runtime.confirmReadCountClear(clearing, context: context, count: 0, latestID: "10")
        let message = ChatMessageRecord(localID: "m20", serverID: "20", conversationID: "g", senderID: "B", senderName: "B", timestamp: 2, state: .sent)
        observer.emit(.received(message, ChatReadCountSnapshot(id: "g", kind: .group, count: 1, latestID: "20")))
        runtime.savedVisibleRead("10", context: context)
        precondition(runtime.visibleReadCountPlan(context: context, count: 1, latestID: "20") == nil)
        runtime.savedVisibleRead("20", context: context)
        let closing = runtime.makeStore(); closing.context = context; closing.close()
        let reopened = runtime.makeStore(); reopened.context = runtime.context(for: route)
        let pending = runtime.visibleReadCountPlan(context: reopened.context!, count: 1, latestID: "20")!
        precondition(pending.ids == ["20"] && pending.remaining == 0, "生产Runtime跨页面保留待扣")
        runtime.commitVisibleReadCount(pending, context: context)
        precondition(runtime.visibleReadCountPlan(context: context, count: 0, latestID: "20") == nil)
        observer.emit(.received(message, ChatReadCountSnapshot(id: "g", kind: .group, count: 1, latestID: "20")))
        runtime.savedVisibleRead("20", context: context)
        precondition(runtime.visibleReadCountPlan(context: context, count: 1, latestID: "20") == nil, "旧身份重复receive不进入新epoch")
        runtime.activate(userUID: "A", tenantID: "club", sessionID: UUID())
        runtime.savedVisibleRead("20", context: context)
        runtime.commitVisibleReadCount(pending, context: context)
        runtime.confirmReadCountClear(clearing, context: context, count: 0, latestID: "20")
        precondition(runtime.visibleReadCountPlan(context: context, count: 1, latestID: "20") == nil)
        runtime.close()
        print("Read count runtime checks: 5 passed")
    }
}
