//
//  ChatLatestPreference.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

/// 最新消息锚点实际几何，不用非懒加载容器的出现事件推断可见性。
struct ChatLatestPreference: PreferenceKey {
    /// 末条身份随几何一起更新，避免上一批消息的底部位置提前放行新正文。
    nonisolated struct Value: Equatable {
        var frame = CGRect.zero
        var lastMessageID: String?
        /// 缓存和远端补齐分别测量；末条ID相同时也不能复用旧快照的布局。
        var initialHistoryRevision = 0
    }

    static var defaultValue = Value()
    /// 同一聊天只保留当前最新锚点区域。
    static func reduce(value: inout Value, nextValue: () -> Value) { value = nextValue() }
}
