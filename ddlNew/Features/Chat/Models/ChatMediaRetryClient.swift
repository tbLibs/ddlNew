//
//  ChatMediaRetryClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/20.
//

import Foundation

/// 重传仍走当前页面的上传器，与普通附件共用取消及AUTH归属。
@MainActor protocol ChatMediaRetryClient: AnyObject {
    func retry(_ message: ChatMessageRecord, context: ChatContext,
               stage: @escaping (ChatMessageRecord) throws -> Void,
               discard: @escaping (String) -> Void,
               failed: @escaping (ChatMessageRecord) -> Void,
               enqueue: @escaping (ChatMessageRecord) throws -> Void) async
}

