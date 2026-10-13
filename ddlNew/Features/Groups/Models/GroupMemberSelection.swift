//
//  GroupMemberSelection.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// 选人状态按UID管理，搜索或折叠不会重置选择。
nonisolated struct GroupMemberSelection {
    let available: [ContactRecord]
    let lockedIDs: Set<String>
    var selectedIDs: Set<String>
    /// 筛掉系统、注销、已在群和重复好友，单聊对方保持预选。
    init(contacts: [ContactRecord], preselectedIDs: Set<String>, excludedIDs: Set<String>) {
        var seen = Set<String>()
        available = contacts.filter { !$0.id.isEmpty && $0.userType == 0 && !$0.isDeleted && !excludedIDs.contains($0.id) && seen.insert($0.id).inserted }
        lockedIDs = preselectedIDs.intersection(Set(available.map(\.id)))
        selectedIDs = lockedIDs
    }
    /// 预选成员不能取消，选人达到上限后禁止继续添加。
    mutating func toggle(_ id: String, maximum: Int) {
        guard !lockedIDs.contains(id), available.contains(where: { $0.id == id }) else { return }
        if selectedIDs.contains(id) { selectedIDs.remove(id) }
        else if selectedIDs.count < maximum { selectedIDs.insert(id) }
    }
    /// 最小和最大数量只计算实际选择的好友，群主由SDK参数单独提供。
    func canSubmit(minimum: Int, maximum: Int) -> Bool { (minimum...maximum).contains(selectedIDs.count) }
    var selected: [ContactRecord] { available.filter { selectedIDs.contains($0.id) } }
}
