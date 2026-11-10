//
//  ContactBusinessError.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// 区分审核受理、重复审核、会话失效和普通失败。
enum ContactBusinessError: LocalizedError {
    case server(code: Int, message: String)
    case invalidInput(String)
    case staleSession
    case malformedResponse
    var errorDescription: String? {
        switch self {
        case .server(let code, let message):
            if code == 44016 { return L10n.tr("申请提交成功，系统稍后处理；好友和聊天记录暂时保留。") }
            if code == 44017 { return L10n.tr("已提交申请，请等待审核；好友和聊天记录暂时保留。") }
            return message.isEmpty ? L10n.tr("操作失败，请稍后重试") : message
        case .invalidInput(let message): return message
        case .staleSession: return L10n.tr("登录状态已变化，请重新打开页面")
        case .malformedResponse: return L10n.tr("服务器返回格式错误，请稍后重试")
        }
    }
}
