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
        print("Mention checks: 3 passed")
    }
}
