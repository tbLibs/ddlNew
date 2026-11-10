import Foundation
import CoreFoundation

/// SDK的游标是毫秒，接口配置的间隔是秒；使用请求开始时间作为成功游标。
nonisolated enum GroupActivitySyncPolicy {
    static func isDue(lastSyncMilliseconds: Int64, nowMilliseconds: Int64, interval: TimeInterval) -> Bool {
        guard interval.isFinite, interval >= 0, nowMilliseconds >= 0 else { return false }
        if lastSyncMilliseconds <= 0 { return true }
        return Double(nowMilliseconds) - Double(lastSyncMilliseconds) > interval * 1000
    }
}

/// 成员接口以pages/currentPage分页，服务端实际页长不保证等于请求pageSize。
nonisolated struct GroupActivityMemberPagination {
    let hasNext: Bool
    init(data: [String: Any], expectedPage: Int, rowCount: Int) throws {
        func integer(_ value: Any?) -> Int? {
            if let number = value as? NSNumber {
                guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
                return Int(number.stringValue)
            }
            return Int(value as? String ?? "")
        }
        guard let pages = integer(data["pages"]), pages >= 0,
              let page = integer(data["currentPage"]), page == expectedPage,
              pages >= page || (pages == 0 && page == 1 && rowCount == 0) else {
            throw GroupActivityScorePage.InvalidPage.malformed
        }
        hasNext = pages > page
        if hasNext && rowCount == 0 { throw GroupActivityScorePage.InvalidPage.malformed }
    }
}

@MainActor final class GroupActivitySyncEngine {
    private var generation = UUID()
    private var jobs: [String: (UUID, Task<Void, Never>)] = [:]
    private var lastAttempt: [String: Int64] = [:]
    private var completed: [String: Int64] = [:]

    func refresh(key: String, lastSyncMilliseconds: Int64, nowMilliseconds: Int64,
                 interval: TimeInterval, valid: @escaping @MainActor () -> Bool,
                 operation: @escaping @MainActor (@escaping @MainActor () -> Bool) async throws -> Void) {
        guard valid(), jobs[key] == nil,
              GroupActivitySyncPolicy.isDue(lastSyncMilliseconds: max(lastSyncMilliseconds, completed[key] ?? 0), nowMilliseconds: nowMilliseconds, interval: interval),
              lastAttempt[key].map({ nowMilliseconds - $0 >= 5000 }) ?? true else { return }
        let run = generation; let id = UUID()
        lastAttempt[key] = nowMilliseconds
        let task = Task { [weak self] in
            guard let self else { return }
            let current: @MainActor () -> Bool = { [weak self] in
                self?.generation == run && self?.jobs[key]?.0 == id && !Task.isCancelled && valid()
            }
            defer { if self.jobs[key]?.0 == id { self.jobs[key] = nil } }
            guard current() else { return }
            do {
                try await operation(current)
                if current() { self.completed[key] = nowMilliseconds }
            } catch { /* 同步失败保留已缓存积分，成员与消息展示不依赖成功。 */ }
        }
        jobs[key] = (id, task)
    }
    func reset() {
        generation = UUID()
        for job in jobs.values { job.1.cancel() }
        jobs.removeAll(); lastAttempt.removeAll(); completed.removeAll()
    }
}

/// 严格解析SDK积分分页结构；损坏页不能当成同步成功并跳过后续增量。
nonisolated struct GroupActivityScorePage {
    let scores: [String: Int]
    let hasNext: Bool
    enum InvalidPage: Error { case malformed }
    init(data: [String: Any], expectedPage: Int) throws {
        func integer(_ value: Any?) -> Int? {
            if let number = value as? NSNumber {
                guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
                return Int(number.stringValue)
            }
            return Int(value as? String ?? "")
        }
        guard let records = data["records"] as? [[String: Any]],
              let pages = integer(data["pages"]), pages >= 0,
              let page = integer(data["current"]), page == expectedPage,
              pages >= page || (pages == 0 && page == 1 && records.isEmpty) else { throw InvalidPage.malformed }
        var values: [String: Int] = [:]
        for record in records {
            let uid: String
            if let raw = record["memberUid"] as? String { uid = raw.trimmingCharacters(in: .whitespacesAndNewlines) }
            else if let raw = record["memberUid"] as? NSNumber,
                    CFGetTypeID(raw) != CFBooleanGetTypeID(), integer(raw) != nil { uid = raw.stringValue }
            else { throw InvalidPage.malformed }
            guard !uid.isEmpty, let score = integer(record["activityScore"]), score >= 0,
                  values[uid] == nil else { throw InvalidPage.malformed }
            values[uid] = score
        }
        scores = values; hasNext = pages > page
        if hasNext && records.isEmpty { throw InvalidPage.malformed }
    }
}
