//
//  OriginalLoginView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI
import SwiftUIX
import SwiftUIIntrospect

/// 保留旧演示注册与登录；当前应用入口只使用 LoginView 的真实 AUTH。
struct OriginalLoginView: View {
    private enum LoginNotice: String, Identifiable {
        case agreement, credentials
        var id: Self { self }
    }

    @EnvironmentObject private var store: ClubStore
    @StateObject private var keyboard = Keyboard()
    @State private var card = ""
    @State private var password = ""
    @State private var invalid = false
    @State private var loading = false
    @State private var showRegistration = false
    @State private var acceptedDocuments = false
    @State private var loginNotice: LoginNotice?
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
                        ClubField(title: "会员卡号或账号", placeholder: "请输入会员卡号或账号", icon: "person", text: $card, focus: $cardFocused)
                        ClubField(title: "密码", placeholder: "请输入密码", icon: "lock", text: $password, secure: true, focus: $passwordFocused).padding(.top, 12)
                        LegalAgreement(isAccepted: $acceptedDocuments)
                            .disabled(loading).padding(.top, 6)
                        Button(loading ? "正在登录…" : "登录") {
                            dismissKeyboard()
                            guard acceptedDocuments else { loginNotice = .agreement; return }
                            let submittedAccount = card.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !submittedAccount.isEmpty, !password.isEmpty else { loginNotice = .credentials; return }
                            invalid = false; loading = true
                            Task {
                                let success = await store.login(card: submittedAccount, password: password)
                                invalid = !success
                                if !success { password = "" }
                                loading = false
                            }
                        }.buttonStyle(ClubButtonStyle()).disabled(loading)
                            .padding(.top, 10).accessibilityIdentifier("login")
                        Button("注册账号") {
                            dismissKeyboard()
                            showRegistration = true
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ClubTheme.darkTeal)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .disabled(loading)
                        .accessibilityIdentifier("registerAccount")
                    }
                }
                HStack(spacing: 32) {
                    Button("更换俱乐部") { dismissKeyboard(); Task { await store.signOut(changeClub: true) } }
                }.font(.system(size: 14)).foregroundColor(ClubTheme.darkTeal).padding(.top, 5).disabled(loading)
            }.padding(.horizontal, 24).padding(.bottom, 28).frame(maxWidth: 460).frame(maxWidth: .infinity)
        }.background(ClubBackground())
            .messagingLoadingToast(loading, title: "正在登录")
            .messagingFeedbackToast(invalid ? "账号或密码不正确，请重新输入。" : nil)
            .introspect(.scrollView, on: .iOS(.v15, .v16, .v17, .v18, .v26, .v27)) { $0.keyboardDismissMode = .interactive }
            .modifier(ClubKeyboardDismissal(isFocused: cardFocused || passwordFocused, dismiss: dismissKeyboard))
            .alert(item: $loginNotice) { notice in
                switch notice {
                case .agreement:
                    return Alert(title: Text("请先勾选协议"),
                                 message: Text("请阅读并勾选同意《隐私政策》和《使用支持》后再登录。"),
                                 primaryButton: .default(Text("勾选")) { acceptedDocuments = true },
                                 secondaryButton: .cancel(Text("取消")))
                case .credentials:
                    return Alert(title: Text("请输入账号和密码"),
                                 message: Text("请填写会员卡号或账号及密码后再登录。"),
                                 dismissButton: .default(Text("知道了")))
                }
            }
            .sheet(isPresented: $showRegistration) {
                AccountRegistrationScreen { registeredAccount in
                    card = registeredAccount
                    password = ""
                    invalid = false
                }
            }
    }
}

struct AccountRegistrationScreen: View {
    @EnvironmentObject private var store: ClubStore
    @Environment(\.dismiss) private var dismiss
    let onRegistered: (String) -> Void
    @State private var account = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var saving = false
    @State private var errorMessage: String?

    private var normalizedAccount: String { account.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canRegister: Bool {
        !normalizedAccount.isEmpty && !password.isEmpty && password == confirmation && !saving
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 22) {
                    ClubLogo(size: 60).padding(.top, 28)
                    Text("创建账号").font(.system(size: 25, weight: .bold))
                    Text("设置账号和密码，注册成功后返回登录页")
                        .font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
                    ClubCard(padding: 20) {
                        VStack(alignment: .leading, spacing: 14) {
                            ClubField(title: "账号", placeholder: "请输入账号", icon: "person", text: $account, identifier: "registerAccountField")
                            ClubField(title: "密码", placeholder: "请输入密码", icon: "lock", text: $password, secure: true, identifier: "registerPasswordField", contentType: .newPassword)
                            ClubField(title: "确认密码", placeholder: "请再次输入密码", icon: "lock", text: $confirmation, secure: true, identifier: "registerConfirmationField", contentType: .newPassword)
                            if !confirmation.isEmpty && password != confirmation {
                                Text("两次输入的密码不一致")
                                    .font(.system(size: 12)).foregroundColor(ClubTheme.error)
                            }

                            Button(saving ? "正在注册…" : "注册") {
                                guard canRegister else { return }
                                saving = true
                                errorMessage = nil
                                let submittedAccount = normalizedAccount
                                let submittedPassword = password
                                Task {
                                    do {
                                        try await store.registerAccount(account: submittedAccount, password: submittedPassword)
                                        onRegistered(submittedAccount)
                                        dismiss()
                                    }
                                    catch {
                                        errorMessage = "注册未完成，请重试。"
                                        saving = false
                                    }
                                }
                            }
                            .buttonStyle(ClubButtonStyle())
                            .disabled(!canRegister)
                            .accessibilityIdentifier("submitRegistration")
                        }
                    }.disabled(saving)
                }
                .padding(.horizontal, 24).padding(.bottom, 28)
                .frame(maxWidth: 460).frame(maxWidth: .infinity)
            }
            .background(ClubBackground())
            .navigationTitle("注册账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(saving) } }
        }
        .navigationViewStyle(.stack)
        .messagingLoadingToast(saving, title: "正在注册")
        .messagingFeedbackToast(errorMessage)
        .interactiveDismissDisabled(saving)
    }
}

private struct LegalAgreement: View {
    @Binding var isAccepted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button { isAccepted.toggle() } label: {
                Image(systemName: isAccepted ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundColor(ClubTheme.darkTeal)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("确认隐私政策和使用支持")
            .accessibilityValue(isAccepted ? "已勾选" : "未勾选")
            .accessibilityAddTraits(isAccepted ? .isSelected : [])
            .accessibilityIdentifier("acceptLegalDocuments")
            VStack(alignment: .leading, spacing: 0) {
                Text("我已阅读并同意以下内容")
                    .font(.footnote).foregroundColor(ClubTheme.secondary)
                LegalEntryLinks()
            }
        }
    }
}
