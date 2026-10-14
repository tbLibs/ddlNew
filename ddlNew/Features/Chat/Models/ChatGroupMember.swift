//
//  ChatGroupMember.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

struct ChatGroupMember: Identifiable, Equatable, Sendable {
    let id: String
    var name: String
    var avatar: String
    var role: Int
    var isDeleted: Bool

    /// 群角色与平台账号角色分开，注销和普通成员不显示管理标识。
    nonisolated var groupRoleTitle: String? {
        guard !isDeleted else { return nil }
        switch role { case 2: return "群主"; case 1: return "管理员"; default: return nil }
    }
}

enum ChatGroupPreviewPolicy {
    /// 旧预览合同为普通五名、管理四名，群主和管理员优先，失效账号不作资料入口。
    nonisolated static func members(_ detail: ChatGroupDetail) -> [ChatGroupMember] {
        guard detail.isActive, detail.membersSyncReady, [0, 1, 2].contains(detail.role) else { return [] }
        return Array(detail.members.filter { !$0.isDeleted && [0, 1, 2].contains($0.role) }.sorted { first, second in
            if first.role != second.role { return first.role > second.role }
            return first.name == second.name ? first.id < second.id : first.name.localizedCompare(second.name) == .orderedAscending
        }.prefix(detail.role == 0 ? 5 : 4))
    }
}
