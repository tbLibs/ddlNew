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
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: waiting ? "clock" : "checkmark.circle")
                    .font(.system(size: 56, weight: .light)).foregroundStyle(ClubTheme.teal).accessibilityHidden(true)
                Text(waiting ? "已加入候补" : "报名成功").font(.title2.weight(.semibold))
                Text(activity.title).font(.subheadline).foregroundStyle(ClubTheme.secondary)
                Text(waiting ? "有空位时将按顺序递补" : "\(activity.meetingPoint) · 请提前10分钟到达")
                    .font(.subheadline).foregroundStyle(ClubTheme.secondary).multilineTextAlignment(.center)
                Text(activity.date).font(.subheadline).foregroundStyle(ClubTheme.secondary)
                Text("活动开始前可查看或取消参与").font(.subheadline).foregroundStyle(ClubTheme.secondary)
            }.padding(.horizontal, 20).padding(.top, 92).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.background(ClubTheme.card.ignoresSafeArea()).foregroundStyle(ClubTheme.ink)
        .safeAreaInset(edge: .bottom) {
            Button("完成", action: onDone).buttonStyle(ClubButtonStyle()).accessibilityIdentifier("viewParticipation")
                .frame(maxWidth: 600).padding(20).frame(maxWidth: .infinity).background(ClubTheme.card)
        }
    }
}
