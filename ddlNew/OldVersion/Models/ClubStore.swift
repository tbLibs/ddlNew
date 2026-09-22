import Foundation
import Combine
import WCDBSwift

enum SessionStage { case splash, restoreFailed, invite, login, member }
enum MemberTab: String, CaseIterable, Identifiable {
    case home = "首页", activities = "活动", messages = "消息", contacts = "通讯录", club = "俱乐部", profile = "我的"
    var id: Self { self }
    var icon: String {
        switch self { case .home: return "home"; case .activities: return "calendar"; case .messages: return "messages"; case .contacts: return "contacts"; case .club: return "users"; case .profile: return "person" }
    }
}
nonisolated enum Participation: String, Codable, Sendable {
    case available, registered, waiting, checkedIn, ended
    var title: String {
        switch self {
        case .available: return "可报名"
        case .registered: return "已报名"
        case .waiting: return "候补中"
        case .checkedIn: return "已签到"
        case .ended: return "已结束"
        }
    }
}

struct ClubActivity: Identifiable, Hashable {
    let id: String
    let title: String
    let category: String
    let date: String
    let place: String
    let meetingPoint: String
    let capacity: Int
    let requirement: String
    let notice: String
    let checkInCode: String
    let checkInTime: String
    static let samples: [ClubActivity] = [
        .init(id: "hike", title: "周六日落轻徒步", category: "户外 · 轻徒步", date: "10月16日 16:30", place: "北山森林公园", meetingPoint: "北山游客中心", capacity: 4, requirement: "6公里轻徒步，需要基础体能", notice: "请穿防滑运动鞋，携带饮用水。取消报名请至少提前12小时。", checkInCode: "6812", checkInTime: "16:00–16:45"),
        .init(id: "ride", title: "城市夜骑 · 江畔线", category: "户外 · 骑行", date: "10月15日 19:30", place: "滨江广场", meetingPoint: "滨江广场", capacity: 8, requirement: "自备自行车与头盔，适合有骑行经验的会员", notice: "请检查车灯和刹车，全程佩戴头盔，遵守领队指引。取消报名请至少提前12小时。", checkInCode: "6812", checkInTime: "19:00–19:45"),
        .init(id: "bird", title: "森林观鸟晨行", category: "自然 · 观鸟", date: "10月24日 06:30", place: "东湖湿地入口", meetingPoint: "东湖湿地入口", capacity: 0, requirement: "适合所有会员，请轻声观察，保护自然", notice: "建议携带望远镜、饮用水与防蚊用品。候补名额会按顺序通知。", checkInCode: "6812", checkInTime: "06:00–06:45")
    ]
}

nonisolated struct ClubSnapshot: Codable, Sendable {
    var connected = false
    var signedIn = false
    var participation: [String: Participation] = ["hike": .available, "ride": .registered, "bird": .waiting]
    // Optional for compatibility with snapshots saved before account deletion existed.
    var accountDeleted: Bool? = nil
}

nonisolated final class ClubStateRow: TableCodable {
    var id: Int = 1
    var payload: String = ""
    enum CodingKeys: String, CodingTableKey {
        typealias Root = ClubStateRow
        case id, payload
        nonisolated(unsafe) static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(id, isPrimary: true)
        }
    }
}

