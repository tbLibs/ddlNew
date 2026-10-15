//
//  MentionRequestChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import Foundation

@MainActor final class MentionStoreShape {
    var context: ChatContext?
    var input = "@后文"
    var isVisible = true
    var errorMessage: String?
}
@MainActor final class MentionRuntimeShape {
    var context: ChatContext?
    func isCurrent(_ value: ChatContext) -> Bool { value == context }
}
struct MentionGroupShape {
    var isActive = true
    var role = 0
    var isPrivateChat = false
    var members = [ChatGroupMember(id: "member", name: "真实成员", avatar: "", role: 0, isDeleted: false)]
}
struct MentionResultShape { var group: MentionGroupShape? }
@MainActor final class SDKChatSettingsClient {
    static var waiting: CheckedContinuation<MentionResultShape, Error>?
    static var closes = 0
    func load(context: ChatContext) async throws -> MentionResultShape {
        try await withCheckedThrowingContinuation { Self.waiting = $0 }
    }
    func close() { Self.closes += 1 }
}

@main struct MentionRequestChecks {
    /// 暂停真实页面方法的SDK等待，迟到成功/失败均不得夺回其它页面或输入面板。
    @MainActor static func main() async {
        await check("正常结果") { _ in }
        await check("已进入设置", invalid: true) { $0.showSettings = true }
        await check("已进入资料", invalid: true) { $0.selectedProfile = "member" }
        await check("页面已不可见", invalid: true) { $0.store.isVisible = false }
        await check("草稿已改变", invalid: true) { $0.store.input += "[微笑]" }
        await check("登录已切换", invalid: true) { $0.runtime.context = nil }
        await check("会话已关闭", invalid: true) { $0.store.context = nil }
        await check("已打开表情", invalid: true) { $0.composerMode.toggle(.stickers) }
        await check("已打开语音", invalid: true) { $0.composerMode.toggle(.voice) }
        await check("已进入多选", invalid: true) { $0.composerMode.selectMessages() }
        await check("用户重新聚焦", invalid: true) { $0.composerFocused = true }
        await check("请求已取消", invalid: true, cancel: true) { _ in }
        await check("迟到失败", invalid: true, failure: true) { $0.store.input += "新草稿" }
        await check("当前失败", failure: true) { _ in }
        await check("普通成员禁私聊", privateChat: true) { _ in }
        print("Mention request checks: 15 passed")
    }

    @MainActor static func check(_ title: String, invalid: Bool = false, cancel: Bool = false,
        failure: Bool = false, privateChat: Bool = false, mutate: (ProductionMentionPage) -> Void) async {
        let page = ProductionMentionPage()
        let context = ChatContext(userUID: "anonymous", tenantID: "test", sessionID: UUID(), route: ChatRoute(id: "g", kind: .group, title: "测试", avatarURL: ""))
        page.store.context = context; page.runtime.context = context
        let request = ChatMentionRequest(context: context, text: page.store.input, range: NSRange(location: 0, length: 1))
        page.mentionRequest = request
        let closedBefore = SDKChatSettingsClient.closes
        let task = Task { await page.loadMentionMembers(request) }
        while SDKChatSettingsClient.waiting == nil { await Task.yield() }
        mutate(page)
        let focusedBefore = page.composerFocused
        if cancel { task.cancel() }
        let waiting = SDKChatSettingsClient.waiting; SDKChatSettingsClient.waiting = nil
        if failure { waiting?.resume(throwing: ChatClientError.unavailable("离线注入失败")) }
        else {
            var group = MentionGroupShape(); group.isPrivateChat = privateChat
            waiting?.resume(returning: MentionResultShape(group: group))
        }
        await task.value
        precondition(SDKChatSettingsClient.closes == closedBefore + 1, title + "未关闭SDK客户")
        if invalid {
            precondition(!page.showMentionPicker && page.composerFocused == focusedBefore && page.store.errorMessage == nil && page.mentionRequest == nil, title + "仍发布弹层/焦点/错误")
        } else if failure || privateChat {
            precondition(!page.showMentionPicker && page.composerFocused && page.store.input == request.text, title + "未保留普通@并恢复编辑")
            precondition((page.store.errorMessage != nil) == failure)
        } else {
            precondition(page.showMentionPicker && page.mentionMembers.map(\.id) == ["-1", "member"] && !page.composerFocused, title + "未展示真实成员及所有人")
        }
    }
}
