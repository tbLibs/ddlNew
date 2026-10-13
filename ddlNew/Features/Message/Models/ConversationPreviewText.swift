// Created by taobo on 2026/10/13.
import Foundation

enum ConversationPreviewText {
    /// 群正文补上发送者；自己发出的@不提醒自己，系统提示保留其独立语义。
    nonisolated static func render(_ text: String, kind: ConversationKind, senderName: String, senderUID: String,
                                  userUID: String, mentionsMe: Bool, includeSender: Bool = true) -> String {
        var preview = text
        if kind == .group, includeSender {
            let name = senderUID == userUID ? "你" : senderName
            if !name.isEmpty { preview = name + "：" + preview }
        }
        if mentionsMe, senderUID != userUID { preview = "[有人@我] " + preview }
        return preview
    }
}
