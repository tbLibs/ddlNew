//
//  ContactSorter.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import Foundation

/// 沿用老项目的中文拼音首字母排序，字母排在数字前，已注销好友放在最后。
nonisolated enum ContactSorter {
    static func searchPinyin(for name: String) -> String {
        (name.applyingTransform(.mandarinToLatin, reverse: false) ?? name)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "zh_CN"))
            .replacingOccurrences(of: " ", with: "")
    }

    static func sortName(for name: String) -> String {
        name.map { character -> String in
            guard character.unicodeScalars.contains(where: { (0x4E00...0x9FFF).contains($0.value) }) else {
                return String(character)
            }
            let latin = String(character).applyingTransform(.mandarinToLatin, reverse: false) ?? String(character)
            let folded = latin.folding(options: .diacriticInsensitive, locale: Locale(identifier: "zh_CN"))
            return String(folded.prefix(1))
        }.joined().replacingOccurrences(of: " ", with: "").uppercased()
    }

    static func sorted(_ contacts: [ContactRecord]) -> [ContactRecord] {
        // 重复 UID 只保留一份，避免 SwiftUI 列表出现重复标识。
        var seen = Set<String>()
        return contacts.filter { !$0.id.isEmpty && $0.userType == 0 && seen.insert($0.id).inserted }
            .sorted { left, right in
                if left.isDeleted != right.isDeleted { return !left.isDeleted }
                if left.initial != right.initial {
                    if left.initial == "#" { return false }
                    if right.initial == "#" { return true }
                    return left.initial < right.initial
                }
                let comparison = compare(left.sortName, right.sortName)
                return comparison == .orderedSame ? left.id < right.id : comparison == .orderedAscending
            }
    }

    /// 输入为 Store 已排好序的快照，搜索时只过滤、分组，不重复排序。
    static func sections(from contacts: [ContactRecord], matching query: String = "") -> [ContactSection] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = contacts.filter { query.isEmpty || $0.searchText.localizedCaseInsensitiveContains(query) }
        let groups = Dictionary(grouping: filtered, by: \.initial)
        return groups.keys.sorted { left, right in
            if left == "#" { return false }
            if right == "#" { return true }
            return left < right
        }.map { ContactSection(id: $0, contacts: groups[$0] ?? []) }
    }

    private static func compare(_ left: String, _ right: String) -> ComparisonResult {
        for (a, b) in zip(left.unicodeScalars, right.unicodeScalars) where a != b {
            let aIsLetter = CharacterSet.letters.contains(a)
            let bIsLetter = CharacterSet.letters.contains(b)
            if aIsLetter != bIsLetter { return aIsLetter ? .orderedAscending : .orderedDescending }
            return a.value < b.value ? .orderedAscending : .orderedDescending
        }
        if left.count == right.count { return .orderedSame }
        return left.count < right.count ? .orderedAscending : .orderedDescending
    }
}
