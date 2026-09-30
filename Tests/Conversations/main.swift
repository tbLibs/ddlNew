//
//  main.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import Foundation

func record(_ id: String, pinned: Bool = false, time: TimeInterval = 0,
            unread: Int = 0, marked: Bool = false, muted: Bool = false) -> ConversationRecord {
    ConversationRecord(id: id, title: id, avatarURL: "", kind: .single, preview: "",
                       latestTime: Date(timeIntervalSince1970: time), unreadCount: unread,
                       isMarkedUnread: marked, isPinned: pinned, isMuted: muted, isDraft: false)
}

let result = ConversationSorter.sorted([
    record("normal-new", time: 50), record("pinned-old", pinned: true, time: 10),
    record("pinned-new", pinned: true, time: 20), record("normal-old", time: 5),
    record("normal-old", time: 40), record("", time: 100),
])
precondition(result.map(\.id) == ["pinned-new", "pinned-old", "normal-new", "normal-old"])
precondition(result.first(where: { $0.id == "normal-old" })?.latestTime == Date(timeIntervalSince1970: 40))
precondition(ConversationSorter.sorted([record("a"), record("b")]).map(\.id) == ["b", "a"])
precondition(ConversationUnread.total([
    record("a", unread: 3), record("b", unread: 8, muted: true), record("c", marked: true),
]) == 4)
print("ConversationSorter checks passed")
