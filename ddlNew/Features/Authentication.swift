import SwiftUI
import AlertToast
import SwiftUIX
import SwiftUIIntrospect

struct SplashScreen: UIViewControllerRepresentable {
    // Reuse the system launch storyboard while local session restoration finishes.
    func makeUIViewController(context: Context) -> UIViewController {
        UIStoryboard(name: "LaunchScreen", bundle: .main).instantiateInitialViewController() ?? UIViewController()
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }
}

struct InviteScreen: View {
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
                        ClubField(title: "俱乐部邀请码", placeholder: "例如 100001", icon: "shield", text: $code, keyboard: .numberPad, focus: $codeFocused)
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

struct LoginScreen: View {
    @EnvironmentObject private var store: ClubStore
    @StateObject private var keyboard = Keyboard()
    @State private var card = ""
    @State private var password = ""
    @State private var invalid = false
    @State private var loading = false
    @State private var showHelp = false
    @State private var showRegistration = false
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
                        Text("例如 YS20260018；也可使用本机注册的账号").font(.system(size: 11)).foregroundColor(ClubTheme.secondary)
                        ClubField(title: "密码", placeholder: "请输入密码", icon: "lock", text: $password, secure: true, focus: $passwordFocused).padding(.top, 12)
                        Text(invalid ? (store.snapshot.accountDeleted == true && card == "YS20260018" ? "本机账号已注销，无法再次登录。" : "账号或密码不正确，请重新输入。") : "会员密码由俱乐部提供；本机账号使用注册时设置的密码")
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
                    Button("登录遇到问题？") { dismissKeyboard(); showHelp = true }
                    Button("更换俱乐部") { dismissKeyboard(); Task { await store.signOut(changeClub: true) } }
                }.font(.system(size: 14)).foregroundColor(ClubTheme.darkTeal).padding(.top, 5).disabled(loading)
                LegalEntryLinks()
            }.padding(.horizontal, 24).padding(.bottom, 28).frame(maxWidth: 460).frame(maxWidth: .infinity)
        }.background(ClubBackground())
            .introspect(.scrollView, on: .iOS(.v15, .v16, .v17, .v18, .v26, .v27)) { $0.keyboardDismissMode = .interactive }
            .modifier(ClubKeyboardDismissal(isFocused: cardFocused || passwordFocused, dismiss: dismissKeyboard))
            .sheet(isPresented: $showHelp) { InformationSheet(page: .loginHelp) }
            .sheet(isPresented: $showRegistration) { AccountRegistrationScreen() }
    }
}

struct AccountRegistrationScreen: View {
    @EnvironmentObject private var store: ClubStore
    @Environment(\.dismiss) private var dismiss
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
                    Text("创建本机账号").font(.system(size: 25, weight: .bold))
                    Text("设置账号和密码，注册后即可进入会员空间")
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
                            if let errorMessage {
                                Text(errorMessage).font(.system(size: 12)).foregroundColor(ClubTheme.error)
                            }
                            Button(saving ? "正在注册…" : "注册") {
                                saving = true
                                errorMessage = nil
                                Task {
                                    do { try await store.registerAccount(account: normalizedAccount, password: password) }
                                    catch {
                                        errorMessage = "本机保存失败，请重试。"
                                        saving = false
                                    }
                                }
                            }
                            .buttonStyle(ClubButtonStyle())
                            .disabled(!canRegister)
                            .accessibilityIdentifier("submitRegistration")
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 28)
                .frame(maxWidth: 460).frame(maxWidth: .infinity)
            }
            .background(ClubBackground())
            .navigationTitle("注册账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
        .navigationViewStyle(.stack)
        .interactiveDismissDisabled(saving)
    }
}
