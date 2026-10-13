//
//  ChatSticker.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//
import Foundation

struct ChatSticker: Identifiable, Sendable {
    let id: String
    let title: String
    let resource: String
    let thumbnail: String
    let width: Double
    let height: Double
    let bytes: Int64
    let fromPackage: Bool
}
struct ChatStickerPage: Sendable { let stickers: [ChatSticker]; let hasMore: Bool }
@MainActor protocol ChatStickersClient: AnyObject {
    /// 仅查询已有收藏和已用包，商城单独不开放。
    func load(context: ChatContext, page: Int) async throws -> ChatStickerPage
    /// 页面关闭同步撤销SDK等待。
    func close()
}
