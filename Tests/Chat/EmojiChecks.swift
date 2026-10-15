//
//  EmojiChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import Foundation

@main struct EmojiChecks {
    /// 执行真实资源索引与UTF16光标映射，不创建UIKit或网络对象。
    static func main() throws {
        let items = try ChatEmojiCatalog.load(from: URL(fileURLWithPath: CommandLine.arguments[1]))
        precondition(items.count == 157 && items.first?.token == "[微笑]" && Set(items.map(\.token)).count == items.count)
        let text = "甲🙂[微笑]乙[气球]"
        let runs = ChatEmojiCatalog.runs(in: text, items: items)
        precondition(runs.compactMap(\.emoji).count == 2)
        precondition(ChatEmojiCatalog.displayOffset(7, in: text, items: items) == 4)
        precondition(ChatEmojiCatalog.rawOffset(4, in: text, items: items) == 7)
        precondition(ChatEmojiCatalog.runs(in: "[未知]", items: items).allSatisfy { $0.emoji == nil })
        let value = ChatEmojiCatalog.replacing(text, range: NSRange(location: 3, length: 0), with: "[快乐]")
        precondition(value.text == "甲🙂[快乐][微笑]乙[气球]" && value.selection.location == 7)
        let deleted = ChatEmojiCatalog.deletingBackward("中[微笑]", selection: NSRange(location: 5, length: 0), items: items)
        precondition(deleted.text == "中" && deleted.selection.location == 1)
        precondition(ChatEmojiCatalog.deletingBackward("甲👨‍👩‍👧‍👦", selection: NSRange(location: NSNotFound, length: 0), items: items).text == "甲")
        precondition(ChatEmojiCatalog.deletingBackward("", selection: NSRange(location: 0, length: 0), items: items).text.isEmpty)
        print("Emoji catalog, token and cursor checks passed")
    }
}
