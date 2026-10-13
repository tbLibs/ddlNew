//
//  SDKChatNoticesClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import NoaChatCore

@MainActor final class SDKChatNoticesClient {
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
        guard let rows = json["rows"] as? [[String: Any]] else { throw ChatClientError.invalidResponse }
        return rows.compactMap { row in
            let id = row["noticeId"] as? String ?? (row["noticeId"] as? NSNumber)?.stringValue ?? ""
            guard !id.isEmpty else { return nil }
            return ChatGroupNotice(id: id, content: row["noticeContent"] as? String ?? "", author: row["nickName"] as? String ?? "", timestamp: row["createTime"] as? String ?? "", pinned: ((row["isTop"] ?? row["status"]) as? NSNumber)?.intValue == 1 || (row["isTop"] as? String) == "1")
        }
    }
    /// 创建编辑删除前再从服务器核对角色，降权不沿用旧页面能力。
    func save(_ notice: ChatGroupNotice?, content: String, pinned: Bool, deleting: Bool = false, sendMessage: Bool = false) async throws {
        guard let context else { throw ChatClientError.sessionExpired }
        let group = try await client.request(context: context) { success, failure in self.sdk.getGroupInfo(with: ["groupId": context.route.id, "userUid": context.userUID], onSuccess: success, onFailure: failure) }
        let role = (group["userGroupRole"] as? NSNumber)?.intValue ?? Int(group["userGroupRole"] as? String ?? "") ?? 0
        guard [1, 2].contains(role), (group["userInGroup"] as? NSNumber)?.boolValue == true else { throw ChatClientError.permission("群管理权限已变化") }
        guard deleting || !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ChatClientError.permission("公告内容不能为空") }
        var values: [String: Any] = ["groupId": context.route.id, "userUid": context.userUID, "noticeContent": content, "isTop": pinned ? "1" : "0", "isSendMsg": sendMessage ? "1" : "0", "translateContent": ""]
        if let notice { values["noticeId"] = notice.id }
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
        guard let content = row["noticeContent"] as? String else { throw ChatClientError.unavailable("公告已删除或当前无权访问") }
        return ChatGroupNotice(id: notice.id, content: content, author: row["nickName"] as? String ?? notice.author, timestamp: row["createTime"] as? String ?? notice.timestamp, pinned: ((row["isTop"] ?? row["status"]) as? NSNumber)?.intValue == 1 || (row["isTop"] as? String) == "1")
    }

    /// 用户打开正文后报告公告已读，取消列表浏览不自动上报。
    func read(_ notice: ChatGroupNotice) async throws {
        guard let context else { throw ChatClientError.sessionExpired }
        _ = try await client.request(context: context) { success, failure in self.sdk.groupReadGroupNotice(with: NSMutableDictionary(dictionary: ["groupId": context.route.id, "userUid": context.userUID, "noticeId": notice.id]), onSuccess: success, onFailure: failure) }
    }
    /// 离开页和退出认证使所有公告回调失效。
    func close() { client.stop(); context = nil }
}
