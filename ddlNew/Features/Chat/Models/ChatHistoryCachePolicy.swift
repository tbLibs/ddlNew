//
//  ChatHistoryCachePolicy.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//
import Foundation

enum ChatHistoryCachePolicy {
    /// HTTP等待期间缓存变更、ACK较新或墓碑优先保留SDK最新完整模型。
    nonisolated static func keepCurrent(remote: ChatMessageRecord, current: ChatMessageRecord, atRequest: ChatMessageRecord?) -> Bool {
        guard let atRequest else { return true }
        return current.status.rawValue != 1 || current.timestamp > remote.timestamp || version(current) != version(atRequest)
    }
    /// 比较实际消息字段，排除每次显示映射新建的@片段UUID和作者展示元数据。
    nonisolated private static func version(_ record: ChatMessageRecord) -> [String] {
        var values = [record.localID, record.serverID, String(record.type), record.text, String(record.timestamp), String(record.status.rawValue), record.referenceID,
                      String(record.isRead), String(record.readCount), String(record.totalReadCount), record.resource, record.thumbnail, record.fileName, String(record.size), String(record.duration), String(record.mediaWidth), String(record.mediaHeight), record.stickerID, String(record.isStickerSet), String(record.gameType), record.cardUID, record.latitude, record.longitude, String(record.isEncrypted), String(record.snapchat), String(record.isCompatible)]
        for mention in record.mentions { values += [mention.userUID, mention.name, String(mention.location), String(mention.length)] }
        values.append(String(record.nestedMessages.count))
        for nested in record.nestedMessages { values += version(nested) }
        return values
    }
    /// 请求开始时存在而回写时不存在表示期间被物理删除，禁止重新插入。
    nonisolated static func wasDeletedDuringRequest(current: ChatMessageRecord?, atRequest: ChatMessageRecord?) -> Bool {
        if case .none = current, case .some = atRequest { return true }
        return false
    }
}
