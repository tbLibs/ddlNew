//
//  FriendApplicationFrames.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

/// 列表行实际屏幕范围用于申请可见已读，预加载行不能扣角标。
struct FriendApplicationFrames: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    /// 以稳定申请身份合并当前渲染行范围。
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) { value.merge(nextValue(), uniquingKeysWith: { _, new in new }) }
}
