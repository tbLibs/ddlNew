//
//  OriginalLoginView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI
import SwiftUIX
import SwiftUIIntrospect

/// 保留原版登录演示页面；应用入口只使用真实 AUTH 流程的 LoginView。
struct OriginalLoginView: View {
    @EnvironmentObject private var store: ClubStore
    @StateObject private var keyboard = Keyboard()
    @State private var card = ""
    @State private var password = ""
    @State private var invalid = false
    @State private var loading = false
    @State private var showHelp = false
    @FocusState private var cardFocused: Bool
    @FocusState private var passwordFocused: Bool

    private func dismissKeyboard() {
        cardFocused = false
        passwordFocused = false
        keyboard.dismiss()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("远山").font(.system(size: 15, weight: .semibold)).foregroundColor(ClubTheme.darkTeal)
                        .frame(width: 74, height: 74).background(ClubTheme.wash).clipShape(RoundedRectangle(cornerRadius: 25))
                    Text("远山户外俱乐部").font(.system(size: 25, weight: .bold))
                    Text("会员登录").font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
                }.padding(.top, 48)
                ClubCard(padding: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        ClubField(title: "会员卡号", placeholder: "请输入会员卡号", icon: "person", text: $card, focus: $cardFocused)
                        Text("例如 YS20260018，会员卡号区分字母和数字").font(.system(size: 11)).foregroundColor(ClubTheme.secondary)
                        ClubField(title: "密码", placeholder: "请输入密码", icon: "lock", text: $password, secure: true, focus: $passwordFocused).padding(.top, 12)
                        Text(invalid ? (store.snapshot.accountDeleted == true ? "本机账号已注销，无法再次登录。" : "会员卡号或密码不正确，请重新输入。") : "密码由俱乐部创建会员账户时提供")
                            .font(.system(size: 11)).foregroundColor(invalid ? ClubTheme.error : ClubTheme.secondary)
                            .accessibilityIdentifier("loginHint")
                        Button(loading ? "正在登录…" : "登录") {
                            dismissKeyboard()
                            loading = true
                            Task {
                                let success = await store.login(card: card.trimmingCharacters(in: .whitespaces), password: password)
                                invalid = !success
                                if !success { password = "" }
                                loading = false
                            }
                        }.buttonStyle(ClubButtonStyle()).disabled(card.isEmpty || password.isEmpty || loading)
                            .padding(.top, 10).accessibilityIdentifier("login")
                    }
                }
                HStack(spacing: 32) {
                    Button("登录遇到问题？") { dismissKeyboard(); showHelp = true }
                    Button("更换俱乐部") { dismissKeyboard(); Task { await store.signOut(changeClub: true) } }
                }.font(.system(size: 14)).foregroundColor(ClubTheme.darkTeal).padding(.top, 5).disabled(loading)
                LegalEntryLinks()
            }.padding(.horizontal, 24).padding(.bottom, 28).frame(maxWidth: 460).frame(maxWidth: .infinity)
        }.background(ClubBackground())
            .introspect(.scrollView, on: .iOS(.v15, .v16, .v17, .v18, .v26, .v27)) { $0.keyboardDismissMode = .interactive }
            .modifier(ClubKeyboardDismissal(isFocused: cardFocused || passwordFocused, dismiss: dismissKeyboard))
            .sheet(isPresented: $showHelp) { InformationSheet(page: .loginHelp) }
    }
}
