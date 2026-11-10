//
//  SDKMiniAppClient.swift
//  ddlNew
//
//  Created by taobo on 2026/11/09.
//
import Foundation
import NoaChatCore
@MainActor final class SDKMiniAppClient: MiniAppClient {
    private var waiters: [UUID: SDKChatRequestWaiter<Any>] = [:]
    private var revision = UUID()
    private let transfer = SDKChatMediaClient()
    private func validate(_ context: ChatContext, _ run: UUID) throws {
        try Task.checkCancellation()
        let sdk = NoaIMSDKManager.sharedTool()
        guard run == revision, ChatRuntime.shared.isCurrent(context), sdk.myUserID() == context.userUID,
              sdk.isUserDatabaseReady(), UserSessionStore.shared.currentUser?.userUID == context.userUID,
              OSSConnectionBootstrap.shared.current?.lastLiceseId == context.tenantID else { throw CancellationError() }
    }
    private func request(_ context: ChatContext, submit: @escaping (@escaping LingIMSuccessCallback, @escaping LingIMFailureCallback) -> Void) async throws -> Any {
        let run = revision; try validate(context, run)
        let id = UUID(); let waiter = SDKChatRequestWaiter<Any>(); waiters[id] = waiter
        defer { waiters[id] = nil }
        let value = try await waiter.run {
            submit({ data, _ in Task { @MainActor in waiter.finish(.success(data ?? NSNull())) } },
                   { code, message, _ in Task { @MainActor in waiter.finish(.failure(MiniAppError.invalid(message ?? L10n.tr("应用请求失败（\(code)）")))) } })
        }
        try validate(context, run); return value
    }
    func list(page: Int, context: ChatContext) async throws -> MiniAppPage {
        let value = try await request(context) { success, failure in NoaIMSDKManager.sharedTool().imMiniAppList(with: NSMutableDictionary(dictionary: ["userUid": context.userUID, "pageNumber": page, "pageSize": 50, "pageStart": (page - 1) * 50]), onSuccess: success, onFailure: failure) }
        return try MiniAppPage.parse(value, page: page)
    }
    func save(_ draft: MiniAppDraft, editing: MiniAppRecord?, context: ChatContext) async throws {
        guard let website = MiniAppWebPolicy.entryURL(draft.url) else { throw MiniAppError.invalid(L10n.tr("请输入有效的网站地址")) }
        var fields: [String: Any] = ["qaName": draft.name.trimmingCharacters(in: .whitespacesAndNewlines), "qaAppUrl": website.absoluteString, "qaAppPic": draft.icon, "qaPwdOpen": draft.passwordEnabled ? 1 : 0, "qaPwd": draft.passwordEnabled ? draft.password : ""]
        if let editing { fields["qaUuid"] = editing.id; fields["qaPwdBefore"] = draft.passwordBefore }
        let value = try await request(context) { success, failure in
            let sdk = NoaIMSDKManager.sharedTool(); let params = NSMutableDictionary(dictionary: fields)
            if editing != nil { sdk.imMiniAppEdit(with: params, onSuccess: success, onFailure: failure) }
            else { sdk.imMiniAppCreate(with: params, onSuccess: success, onFailure: failure) }
        }
        try accepted(value)
    }
    private func accepted(_ value: Any) throws { if let n = value as? NSNumber, !n.boolValue { throw MiniAppError.invalid(L10n.tr("服务器未接受操作")) } }
    func delete(_ record: MiniAppRecord, context: ChatContext) async throws {
        let value = try await request(context) { success, failure in NoaIMSDKManager.sharedTool().imMiniAppDelete(with: NSMutableDictionary(dictionary: ["qaUuid": record.id, "appType": record.appType]), onSuccess: success, onFailure: failure) }; try accepted(value)
    }
    func detail(id: String, password: String, context: ChatContext) async throws -> MiniAppRecord {
        let value = try await request(context) { success, failure in NoaIMSDKManager.sharedTool().imMiniAppDetail(with: NSMutableDictionary(dictionary: ["qaUuid": id, "qaPwd": password]), onSuccess: success, onFailure: failure) }
        let result = try MiniAppPage.record(value); guard result.id == id else { throw MiniAppError.invalid(L10n.tr("应用标识不匹配")) }; return result
    }
    func upload(_ file: URL, context: ChatContext) async throws -> String {
        let run = revision; try validate(context, run)
        let size = Int64(try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        guard size > 0, size <= 50 * 1024 else { throw MiniAppError.invalid(L10n.tr("图标不得超过50KiB")) }
        let result = try await transfer.upload(ChatAttachment(file: file, type: ChatAttachment.miniAppIconType, name: file.lastPathComponent, bytes: size), context: context) { _ in }
        try validate(context, run); return result.resource
    }
    func cancel() { revision = UUID(); waiters.values.forEach { $0.cancel() }; waiters.removeAll(); transfer.cancel() }
}
