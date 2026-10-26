//
//  MassMessagePresentation.swift
//  ddlNew
//
//  Created by taobo on 2026/10/23.
//

import Foundation

/// 仅供现有附件预览使用，不写入聊天库，也不混入普通聊天历史。
enum MassMessagePresentation {
    static func message(_ record: MassMessageRecord, context: ChatContext) -> ChatMessageRecord {
        let body = record.body
        let resource = body[record.type == 5 ? "path" : "name"] ?? ""
        let originalExtension = URL(string: resource)?.pathExtension ?? ""
        let mediaExtension = originalExtension.isEmpty ? (record.type == 2 ? "mp4" : "jpg") : originalExtension
        return ChatMessageRecord(localID: "mass:" + record.id, conversationID: context.route.id,
            senderID: context.userUID, senderName: "我", type: record.type, text: record.summary,
            timestamp: Int64(record.sentAt) ?? 0, state: .sent,
            resource: resource,
            thumbnail: body[record.type == 2 ? "cImg" : "iImg"] ?? "",
            fileName: record.type == 5 ? body["name"] ?? "文件" : (record.type == 2 ? "视频." : "图片.") + mediaExtension,
            size: Int64(body["size"] ?? "") ?? 0, duration: Double(body["length"] ?? "") ?? 0,
            mediaWidth: Double(body[record.type == 2 ? "cWidth" : "width"] ?? "") ?? 0,
            mediaHeight: Double(body[record.type == 2 ? "cHeight" : "height"] ?? "") ?? 0)
    }

    static func time(_ raw: String) -> String {
        guard let number = Double(raw), number > 0 else { return raw.isEmpty ? "时间未知" : raw }
        let date = Date(timeIntervalSince1970: number > 10_000_000_000 ? number / 1000 : number)
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
