//
//  ActivityDetailScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct ActivityDetailScreen: View {
    @Environment(\.locale) private var localizationLocale
    @EnvironmentObject private var store: ClubStore
    let activity: ClubActivity
    @State private var showConfirmation = false
    @State private var showCancellation = false
    @State private var showCheckIn = false
    private var status: Participation { store.status(activity) }
    var body: some View {
        ClubScroll {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 18) {
                    Spacer(minLength: 70)
                    ClubBadge(text: activity.displayCategory)
                    Text(activity.displayTitle).font(.system(size: 29, weight: .bold))
                }.padding(24).frame(maxWidth: .infinity, minHeight: 230, alignment: .bottomLeading).background(ClubTheme.wash)
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top, spacing: 10) {
                        fact(L10n.tr("活动时间"), icon: "calendar", value: activity.displayDate)
                        fact(L10n.tr("集合地点"), icon: "map", value: activity.displayMeetingPoint)
                    }
                    Text(L10n.tr("参与状态")).font(.system(size: 18, weight: .semibold))
                    ClubCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(statusHeadline).font(.system(size: 15, weight: .semibold))
                                    Text(status == .waiting ? L10n.tr("有空位时将按顺序递补") : L10n.tr("活动开始前可查看参与信息"))
                                        .font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
                                }
                                Spacer()
                                ClubBadge(text: status.title)
                            }
                            Divider()
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L10n.tr("会员可参加")).font(.system(size: 15, weight: .semibold))
                                Text(activity.displayRequirement).font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
                            }
                        }
                    }
                    Text(L10n.tr("参与须知")).font(.system(size: 18, weight: .semibold))
                    ClubCard { Text(activity.displayNotice).font(.system(size: 15)).foregroundColor(ClubTheme.secondary).lineSpacing(5) }
                    if status == .registered || status == .waiting {
                        Button(L10n.tr("取消\(status == .waiting ? L10n.tr("候补") : L10n.tr("报名"))"), role: .destructive) { showCancellation = true }
                            .font(.system(size: 14)).frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                }.padding(.horizontal, 20)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.tr("报名状态")).font(.system(size: 10)).foregroundColor(ClubTheme.secondary)
                    Text(status == .available ? (activity.capacity > 0 ? L10n.tr("剩\(activity.capacity)位") : L10n.tr("名额已满")) : status.title)
                        .font(.system(size: 14, weight: .semibold))
                }.frame(minWidth: 90, alignment: .leading)
                Button {
                    if status == .available { showConfirmation = true }
                    if status == .registered { showCheckIn = true }
                } label: {
                    HStack { ClubIcon(name: "check", size: 14); Text(actionTitle) }
                }.buttonStyle(ClubButtonStyle()).disabled(status != .available && status != .registered)
            }.padding(12).background(ClubTheme.card)
        }
        // 参与状态改变后仍在当前导航栈中打开签到页，避免详情页被提前关闭。
        .navigationDestination(isPresented: $showCheckIn) {
            CheckInScreen(activity: activity)
        }
        .toolbar(.visible, for: .navigationBar).navigationBarTitleDisplayMode(.inline).navigationTitle(L10n.tr("活动详情"))
        .sheet(isPresented: $showConfirmation) {
            NavigationView { RegistrationScreen(activity: activity) }.navigationViewStyle(.stack)
        }
        .alert(L10n.tr("确认取消参与？"), isPresented: $showCancellation) {
            Button(L10n.tr("保留"), role: .cancel) { }
            Button(L10n.tr("确认取消"), role: .destructive) { Task { await store.cancel(activity) } }
        } message: { Text(L10n.tr("取消后，活动参与状态将更新。")) }
    }
    private var statusHeadline: String {
        switch status {
        case .available: return activity.capacity > 0 ? L10n.tr("剩余\(activity.capacity)个名额") : L10n.tr("名额已满，可加入候补")
        case .registered: return L10n.tr("报名已确认")
        case .waiting: return L10n.tr("正在候补队列中")
        case .checkedIn: return L10n.tr("已完成活动签到")
        case .ended: return L10n.tr("活动已结束")
        }
    }
    private var actionTitle: String {
        switch status {
        case .available: return activity.capacity > 0 ? L10n.tr("立即报名") : L10n.tr("加入候补")
        case .registered: return L10n.tr("前往签到")
        case .waiting: return L10n.tr("候补等待中")
        case .checkedIn: return L10n.tr("已完成签到")
        case .ended: return L10n.tr("活动已结束")
        }
    }
    private func fact(_ title: String, icon: String, value: String) -> some View {
        ClubCard {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 10)).foregroundColor(ClubTheme.secondary)
                ClubIcon(name: icon, size: 14).foregroundColor(ClubTheme.secondary)
                Text(value).font(.system(size: 15, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, minHeight: 55, alignment: .leading)
        }
    }
}
