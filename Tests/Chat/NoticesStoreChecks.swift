import Foundation

@MainActor final class NoticesClientFake: ChatNoticesClient {
    var rows = [ChatGroupNotice(id: "n1", content: "原公告", author: "作者", timestamp: "9", pinned: false)]
    var failLoad = false
    var failSave = false
    var saved: (String?, String, Bool, Bool, Bool)?
    var readIDs: [String] = []
    var loadedPages: [Int] = []
    var suspendDetail = false
    var pendingDetail: CheckedContinuation<ChatGroupNotice, Error>?
    /// 传输身份由生产Store控制。
    func open(_ context: ChatContext) {}
    /// 模拟服务器可用与回读失败。
    func load(page: Int) async throws -> [ChatGroupNotice] {
        loadedPages.append(page)
        if failLoad { throw ChatClientError.unavailable("读取失败") }; return rows
    }
    /// 记录真实Store传来的正文、置顶、删除和发送消息标志。
    func save(_ notice: ChatGroupNotice?, content: String, pinned: Bool, deleting: Bool, sendMessage: Bool) async throws {
        if failSave { throw ChatClientError.unavailable("保存失败") }
        saved = (notice?.id, content, pinned, deleting, sendMessage)
    }
    /// 详情返回服务器最新正文。
    func detail(_ notice: ChatGroupNotice) async throws -> ChatGroupNotice {
        if suspendDetail { return try await withCheckedThrowingContinuation { pendingDetail = $0 } }
        return rows.first { $0.id == notice.id } ?? notice
    }
    /// 记录真正显示详情后的已读请求。
    func read(_ notice: ChatGroupNotice) async throws { readIDs.append(notice.id) }
    /// 无外部运行资源。
    func close() {}
}

@main struct NoticesStoreChecks {
    /// 生产Store回归：保存确认与刷新成败分开，详情编辑读取当前内容。
    @MainActor static func main() async {
        let client = NoticesClientFake(); let store = ChatNoticesStore(client: client)
        let context = ChatContext(userUID: "owner", tenantID: "t", sessionID: UUID(), route: ChatRoute(id: "g", kind: .group, title: "群", avatarURL: ""))
        await store.open(context)
        let notice = store.notices[0]
        client.failSave = true
        let failed = await store.save(notice, content: "新公告", pinned: false)
        precondition(!failed && store.notices == [notice] && !store.busy, "保存拒绝必须保留原列表和编辑状态")
        client.failSave = false; client.failLoad = true
        let accepted = await store.save(notice, content: "新公告", pinned: false)
        precondition(accepted && store.notices == [notice] && store.errorMessage != nil && !store.busy, "已保存但回读失败不得清空公告或要求重发")
        client.failLoad = false
        client.rows = [ChatGroupNotice(id: "n1", content: "新公告", author: "作者", timestamp: "10", pinned: false)]
        await store.read(notice)
        precondition(store.detail?.content == "新公告" && store.notices.first?.content == "新公告", "详情成功同步列表，编辑不得取旧正文")
        precondition(client.readIDs == ["n1"], "成功展示最新详情后才上报已读")
        let saved = await store.save(notice, content: "再修改", pinned: true, sendMessage: true)
        precondition(saved && client.saved?.0 == "n1" && client.saved?.1 == "再修改" && client.saved?.2 == true && client.saved?.4 == true, "编辑稳定ID、正文和独立开关须传递")
        precondition(store.detail == nil && store.errorMessage == nil, "保存成功清理同公告旧详情和旧错误")
        client.suspendDetail = true
        let lateDetail = Task { await store.read(notice) }
        for _ in 0..<1000 { if client.pendingDetail != nil { break }; await Task.yield() }
        precondition(client.pendingDetail != nil, "等待旧详情请求实际挂起")
        _ = await store.save(notice, content: "最新版", pinned: false)
        client.pendingDetail?.resume(returning: notice); client.pendingDetail = nil
        await lateDetail.value
        precondition(store.detail == nil && client.readIDs == ["n1"], "保存前迟到详情不能恢复旧正文或上报旧版已读")
        client.suspendDetail = false
        client.rows = [ChatGroupNotice(id: "old", content: "旧", author: "", timestamp: "9", pinned: false), ChatGroupNotice(id: "new", content: "新", author: "", timestamp: "10", pinned: false), ChatGroupNotice(id: "top", content: "置顶", author: "", timestamp: "1", pinned: true)]
        await store.reload()
        precondition(store.notices.map(\.id) == ["top", "new", "old"], "真实置顶优先，毫秒时间按数字倒序")
        client.rows = (0..<20).map { ChatGroupNotice(id: "n\($0)", content: "公告", author: "", timestamp: "1", pinned: false) }
        await store.reload()
        client.failLoad = true; await store.loadMore()
        client.failLoad = false; client.rows = []; await store.loadMore()
        precondition(Array(client.loadedPages.suffix(2)) == [2, 2] && !store.hasMore, "分页失败保留页号，再试空页才停止")
        client.suspendDetail = true
        let expiredDetail = Task { await store.read(notice) }
        for _ in 0..<1000 { if client.pendingDetail != nil { break }; await Task.yield() }
        precondition(client.pendingDetail != nil, "等待会话关闭前的请求挂起")
        store.close()
        client.pendingDetail?.resume(returning: notice); client.pendingDetail = nil
        await expiredDetail.value
        precondition(store.notices.isEmpty && store.detail == nil, "会话关闭清理公告与详情")
        print("Notices store checks: 12 passed")
    }
}
