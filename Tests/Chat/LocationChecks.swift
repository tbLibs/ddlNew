//
//  LocationChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//

import Foundation

@MainActor final class LocationClient: ChatClient {
    var callback: ((ChatEvent) -> Void)?
    var page = ChatPage(messages: [], hasMore: false)
    var waiting: CheckedContinuation<ChatPage, Error>?
    var suspended = false
    var localRecords: [ChatMessageRecord]?
    func history(context: ChatContext, before: String?, offset: Int) async throws -> ChatPage {
        if suspended { return try await withCheckedThrowingContinuation { waiting = $0 } }
        return page
    }
    func cached(context: ChatContext, offset: Int) throws -> [ChatMessageRecord] {
        guard let localRecords else { return page.messages }
        return Array(localRecords.dropFirst(offset).prefix(100))
    }
    func observe(context: ChatContext, onEvent: @escaping @MainActor (ChatEvent) -> Void) { callback = onEvent }
    func stop() {}
    func send(_ message: ChatMessageRecord, context: ChatContext) throws {}
    func permissions(context: ChatContext) throws -> ChatPermission { ChatPermission() }
    func read(_ messages: [ChatMessageRecord], context: ChatContext) async throws {}
    func perform(_ action: ChatMessageAction, message: ChatMessageRecord, context: ChatContext) async throws {}
}

@main struct LocationChecks {
    @MainActor static func main() async {
        var failures = 0
        func check(_ condition: Bool, _ name: String) { if !condition { failures += 1; print("FAIL: " + name) } }
        let client = LocationClient()
        let chat = ChatStore(client: client)
        let context = ChatContext(userUID: "self", tenantID: "club", sessionID: UUID(), route: ChatRoute(id: "peer", kind: .single, title: "好友", avatarURL: ""))
        let recent = message("recent", server: "s2", time: 200)
        let old = message("old", server: "s1", time: 100)
        client.page = ChatPage(messages: [recent], hasMore: true)
        await chat.open(context)
        await chat.locate("s2")
        let first = chat.observedLocation
        await chat.locate("s2")
        check(chat.observedLocation != first, "重复点击同一置顶消息仍产生新的页面定位事件")
        check(chat.locatedMessageID == "recent" && !chat.isAtBottom, "命中已加载消息后退出末尾跟随")
        client.suspended = true
        let locating = Task { await chat.locate("s1") }
        while client.waiting == nil { await Task.yield() }
        check(!chat.isAtBottom, "补页开始前停止末尾跟随")
        client.waiting?.resume(returning: ChatPage(messages: [old], hasMore: false)); client.waiting = nil
        await locating.value
        check(chat.locatedMessageID == "old", "置顶服务器ID可补页映射到实际本地行ID")
        await chat.locate("missing")
        check(chat.errorMessage != nil, "不存在的置顶消息仍提示失败")
        await chat.locate("s1")
        check(chat.errorMessage == nil, "再次成功定位清除旧失败反馈")
        client.suspended = false; chat.close(); await chat.open(context)
        client.suspended = true
        let late = Task { await chat.locate("s1") }
        while client.waiting == nil { await Task.yield() }
        chat.close()
        client.waiting?.resume(returning: ChatPage(messages: [old], hasMore: false)); client.waiting = nil
        await late.value
        check(chat.locatedMessageID == nil && chat.messages.isEmpty, "关闭会话后迟到补页不能定位旧消息")
        client.suspended = false
        let recentPage = (0..<100).map { message("new-\($0)", server: "new-s-\($0)", time: Int64(200 + $0)) }
        client.localRecords = recentPage + [old]
        client.page = ChatPage(messages: recentPage, hasMore: false)
        await chat.open(context)
        await chat.locate("s1")
        check(chat.locatedMessageID == "old" && chat.messages.count == 101, "沿旧端从SDK本地历史补齐较早置顶，不受远程hasMore限制")
        chat.close()
        client.localRecords = nil
        client.page = ChatPage(messages: [recent], hasMore: true)
        await chat.open(context)
        client.suspended = true
        let paging = Task { await chat.loadMore() }
        while client.waiting == nil { await Task.yield() }
        let duringPaging = Task { await chat.locate("s1") }
        await Task.yield()
        client.waiting?.resume(returning: ChatPage(messages: [old], hasMore: false)); client.waiting = nil
        await paging.value; await duringPaging.value
        check(chat.locatedMessageID == "old" && chat.errorMessage == nil, "用户在历史请求进行中点击置顶，应等待现有补页再定位")
        chat.close()
        client.suspended = false
        var recalled = old; recalled.status = .recalled
        client.page = ChatPage(messages: [recalled, recent], hasMore: false)
        await chat.open(context)
        await chat.locate("s1")
        check(chat.locatedMessageID == nil && chat.errorMessage != nil && chat.messages.contains(where: { $0.status == .recalled }), "沿旧端拒绝已撤回的置顶目标，同时保留撤回占位")
        chat.close()
        client.page = ChatPage(messages: [recent], hasMore: true)
        await chat.open(context)
        client.page = ChatPage(messages: [recalled], hasMore: false)
        client.localRecords = [recent]
        await chat.locate("s1")
        check(chat.locatedMessageID == nil && chat.errorMessage != nil, "远程补页中的撤回记录不能成为定位成功目标")
        chat.close()
        let firstAtSameTime = message("a", server: "same-a", time: 500)
        let targetAtSameTime = message("z", server: "same-z", time: 500)
        client.localRecords = [firstAtSameTime]
        client.page = ChatPage(messages: [firstAtSameTime], hasMore: true)
        await chat.open(context)
        client.page = ChatPage(messages: [targetAtSameTime], hasMore: false)
        await chat.locate("same-z")
        check(chat.locatedMessageID == "z" && chat.errorMessage == nil, "补页已含目标时即使首条ID未变也必须定位")
        chat.close()
        if failures > 0 { exit(1) }
        print("消息定位Store检查：12项通过")
    }
    static func message(_ local: String, server: String, time: Int64) -> ChatMessageRecord {
        ChatMessageRecord(localID: local, serverID: server, conversationID: "peer", senderID: "peer", senderName: "好友", text: local, timestamp: time, state: .sent)
    }
}
