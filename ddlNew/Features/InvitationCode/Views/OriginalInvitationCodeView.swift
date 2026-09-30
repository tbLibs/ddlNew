//
//  OriginalInvitationCodeView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI
import AlertToast
import SwiftUIX
import SwiftUIIntrospect

/// 保留原版邀请码演示页面；应用入口只使用 InvitationCodeView。
struct OriginalInvitationCodeView: View {
    @EnvironmentObject private var store: ClubStore
    @StateObject private var keyboard = Keyboard()
    @State private var code = ""
    @State private var invalid = false
    @State private var connecting = false
    @FocusState private var codeFocused: Bool
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                ClubLogo(size: 60).padding(.top, 48)
                VStack(spacing: 10) {
                    Text("连接你的俱乐部").font(.system(size: 25, weight: .bold))
                    Text(invalid ? "修改邀请码后可以再次尝试" : (connecting ? "正在确认俱乐部信息" : "输入邀请码后进入专属会员空间"))
                        .font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
                }
                ClubCard(padding: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        if invalid {
                            VStack(spacing: 12) {
                                ClubIcon(name: "alert", size: 26).foregroundColor(ClubTheme.darkTeal)
                                    .frame(width: 72, height: 72).background(ClubTheme.wash).clipShape(RoundedRectangle(cornerRadius: 24))
                                Text("未找到对应的俱乐部").font(.system(size: 20, weight: .semibold))
                                Text("请检查邀请码，或向俱乐部工作人员确认。")
                                    .font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
                            }.frame(maxWidth: .infinity).padding(.vertical, 20)
                        }
                        ClubField(title: "俱乐部邀请码", placeholder: "例如 10001", icon: "shield", text: $code, keyboard: .numberPad, focus: $codeFocused)
                        Text("请输入俱乐部提供的邀请码")
                            .font(.system(size: 11)).foregroundColor(ClubTheme.secondary)
                        Button("连接俱乐部") {
                            codeFocused = false
                            keyboard.dismiss()
                            guard !code.isEmpty else { return }
                            let submittedCode = code
                            connecting = true
                            Task {
                                let success = await store.connect(code: submittedCode)
                                connecting = false
                                invalid = !success
                            }
                        }.buttonStyle(ClubButtonStyle()).disabled(code.isEmpty || connecting).padding(.top, 10)
                            .accessibilityIdentifier("connectClub")
                    }
                }.padding(.top, 4)
                if !invalid {
                    Text("没有邀请码？请联系俱乐部工作人员获取。")
                        .font(.system(size: 11)).foregroundColor(ClubTheme.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
                        .background(ClubTheme.card.opacity(0.7)).clipShape(RoundedRectangle(cornerRadius: 15))
                }
                LegalEntryLinks()
                Spacer(minLength: 24)
            }.padding(.horizontal, 24).frame(maxWidth: 460).frame(maxWidth: .infinity)
        }
        .modifier(ClubKeyboardDismissal(isFocused: codeFocused) {
            codeFocused = false
            keyboard.dismiss()
        })
        .background(ClubBackground()).allowsHitTesting(!connecting).blur(radius: connecting ? 2 : 0)
        .introspect(.scrollView, on: .iOS(.v15, .v16, .v17, .v18, .v26, .v27)) { $0.keyboardDismissMode = .interactive }
        .toast(isPresenting: $connecting, duration: 0, tapToDismiss: false) {
            AlertToast(type: .loading, title: "正在连接俱乐部", subTitle: "请稍候，不要关闭 App",
                       style: .style(backgroundColor: ClubTheme.card, titleColor: ClubTheme.ink))
        }
        .onChange(of: code) { value in
            let normalized = value.compactMap(\.wholeNumberValue).filter { (0...9).contains($0) }.map(String.init).joined()
            if code != normalized { code = normalized }
        }
    }
}
