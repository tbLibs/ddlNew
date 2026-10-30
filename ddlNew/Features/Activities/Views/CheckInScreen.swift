//
//  CheckInScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct CheckInScreen: View {
    @EnvironmentObject private var store: ClubStore
    @Environment(\.dismiss) private var dismiss
    let activity: ClubActivity
    @State private var code = ""
    @State private var invalid = false
    @State private var saving = false
    @FocusState private var codeFocused: Bool
    private var checkedIn: Bool { store.status(activity) == .checkedIn }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if checkedIn {
                    VStack(spacing: 24) {
                        Image(systemName: "checkmark.circle").font(.system(size: 56, weight: .light)).foregroundStyle(ClubTheme.teal).accessibilityHidden(true)
                        Text("签到成功").font(.title2.weight(.semibold))
                        Text(activity.title).font(.subheadline).foregroundStyle(ClubTheme.secondary)
                        Text("签到记录已保存，祝你度过愉快的活动时光。").font(.subheadline).foregroundStyle(ClubTheme.secondary).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity).padding(.top, 64)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(activity.title).font(.headline)
                        Text("签到时间 \(activity.checkInTime)").font(.subheadline).foregroundStyle(ClubTheme.secondary)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("4位签到码").font(.footnote.weight(.medium)).foregroundStyle(ClubTheme.secondary)
                        TextField("输入签到码", text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode)
                            .focused($codeFocused).padding(.horizontal, 16).frame(minHeight: 52)
                            .background(ClubTheme.wash, in: RoundedRectangle(cornerRadius: 10))
                            .accessibilityLabel("4位签到码").accessibilityIdentifier("checkInCode")
                        if invalid { Text("签到码不正确").font(.subheadline).foregroundStyle(ClubTheme.error) }
                    }.padding(.top, 20)
                    Text("请到达集合点后完成签到；遇到问题请联系活动负责人。").font(.subheadline).foregroundStyle(ClubTheme.secondary)
                }
            }.padding(20).frame(maxWidth: 600, alignment: .leading).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(ClubTheme.card.ignoresSafeArea()).foregroundStyle(ClubTheme.ink).tint(ClubTheme.teal)
        .safeAreaInset(edge: .bottom) {
            if !checkedIn {
                Button("确认签到") {
                    codeFocused = false
                    saving = true
                    Task { invalid = !(await store.checkIn(activity, code: code)); saving = false }
                }.buttonStyle(ClubButtonStyle()).disabled(code.count != 4 || saving)
                    .accessibilityIdentifier("confirmCheckIn")
                    .frame(maxWidth: 600).padding(20).frame(maxWidth: .infinity).background(ClubTheme.card)
            } else {
                Button("完成") { dismiss() }.buttonStyle(ClubButtonStyle())
                    .frame(maxWidth: 600).padding(20).frame(maxWidth: .infinity).background(ClubTheme.card)
            }
        }
        .modifier(ClubKeyboardDismissal(isFocused: codeFocused) { codeFocused = false })
        .toolbar(.visible, for: .navigationBar).navigationTitle("个人签到").navigationBarTitleDisplayMode(.inline)
        .onChange(of: code) { code = String($0.filter(\.isNumber).prefix(4)); invalid = false }
    }
}
