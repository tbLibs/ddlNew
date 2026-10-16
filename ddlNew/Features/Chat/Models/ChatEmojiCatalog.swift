//
//  ChatEmojiCatalog.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import Foundation

nonisolated struct ChatEmojiItem: Identifiable, Sendable {
    let token: String
    let image: String
    var id: String { token }
}

nonisolated struct ChatEmojiRun {
    let text: String
    let range: NSRange
    let emoji: ChatEmojiItem?
}

/// 只识别旧端词典中的完整标记；未知方括号文本原样保留。
nonisolated enum ChatEmojiCatalog {
    static let items: [ChatEmojiItem] = (Bundle.main.url(forResource: "ChatEmojiCatalog", withExtension: "plist").flatMap { try? load(from: $0) }) ?? []
    private static let lookup = Dictionary(items.map { ($0.token, $0) }, uniquingKeysWith: { first, _ in first })
    private static let tokenRegex = try? NSRegularExpression(pattern: "\\[[^ \\[\\]]+?\\]")

    /// 旧表情使用zhCN作为wire正文，资源名保持旧端原值。
    static func load(from url: URL) throws -> [ChatEmojiItem] {
        let value = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        guard let rows = value as? [[String: String]] else { throw CocoaError(.fileReadCorruptFile) }
        return try rows.map {
            guard let token = $0["zhCN"], token.hasPrefix("["), token.hasSuffix("]"), let image = $0["emojiName"], !image.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
            return ChatEmojiItem(token: token, image: image)
        }
    }

    /// UTF16范围同时服务UIKit光标与发送方/接收方正文渲染。
    static func runs(in text: String, items: [ChatEmojiItem]? = nil) -> [ChatEmojiRun] {
        guard !text.isEmpty else { return [] }
        let raw = text as NSString
        // 普通文字不进入正则或表情词典；生产词典和正则全程复用。
        guard text.contains("["), text.contains("]"), let regex = tokenRegex else {
            return [ChatEmojiRun(text: text, range: NSRange(location: 0, length: raw.length), emoji: nil)]
        }
        let lookup = items.map { Dictionary($0.map { ($0.token, $0) }, uniquingKeysWith: { first, _ in first }) } ?? lookup
        var result: [ChatEmojiRun] = [], cursor = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: raw.length)) {
            guard let emoji = lookup[raw.substring(with: match.range)] else { continue }
            if match.range.location > cursor { let range = NSRange(location: cursor, length: match.range.location - cursor); result.append(ChatEmojiRun(text: raw.substring(with: range), range: range, emoji: nil)) }
            result.append(ChatEmojiRun(text: emoji.token, range: match.range, emoji: emoji)); cursor = NSMaxRange(match.range)
        }
        if cursor < raw.length { let range = NSRange(location: cursor, length: raw.length - cursor); result.append(ChatEmojiRun(text: raw.substring(with: range), range: range, emoji: nil)) }
        return result
    }

    /// wire标记占多个UTF16单位，显示附件只占一个单位，不能直接复用光标偏移。
    static func displayOffset(_ raw: Int, in text: String, items: [ChatEmojiItem]? = nil) -> Int {
        var result = min(max(0, raw), text.utf16.count)
        for run in runs(in: text, items: items) where run.emoji != nil {
            if raw >= NSMaxRange(run.range) { result -= run.range.length - 1 }
            else if raw > run.range.location { result -= raw - run.range.location - 1; break }
        }
        return result
    }

    /// 显示光标回到完整标记边界，选择、复制和成员插入都使用wire范围。
    static func rawOffset(_ display: Int, in text: String, items: [ChatEmojiItem]? = nil) -> Int {
        var raw = max(0, display), removed = 0
        for run in runs(in: text, items: items) where run.emoji != nil {
            let start = run.range.location - removed
            if display > start { raw += run.range.length - 1 }
            removed += run.range.length - 1
        }
        return min(raw, text.utf16.count)
    }

    /// 选中插入点可能来自已关闭键盘，失效范围退到文末且不越界。
    static func replacing(_ text: String, range: NSRange, with value: String) -> (text: String, selection: NSRange) {
        let raw = text as NSString
        let valid = range.location != NSNotFound && range.location >= 0 && range.length >= 0 && range.location <= raw.length && range.length <= raw.length - range.location
        let range = valid ? range : NSRange(location: raw.length, length: 0)
        return (raw.replacingCharacters(in: range, with: value), NSRange(location: range.location + value.utf16.count, length: 0))
    }

    /// 表情标记与Unicode组合字素整段删除，不留下半个标记或拆散家庭emoji。
    static func deletingBackward(_ text: String, selection: NSRange, items: [ChatEmojiItem]? = nil) -> (text: String, selection: NSRange) {
        let raw = text as NSString
        let cursor = selection.location == NSNotFound ? raw.length : min(max(0, selection.location), raw.length)
        if selection.length > 0 { return replacing(text, range: selection, with: "") }
        guard cursor > 0 else { return (text, NSRange(location: 0, length: 0)) }
        let token = runs(in: text, items: items).first { $0.emoji != nil && NSMaxRange($0.range) == cursor }
        return replacing(text, range: token?.range ?? raw.rangeOfComposedCharacterSequence(at: cursor - 1), with: "")
    }
}
