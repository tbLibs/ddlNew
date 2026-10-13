import Foundation
@main private struct PreviewChecks {
    /// 验证群发送者前缀和最新@提醒只依据明确的UID命中。
    static func main() {
        precondition(ConversationPreviewText.render("hello", kind: .group, senderName: "群昵称", senderUID: "other", userUID: "me", mentionsMe: false) == "群昵称：hello")
        precondition(ConversationPreviewText.render("hello", kind: .group, senderName: "昵称", senderUID: "me", userUID: "me", mentionsMe: true) == "你：hello")
        precondition(ConversationPreviewText.render("@伙伴", kind: .group, senderName: "备注", senderUID: "other", userUID: "me", mentionsMe: true) == "[有人@我] 备注：@伙伴")
        precondition(ConversationPreviewText.render("公告", kind: .group, senderName: "other", senderUID: "other", userUID: "me", mentionsMe: false, includeSender: false) == "公告")
        print("Conversation preview checks passed")
    }
}
