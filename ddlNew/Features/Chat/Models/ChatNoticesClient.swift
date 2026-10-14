//
//  ChatNoticesClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import Foundation

/// 保留SDK为生产数据源，允许离线复验列表、详情与保存回读状态。
@MainActor protocol ChatNoticesClient {
    func open(_ context: ChatContext)
    func load(page: Int) async throws -> [ChatGroupNotice]
    func save(_ notice: ChatGroupNotice?, content: String, pinned: Bool, deleting: Bool, sendMessage: Bool) async throws
    func detail(_ notice: ChatGroupNotice) async throws -> ChatGroupNotice
    func read(_ notice: ChatGroupNotice) async throws
    func close()
}
