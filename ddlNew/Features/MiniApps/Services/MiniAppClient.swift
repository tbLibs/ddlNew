//
//  MiniAppClient.swift
//  ddlNew
//
//  Created by taobo on 2026/11/09.
//
import Foundation
@MainActor protocol MiniAppClient: AnyObject {
    func list(page: Int, context: ChatContext) async throws -> MiniAppPage
    func save(_ draft: MiniAppDraft, editing: MiniAppRecord?, context: ChatContext) async throws
    func delete(_ record: MiniAppRecord, context: ChatContext) async throws
    func detail(id: String, password: String, context: ChatContext) async throws -> MiniAppRecord
    func upload(_ file: URL, context: ChatContext) async throws -> String
    func cancel()
}
@MainActor protocol MiniAppFloatClient {
    func load(context: ChatContext) throws -> [MiniAppFloatRecord]
    func save(_ record: MiniAppFloatRecord, context: ChatContext) throws
    func delete(id: String, context: ChatContext) throws
    func clear(context: ChatContext) throws
}
