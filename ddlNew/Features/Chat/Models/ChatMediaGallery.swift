//
//  ChatMediaGallery.swift
//  ddlNew
//
//  Created by taobo on 2026/10/16.
//

import Foundation

/// 一次全屏浏览的消息快照，翻页使用消息身份，不使用会随补页变化的数组下标。
struct ChatMediaGallery: Identifiable {
    let selected: ChatMessageRecord
    let items: [ChatMessageRecord]
    var id: String { initialID }
    var initialID: String { selected.id }

    /// 同一会话的图片视频混排；贴纸单独打开，上传占位及撤回资源不进入预览。
    init(selected: ChatMessageRecord, messages: [ChatMessageRecord]) {
        self.selected = selected
        var unique: [String: ChatMessageRecord] = [:]
        let candidates = selected.type == 12 ? [selected] : messages + [selected]
        for message in candidates where message.conversationID == selected.conversationID {
            guard message.status == .normal, message.isCompatible, !message.isMediaUploading,
                  !message.resource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !message.localID.isEmpty || !message.serverID.isEmpty,
                  selected.type == 12 ? message.type == 12 : [1, 2].contains(message.type) else { continue }
            unique[message.id] = message
        }
        items = unique.values.sorted { $0.timestamp == $1.timestamp ? $0.id < $1.id : $0.timestamp < $1.timestamp }
    }

    /// 放大后的拖动留给图片，水平划动留给分页，仅明显向下划动退出。
    static func shouldDismiss(translation: CGSize, zoomScale: CGFloat) -> Bool {
        zoomScale <= 1.01 && translation.height > 100 && translation.height > abs(translation.width) * 1.5
    }
}
