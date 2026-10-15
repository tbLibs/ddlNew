//
//  ChatScrollGeometry.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//

import SwiftUI

/// 滚动中的原始坐标只供命令式定位和可见判断，不逐像素发布整页更新。
@MainActor final class ChatScrollGeometry {
    var messageFrames: [String: CGRect] = [:]
    var latestLayout = ChatLatestPreference.Value()
}
