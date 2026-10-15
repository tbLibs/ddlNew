//
//  ComplaintTarget.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import Foundation

/// 系统投诉只支持明确的用户、群和通用反馈；不接邀请码或域名投诉。
nonisolated enum ComplaintTarget: Identifiable, Equatable, Sendable {
    case user(String), group(String), general
    var id: String {
        switch self { case .user(let id): return "user:" + id; case .group(let id): return "group:" + id; case .general: return "general" }
    }
}
