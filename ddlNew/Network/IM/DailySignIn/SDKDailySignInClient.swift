import Foundation
import ObjectiveC
import NoaChatCore

/// 复用xgd五个签到接口与SDK本地提醒表，不另建签到数据库。
@MainActor final class SDKDailySignInClient: DailySignInClient {
    private var waiters: [UUID: SDKChatRequestWaiter<Any>] = [:]
    private var revision = UUID()
    private func validate(_ context: ChatContext, _ run: UUID) throws {
        try Task.checkCancellation()
        let sdk = NoaIMSDKManager.sharedTool()
        guard run == revision, ChatRuntime.shared.isCurrent(context), sdk.myUserID() == context.userUID,
              sdk.isUserDatabaseReady(), UserSessionStore.shared.currentUser?.userUID == context.userUID,
              OSSConnectionBootstrap.shared.current?.lastLiceseId == context.tenantID else { throw CancellationError() }
    }
    private func request(_ context: ChatContext, submit: @escaping (@escaping LingIMSuccessCallback, @escaping LingIMFailureCallback) -> Void) async throws -> Any {
        let run = revision; try validate(context, run)
        let id = UUID(), waiter = SDKChatRequestWaiter<Any>(); waiters[id] = waiter
        defer { waiters[id] = nil }
        let result = try await waiter.run {
            submit({ data, _ in Task { @MainActor in waiter.finish(.success(data ?? NSNull())) } },
                   { code, message, _ in
                let text = message.flatMap { $0.isEmpty ? nil : $0 } ?? L10n.tr("签到请求失败（\(code)），请重试")
                Task { @MainActor in waiter.finish(.failure(DailySignInError.message(text))) }
            })
        }
        try validate(context, run); return result
    }
    private func params(_ context: ChatContext, month: SignInMonth? = nil) -> NSMutableDictionary {
        var fields: [String: Any] = ["userUid": context.userUID]
        if let month { fields.merge(month.fields) { _, new in new } }
        return NSMutableDictionary(dictionary: fields)
    }
    func info(context: ChatContext) async throws -> DailySignInInfo {
        let value = try await request(context) { success, failure in
            NoaIMSDKManager.sharedTool().imSignIn(withInfo: self.params(context), onSuccess: success, onFailure: failure)
        }; return try DailySignInInfo.parse(value)
    }
    func records(month: SignInMonth, context: ChatContext) async throws -> DailySignInRecords {
        let value = try await request(context) { success, failure in
            NoaIMSDKManager.sharedTool().imSignIn(withRecord: self.params(context, month: month), onSuccess: success, onFailure: failure)
        }; return try DailySignInRecords.parse(value)
    }
    func points(month: SignInMonth, context: ChatContext) async throws -> DailySignInPoints {
        let value = try await request(context) { success, failure in
            NoaIMSDKManager.sharedTool().imSignIn(withIntergralDetail: self.params(context, month: month), onSuccess: success, onFailure: failure)
        }; return try DailySignInPoints.parse(value)
    }
    func rule(context: ChatContext) async throws -> DailySignInRule {
        let value = try await request(context) { success, failure in
            NoaIMSDKManager.sharedTool().imSignIn(withRule: self.params(context), onSuccess: success, onFailure: failure)
        }; return try DailySignInRule.parse(value)
    }
    func sign(context: ChatContext) async throws -> Int64? {
        let value = try await request(context) { success, failure in
            NoaIMSDKManager.sharedTool().imSignInRecord(withSign: self.params(context), onSuccess: success, onFailure: failure)
        }
        return try SignInPayload.receipt(value)
    }
    func reminders(sessionID: String, offset: Int, context: ChatContext) throws -> [DailySignInReminder] {
        let sdk = NoaIMSDKManager.sharedTool()
        objc_sync_enter(sdk); defer { objc_sync_exit(sdk) }
        try validate(context, revision)
        guard !sessionID.isEmpty, offset >= 0 else { throw DailySignInError.invalidResponse }
        let rows = sdk.messageGetSignInHistoryRecord(with: sessionID, offset: offset) as? [NoaIMChatMessageModel] ?? []
        let result = rows.enumerated().map { index, row in
            DailySignInReminder(id: row.serviceMsgID?.isEmpty == false ? row.serviceMsgID! : row.msgID?.isEmpty == false ? row.msgID! : "\(sessionID)-\(offset + index)-\(row.sendTime)", date: Date(timeIntervalSince1970: Double(row.sendTime) / 1000))
        }
        // 与xgd一致，打开助手只清本地提醒；不向普通单群聊已读接口传特殊会话。
        let localSession: LingIMSessionModel? = offset == 0 ? sdk.toolCheckMySession(with: sessionID) : nil
        if let session = localSession, session.sessionUnreadCount > 0 {
            session.sessionUnreadCount = 0
            guard sdk.toolUpdateSession(with: session) else { throw DailySignInError.message(L10n.tr("无法更新本机会话，请刷新确认状态")) }
        }
        return result
    }
    func cancel() { revision = UUID(); waiters.values.forEach { $0.cancel() }; waiters.removeAll() }
}
