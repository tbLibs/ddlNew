//
//  SDKMassMessageClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/23.
//

import Foundation
import NoaChatCore

/// 群发使用独立服务端任务，不向每个聊天重复发送或伪造聊天ACK。
@MainActor final class SDKMassMessageClient: MassMessageClient {
    let context: ChatContext
    private var generation = UUID()
    private var pending: [UUID: () -> Void] = [:]
    private var sdk: NoaIMSDKManager { NoaIMSDKManager.sharedTool() }
    init(context: ChatContext) { self.context = context }

    func load(page: Int) async throws -> MassMessagePage<MassMessageRecord> {
        let value = try await request(Self.page(page)) { self.sdk.groupHairGetMessageList(with: $0, onSuccess: $1, onFailure: $2) }
        return try MassMessagePayload.records(value)
    }
    func recipients(record: MassMessageRecord, failures: Bool, page: Int) async throws -> MassMessagePage<MassMessageRecipient> {
        var values = Self.page(page); values["labelId"] = record.labelID; values["taskId"] = record.id
        let value = try await request(values) { params, success, failure in
            if failures { self.sdk.groupHairGetGroupHairErrorUserList(with: params, onSuccess: success, onFailure: failure) }
            else { self.sdk.groupHairGetGroupHairUserList(with: params, onSuccess: success, onFailure: failure) }
        }
        let page = try MassMessagePayload.recipients(value, failures: failures)
        return MassMessagePage(records: page.records.map { recipient in
            var value = recipient
            if value.isGroup, let group = self.sdk.toolCheckMyGroup(with: value.uid) as LingIMGroupModel? {
                value.name = group.groupName ?? value.uid; value.avatar = group.groupAvatar ?? ""
            } else if !value.isGroup, let friend = self.sdk.toolCheckMyFriend(with: value.uid) {
                value.name = friend.disableStatus == 4 ? "账号已注销" : [friend.remarks ?? "", friend.nickname ?? "", value.uid].first { !$0.isEmpty } ?? value.uid
                value.avatar = friend.disableStatus == 4 ? "" : friend.avatar ?? ""
            }
            return value
        }, total: page.total)
    }
    func create(label: String, recipients: [MassMessageRecipient]) async throws -> String {
        try checkPermission()
        let values: [String: Any] = ["label": label, "userUidList": Array(Set(recipients.filter { !$0.isGroup }.map(\.uid))).sorted(),
                                     "groupUidList": Array(Set(recipients.filter(\.isGroup).map(\.uid))).sorted()]
        let value = try await request(values) { self.sdk.groupHairCreateHairGroup(with: $0, onSuccess: $1, onFailure: $2) }
        let id = MassMessagePayload.string(value)
        guard !id.isEmpty, !(value is Bool) else { throw MassMessageError.invalidResponse }
        return id
    }
    func send(labelID: String, type: Int, body: String) async throws {
        try checkPermission()
        let value = try await request(["labelId": labelID, "mtype": type, "body": body]) { self.sdk.groupHairSendHairMessage(with: $0, onSuccess: $1, onFailure: $2) }
        try accepted(value)
        sdk.reconnectSyncSessionsFromServer()
    }
    func delete(_ record: MassMessageRecord) async throws {
        let value = try await request(["taskId": record.id]) { self.sdk.groupHairDeleteHairMessage(with: $0, onSuccess: $1, onFailure: $2) }
        try accepted(value)
    }
    /// 业务成功回调允许旧端空载荷，但明确false不按成功处理。
    private func accepted(_ value: Any) throws {
        if let number = value as? NSNumber, !number.boolValue { throw MassMessageError.invalidResponse }
        if let json = value as? [String: Any], let success = json["success"] as? Bool, !success { throw MassMessageError.invalidResponse }
    }
    private func checkPermission() throws {
        guard UserRoleAuthorityStore.shared.current?.allows("groupHairAssistant") == true else { throw MassMessageError.message("当前账号没有群发权限") }
    }
    private static func page(_ page: Int) -> [String: Any] { ["pageNumber": page, "pageSize": 15, "pageStart": (page - 1) * 15] }

    /// 统一传递原身份，SDK无取消句柄时结束等待并丢弃迟到回调。
    private func request(_ values: [String: Any], start: (NSMutableDictionary, @escaping LingIMSuccessCallback, @escaping LingIMFailureCallback) -> Void) async throws -> Any {
        try validate()
        let run = generation, id = UUID(), waiter = SDKChatRequestWaiter<Data>()
        pending[id] = { waiter.cancel() }; defer { pending[id] = nil }
        var values = values; values["userUid"] = context.userUID
        let data = try await waiter.run {
            start(NSMutableDictionary(dictionary: values), { value, _ in
                let data = try? JSONSerialization.data(withJSONObject: value ?? NSNull(), options: [.fragmentsAllowed])
                Task { @MainActor in
                    if let data { waiter.finish(.success(data)) } else { waiter.finish(.failure(MassMessageError.invalidResponse)) }
                }
            }, { _, message, _ in
                Task { @MainActor in waiter.finish(.failure(MassMessageError.message(message?.isEmpty == false ? message! : "群发请求失败，请重试"))) }
            })
        }
        try validate(); guard run == generation else { throw CancellationError() }
        return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }
    private func validate() throws {
        try Task.checkCancellation()
        guard ChatRuntime.shared.isCurrent(context), sdk.myUserID() == context.userUID, sdk.isUserDatabaseReady() else { throw MassMessageError.sessionExpired }
    }
    func cancel() { generation = UUID(); let actions = Array(pending.values); pending.removeAll(); actions.forEach { $0() } }
}
