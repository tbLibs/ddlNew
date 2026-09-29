//
//  ClubHubScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 复用现有活动和俱乐部页面；由当前 Tab 的导航栈提供返回入口。
struct ClubHubScreen: View {
    let destination: ClubHomeDestination

    var body: some View {
        Group {
            switch destination {
            case .activities: ActivitiesScreen()
            case .club: ClubScreen()
            }
        }
        .navigationTitle(destination.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
        .accessibilityIdentifier("home.destination.\(destination == .activities ? "activities" : "club")")
    }
}
