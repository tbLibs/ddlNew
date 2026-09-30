//
//  RegistrationResultScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct RegistrationResultScreen: View {
    @EnvironmentObject private var store: ClubStore
    let activity: ClubActivity
    let onDone: () -> Void
    private var waiting: Bool { store.status(activity) == .waiting }
    var body: some View {
        ClubScroll {
            VStack(spacing: 20) {
                ClubIcon(name: waiting ? "clock" : "check", size: 28).foregroundColor(ClubTheme.darkTeal)
                    .frame(width: 72, height: 72).background(ClubTheme.wash).clipShape(RoundedRectangle(cornerRadius: 25)).padding(.top, 48)
                Text(waiting ? "已加入候补" : "报名成功").font(.system(size: 28, weight: .bold)).padding(.top, 6)
                Text(waiting ? "有空位时将按顺序递补" : "你已加入“\(activity.title)”").font(.system(size: 14)).foregroundColor(ClubTheme.secondary)
                ClubCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label { Text(activity.date) } icon: { ClubIcon(name: "calendar") }
                        Text("\(activity.meetingPoint) · 请提前10分钟到达").font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
                        Divider()
                        Label { Text(waiting ? "候补已确认" : "报名已确认") } icon: { ClubIcon(name: "shield") }
                        Text("活动开始前可查看或取消参与").font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
                    }.font(.system(size: 15, weight: .medium)).padding(.vertical, 10)
                }
                Button("查看参与信息", action: onDone).buttonStyle(ClubButtonStyle())
                    .accessibilityIdentifier("viewParticipation")
            }.padding(.horizontal, 24)
        }
    }
}
