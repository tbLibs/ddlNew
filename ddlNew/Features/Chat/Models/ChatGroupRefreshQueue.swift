//
//  ChatGroupRefreshQueue.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//
import Foundation

struct ChatGroupRefreshQueue: Sendable {
    private var running: Set<String> = []
    private var pending: Set<String> = []
    /// 不同群独立刷新，同群进行中再次变化仅登记一次后续回读。
    nonisolated mutating func begin(_ groupID: String) -> Bool {
        if running.contains(groupID) { pending.insert(groupID); return false }
        running.insert(groupID); return true
    }
    /// 同群完成后返回是否还需再查一次，不取消其他群等待。
    nonisolated mutating func finish(_ groupID: String) -> Bool { running.remove(groupID); return pending.remove(groupID) != nil }
}
