import Foundation
@MainActor final class StickerClientFake: ChatStickersClient {
    var rows: [ChatSticker] = []
    var suspended = false
    var waiting: CheckedContinuation<ChatStickerPage, Error>?
    /// 可暂停请求验证旧页迟到不能跨身份显示。
    func load(context: ChatContext, page: Int) async throws -> ChatStickerPage { if suspended { return try await withCheckedThrowingContinuation { waiting = $0 } }; return ChatStickerPage(stickers: rows, hasMore: true) }
    /// 取消不阻止假客户端旧回调，用来验证Store边界。
    func close() {}
}
@main struct StickerChecks {
    /// 验证生产贴纸Store稳定ID去重与离页身份隔离。
    @MainActor static func main() async {
        let client = StickerClientFake(); let store = ChatStickersStore(client: client)
        let context = ChatContext(userUID: "me", tenantID: "t", sessionID: UUID(), route: ChatRoute(id: "peer", kind: .single, title: "好友", avatarURL: ""))
        client.rows = [sticker("1"), sticker("1"), sticker("2")]
        await store.open(context); precondition(store.stickers.count == 2, "重复稳定ID只呈现一条")
        await store.loadMore(); precondition(store.stickers.count == 2, "页边界重复不制造副本")
        client.suspended = true; let request = Task { await store.loadMore() }; await Task.yield(); store.close()
        client.waiting?.resume(returning: ChatStickerPage(stickers: [sticker("late")], hasMore: false)); await request.value
        precondition(store.stickers.isEmpty && !store.busy && store.errorMessage == nil, "离页迟到资源和错误隔离")
        print("Sticker checks: 3 passed")
    }
    /// 表情来自客户端注入资源，不使用固定产品假消息。
    static func sticker(_ id: String) -> ChatSticker { ChatSticker(id: id, title: "贴纸", resource: "resource/" + id, thumbnail: "", width: 100, height: 100, bytes: 2000, fromPackage: true) }
}
