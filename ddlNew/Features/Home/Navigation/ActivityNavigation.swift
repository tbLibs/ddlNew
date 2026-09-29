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

    func open(_ activity: ClubActivity) {
        path.append(activity)
    }
}
