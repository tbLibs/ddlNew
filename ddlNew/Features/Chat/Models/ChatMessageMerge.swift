//
//  ChatMessageMerge.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

enum ChatMessageMerge {
    /// 双ID取等价类并保留气泡本地身份；删除撤回与成功ACK不可被旧补页回退。
    nonisolated static func merge(_ current: [ChatMessageRecord], with incoming: [ChatMessageRecord], history: Bool = false, ack: Bool = false) -> [ChatMessageRecord] {
        var result = current
        for var item in incoming where !item.localID.isEmpty || !item.serverID.isEmpty {
            let matches = result.indices.filter { index in
                let old = result[index]
                return (!item.localID.isEmpty && old.localID == item.localID) || (!item.serverID.isEmpty && old.serverID == item.serverID)
            }
            if let first = matches.first {
                let olds = matches.map { result[$0] }
                item.localID = olds.first(where: { !$0.localID.isEmpty })?.localID ?? item.localID
                if let status = olds.first(where: { $0.status != .normal })?.status { item.status = status }
                if olds.contains(where: { $0.state == .sent }) && item.state != .sent {
                    item.state = .sent; item.failure = nil
                    item.serverID = olds.first(where: { !$0.serverID.isEmpty })?.serverID ?? item.serverID
                }
                if let old = olds.first(where: { $0.state == .sent }) {
                    let stale = item.timestamp < old.timestamp
                    if !ack { item.timestamp = old.timestamp }
                    if history || stale { item.type = old.type; item.text = old.text; item.referenceID = old.referenceID; item.mentions = old.mentions; item.nestedMessages = old.nestedMessages; item.resource = old.resource; item.thumbnail = old.thumbnail; item.stickerID = old.stickerID; item.isStickerSet = old.isStickerSet; item.gameType = old.gameType }
                }
                if item.type == 21 && !(item.state == .sending && olds.contains(where: { $0.state == .failed })) && olds.contains(where: {
                    $0.gameAnimationPlayed && $0.type == 21 && $0.gameType == item.gameType && $0.text == item.text
                        && (ack || $0.timestamp == item.timestamp)
                }) { item.gameAnimationPlayed = true }
                item.isRead = item.isRead || olds.contains(where: \.isRead)
                item.readCount = max(item.readCount, olds.map(\.readCount).max() ?? 0)
                result[first] = item
                for index in matches.dropFirst().reversed() { result.remove(at: index) }
            } else { result.append(item) }
        }
        return result.filter { ![9, 13, 15].contains($0.type) }.sorted {
            $0.timestamp == $1.timestamp ? $0.id < $1.id : $0.timestamp < $1.timestamp
        }
    }
}
