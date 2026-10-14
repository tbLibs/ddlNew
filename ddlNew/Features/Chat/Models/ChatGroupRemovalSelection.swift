//
//  ChatGroupRemovalSelection.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import Foundation

/// 只保存勾选UID，候选与提交资格始终读取当前群成员和权限。
struct ChatGroupRemovalSelection {
    private(set) var selectedIDs: Set<String> = []

    /// 与真实移除策略共用角色校验，群主、本人和失效成员不能被选择。
    nonisolated static func candidates(in detail: ChatGroupDetail, userUID: String) -> [ChatGroupMember] {
        var seen = Set<String>()
        return ChatGroupPolicy.removableMembers(in: detail, userUID: userUID).filter { seen.insert($0.id).inserted }
    }

    /// 搜索仅改变显示列表，勾选和取消均按UID操作，到上限后仍可取消。
    @discardableResult mutating func toggle(_ id: String, detail: ChatGroupDetail, userUID: String) -> Bool {
        if selectedIDs.remove(id) != nil { return true }
        guard selectedIDs.count < 500, Self.candidates(in: detail, userUID: userUID).contains(where: { $0.id == id }) else { return false }
        selectedIDs.insert(id)
        return true
    }

    /// 同步降权、离群或注销后撤销旧勾选，不保留失效提交对象。
    mutating func reconcile(detail: ChatGroupDetail?, userUID: String) {
        selectedIDs.formIntersection(Set(detail.map { Self.candidates(in: $0, userUID: userUID).map(\.id) } ?? []))
    }

    /// 提交前全量核对，不能悄悄丢弃不合法UID后移除另一批成员。
    func action(detail: ChatGroupDetail, userUID: String, deleteMessages: Bool) -> ChatGroupAction? {
        let ids = Self.candidates(in: detail, userUID: userUID).filter { selectedIDs.contains($0.id) }.map(\.id)
        let action = ChatGroupAction.remove(ids, deleteMessages: deleteMessages)
        guard ids.count == selectedIDs.count, ChatGroupPolicy.permits(action, detail: detail, userUID: userUID) else { return nil }
        return action
    }
}
