//
//  ChatLatestPreference.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

/// 最新消息锚点实际几何，不用非懒加载容器的出现事件推断可见性。
struct ChatLatestPreference: PreferenceKey {
    static var defaultValue = CGRect.zero
    /// 同一聊天只保留当前最新锚点区域。
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}
