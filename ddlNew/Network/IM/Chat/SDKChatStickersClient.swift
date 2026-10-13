//
//  SDKChatStickersClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//
import Foundation
import NoaChatCore

@MainActor final class SDKChatStickersClient: ChatStickersClient {
    private let client = SDKChatClient(validSession: { ChatRuntime.shared.isCurrent($0) })
    private var context: ChatContext?
    /// 收藏按20分页，已用表情包仅首批加载并按资源身份去重。
    func load(context: ChatContext, page: Int) async throws -> ChatStickerPage {
        if self.context != context { client.observe(context: context, onEvent: { _ in }); self.context = context }
        let response = try await client.request(context: context) { success, failure in
            NoaIMSDKManager.sharedTool().imSdkUserGetCollectStickersList(NSMutableDictionary(dictionary: ["lastUpdateTime": 0, "pageNumber": page, "pageSize": 20, "pageStart": (page - 1) * 20, "userUid": context.userUID]), onSuccess: success, onFailure: failure)
        }
        let rows = response["rows"] as? [[String: Any]] ?? response["_value"] as? [[String: Any]] ?? []
        var values = rows.compactMap { sticker($0, fromPackage: false) }
        if page == 1 {
            let response = try await client.request(context: context) { success, failure in
                NoaIMSDKManager.sharedTool().imSdkUserFindUsedStickersPackageList(NSMutableDictionary(dictionary: ["lastUpdateTime": 0, "userUid": context.userUID]), onSuccess: success, onFailure: failure)
            }
            let packages = response["_value"] as? [[String: Any]] ?? response["rows"] as? [[String: Any]] ?? []
            for package in packages { values += (package["stickersList"] as? [[String: Any]] ?? []).compactMap { sticker($0, fromPackage: true) } }
        }
        try client.validate(context)
        var keys: Set<String> = []
        return ChatStickerPage(stickers: values.filter { keys.insert($0.id).inserted }, hasMore: rows.count == 20)
    }
    /// 资源字段按真实SDK表情模型映射，失效空地址不制造占位消息。
    private func sticker(_ row: [String: Any], fromPackage: Bool) -> ChatSticker? {
        let resource = row["contentUrl"] as? String ?? ""
        let id = row["stickersId"] as? String ?? (row["stickersId"] as? NSNumber)?.stringValue ?? row["id"] as? String ?? (row["id"] as? NSNumber)?.stringValue ?? row["stickersKey"] as? String ?? ""
        guard (row["isDeleted"] as? NSNumber)?.boolValue != true, !resource.isEmpty, !id.isEmpty else { return nil }
        return ChatSticker(id: id, title: row["name"] as? String ?? "贴纸", resource: resource, thumbnail: row["thumbUrl"] as? String ?? "", width: (row["width"] as? NSNumber)?.doubleValue ?? 0, height: (row["height"] as? NSNumber)?.doubleValue ?? 0, bytes: (row["size"] as? NSNumber)?.int64Value ?? 0, fromPackage: fromPackage)
    }
    /// 关闭停止等待，旧账号结果不能进入新表情页。
    func close() { client.stop(); context = nil }
}
