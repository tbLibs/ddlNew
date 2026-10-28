//
//  OwnProfileChange.swift
//  ddlNew
//
//  Created by taobo on 2026/10/28.
//
import Foundation

/// 个人资料只开放头像和昵称，账号与认证凭据不参与编辑。
enum OwnProfileChange: Equatable {
    case nickname(String)
    case avatar(String)

    var fields: [String: String] {
        switch self {
        case .nickname(let value): return ["nickname": value]
        case .avatar(let value): return ["avatar": value]
        }
    }
}

enum OwnProfileError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { switch self { case .invalid(let message): return message } }
}

@MainActor protocol OwnProfileClient: AnyObject {
    func upload(_ file: URL, context: ChatContext) async throws -> String
    func save(_ change: OwnProfileChange, context: ChatContext) async throws
    func apply(_ change: OwnProfileChange, context: ChatContext) throws
    func cancel()
}
