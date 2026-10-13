//
//  ChatMentionSegment.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

struct ChatMentionSegment: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let userUID: String
    let name: String
    var location: Int
    var length: Int
}

enum ChatMentionEngine {
    /// 按UTF16范围倒序替换为旧协议垂直制表UID，重名也不共用映射。
    nonisolated static func wireText(_ text: String, segments: [ChatMentionSegment]) -> String {
        let result = NSMutableString(string: text)
        for segment in segments.sorted(by: { $0.location > $1.location }) {
            guard segment.location >= 0, segment.location + segment.length <= result.length else { continue }
            let range = NSRange(location: segment.location, length: segment.length)
            guard result.substring(with: range) == "@" + segment.name + " " else { continue }
            result.replaceCharacters(in: range, with: "\u{000b}" + segment.userUID + "\u{000b} ")
        }
        return result as String
    }
    /// 只过滤可见正文片段，垂直制表内UID必须完整保留。
    nonisolated static func filterSensitive(_ wire: String, words: [String]) -> String {
        let pieces = wire.components(separatedBy: "\u{000b}")
        return pieces.enumerated().map { index, piece in
            guard index % 2 == 0 else { return piece }
            return words.filter { !$0.isEmpty }.sorted { $0.utf16.count > $1.utf16.count }.reduce(piece) { $0.replacingOccurrences(of: $1, with: String(repeating: "*", count: $1.utf16.count)) }
        }.joined(separator: "\u{000b}")
    }

    /// 从UID协议正文按出现位置恢复显示与片段，历史重名不会误绑定。
    nonisolated static func renderWire(_ wire: String, names: [String: String]) -> (String, [ChatMentionSegment]) {
        let raw = wire as NSString
        guard let expression = try? NSRegularExpression(pattern: "\u{000b}([^\u{000b}]+)\u{000b}") else { return (wire, []) }
        let result = NSMutableString(); var cursor = 0; var segments: [ChatMentionSegment] = []
        for match in expression.matches(in: wire, range: NSRange(location: 0, length: raw.length)) {
            result.append(raw.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
            let uid = raw.substring(with: match.range(at: 1)); let name = names[uid] ?? "未知成员"
            let start = result.length; result.append("@" + name)
            let next = NSMaxRange(match.range)
            let includesSpace = next < raw.length && raw.substring(with: NSRange(location: next, length: 1)) == " "
            segments.append(ChatMentionSegment(id: UUID(), userUID: uid, name: name, location: start, length: (name as NSString).length + 1 + (includesSpace ? 1 : 0)))
            cursor = next
        }
        result.append(raw.substring(from: cursor))
        return (result as String, segments)
    }

    /// 片段局部编辑会移除整个@显示片段，后续UTF16范围同步平移。
    nonisolated static func editing(old: String, new: String, segments: [ChatMentionSegment]) -> (String, [ChatMentionSegment]) {
        let oldUnits = Array(old.utf16); let newUnits = Array(new.utf16)
        var start = 0
        while start < min(oldUnits.count, newUnits.count), oldUnits[start] == newUnits[start] { start += 1 }
        var suffix = 0
        while suffix < min(oldUnits.count - start, newUnits.count - start), oldUnits[oldUnits.count - suffix - 1] == newUnits[newUnits.count - suffix - 1] { suffix += 1 }
        let oldEnd = oldUnits.count - suffix; let newEnd = newUnits.count - suffix
        let delta = newEnd - oldEnd
        var kept: [ChatMentionSegment] = []; var remove: [NSRange] = []
        for var segment in segments {
            let end = segment.location + segment.length
            let intersects = start < end && oldEnd > segment.location || (start == oldEnd && start > segment.location && start < end)
            if intersects {
                let begin = min(segment.location, start)
                let finish = max(begin, end + delta)
                if finish <= newUnits.count { remove.append(NSRange(location: begin, length: finish - begin)) }
            } else {
                if segment.location >= oldEnd { segment.location += delta }
                kept.append(segment)
            }
        }
        let result = NSMutableString(string: new)
        for range in remove.sorted(by: { $0.location > $1.location }) {
            guard range.location >= 0, NSMaxRange(range) <= result.length else { continue }
            result.deleteCharacters(in: range)
            for index in kept.indices where kept[index].location >= NSMaxRange(range) { kept[index].location -= range.length }
        }
        return (result as String, kept)
    }
}
