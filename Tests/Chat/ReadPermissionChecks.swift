//
//  ReadPermissionChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import Foundation

@main private struct ReadPermissionChecks {
    /// 生产策略覆盖可见正文范围、最新计数、严格布尔和禁言期限重查，不请求真实SDK。
    static func main() {
        var count = 0
        func check(_ value: Bool, _ label: String) { precondition(value, label); count += 1 }
        func message(_ local: String, server: String, sender: String = "peer", conversation: String = "chat", type: Int = 0, read: Bool = false, status: ChatMessageStatus = .normal) -> ChatMessageRecord {
            ChatMessageRecord(localID: local, serverID: server, conversationID: conversation, senderID: sender,
                senderName: "匿名", type: type, text: "测试", timestamp: 1, state: .sent, status: status, isRead: read)
        }
        let visible = message("visible", server: "s1")
        check(ChatVisibleReadPolicy.wireEntry(visible) == "s1_peer_visible", "已读wire必须保留服务端ID、真实发送者与原客户端ID三段")
        check(ChatVisibleReadPolicy.wireEntry(message("", server: "s1")) == nil, "原客户端ID缺失时不伪造上报")
        check(ChatVisibleReadPolicy.wireEntry(message("local", server: "s1", sender: "")) == nil, "发送UID缺失时不伪造上报")
        check(ChatVisibleReadPolicy.wireEntry(message("local", server: "")) == nil, "服务端ID缺失时不伪造上报")
        check(ChatVisibleReadPolicy.wireEntry(message("client_part", server: "server_part", sender: "sender_part")) == "server_part_sender_part_client_part", "已有下划线按旧版原样拼接，不编码或猜分隔身份")
        let duplicate = message("secondLocal", server: "s1")
        let own = message("own", server: "s2", sender: "me")
        let read = message("read", server: "s3", read: true)
        let event = message("event", server: "s4", type: 13)
        let deleted = message("deleted", server: "s5", status: .deleted)
        let other = message("other", server: "s6", conversation: "other-chat")
        let noServerID = message("noServerID", server: "")
        let noSenderID = message("noSenderID", server: "s7", sender: "")
        let body = message("media", server: "s8", type: 1)
        let values = ChatVisibleReadPolicy.candidates([visible, duplicate, own, read, event, deleted, other, noServerID, noSenderID, body], userUID: "me", conversationID: "chat")
        check(values.map(\.serverID) == ["s1", "s8"], "只包含去重的未读接收正文，不含已读/自己/跨会话/非正文")
        check(ChatVisibleReadPolicy.candidates([read], userUID: "me", conversationID: "chat").isEmpty, "重复读不再次扣计数")
        check(ChatVisibleReadPolicy.candidates([], userUID: "me", conversationID: "chat").isEmpty, "空视口不读历史")
        check(ChatVisibleReadPolicy.remainingUnread(5, transitionedIDs: ["s1"]) == 4, "一条可见只扣一条，屏外四条保留")
        check(ChatVisibleReadPolicy.remainingUnread(7, transitionedIDs: ["s1", "s8"]) == 5, "使用最新计数保留并发新未读")
        check(ChatVisibleReadPolicy.remainingUnread(5, transitionedIDs: []) == 5, "写库失败不减少未读")
        check(ChatVisibleReadPolicy.remainingUnread(1, transitionedIDs: ["s1", "s8"]) == 0, "他端先读导致计数较小时不为负数")
        check(ChatVisibleReadPolicy.remainingUnread(-1, transitionedIDs: []) == 0, "坏计数保守归零")
        var pending = ChatVisibleReadTransitions()
        pending.saved("s1"); pending.saved("s1"); pending.saved("")
        check(pending.pendingIDs == ["s1"], "实际成功转读按服务端ID去重")
        let firstFailedCount = pending.remainingUnread(5)
        check(firstFailedCount == 4 && pending.pendingIDs == ["s1"], "会话写失败保留待扣身份")
        pending.saved("s8")
        check(pending.remainingUnread(7) == 5, "重试使用最新计数保留并发新消息")
        pending.committed()
        check(pending.pendingIDs.isEmpty && pending.remainingUnread(5) == 5, "会话写成功消费身份，不在下次重复扣减")
        pending.saved("oldUserMessage")
        pending = ChatVisibleReadTransitions()
        check(pending.pendingIDs.isEmpty && pending.remainingUnread(9) == 9, "退出重置不向新会话扣减旧身份")
        for value: Any in [1, true, "1", "true", " TRUE "] {
            check(ChatGroupPermissionPayload.boolean(value) == true, "明确布尔真")
        }
        for value: Any in [0, false, "0", "false"] {
            check(ChatGroupPermissionPayload.boolean(value) == false, "明确布尔假")
        }
        for value: Any in [2, -1, 1.5, "yes", "2", "", NSNull(), ["true": true]] {
            check(ChatGroupPermissionPayload.boolean(value) == nil, "非法布尔不转换成允许")
        }
        check(ChatGroupPermissionPayload.verified(detail: ["userInGroup": "1"], mute: ["isGroupForbid": "0", "isGroupChat": 0]), "字符串权限真实就绪")
        check(!ChatGroupPermissionPayload.verified(detail: ["userInGroup": true], mute: [:]), "空禁言回执不能确认可发送")
        check(!ChatGroupPermissionPayload.verified(detail: ["userInGroup": "unknown"], mute: ["isGroupForbid": 0, "isGroupChat": 0]), "非法在群字段不就绪")
        let utc = TimeZone(secondsFromGMT: 0)!
        let mute: [String: Any] = ["isGroupForbid": "1", "startTime": "2026-10-14 12:00:00", "endTime": "2026-10-14 12:05:00"]
        let expiry = ChatGroupMuteExpiry.decode(mute, timeZone: utc)!
        let before = expiry.deadline.addingTimeInterval(-10), after = expiry.deadline.addingTimeInterval(10)
        var state = ChatGroupMuteExpiryState()
        check(state.plan(expiry, now: before) == expiry, "未到期安排真实重查")
        check(state.plan(expiry, now: after) == expiry, "首次看到已过期禁言立即重查")
        state.checked(expiry)
        check(state.plan(expiry, now: after) == nil, "到期仍禁言或网络失败不自旋")
        check(state.plan(expiry, now: before) == expiry, "系统时钟回退仍保留未来截止检查")
        let extended = ChatGroupMuteExpiry.decode(["isGroupForbid": 1, "startTime": "2026-10-14 12:00:00", "endTime": "2026-10-14 12:10:00"], timeZone: utc)!
        check(state.plan(extended, now: after) == extended, "服务器延长禁言后安排新的期限")
        check(ChatGroupMuteExpiryState().plan(expiry, now: after) == expiry, "新的登录所有者不继承旧检查状态")
        check(state.plan(nil, now: after) == nil, "已解禁不安排期限任务")
        check(ChatGroupMuteExpiry.decode(["isGroupForbid": 0, "startTime": mute["startTime"]!, "endTime": mute["endTime"]!], timeZone: utc) == nil, "未禁言忽略旧期限")
        for values: [String: Any] in [
            ["isGroupForbid": 1],
            ["isGroupForbid": 1, "startTime": "bad", "endTime": "2026-10-14 12:10:00"],
            ["isGroupForbid": 1, "startTime": "2026-10-14 12:10:00", "endTime": "2026-10-14 12:05:00"],
            ["isGroupForbid": 1, "startTime": "2026-02-30 12:00:00", "endTime": "2026-10-14 12:05:00"],
            ["isGroupForbid": 1, "startTime": "2026-10-14 12:00:00", "endTime": "2026-10-14 12:05:00+0800"]
        ] { check(ChatGroupMuteExpiry.decode(values, timeZone: utc) == nil, "无效时间不猜解禁") }
        print("Chat read and permission checks passed: \(count)")
    }
}
