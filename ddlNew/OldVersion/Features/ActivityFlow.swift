import SwiftUI

struct ActivityDetailScreen: View {
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
                    ClubBadge(text: activity.category)
                    Text(activity.title).font(.system(size: 29, weight: .bold))
                }.padding(24).frame(maxWidth: .infinity, minHeight: 230, alignment: .bottomLeading).background(ClubTheme.wash)
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top, spacing: 10) {
                        fact("活动时间", icon: "calendar", value: activity.date)
                        fact("集合地点", icon: "map", value: activity.meetingPoint)
                    }
                    Text("参与状态").font(.system(size: 18, weight: .semibold))
                    ClubCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(statusHeadline).font(.system(size: 15, weight: .semibold))
                                    Text(status == .waiting ? "有空位时将按顺序递补" : "活动开始前可查看参与信息")
                                        .font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
                                }
                                Spacer()
                                ClubBadge(text: status.title)
                            }
                            Divider()
                            VStack(alignment: .leading, spacing: 6) {
                                Text("会员可参加").font(.system(size: 15, weight: .semibold))
                                Text(activity.requirement).font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
                            }
                        }
                    }
                    Text("参与须知").font(.system(size: 18, weight: .semibold))
                    ClubCard { Text(activity.notice).font(.system(size: 15)).foregroundColor(ClubTheme.secondary).lineSpacing(5) }
                    if status == .registered || status == .waiting {
                        Button("取消\(status == .waiting ? "候补" : "报名")", role: .destructive) { showCancellation = true }
                            .font(.system(size: 14)).frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                }.padding(.horizontal, 20)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("报名状态").font(.system(size: 10)).foregroundColor(ClubTheme.secondary)
                    Text(status == .available ? (activity.capacity > 0 ? "剩\(activity.capacity)位" : "名额已满") : status.title)
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
        // Keep the active navigation link alive when the participation status changes.
        .background(NavigationLink(destination: CheckInScreen(activity: activity), isActive: $showCheckIn) { EmptyView() }.hidden())
        .navigationBarHidden(false).navigationBarTitleDisplayMode(.inline).navigationTitle("活动详情")
        .modifier(ClubDetailChrome())
        .sheet(isPresented: $showConfirmation) {
            NavigationView { RegistrationScreen(activity: activity) }.navigationViewStyle(.stack)
        }
        .alert("确认取消参与？", isPresented: $showCancellation) {
            Button("保留", role: .cancel) { }
            Button("确认取消", role: .destructive) { Task { await store.cancel(activity) } }
        } message: { Text("取消后将更新本机参与状态，不会向俱乐部发送请求。") }
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
        ClubCard {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 10)).foregroundColor(ClubTheme.secondary)
                ClubIcon(name: icon, size: 14).foregroundColor(ClubTheme.secondary)
                Text(value).font(.system(size: 15, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, minHeight: 55, alignment: .leading)
        }
    }
}

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

struct CheckInScreen: View {
    @EnvironmentObject private var store: ClubStore
    let activity: ClubActivity
    @State private var code = ""
    @State private var invalid = false
    @State private var saving = false
    @FocusState private var codeFocused: Bool
    private var checkedIn: Bool { store.status(activity) == .checkedIn }
    var body: some View {
        ClubScroll {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeading(eyebrow: activity.title, title: "活动签到").padding(.bottom, 6)
                ClubCard(padding: 28, highlighted: true) {
                    VStack(spacing: 20) {
                        ClubBadge(text: checkedIn ? "签到已完成" : "签到开放中")
                        Text(checkedIn ? "签到成功" : "输入活动签到码").font(.system(size: 25, weight: .bold))
                        Text("签到时间 \(activity.checkInTime)").font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
                        if !checkedIn {
                            ZStack {
                                HStack(spacing: 9) {
                                    ForEach(0..<4, id: \.self) { index in
                                        Text(index < code.count ? String(Array(code)[index]) : " ")
                                            .font(.system(size: 28, weight: .medium)).frame(maxWidth: .infinity).frame(height: 60)
                                            .background(ClubTheme.card.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 16))
                                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(ClubTheme.teal.opacity(0.4), lineWidth: 1))
                                    }
                                }.accessibilityHidden(true)
                                TextField("4位签到码", text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode)
                                    .focused($codeFocused).foregroundColor(.clear).tint(.clear).opacity(0.025)
                                    .accessibilityLabel("4位签到码").accessibilityIdentifier("checkInCode")
                                    .frame(height: 60)
                            }.contentShape(Rectangle()).onTapGesture { codeFocused = true }
                            Button("确认签到") {
                                codeFocused = false
                                saving = true
                                Task { invalid = !(await store.checkIn(activity, code: code)); saving = false }
                            }.buttonStyle(ClubButtonStyle()).disabled(code.count != 4 || saving).padding(.top, 14)
                                .accessibilityIdentifier("confirmCheckIn")
                        } else {
                            ClubIcon(name: "check", size: 36).foregroundColor(ClubTheme.darkTeal).padding(22)
                        }
                    }.frame(maxWidth: .infinity)
                }
                ClubCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(checkedIn ? "已签到" : (invalid ? "签到码不正确" : "尚未签到")).font(.system(size: 15, weight: .semibold))
                            .foregroundColor(invalid && !checkedIn ? ClubTheme.error : ClubTheme.ink)
                        Text(checkedIn ? "签到记录已保存，祝你度过愉快的活动时光。" : "请到达集合点后完成签到；遇到问题请联系活动负责人。")
                            .font(.system(size: 12)).foregroundColor(ClubTheme.secondary).lineSpacing(4)
                    }
                }
            }.padding(20)
        }
        .modifier(ClubKeyboardDismissal(isFocused: codeFocused) { codeFocused = false })
        .navigationBarHidden(false).navigationTitle("个人签到").navigationBarTitleDisplayMode(.inline)
        .modifier(ClubDetailChrome())
        .onChange(of: code) { code = String($0.filter(\.isNumber).prefix(4)); invalid = false }
    }
}
