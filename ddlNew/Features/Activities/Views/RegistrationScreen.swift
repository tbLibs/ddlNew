//
//  RegistrationScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct RegistrationScreen: View {
    @EnvironmentObject private var store: ClubStore
    @Environment(\.dismiss) private var dismiss
    let activity: ClubActivity
    @State private var accepted = false
    @State private var saving = false
    @State private var completed = false
    var body: some View {
        Group {
            if completed {
                RegistrationResultScreen(activity: activity) { dismiss() }
            } else {
                ClubScroll {
                    VStack(spacing: 16) {
                        ClubCard(padding: 24, highlighted: true) {
                            VStack(alignment: .leading, spacing: 16) {
                                ClubBadge(text: activity.category)
                                Text(activity.title).font(.system(size: 25, weight: .bold))
                                Text("\(activity.date) · \(activity.meetingPoint)").font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
                            }
                        }
                        ClubCard {
                            VStack(alignment: .leading, spacing: 24) {
                                Text("报名会员").font(.system(size: 17, weight: .semibold))
                                HStack(spacing: 12) {
                                    MemberAvatar()
                                    VStack(alignment: .leading, spacing: 7) {
                                        Text("林夏").font(.system(size: 15, weight: .semibold))
                                        Text("会员卡号 YS****18").font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
                                    }
                                    Spacer()
                                    ClubBadge(text: "本人")
                                }
                            }.padding(.vertical, 4)
                        }
                        ClubCard {
                            VStack(alignment: .leading, spacing: 18) {
                                Text("参与确认").font(.system(size: 17, weight: .semibold))
                                Toggle(isOn: $accepted) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("我已阅读参与须知").font(.system(size: 15, weight: .semibold))
                                        Text("取消报名请至少提前12小时").font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
                                    }
                                }.tint(ClubTheme.teal).accessibilityIdentifier("acceptRules")
                                Text(activity.notice).font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
                            }
                        }
                        Button {
                            saving = true
                            Task {
                                await store.register(activity)
                                saving = false
                                completed = true
                            }
                        } label: {
                            HStack { if saving { ProgressView().tint(.white) } else { ClubIcon(name: "check", size: 14) }; Text(activity.capacity > 0 ? "确认报名" : "确认加入候补") }
                        }.buttonStyle(ClubButtonStyle()).disabled(!accepted || saving).padding(.top, 4)
                            .accessibilityIdentifier("confirmRegistration")
                    }.padding(20)
                }
            }
        }
        .navigationTitle(completed ? "" : "确认报名").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("关闭报名页面")
            }
        }
        .interactiveDismissDisabled(saving)
    }
}
