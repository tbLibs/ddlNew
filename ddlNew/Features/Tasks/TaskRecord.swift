import Foundation

nonisolated enum TaskProgress: String, Codable, CaseIterable, Sendable {
    case pending, active, review, completed, cancelled
    var title: String {
        switch self {
        case .pending: return "待处理"
        case .active: return "进行中"
        case .review: return "待确认"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        }
    }
    var isFinished: Bool { self == .completed || self == .cancelled }
}

nonisolated struct TaskSource: Codable, Equatable, Sendable {
    var conversationID: String
    var conversationName: String
    var messageID: String
    // 旧归档只有群来源，没有此字段；缺省仍按群聊解析。
    var isGroup: Bool? = nil

    var isGroupConversation: Bool { isGroup ?? true }
    var title: String { isGroupConversation ? "来源群聊" : "来源单聊" }
    func belongsToGroup(_ id: String) -> Bool { isGroupConversation && conversationID == id }

    // 沿用旧持久化键，升级后已有事项无需重写或丢弃。
    private enum CodingKeys: String, CodingKey {
        case conversationID = "groupID"
        case conversationName = "groupName"
        case messageID, isGroup
    }
}

nonisolated struct TaskChange: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var date = Date()
    var progress: TaskProgress
}

nonisolated struct TaskRecord: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var title = ""
    var notes = ""
    var responsible = ""
    var result = ""
    var dueDate: Date?
    var source: TaskSource?
    var progress: TaskProgress = .pending
    var createdAt = Date()
    var updatedAt = Date()
    var version = 0
    var changes: [TaskChange] = []

    func isOverdue(at date: Date) -> Bool {
        !progress.isFinished && dueDate.map { $0 < date } == true
    }
    func validated() throws -> Self {
        var record = self
        record.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !record.title.isEmpty, record.title.count <= 80,
              notes.count <= 1000, responsible.count <= 80, result.count <= 1000 else {
            throw TaskStorageError.invalidFields
        }
        return record
    }
}

nonisolated struct TaskOwner: Codable, Equatable, Sendable {
    let tenantID: String
    let userUID: String
}

nonisolated enum TaskStorageError: Error {
    case invalidFields, invalidArchive, unavailable, changed, missing
    var message: String {
        switch self {
        case .invalidFields: return "请填写事项标题，并检查输入长度"
        case .invalidArchive: return "事项数据无法读取，原文件已保留，请重试"
        case .unavailable: return "事项暂不可用，请重新打开页面"
        case .changed: return "事项已发生变化，请返回后重新编辑"
        case .missing: return "事项已删除"
        }
    }
}
