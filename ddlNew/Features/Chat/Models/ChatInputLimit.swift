import Foundation

/// 输入上限按可见字素计算；完整内置表情算一个，不拆Unicode或协议标记。
nonisolated enum ChatInputLimit {
    static let maximum = 1_000

    static func length(_ text: String, items: [ChatEmojiItem]? = nil) -> Int {
        ChatEmojiCatalog.runs(in: text, items: items).reduce(0) { $0 + ($1.emoji == nil ? $1.text.count : 1) }
    }

    static func allows(_ text: String) -> Bool { length(text) <= maximum }

    static func prefix(_ text: String, capacity: Int = maximum, items: [ChatEmojiItem]? = nil) -> String {
        var remaining = max(0, capacity), result = ""
        for run in ChatEmojiCatalog.runs(in: text, items: items) {
            guard remaining > 0 else { break }
            if run.emoji != nil { result += run.text; remaining -= 1 }
            else {
                let accepted = run.text.prefix(remaining)
                result += accepted; remaining -= accepted.count
            }
        }
        return result
    }

    /// 只裁剪新插入的部分，保留光标两侧原文；选区替换会释放相应容量。
    static func replacing(_ text: String, range: NSRange, with replacement: String) -> (text: String, selection: NSRange) {
        let raw = text as NSString
        let valid = range.location != NSNotFound && range.location >= 0 && range.length >= 0
            && range.location <= raw.length && range.length <= raw.length - range.location
        let range = valid ? range : NSRange(location: raw.length, length: 0)
        let retained = raw.replacingCharacters(in: range, with: "")
        let accepted = prefix(replacement, capacity: maximum - length(retained))
        return ChatEmojiCatalog.replacing(text, range: range, with: accepted)
    }

    /// 输入法提交后才限长，比较已提交旧稿以保留组合输入之后的正文。
    static func committing(_ new: String, over old: String) -> (text: String, selection: NSRange) {
        let before = Array(old), after = Array(new)
        var start = 0, suffix = 0
        while start < min(before.count, after.count), before[start] == after[start] { start += 1 }
        while suffix < min(before.count - start, after.count - start),
              before[before.count - suffix - 1] == after[after.count - suffix - 1] { suffix += 1 }
        let location = String(before.prefix(start)).utf16.count
        let removed = String(before[start..<(before.count - suffix)]).utf16.count
        return replacing(old, range: NSRange(location: location, length: removed),
            with: String(after[start..<(after.count - suffix)]))
    }
}