/// Database work stays off the main actor; passwords are never persisted.
actor ClubRepository {
    private var database: Database?
    private func open() throws -> Database {
        if let database { return database }
        var directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("ClubMember", isDirectory: true)
        #if DEBUG
        // A UUID-scoped database gives UI tests isolation while retaining relaunch coverage.
        if let value = ProcessInfo.processInfo.environment["CLUB_UI_TEST_DATABASE_ID"], let id = UUID(uuidString: value) {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("ClubTests-\(id.uuidString)", isDirectory: true)
        }
        #endif
        let protection: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: protection)
        try FileManager.default.setAttributes(protection, ofItemAtPath: directory.path)
        // Apply protection to files created by earlier versions as well as new databases.
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            where file.lastPathComponent.hasPrefix("membership.sqlite") {
            try FileManager.default.setAttributes(protection, ofItemAtPath: file.path)
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        let db = Database(at: directory.appendingPathComponent("membership.sqlite").path)
        try db.create(table: "member_state", of: ClubStateRow.self)
        database = db
        return db
    }
    func load() throws -> ClubSnapshot {
        let row: ClubStateRow? = try open().getObject(fromTable: "member_state")
        guard let row, let data = row.payload.data(using: .utf8) else { return ClubSnapshot() }
        return try JSONDecoder().decode(ClubSnapshot.self, from: data)
    }
    func save(_ snapshot: ClubSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        let row = ClubStateRow()
        row.payload = String(decoding: data, as: UTF8.self)
        try open().insertOrReplace(row, intoTable: "member_state")
    }
}

@MainActor final class ClubStore: ObservableObject {
    @Published var stage: SessionStage = .splash
    @Published var selectedTab: MemberTab = .home
    @Published private(set) var snapshot = ClubSnapshot()
    @Published var toastMessage = ""
    @Published var showToast = false
    let activities = ClubActivity.samples
    private let repository = ClubRepository()
    private var restored = false
    func restore() async {
        guard !restored else { return }
        restored = true
        do { snapshot = try await repository.load() }
        catch {
            // Do not overwrite an unreadable database with a fresh account state.
            restored = false
            stage = .restoreFailed
            return
        }
        stage = snapshot.signedIn ? .member : (snapshot.connected ? .login : .invite)
    }
    func connect(code: String) async -> Bool {
        try? await Task.sleep(nanoseconds: 750_000_000)
        guard code == "100001" else { return false }
        snapshot.connected = true
        await persist()
        stage = .login
        return true
    }
    func login(card: String, password: String) async -> Bool {
        try? await Task.sleep(nanoseconds: 500_000_000)
        guard snapshot.accountDeleted != true, card == "YS20260018", password == "123456" else { return false }
        snapshot.signedIn = true
        await persist()
        stage = .member
        return true
    }
    func signOut(changeClub: Bool = false) async {
        snapshot.signedIn = false
        if changeClub { snapshot.connected = false }
        selectedTab = .home
        await persist()
        stage = changeClub ? .invite : .login
    }
    func deleteAccount() async throws {
        let deleted = ClubSnapshot(connected: false, signedIn: false, participation: [:], accountDeleted: true)
        // Commit first: a failed write must not look like successful deletion.
        try await repository.save(deleted)
        snapshot = deleted
        selectedTab = .home
        stage = .invite
        notify("本机账号已注销")
    }
    func status(_ activity: ClubActivity) -> Participation { snapshot.participation[activity.id] ?? .available }
    func activities(with states: Set<Participation>) -> [ClubActivity] { activities.filter { states.contains(status($0)) } }
    func register(_ activity: ClubActivity) async {
        guard status(activity) == .available else { return }
        snapshot.participation[activity.id] = activity.capacity > 0 ? .registered : .waiting
        await persist()
    }
    func cancel(_ activity: ClubActivity) async {
        guard [.registered, .waiting].contains(status(activity)) else { return }
        snapshot.participation[activity.id] = .available
        await persist()
        notify("已取消参与")
    }
    func checkIn(_ activity: ClubActivity, code: String) async -> Bool {
        guard status(activity) == .registered, code == activity.checkInCode else { return false }
        snapshot.participation[activity.id] = .checkedIn
        await persist()
        notify("签到成功，享受这次活动吧")
        return true
    }
    func notify(_ text: String) { toastMessage = text; showToast = true }
    private func persist() async {
        do { try await repository.save(snapshot) }
        catch { notify("本地保存失败，变更仅保留在本次使用中") }
    }
}
