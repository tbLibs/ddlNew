//
//  FriendApplicationViewport.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

/// 原生List当前可见范围与各行范围统一使用全局坐标。
struct FriendApplicationViewport: PreferenceKey {
    static var defaultValue = CGRect.zero
    /// 列表只产生一个可见区域，保留本轮测量值。
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}
