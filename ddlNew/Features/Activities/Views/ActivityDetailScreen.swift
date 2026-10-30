//
//  ActivityDetailScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct ActivityDetailScreen: View {
    @EnvironmentObject private var store: ClubStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let activity: ClubActivity
    @State private var showConfirmation = false
    @State private var showCancellation = false
    @State private var showCheckIn = false
    private var status: Participation { store.status(activity) }
    var body: some View {
        ClubScroll {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(activity.title).font(.title.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(activity.category).font(.subheadline).foregroundStyle(ClubTheme.secondary)
                }.padding(.horizontal, 20).padding(.top, 24)
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 20) {
                        fact("活动时间", icon: "calendar", value: activity.date)
                        fact("集合地点", icon: "map", value: activity.meetingPoint)
                    }
                VStack(alignment: .leading, spacing: 5) {
                    Text("报名状态").font(.caption).foregroundColor(ClubTheme.secondary)
                    Text(status == .available ? (activity.capacity > 0 ? "剩\(activity.capacity)位" : "名额已满") : status.title)
                        .font(.subheadline.weight(.semibold))
                }.frame(minWidth: 90, alignment: .leading)

                    Text("参与状态").font(.headline.weight(.semibold))
                    Group {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(statusHeadline).font(.body.weight(.semibold))
                                    Text(status == .waiting ? "有空位时将按顺序递补" : "活动开始前可查看参与信息")
                                        .font(.subheadline).foregroundColor(ClubTheme.secondary)
                                }
                                Spacer()
                                ClubBadge(text: status.title)
                            }
                            Divider()
                            VStack(alignment: .leading, spacing: 6) {
                                Text("会员可参加").font(.body.weight(.semibold))
                                Text(activity.requirement).font(.subheadline).foregroundColor(ClubTheme.secondary)
                            }
                        }
                    }
                    Text("参与须知").font(.headline.weight(.semibold))
                    Text(activity.notice).font(.body).foregroundColor(ClubTheme.secondary).lineSpacing(5)
                    if status == .registered || status == .waiting {
                        Button("取消\(status == .waiting ? "候补" : "报名")", role: .destructive) { showCancellation = true }
                            .font(.body).frame(maxWidth: .infinity, minHeight: 44).padding(.vertical, 8)
                    }
                }.padding(.horizontal, 20)
            }
        }
        .safeAreaInset(edge: .bottom) {
                Button {
                    if status == .available { showConfirmation = true }
                    if status == .registered { showCheckIn = true }
                } label: {
                    HStack { ClubIcon(name: "check", size: 14); Text(actionTitle) }
                }.buttonStyle(ClubButtonStyle()).disabled(status != .available && status != .registered)
                .frame(maxWidth: 600).padding(.horizontal, 20).padding(.vertical, 12).frame(maxWidth: .infinity).background(ClubTheme.card)
        }
        // 参与状态改变后仍在当前导航栈中打开签到页，避免详情页被提前关闭。
        .navigationDestination(isPresented: $showCheckIn) {
            CheckInScreen(activity: activity)
        }
        .toolbar(.visible, for: .navigationBar).navigationBarTitleDisplayMode(.inline).navigationTitle("活动详情")
        .sheet(isPresented: $showConfirmation) {
            NavigationView { RegistrationScreen(activity: activity) }.navigationViewStyle(.stack)
        }
        .alert("确认取消参与？", isPresented: $showCancellation) {
            Button("保留", role: .cancel) { }
            Button("确认取消", role: .destructive) { Task { await store.cancel(activity) } }
        } message: { Text("取消后，活动参与状态将更新。") }
    }
    private var statusHeadline: String {
        switch status {
        case .available: return activity.capacity > 0 ? "剩余\(activity.capacity)个名额" : "名额已满，可加入候补"
        case .registered: return "报名已确认"
        case .waiting: return "正在候补队列中"
        case .checkedIn: return "已完成活动签到"
        case .ended: return "活动已结束"
        }
    }
    private var actionTitle: String {
        switch status {
        case .available: return activity.capacity > 0 ? "立即报名" : "加入候补"
        case .registered: return "前往签到"
        case .waiting: return "候补等待中"
        case .checkedIn: return "已完成签到"
        case .ended: return "活动已结束"
        }
    }
    private func fact(_ title: String, icon: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ClubIcon(name: icon, size: 22).foregroundStyle(ClubTheme.teal).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.caption).foregroundStyle(ClubTheme.secondary)
                Text(value).font(.body).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}
