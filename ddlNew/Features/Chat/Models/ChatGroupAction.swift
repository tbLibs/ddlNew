//
//  ChatGroupAction.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

enum ChatGroupAction: Equatable, Sendable {
    case rename(String), nickname(String), avatar(String)
    case invite([ChatGroupMember], reason: String = ""), remove([String], deleteMessages: Bool)
    case muteAll(Bool), muteMembers([String], minutes: Int)
    case setManagers([String], enabled: Bool), transferOwner(String)
    case privateChat(Bool), approval(Bool), history(Bool), qr(Bool), remind(Bool), prohibitCalls(Bool)
    case leave, dissolve
}

enum ChatGroupPolicy {
    /// 每个操作按最新服务端角色及目标角色校验，不让普通成员复用旧管理页面。
    nonisolated static func permits(_ action: ChatGroupAction, detail: ChatGroupDetail, userUID: String) -> Bool {
        guard detail.isActive, [0, 1, 2].contains(detail.role) else { return false }
        switch action {
        case .nickname: return true
        case .invite(let members, _):
            return !members.isEmpty && members.count <= 200 && Set(members.map(\.id)).count == members.count && members.allSatisfy { member in !member.isDeleted && !member.id.isEmpty && member.id != userUID && !detail.members.contains(where: { $0.id == member.id }) }
        case .leave: return detail.role != 2
        case .dissolve: return detail.role == 2
        case .setManagers(let ids, _):
            return detail.role == 2 && !ids.isEmpty && ids.allSatisfy { id in
                id != userUID && detail.members.contains { $0.id == id && [0, 1].contains($0.role) && !$0.isDeleted }
            }
        case .transferOwner(let id):
            return detail.role == 2 && id != userUID && detail.members.contains { $0.id == id && [0, 1].contains($0.role) && !$0.isDeleted }
        case .muteMembers(_, let minutes) where ![0, 10, 60, 720, 1440, 10080, 43200, -1].contains(minutes): return false
        case .remove(let ids, _):
            guard !ids.isEmpty, ids.count <= 500, Set(ids).count == ids.count else { return false }
            return Set(ids).isSubset(of: Set(removableMembers(in: detail, userUID: userUID).map(\.id)))
        case .muteMembers(let ids, _):
            guard detail.role > 0, !ids.isEmpty, !ids.contains(userUID) else { return false }
            return ids.allSatisfy { id in detail.members.contains { $0.id == id && [0, 1].contains($0.role) && $0.role < detail.role && !$0.isDeleted } }
        default: return detail.role == 1 || detail.role == 2
        }
    }

    /// 选择页和提交共用移除资格，一次扫描名单，避免大群逐行重复遍历全表。
    nonisolated static func removableMembers(in detail: ChatGroupDetail, userUID: String) -> [ChatGroupMember] {
        guard detail.isActive, detail.membersSyncReady, [1, 2].contains(detail.role), !userUID.isEmpty else { return [] }
        return detail.members.filter {
            !$0.id.isEmpty && $0.id != userUID && !$0.isDeleted && [0, 1].contains($0.role) && $0.role < detail.role
        }
    }
}
