//
//  ChatAttachment.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

struct ChatAttachment: Sendable {
    /// 仅安全表单内部使用的上传类型，不是聊天wire消息类型。
    static let complaintEvidenceType = 102
    /// 个人头像专用上传类型，不属于聊天消息类型。
    static let userAvatarType = 103
    let file: URL
    let type: Int
    let name: String
    let bytes: Int64
    var duration: Double = 0
    var width: Double = 0
    var height: Double = 0
    var previewFile: URL?
}

struct ChatUploadedAttachment: Sendable {
    let resource: String
    let thumbnail: String
}

@MainActor protocol ChatMediaClient: AnyObject {
    /// 上传前与发送前均由真实客户端校验角色、租户和当前登录轮次。
    func upload(_ attachment: ChatAttachment, context: ChatContext, progress: @escaping @MainActor (Double) -> Void) async throws -> ChatUploadedAttachment
    /// 界面取消和退出同步停止该媒体传输。
    func cancel()
}

enum ChatAttachmentPolicy {
    /// 配额以MB转换字节，防止异常服务端大数触发整数溢出。
    static func allowedBytes(_ bytes: Int64, maximumMB: Int64) -> Bool {
        let limit = maximumMB.multipliedReportingOverflow(by: 1024 * 1024)
        return bytes > 0 && maximumMB > 0 && !limit.overflow && bytes <= limit.partialValue
    }
}
