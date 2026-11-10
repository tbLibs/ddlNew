import Foundation

@main struct InputLimitChecks {
    static func main() {
        let full = String(repeating: "中", count: 1_000)
        precondition(ChatInputLimit.allows(full))
        precondition(!ChatInputLimit.allows(full + "a"))
        precondition(ChatInputLimit.prefix(full + "a") == full)
        let family = "👨‍👩‍👧‍👦"
        precondition(ChatInputLimit.prefix(String(repeating: family, count: 1_001)).count == 1_000)
        let item = ChatEmojiItem(token: "[微笑]", image: "smile")
        let emoji = String(repeating: item.token, count: 1_001)
        precondition(ChatInputLimit.length(emoji, items: [item]) == 1_001)
        precondition(ChatInputLimit.prefix(emoji, items: [item]) == String(repeating: item.token, count: 1_000))
        let replaced = ChatInputLimit.replacing(full, range: NSRange(location: 100, length: 2), with: "abcde")
        precondition(replaced.text == String(repeating: "中", count: 100) + "ab" + String(repeating: "中", count: 898))
        precondition(replaced.selection == NSRange(location: 102, length: 0))
        let old = String(repeating: "a", count: 998) + "后"
        let new = String(repeating: "a", count: 998) + "中文" + "后"
        precondition(ChatInputLimit.committing(new, over: old).text == String(repeating: "a", count: 998) + "中后")
        precondition(ChatInputLimit.replacing(full, range: NSRange(location: 20, length: 0), with: "x").text == full)
        precondition(ChatInputLimit.replacing(full, range: NSRange(location: 20, length: 1), with: "").text.count == 999)
        precondition(ChatInputLimit.prefix("a\ne\u{301}", capacity: 3) == "a\ne\u{301}")
        print("Chat input 1000-character limit checks passed")
    }
}
