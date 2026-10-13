//
//  ChatHistoryCategory.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

enum ChatHistoryCategory: String, CaseIterable, Sendable {
    case text = "文字", media = "图片视频", files = "文件"
    nonisolated var types: [Int] { switch self { case .text: return [0, 10]; case .media: return [1, 2]; case .files: return [5] } }
}
struct ChatHistorySearchPage: Sendable { let messages: [ChatMessageRecord]; let nextOffset: Int; let hasMore: Bool }
