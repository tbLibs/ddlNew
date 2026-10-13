//
//  LoginSecurityNoticeStore.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import Combine

/// 原因独立于会话保存；会话清理和根页面重建不能吞掉认证拒绝提示。
@MainActor
final class LoginSecurityNoticeStore: ObservableObject {
    static let shared = LoginSecurityNoticeStore()
    @Published private(set) var message: String?

    func record(message: String) {
        guard !message.isEmpty else { return }
        self.message = message
    }

    func clear() { message = nil }
}
