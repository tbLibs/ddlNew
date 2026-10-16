//
//  ChatScrollGeometry.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//

import SwiftUI
import Combine

/// 滚动中的原始坐标只供命令式定位和可见判断，不逐像素发布整页更新。
@MainActor final class ChatScrollGeometry {
    var messageFrames: [String: CGRect] = [:]
    var latestLayout = ChatLatestPreference.Value()
    /// 页面只保存引用、不观察发布；游戏气泡单独订阅自己的可见资格。
    @Published var visibleMessageIDs: Set<String> = []

    /// 当前值立即交给新建的懒加载游戏行，其他消息进出视口不重复通知该行。
    func updates(for messageID: String) -> AnyPublisher<Bool, Never> {
        $visibleMessageIDs.map { $0.contains(messageID) }.removeDuplicates().eraseToAnyPublisher()
    }
}
