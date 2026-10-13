import Foundation

@main struct ReviewActionChecks {
    /// 验证管理员撤回独立于本人时限，且不能越过角色边界。
    static func main() {
        var permission = ChatPermission()
        permission.isGroup = true; permission.role = 1; permission.canRecallOthers = true
        var message = ChatMessageRecord(localID: "m", serverID: "s", conversationID: "g", senderID: "peer", senderName: "成员", senderRole: 0, timestamp: 1, state: .sent)
        check(allowed(message, permission), "管理员即使本人撤回窗口关闭也能撤回普通成员旧消息")
        permission.canRecall = true; permission.recallWindow = 10
        check(allowed(message, permission), "管理员撤回他人不受本人十秒窗口限制")
        message.senderRole = 1
        check(!allowed(message, permission), "管理员不能撤回同级消息")
        message.senderRole = 2
        check(!allowed(message, permission), "管理员不能撤回群主消息")
        message.senderRole = nil
        check(!allowed(message, permission), "未知角色不能开放管理撤回")
        message.senderRole = 0; permission.isGroup = false
        check(!allowed(message, permission), "单聊不使用群管理权限")
        permission.isGroup = true; permission.role = 2; message.senderRole = 1
        check(allowed(message, permission), "群主可撤回管理员旧消息")
        message = ChatMessageRecord(localID: "mine", serverID: "own", conversationID: "g", senderID: "me", senderName: "我", senderRole: 2, timestamp: 1, state: .sent)
        check(!allowed(message, permission), "群主本人旧消息仍受本人时限约束")
        message.timestamp = 99_000
        check(allowed(message, permission), "本人窗口内消息可撤回")
        print("Review action checks: 9 passed")
    }

    /// 使用固定当前时间校验生产策略，避免依赖测试执行时钟。
    static func allowed(_ message: ChatMessageRecord, _ permission: ChatPermission) -> Bool {
        ChatActionPolicy.allowed(for: message, userUID: "me", permission: permission, now: 100_000).contains(.recall)
    }

    /// 断言失败必须使测试入口失败。
    static func check(_ value: Bool, _ description: String) { precondition(value, description) }
}
