//
//  CheckInScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

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
