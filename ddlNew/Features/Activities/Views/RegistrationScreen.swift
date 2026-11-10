//
//  RegistrationScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct RegistrationScreen: View {
    @Environment(\.locale) private var localizationLocale
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
                                ClubBadge(text: activity.displayCategory)
                                Text(activity.displayTitle).font(.system(size: 25, weight: .bold))
                                Text("\(activity.displayDate) · \(activity.displayMeetingPoint)").font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
                            }
                        }
                        ClubCard {
                            VStack(alignment: .leading, spacing: 24) {
                                Text(L10n.tr("报名会员")).font(.system(size: 17, weight: .semibold))
                                HStack(spacing: 12) {
                                    MemberAvatar()
                                    VStack(alignment: .leading, spacing: 7) {
                                        Text(store.memberDisplayName).font(.system(size: 15, weight: .semibold))
                                        Text(store.snapshot.activeAccount.map { L10n.tr("账号 \($0)") } ?? L10n.tr("会员卡号 YS****18")).font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
                                    }
                                    Spacer()
                                    ClubBadge(text: L10n.tr("本人"))
                                }
                            }.padding(.vertical, 4)
                        }
                        ClubCard {
                            VStack(alignment: .leading, spacing: 18) {
                                Text(L10n.tr("参与确认")).font(.system(size: 17, weight: .semibold))
                                Toggle(isOn: $accepted) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(L10n.tr("我已阅读参与须知")).font(.system(size: 15, weight: .semibold))
                                        Text(L10n.tr("取消报名请至少提前12小时")).font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
                                    }
                                }.tint(ClubTheme.teal).accessibilityIdentifier("acceptRules")
                                Text(activity.displayNotice).font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
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
                            HStack { if saving { ProgressView().tint(.white) } else { ClubIcon(name: "check", size: 14) }; Text(activity.capacity > 0 ? L10n.tr("确认报名") : L10n.tr("确认加入候补")) }
                        }.buttonStyle(ClubButtonStyle()).disabled(!accepted || saving).padding(.top, 4)
                            .accessibilityIdentifier("confirmRegistration")
                    }.padding(20)
                }
            }
        }
        .navigationTitle(completed ? "" : L10n.tr("确认报名")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel(L10n.tr("关闭报名页面"))
            }
        }
        .interactiveDismissDisabled(saving)
    }
}
