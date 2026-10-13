//
//  SDKChatHistorySearchClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import NoaChatCore
import ObjectiveC

@MainActor final class SDKChatHistorySearchClient {
    /// 分类查询覆盖当前账号全部SDK本地缓存，每次结果50条并保留后续游标。
    func search(context: ChatContext, category: ChatHistoryCategory, keyword: String, memberIDs: [String], offset: Int) async throws -> ChatHistorySearchPage {
        guard ChatRuntime.shared.isCurrent(context) else { throw ChatClientError.sessionExpired }
        if context.route.kind == .group, !memberIDs.isEmpty {
            let group: LingIMGroupModel? = NoaIMSDKManager.sharedTool().toolCheckMyGroup(with: context.route.id)
            guard group?.closeSearchUser == false else { throw ChatClientError.permission("本群已关闭按成员搜索") }
        }
        let page = try await Task.detached {
            let sdk = NoaIMSDKManager.sharedTool(); objc_sync_enter(sdk); defer { objc_sync_exit(sdk) }
            guard sdk.myUserID() == context.userUID, sdk.isUserDatabaseReady() else { throw ChatClientError.sessionExpired }
            var cursor = offset; var matching: [ChatMessageRecord] = []; var more = true
            // LIKE通配符不作为用户查询语义，先按类型/成员分页再做字面文本匹配。
            while matching.count < 50 && more {
                try Task.checkCancellation()
                let rows = sdk.toolGetChatMessageHistory(with: context.route.id, offset: cursor, messageType: category.types.map(NSNumber.init(value:)), textMessageLike: nil, userIdList: memberIDs) as? [NoaIMChatMessageModel] ?? []
                if rows.isEmpty { more = false; break }
                for model in rows {
                    cursor += 1
                    let item = SDKChatMessageMapper.record(model, userUID: context.userUID)
                    if item.isBody && (keyword.isEmpty || item.displayText.localizedCaseInsensitiveContains(keyword)) { matching.append(item) }
                    if matching.count == 50 { break }
                }
                if matching.count < 50 && rows.count < 50 { more = false }
            }
            return ChatHistorySearchPage(messages: matching, nextOffset: cursor, hasMore: more)
        }.value
        guard ChatRuntime.shared.isCurrent(context) else { throw ChatClientError.sessionExpired }
        return page
    }

    /// 成员筛选来自当前SDK成员表；关闭成员搜索时不暴露选择入口。
    func members(context: ChatContext) async throws -> [ChatGroupMember] {
        let sdk = NoaIMSDKManager.sharedTool()
        guard ChatRuntime.shared.isCurrent(context), context.route.kind == .group else { return [] }
        let group: LingIMGroupModel? = sdk.toolCheckMyGroup(with: context.route.id)
        guard group?.closeSearchUser == false else { return [] }
        let client = SDKChatSettingsClient(); defer { client.close() }
        let detail = try await client.load(context: context).group
        guard ChatRuntime.shared.isCurrent(context), let detail, detail.isActive, (sdk.toolCheckMyGroup(with: context.route.id) as LingIMGroupModel?)?.closeSearchUser == false else { return [] }
        return detail.members
    }
}
