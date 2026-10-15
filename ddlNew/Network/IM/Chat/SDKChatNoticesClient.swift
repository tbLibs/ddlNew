//
//  SDKChatNoticesClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import NoaChatCore

@MainActor final class SDKChatNoticesClient: ChatNoticesClient {
    private let client = SDKChatClient(validSession: { ChatRuntime.shared.isCurrent($0) })
    private var context: ChatContext?
    private var sdk: NoaIMSDKManager { NoaIMSDKManager.sharedTool() }

    /// 绑定真实群会话，不独立认证或创建另一数据库。
    func open(_ context: ChatContext) { close(); self.context = context; client.observe(context: context, onEvent: { _ in }) }
    /// 群公告分页20条，界面保留置顶和普通公告顺序。
    func load(page: Int) async throws -> [ChatGroupNotice] {
        guard let context else { throw ChatClientError.sessionExpired }
        let json = try await client.request(context: context) { success, failure in
            self.sdk.groupCheckGroupNotice(with: NSMutableDictionary(dictionary: ["groupId": context.route.id, "userUid": context.userUID, "pageNumber": page, "pageSize": 20, "pageStart": (page - 1) * 20]), onSuccess: success, onFailure: failure)
        }
        return try ChatGroupNoticePayload.notices(from: json)
    }
    /// 仅群信息决定公告管理入口，不依赖成员或禁言请求，提交仍独立重新核权。
    func managementRole() async throws -> Int {
        guard let context else { throw ChatClientError.sessionExpired }
        let group = try await client.request(context: context) { success, failure in
            self.sdk.getGroupInfo(with: ["groupId": context.route.id, "userUid": context.userUID], onSuccess: success, onFailure: failure)
        }
        return ChatGroupNoticePayload.managementRole(from: group)
    }
    /// 创建编辑删除前再从服务器核对角色，降权不沿用旧页面能力。
    func save(_ notice: ChatGroupNotice?, content: String, pinned: Bool, deleting: Bool = false, sendMessage: Bool = false) async throws {
        guard let context else { throw ChatClientError.sessionExpired }
        let group = try await client.request(context: context) { success, failure in self.sdk.getGroupInfo(with: ["groupId": context.route.id, "userUid": context.userUID], onSuccess: success, onFailure: failure) }
        let role = (group["userGroupRole"] as? NSNumber)?.intValue ?? Int(group["userGroupRole"] as? String ?? "") ?? 0
        guard [1, 2].contains(role), (group["userInGroup"] as? NSNumber)?.boolValue == true else { throw ChatClientError.permission("群管理权限已变化") }
        guard deleting || !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ChatClientError.permission("公告内容不能为空") }
        let values: [String: Any]
        if deleting {
            guard let notice else { throw ChatClientError.invalidResponse }
            values = ["groupId": context.route.id, "userUid": context.userUID, "noticeId": notice.id]
        } else {
            values = ChatGroupNoticePayload.saveParameters(notice: notice, content: content, pinned: pinned, sendMessage: sendMessage, groupID: context.route.id, userUID: context.userUID)
        }
        _ = try await client.request(context: context) { success, failure in
            let params = NSMutableDictionary(dictionary: values)
            if deleting { self.sdk.groupDeleteGroupNotice(with: params, onSuccess: success, onFailure: failure) }
            else if notice != nil { self.sdk.groupChangeGroupNotice(with: params, onSuccess: success, onFailure: failure) }
            else { self.sdk.groupCreateGroupNotice(with: params, onSuccess: success, onFailure: failure) }
        }
    }
    /// 正文打开后查询当前公告版本，列表摘要不能替代真实详情。
    func detail(_ notice: ChatGroupNotice) async throws -> ChatGroupNotice {
        guard let context else { throw ChatClientError.sessionExpired }
        let row = try await client.request(context: context) { success, failure in
            self.sdk.groupCheckOneGroupNotice(with: NSMutableDictionary(dictionary: ["groupId": context.route.id, "userUid": context.userUID, "noticeId": notice.id]), onSuccess: success, onFailure: failure)
        }
        return try ChatGroupNoticePayload.notice(from: row, fallback: notice)
    }

    /// 用户打开正文后报告公告已读，取消列表浏览不自动上报。
    func read(_ notice: ChatGroupNotice) async throws {
        guard let context else { throw ChatClientError.sessionExpired }
        _ = try await client.request(context: context) { success, failure in self.sdk.groupReadGroupNotice(with: NSMutableDictionary(dictionary: ["groupId": context.route.id, "userUid": context.userUID, "noticeId": notice.id]), onSuccess: success, onFailure: failure) }
    }
    /// 离开页和退出认证使所有公告回调失效。
    func close() { client.stop(); context = nil }
}
