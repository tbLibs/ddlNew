//
//  CheckInSelectionScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct CheckInSelectionScreen: View {
    @Environment(\.locale) private var localizationLocale
    @EnvironmentObject private var store: ClubStore
    var body: some View {
        ClubScroll {
            VStack(spacing: 14) {
                let activities = store.activities(with: [.registered, .checkedIn])
                if activities.isEmpty {
                    EmptyClubState(title: L10n.tr("暂无可签到的活动"), message: L10n.tr("报名后，到达集合点即可输入活动签到码。"))
                }
                ForEach(activities) { activity in
                    NavigationLink(destination: CheckInScreen(activity: activity)) {
                        ClubCard {
                            HStack(spacing: 14) {
                                ClubIcon(name: "scan", size: 24)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(activity.displayTitle).font(.headline)
                                    Text(activity.displayDate).font(.caption).foregroundColor(ClubTheme.secondary)
                                }
                                Spacer()
                                ClubBadge(text: store.status(activity) == .checkedIn ? L10n.tr("已签到") : L10n.tr("去签到"))
                            }.padding(.vertical, 10)
                        }
                    }.buttonStyle(.plain)
                }
            }.padding(20)
        }.toolbar(.visible, for: .navigationBar).navigationTitle(L10n.tr("选择签到活动")).navigationBarTitleDisplayMode(.inline)
    }
}
