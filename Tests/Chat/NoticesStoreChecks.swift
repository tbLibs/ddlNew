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
    var suspendLoad = false
    var pendingLoad: CheckedContinuation<[ChatGroupNotice], Error>?
    var role = 2
    var failRole = false
    var suspendRole = false
    var pendingRole: CheckedContinuation<Int, Error>?
    var suspendSave = false
    var pendingSave: CheckedContinuation<Void, Error>?
    var detailRows: [String: ChatGroupNotice] = [:]
    var failDetail = false
    var replacementRowsOnSave: [ChatGroupNotice]?
    /// 传输身份由生产Store控制。
    func open(_ context: ChatContext) {}
    /// 模拟服务器可用与回读失败。
    func load(page: Int) async throws -> [ChatGroupNotice] {
        loadedPages.append(page)
        if suspendLoad { return try await withCheckedThrowingContinuation { pendingLoad = $0 } }
        if failLoad { throw ChatClientError.unavailable("读取失败") }; return rows
    }
    /// 群信息与列表使用独立传输结果，复验管理入口不依赖其它群设置请求。
    func managementRole() async throws -> Int {
        if suspendRole { return try await withCheckedThrowingContinuation { pendingRole = $0 } }
        if failRole { throw ChatClientError.unavailable("群信息读取失败") }
        return role
    }
    /// 记录真实Store传来的正文、置顶、删除和发送消息标志。
    func save(_ notice: ChatGroupNotice?, content: String, pinned: Bool, deleting: Bool, sendMessage: Bool) async throws {
        if failSave { throw ChatClientError.unavailable("保存失败") }
        if suspendSave { try await withCheckedThrowingContinuation { pendingSave = $0 } }
        saved = (notice?.id, content, pinned, deleting, sendMessage)
        if let replacementRowsOnSave { rows = replacementRowsOnSave }
    }
    /// 详情返回服务器最新正文。
    func detail(_ notice: ChatGroupNotice) async throws -> ChatGroupNotice {
        if failDetail { throw ChatClientError.unavailable("详情读取失败") }
        if suspendDetail { return try await withCheckedThrowingContinuation { pendingDetail = $0 } }
        return detailRows[notice.id] ?? rows.first { $0.id == notice.id } ?? notice
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
        precondition(store.managementRole == 2, "群信息提供真实群主角色")
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
        precondition(store.detail?.content == "再修改" && store.detail?.pinned == true && store.errorMessage == nil, "保存成功保留已确认完整正文和开关，不退回列表摘要")
        client.suspendDetail = true
        let lateDetail = Task { await store.read(notice) }
        for _ in 0..<1000 { if client.pendingDetail != nil { break }; await Task.yield() }
        precondition(client.pendingDetail != nil, "等待旧详情请求实际挂起")
        _ = await store.save(notice, content: "最新版", pinned: false)
        client.pendingDetail?.resume(returning: notice); client.pendingDetail = nil
        await lateDetail.value
        precondition(store.detail?.content == "最新版" && client.readIDs == ["n1"], "保存前迟到详情不能恢复旧正文或上报旧版已读")
        client.suspendDetail = false
        client.rows = [ChatGroupNotice(id: "old", content: "旧", author: "", timestamp: "9", pinned: false), ChatGroupNotice(id: "new", content: "新", author: "", timestamp: "10", pinned: false), ChatGroupNotice(id: "top", content: "置顶", author: "", timestamp: "1", pinned: true)]
        await store.reload()
        precondition(store.notices.map(\.id) == ["top", "new", "old"], "真实置顶优先，毫秒时间按数字倒序")
        client.rows = (0..<20).map { ChatGroupNotice(id: "n\($0)", content: "公告", author: "", timestamp: "1", pinned: false) }
        await store.reload()
        client.failLoad = true; await store.loadMore()
        client.failLoad = false; client.rows = []; await store.loadMore()
        precondition(Array(client.loadedPages.suffix(2)) == [2, 2] && !store.hasMore, "分页失败保留页号，再试空页才停止")
        client.rows = [notice]; await store.reload()
        var acceptedCallbacks = 0
        client.failSave = true
        let failedDelete = await store.save(notice, content: notice.content, pinned: notice.pinned, deleting: true, onAccepted: { acceptedCallbacks += 1 })
        precondition(!failedDelete && store.notices == [notice] && store.deletedNoticeID == nil && acceptedCallbacks == 0, "删除拒绝不发返回事件和导航回调，详情和编辑页应保留")
        client.failSave = false
        client.suspendLoad = true
        let deleting = Task { await store.save(notice, content: notice.content, pinned: notice.pinned, deleting: true, onAccepted: { acceptedCallbacks += 1 }) }
        for _ in 0..<1000 { if client.pendingLoad != nil { break }; await Task.yield() }
        precondition(client.pendingLoad != nil, "等待删除后的列表回读实际挂起")
        precondition(store.notices.isEmpty, "服务器删除受理后必须立即移除公告，不等列表回读才能返回")
        precondition(store.deletedNoticeID == notice.id && store.busy && acceptedCallbacks == 1, "删除确认在回读完成前直接调用可见页面的返回completion")
        client.pendingLoad?.resume(throwing: ChatClientError.unavailable("刷新失败")); client.pendingLoad = nil
        let deleted = await deleting.value
        precondition(deleted && store.notices.isEmpty && store.errorMessage?.contains("已删除") == true, "删除后回读失败不能恢复已删除公告或伪报删除失败")
        client.suspendLoad = false
        await store.reload()
        precondition(store.notices.isEmpty, "服务器迟到旧首屏不能恢复已确认删除公告")
        store.close(); await store.open(context)
        precondition(store.deletedNoticeID == nil && store.notices == [notice], "新会话清理删除事件和本轮删除过滤")
        client.failRole = true; await store.refreshRole()
        precondition(store.managementRole == 0 && store.notices == [notice], "角色读取失败隐藏写入口并保留可读公告")
        client.failRole = false; client.suspendRole = true
        let oldRole = Task { await store.refreshRole() }
        for _ in 0..<1000 { if client.pendingRole != nil { break }; await Task.yield() }
        precondition(client.pendingRole != nil, "等待旧角色请求实际挂起")
        client.suspendRole = false; client.role = 0; await store.refreshRole()
        client.pendingRole?.resume(returning: 2); client.pendingRole = nil
        await oldRole.value
        precondition(store.managementRole == 0, "旧群主角色回执不能覆盖更新的降权回执")
        client.suspendRole = true
        let closedRole = Task { await store.refreshRole() }
        for _ in 0..<1000 { if client.pendingRole != nil { break }; await Task.yield() }
        precondition(client.pendingRole != nil, "等待关闭前角色请求挂起")
        store.close(); client.pendingRole?.resume(returning: 2); client.pendingRole = nil
        await closedRole.value
        precondition(store.managementRole == 0, "旧会话角色回执不得恢复管理入口")
        client.suspendRole = false; await store.open(context)
        let preview = ChatGroupNotice(id: "n1", content: "完整第一行🙂\n...", author: "作者", timestamp: "9", pinned: false)
        let full = ChatGroupNotice(id: "n1", content: "完整第一行🙂\n必须保留第二行以及字面...", author: "作者", timestamp: "9", pinned: false)
        client.rows = [preview]; client.detailRows = [full.id: full]
        await store.reload(); await store.read(preview)
        precondition(store.detail?.content == full.content, "详情接口完整正文独立于带省略号的列表摘要")
        let editable = await store.prepareEdit(preview)
        precondition(editable?.content == full.content, "列表长按编辑也读取完整详情而非摘要")
        let toggleOnly = await store.save(editable, content: full.content, pinned: true)
        precondition(toggleOnly && client.saved?.1 == full.content && store.notices.first?.content == preview.content && store.detail?.content == full.content && store.detail?.pinned == true, "只改开关保存后，列表摘要不能覆盖完整详情和已确认开关")
        client.failDetail = true
        let failedEditor = await store.prepareEdit(preview)
        precondition(failedEditor == nil && store.detail?.content == full.content, "完整详情读取失败不开放摘要编辑，并保留已读完整正文")
        client.failDetail = false; client.failLoad = true
        let refreshedFailure = await store.save(full, content: full.content + "\n新增末行", pinned: false)
        precondition(refreshedFailure && store.detail?.content == full.content + "\n新增末行" && store.errorMessage != nil, "保存受理后即使列表回读失败仍回列表并提供失败重读提示，完整正文保留")
        client.failLoad = false; client.failSave = true
        let rejectedEdit = await store.save(full, content: "未确认草稿", pinned: true)
        precondition(!rejectedEdit && store.detail?.content == full.content + "\n新增末行", "保存失败不替换已确认完整详情，编辑草稿由页面保留")
        client.failSave = false; client.suspendDetail = true
        let oldEditor = Task { await store.prepareEdit(preview) }
        for _ in 0..<1000 { if client.pendingDetail != nil { break }; await Task.yield() }
        precondition(client.pendingDetail != nil, "等待编辑完整正文请求挂起")
        store.close(); await store.open(context)
        client.pendingDetail?.resume(returning: full); client.pendingDetail = nil
        let staleEditor = await oldEditor.value
        precondition(staleEditor == nil && store.detail == nil, "旧会话编辑详情回执不能打开新会话编辑器")
        client.suspendDetail = false
        client.suspendSave = true
        let oldDeletion = Task { await store.save(notice, content: notice.content, pinned: notice.pinned, deleting: true, onAccepted: { acceptedCallbacks += 1 }) }
        for _ in 0..<1000 { if client.pendingSave != nil { break }; await Task.yield() }
        precondition(client.pendingSave != nil, "等待旧会话删除请求挂起")
        store.close(); client.pendingSave?.resume(returning: ()); client.pendingSave = nil
        let staleDeleted = await oldDeletion.value
        precondition(!staleDeleted && store.deletedNoticeID == nil && store.notices.isEmpty && acceptedCallbacks == 1, "旧会话删除回执不能发返回completion误关新会话详情")
        client.suspendDetail = true
        let expiredDetail = Task { await store.read(notice) }
        for _ in 0..<1000 { if client.pendingDetail != nil { break }; await Task.yield() }
        precondition(client.pendingDetail != nil, "等待会话关闭前的请求挂起")
        store.close()
        client.pendingDetail?.resume(returning: notice); client.pendingDetail = nil
        await expiredDetail.value
        precondition(store.notices.isEmpty && store.detail == nil, "会话关闭清理公告与详情")
        // 真机已确认编辑受理后生成新版ID；页面应回列表，再按真实新版ID读完整详情，不猜身份映射。
        let versions = NoticesClientFake(); let versionStore = ChatNoticesStore(client: versions)
        let old = ChatGroupNotice(id: "v1", content: "第一行\n完整第二行", author: "作者", timestamp: "10", pinned: false)
        let newPreview = ChatGroupNotice(id: "v2", content: "第一行\n...", author: "作者", timestamp: "11", pinned: true)
        let newFull = ChatGroupNotice(id: "v2", content: old.content, author: "作者", timestamp: "11", pinned: true)
        versions.rows = [old]; versions.detailRows = [old.id: old, newFull.id: newFull]
        await versionStore.open(context); await versionStore.read(old)
        versions.replacementRowsOnSave = [newPreview]
        let versionSaved = await versionStore.save(old, content: old.content, pinned: true)
        precondition(versionSaved && versions.saved?.0 == "v1" && versions.saved?.1 == old.content, "只改开关仍提交所编辑版本的完整原文")
        precondition(versionStore.notices.map(\.id) == ["v2"] && versionStore.detail?.content == old.content, "回列表采用服务端新版ID，旧详情等待关闭期间保持完整正文")
        let newEditable = await versionStore.prepareEdit(versionStore.notices[0])
        precondition(newEditable?.id == "v2" && newEditable?.content == old.content, "从新列表再编辑须按新版ID取完整详情，不复用旧身份或摘要")
        print("Notices store checks: 38 passed")
    }
}
