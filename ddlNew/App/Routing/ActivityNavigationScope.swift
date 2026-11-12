//
//  ActivityNavigationScope.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 每个Tab独立持有导航栈，底栏显隐统一跟随实际路径。
struct ActivityNavigationScope<Content: View>: View {
    @StateObject private var navigation = ActivityNavigation()
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack(path: $navigation.path) {
            content
        }
        // 注入整个导航栈，直接指定目标页面的 NavigationLink 也能取得同一份导航对象。
        .environmentObject(navigation)
        .toolbar(navigation.path.isEmpty ? .visible : .hidden, for: .tabBar)
    }
}
