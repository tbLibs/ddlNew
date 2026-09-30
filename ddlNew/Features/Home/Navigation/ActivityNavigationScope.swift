//
//  ActivityNavigationScope.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 页面与详情共用同一个导航栈，不在二级页面嵌套新的栈或布尔弹出状态。
struct ActivityNavigationScope<Content: View>: View {
    @StateObject private var navigation = ActivityNavigation()
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack(path: $navigation.path) {
            content
                .navigationDestination(for: ClubHomeDestination.self) { destination in
                    ClubHubScreen(destination: destination).environmentObject(navigation)
                }
                .navigationDestination(for: RecordKind.self) { kind in
                    RecordsScreen(kind: kind)
                }
                .navigationDestination(for: ClubActivity.self) { activity in
                    ActivityDetailScreen(activity: activity).environmentObject(navigation)
                }
        }
        // 注入整个导航栈，直接指定目标页面的 NavigationLink 也能取得同一份导航对象。
        .environmentObject(navigation)
    }
}
