import Foundation

/// 框架页码与消息 ID 的边界：补历史保留当前消息，重复通知不重复启动加载。
struct ChatPhotoBrowserSelection {
    private(set) var ids: [String]
    private(set) var selectedID: String
    var index: Int { ids.firstIndex(of: selectedID) ?? 0 }

    init(ids: [String], selectedID: String) {
        self.ids = ids
        self.selectedID = ids.contains(selectedID) ? selectedID : (ids.first ?? "")
    }

    mutating func replace(_ ids: [String]) {
        let oldIndex = index
        self.ids = ids
        if !ids.contains(selectedID) { selectedID = ids.isEmpty ? "" : ids[min(oldIndex, ids.count - 1)] }
    }

    mutating func select(index: Int) -> String? {
        guard ids.indices.contains(index), ids[index] != selectedID else { return nil }
        selectedID = ids[index]
        return selectedID
    }
}
