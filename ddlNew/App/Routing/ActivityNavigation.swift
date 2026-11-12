//
//  ActivityNavigation.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI
import Combine

/// 每个 Tab 独立持有导航路径，详情返回时保留此前的列表和筛选状态。
@MainActor final class ActivityNavigation: ObservableObject {
    @Published var path = NavigationPath()

    /// 所有主界面push共享实际路径，底栏显隐只根据这份状态判断。
    func open<Route: Hashable>(_ route: Route) {
        path.append(route)
    }
}
