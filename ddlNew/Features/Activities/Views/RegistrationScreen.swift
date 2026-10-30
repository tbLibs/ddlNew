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
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        Group {
                            VStack(alignment: .leading, spacing: 16) {
                                Text(activity.title).font(.title2.weight(.bold))
                                Text("\(activity.date) · \(activity.meetingPoint)").font(.subheadline).foregroundColor(ClubTheme.secondary)
                            }
                        }
                        Group {
                            VStack(alignment: .leading, spacing: 24) {
                                Text("报名会员").font(.body.weight(.semibold))
                                HStack(spacing: 12) {
                                    MemberAvatar()
                                    VStack(alignment: .leading, spacing: 7) {
                                        Text(store.memberDisplayName).font(.body.weight(.semibold))
                                        Text(store.snapshot.activeAccount.map { "账号 \($0)" } ?? "会员卡号 YS****18").font(.subheadline).foregroundColor(ClubTheme.secondary)
                                    }
                                    Spacer()
                                    ClubBadge(text: "本人")
                                }
                            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(ClubTheme.wash, in: RoundedRectangle(cornerRadius: 10))
                        }
                        Group {
                            VStack(alignment: .leading, spacing: 18) {
                                Text("参与确认").font(.body.weight(.semibold))
                                Toggle(isOn: $accepted) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("我已阅读参与须知").font(.body.weight(.semibold))
                                        Text("取消报名请至少提前12小时").font(.subheadline).foregroundColor(ClubTheme.secondary)
                                    }
                                }.tint(ClubTheme.teal).accessibilityIdentifier("acceptRules")
                                Text(activity.notice).font(.subheadline).foregroundColor(ClubTheme.secondary)
                            }
                        }

                    }.padding(20).frame(maxWidth: 600, alignment: .leading).frame(maxWidth: .infinity)
                }.background(ClubTheme.card.ignoresSafeArea()).foregroundStyle(ClubTheme.ink).tint(ClubTheme.teal)
                .safeAreaInset(edge: .bottom) {
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
                            .frame(maxWidth: 600).padding(20).frame(maxWidth: .infinity).background(ClubTheme.card)
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
