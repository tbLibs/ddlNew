//
//  RegistrationResultScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct RegistrationResultScreen: View {
    @Environment(\.locale) private var localizationLocale
    @EnvironmentObject private var store: ClubStore
    let activity: ClubActivity
    let onDone: () -> Void
    private var waiting: Bool { store.status(activity) == .waiting }
    var body: some View {
        ClubScroll {
            VStack(spacing: 20) {
                ClubIcon(name: waiting ? "clock" : "check", size: 28).foregroundColor(ClubTheme.darkTeal)
                    .frame(width: 72, height: 72).background(ClubTheme.wash).clipShape(RoundedRectangle(cornerRadius: 25)).padding(.top, 48)
                Text(waiting ? L10n.tr("已加入候补") : L10n.tr("报名成功")).font(.system(size: 28, weight: .bold)).padding(.top, 6)
                Text(waiting ? L10n.tr("有空位时将按顺序递补") : L10n.tr("你已加入“\(activity.displayTitle)”")).font(.system(size: 14)).foregroundColor(ClubTheme.secondary)
                ClubCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label { Text(activity.displayDate) } icon: { ClubIcon(name: "calendar") }
                        Text(L10n.tr("\(activity.displayMeetingPoint) · 请提前10分钟到达")).font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
                        Divider()
                        Label { Text(waiting ? L10n.tr("候补已确认") : L10n.tr("报名已确认")) } icon: { ClubIcon(name: "shield") }
                        Text(L10n.tr("活动开始前可查看或取消参与")).font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
                    }.font(.system(size: 15, weight: .medium)).padding(.vertical, 10)
                }
                Button(L10n.tr("查看参与信息"), action: onDone).buttonStyle(ClubButtonStyle())
                    .accessibilityIdentifier("viewParticipation")
            }.padding(.horizontal, 24)
        }
    }
}
