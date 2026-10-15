import Foundation

@main struct MentionChecks {
    /// 重名必须按片段UID替换，局部编辑片段则整个片段失效。
    static func main() {
        let text = "@同名 @同名 hello🙂"
        let first = ChatMentionSegment(id: UUID(), userUID: "u1", name: "同名", location: 0, length: 4)
        let second = ChatMentionSegment(id: UUID(), userUID: "u2", name: "同名", location: 4, length: 4)
        precondition(ChatMentionEngine.wireText(text, segments: [first, second]) == "\u{000b}u1\u{000b} \u{000b}u2\u{000b} hello🙂", "同名不同UID必须独立绑定")
        let result = ChatMentionEngine.editing(old: text, new: "@同 @同名 hello🙂", segments: [first, second])
        precondition(result.1.count == 1 && result.1[0].userUID == "u2" && result.0 == "@同名 hello🙂", "部分删@应整段删除并平移后续片段")
        let masked = ChatMentionEngine.filterSensitive("\u{000b}u1\u{000b} u1敏感", words: ["u1", "敏感"])
        precondition(masked == "\u{000b}u1\u{000b} ****", "敏感词不能改变@协议UID")
        let inserted = ChatMentionEngine.inserting(userUID: "u3", name: "新成员", replacingAt: NSRange(location: 4, length: 1), in: "🙂前缀@后文", segments: [])
        precondition(inserted?.0 == "🙂前缀@新成员 后文" && inserted?.1.first?.location == 4 && inserted?.2.location == 9, "成员必须替换光标处单个@而非追加文末")
        precondition(ChatMentionEngine.inserting(userUID: "u3", name: "新成员", replacingAt: NSRange(location: 0, length: 1), in: "已改变", segments: []) == nil, "迟到选择不能覆盖已经改变的输入")
        if let inserted { precondition(ChatMentionEngine.wireText(inserted.0, segments: inserted.1) == "🙂前缀\u{000b}u3\u{000b} 后文") }
        let around = "@同名 @中间@同名 "
        let trailing = ChatMentionSegment(id: UUID(), userUID: "u2", name: "同名", location: 7, length: 4)
        let middle = ChatMentionEngine.inserting(userUID: "u3", name: "新成员", replacingAt: NSRange(location: 4, length: 1), in: around, segments: [first, trailing])
        precondition(middle?.0 == "@同名 @新成员 中间@同名 " && middle?.1.map(\.userUID) == ["u1", "u3", "u2"] && middle?.1.last?.location == 11, "中间插入不得丢失或错位前后的同名成员UID")
        let repeated = ChatMentionSegment(id: UUID(), userUID: "oldUID", name: "旧", location: 1, length: 3)
        let withAtName = ChatMentionEngine.inserting(userUID: "newUID", name: "@旧", replacingAt: NSRange(location: 0, length: 1), in: "@@旧 ", segments: [repeated])
        precondition(withAtName?.1.last?.location == 4, "昵称含@和重复正文仍按真实替换范围平移旧片段")
        if let withAtName { precondition(ChatMentionEngine.wireText(withAtName.0, segments: withAtName.1) == "\u{000b}newUID\u{000b} \u{000b}oldUID\u{000b} ", "重叠文本不能丢失新选成员UID") }
        precondition(ChatMentionEngine.inserting(userUID: "newUID", name: "新", replacingAt: NSRange(location: 1, length: 1), in: "@@旧 ", segments: [repeated]) == nil, "不可替换已有UID片段内的@")
        print("Mention checks: cursor insertion and original protocol passed")
    }
}
