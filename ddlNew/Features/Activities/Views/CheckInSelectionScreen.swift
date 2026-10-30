//
//  CheckInSelectionScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct CheckInSelectionScreen: View {
    @EnvironmentObject private var store: ClubStore
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                let activities = store.activities(with: [.registered, .checkedIn])
                if activities.isEmpty {
                    EmptyClubState(title: "暂无可签到的活动", message: "报名后，到达集合点即可输入活动签到码。")
                }
                ForEach(activities) { activity in
                    NavigationLink(destination: CheckInScreen(activity: activity)) {
                        HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(activity.title).font(.headline)
                                    Text(activity.date).font(.caption).foregroundColor(ClubTheme.secondary)
                                }
                                Spacer()
                                if store.status(activity) == .checkedIn { Text("已签到").font(.caption).foregroundStyle(ClubTheme.secondary) }
                                Image(systemName: "chevron.right").font(.subheadline).foregroundStyle(ClubTheme.secondary)
                            }.frame(maxWidth: .infinity, minHeight: 74, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Divider().overlay(ClubTheme.border)
                }
            }.padding(20)
        }.background(ClubTheme.card.ignoresSafeArea()).foregroundStyle(ClubTheme.ink).tint(ClubTheme.teal).toolbar(.visible, for: .navigationBar).navigationTitle("选择签到活动").navigationBarTitleDisplayMode(.inline)
    }
}
