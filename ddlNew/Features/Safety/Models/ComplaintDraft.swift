//
//  ComplaintDraft.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import Foundation

/// 草稿只在当前表单内存中保留，上传完成数量与用户选择数量必须一致。
nonisolated struct ComplaintDraft: Sendable {
    var reason: ComplaintReason = .harmful
    var content = ""
    var email = ""
    var images: [URL] = []
    var validationMessage: String? {
        if images.isEmpty || images.count > 9 { return "请选择1至9张图片证据" }
        if content.utf16.count > 200 { return "投诉内容最多200字" }
        if !hasValidEmail { return "请输入有效的联系邮箱" }
        return nil
    }
    var hasValidEmail: Bool {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return address.range(of: "^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9\\-]+(?:\\.[A-Za-z0-9\\-]+)*\\.[A-Za-z]{2,}$", options: .regularExpression) != nil
    }
    /// 上传前校验表单与目标，避免无效输入先产生孤立证据文件。
    func validate(target: ComplaintTarget, userUID: String) throws {
        if let validationMessage { throw ComplaintError.invalidInput(validationMessage) }
        guard !userUID.isEmpty else { throw ComplaintError.invalidInput("登录状态已变化") }
        switch target {
        case .user(let id): guard !id.isEmpty, id != userUID, id != "100002" else { throw ComplaintError.invalidInput("当前用户不可投诉") }
        case .group(let id): guard !id.isEmpty else { throw ComplaintError.invalidInput("群信息已失效") }
        case .general: break
        }
    }
    /// 构造旧系统投诉字段，不混用域名反馈字段，也不将空目标降级为通用投诉。
    func parameters(target: ComplaintTarget, userUID: String, nickname: String, account: String, uploaded: [String]) throws -> [String: String] {
        try validate(target: target, userUID: userUID)
        guard uploaded.count == images.count,
              uploaded.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.contains(",") }) else { throw ComplaintError.invalidInput("图片证据尚未全部上传，请重试") }
        var result = ["userUid": userUID, "nickname": nickname, "username": account, "ufbImages": uploaded.joined(separator: ","), "ufbContentGroup": reason.rawValue, "ufbUserEmail": email.trimmingCharacters(in: .whitespacesAndNewlines)]
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { result["ufbComment"] = text }
        switch target {
        case .user(let id):
            result["ufbToType"] = "0"; result["ufbToUserId"] = id
        case .group(let id):
            result["ufbToType"] = "1"; result["ufbToGroupId"] = id
        case .general: result["ufbToType"] = "3"
        }
        return result
    }
}
