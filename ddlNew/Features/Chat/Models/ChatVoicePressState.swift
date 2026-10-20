//
//  ChatVoicePressState.swift
//  ddlNew
//
//  Created by taobo on 2026/10/19.
//

/// 一次按住只消费一个结束事件，60秒后松手不会重复发送。
struct ChatVoicePressState {
    private(set) var isHolding = false
    private(set) var isInside = true

    mutating func begin() -> Bool {
        guard !isHolding else { return false }
        isHolding = true; isInside = true; return true
    }

    mutating func move(inside: Bool) { if isHolding { isInside = inside } }

    /// nil表示已消费；false取消；true按旧端松手发送。
    mutating func release(inside: Bool) -> Bool? {
        guard isHolding else { return nil }
        cancel(); return inside
    }

    /// 旧端录满60秒直接结束发送，不再等待松手。
    mutating func reachLimit() -> Bool {
        guard isHolding else { return false }
        cancel(); return true
    }

    mutating func cancel() { isHolding = false; isInside = true }
}
