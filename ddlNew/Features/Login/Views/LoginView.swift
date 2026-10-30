//
//  LoginView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/21.
//

import SwiftUI

/// 独立的登录页面，支持更换俱乐部和打开网页，不依赖旧版页面或会员状态。
struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @ObservedObject private var securityNotice = LoginSecurityNoticeStore.shared
    /// 共享登录前连接状态；页面显示不代表 SDK 已完成握手。
    @ObservedObject private var connection = IMConnectionCoordinator.shared
    /// AUTH 与访客连接分开，登录后继续显示 SDK 的重连和认证状态。
    @ObservedObject private var authentication = IMUserAuthenticationService.shared
    /// 验证弹窗按请求标识隔离；旧弹窗关闭不能取消下一次验证。
    @ObservedObject private var verification = LoginVerificationCoordinator.shared
    /// 用户输入的会员卡号与密码；勾选记住密码时仅写入 Keychain。
    @State private var card = ""
    @State private var password = ""
    /// 首次打开默认开启；普通偏好只保存开关，不保存账号密码。
    @AppStorage(loginRememberPasswordAppStorageKey) private var rememberPassword = true
    /// 一个页面生命周期内只回填一次，避免弹窗关闭后覆盖正在编辑的输入。
    @State private var didRestoreRememberedLogin = false
    /// 两个网页入口共用一个 Safari 弹窗，避免同时呈现多个浏览器。
    @State private var webLink: WebLink?
    @State private var showingRegistration = false
    /// 输入焦点仅用于键盘展示和收起，不影响 App 路由。
    @FocusState private var cardFocused: Bool
    @FocusState private var passwordFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                brandHeader
                loginForm
                legalEntries
                loginAction
                auxiliaryActions
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .background(LoginBackground())
        .messagingLoadingToast(viewModel.loginPhase.isBusy && verification.request == nil, title: viewModel.loginPhase.buttonTitle)
        .messagingFeedbackToast(loginFeedback, isEnabled: verification.request == nil && !showingRegistration, presentInitial: true)
        .scrollDismissesKeyboard(.interactively)
        .onSubmit(dismissKeyboard)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if cardFocused || passwordFocused {
                keyboardDismissBar
            }
        }
        .sheet(item: $webLink) { link in
            SafariView(url: link.url)
                .ignoresSafeArea()
        }
        .sheet(item: $verification.request) { request in
            LoginVerificationSheet(
                request: request,
                submit: { verification.submit($0, for: request.id) },
                cancel: { verification.cancel(requestID: request.id) }
            )
            .onDisappear { verification.cancel(requestID: request.id) }
        }
        .sheet(isPresented: $showingRegistration) { AccountRegistrationView() }
        .alert("提示", isPresented: $viewModel.showsLegalConsentAlert) {
            Button("取消", role: .cancel) {}
            Button("同意并继续") {
                viewModel.hasAcceptedLegalDocuments = true
                login()
            }
        } message: {
            Text("请阅读并同意《隐私政策》和《使用支持》")
        }
        .onChange(of: verification.request?.id) { _ in dismissKeyboard() }
        .onAppear(perform: restoreRememberedLogin)
        .onChange(of: rememberPassword) { enabled in
            if !enabled { viewModel.clearRememberedLogin() }
        }
        .onDisappear {
            viewModel.cancelLogin()
            password = ""
        }
        .onChange(of: viewModel.loginPhase) { phase in
            if phase == .succeeded { password = "" }
        }
    }

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: 56) {
            HStack(spacing: 10) {
                Image("DingDongMark").resizable().scaledToFit().frame(width: 42, height: 42).accessibilityHidden(true)
                Text("叮咚聊").font(.title2.weight(.semibold))
                Spacer(minLength: 8)
                Button("更换俱乐部", action: changeClub)
                    .font(.subheadline).foregroundStyle(LoginPalette.darkTeal)
                    .frame(minHeight: 44).accessibilityIdentifier("changeClub")
            }
            Text("欢迎回来").font(.largeTitle.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.top, 12).padding(.bottom, 12)
    }

    private var loginForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            LoginField(
                title: "账号",
                placeholder: "请输入会员卡号",
                icon: "person",
                text: $card,
                focus: $cardFocused
            )
            .disabled(viewModel.loginPhase.isBusy)


            LoginField(
                title: "密码",
                placeholder: "请输入密码",
                icon: "lock",
                text: $password,
                secure: true,
                focus: $passwordFocused
            )
            .disabled(viewModel.loginPhase.isBusy)
            .padding(.top, 12)

            Toggle("记住密码", isOn: $rememberPassword)
                .font(.subheadline)
                .tint(LoginPalette.darkTeal)
                .frame(minHeight: 44)
                .disabled(viewModel.loginPhase.isBusy)
                .accessibilityIdentifier("rememberPassword")



            if viewModel.loginPhase != .succeeded {
                Text(connection.phase.message)
                    .font(.footnote)
                    .foregroundColor(LoginPalette.secondary)
                    .accessibilityIdentifier("loginConnectionStatus")
            }
            if case .failed = connection.phase {
                Button("重试连接") {
                    viewModel.cancelLogin()
                    connection.startCachedReconnect()
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("retryLoginConnection")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loginAction: some View {
        // 不因缓存重连禁用按钮；请求期间防止重复提交，发送前由服务检查真实连接。
        Button(viewModel.loginPhase.buttonTitle, action: login)
            .buttonStyle(LoginButtonStyle())
            .disabled(card.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty
                      || viewModel.loginPhase.isBusy || viewModel.loginPhase == .succeeded)
            .padding(.top, 10)
            .accessibilityIdentifier("login")
    }

    private var loginFeedback: String? {
        if case .failed(let message) = viewModel.loginPhase { return message }
        return viewModel.rememberedLoginMessage ?? securityNotice.message
    }

    private var auxiliaryActions: some View {
        HStack(spacing: 32) {
            if AccountRegistrationService.currentContext()?.allowsAccountRegistration == true {
                Button("注册账号") {
                    dismissKeyboard()
                    viewModel.cancelLogin()
                    password = ""
                    showingRegistration = true
                }
                .disabled(viewModel.loginPhase.isBusy || verification.request != nil)
                .accessibilityIdentifier("openAccountRegistration")
            }
        }
        .font(.subheadline)
        .foregroundColor(LoginPalette.darkTeal)
        .frame(minHeight: 44)
        .padding(.top, 5)
    }

    /// 勾选与阅读入口独立；打开在线网页不改变用户的同意状态。
    private var legalEntries: some View {
        HStack(alignment: .top, spacing: 8) {
            Button { viewModel.hasAcceptedLegalDocuments.toggle() } label: {
                Image(systemName: viewModel.hasAcceptedLegalDocuments ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("同意隐私政策和使用支持")
            .accessibilityValue(viewModel.hasAcceptedLegalDocuments ? "已勾选" : "未勾选")
            .accessibilityAddTraits(viewModel.hasAcceptedLegalDocuments ? .isSelected : [])
            .accessibilityIdentifier("acceptLegalDocuments")

            VStack(alignment: .leading, spacing: 0) {
                Text("我已阅读并同意以下内容")
                    .foregroundColor(LoginPalette.secondary)
                HStack(spacing: 24) {
                    Button("隐私政策") { openWebPage(privacyPolicyURLString) }
                        .accessibilityIdentifier("openPrivacyPolicy")
                    Button("使用支持") { openWebPage(usageSupportURLString) }
                        .accessibilityIdentifier("openSupport")
                }
                .frame(minHeight: 44)
            }
        }
        .font(.footnote)
        .foregroundColor(LoginPalette.darkTeal)
        .frame(minHeight: 44)
        .disabled(viewModel.loginPhase.isBusy)
    }

    private var keyboardDismissBar: some View {
        HStack {
            Spacer()
            Button("完成", action: dismissKeyboard)
                .font(.body.weight(.semibold))
                .foregroundColor(LoginPalette.darkTeal)
                .frame(minWidth: 60, minHeight: 44)
                .accessibilityIdentifier("keyboardDone")
        }
        .padding(.horizontal, 16)
        .background(LoginPalette.card)
    }

    private func dismissKeyboard() {
        cardFocused = false
        passwordFocused = false
    }

    private func login() {
        dismissKeyboard()
        guard viewModel.hasAcceptedLegalDocuments else {
            viewModel.showsLegalConsentAlert = true
            return
        }
        securityNotice.clear()
        viewModel.login(account: card, password: password, rememberPassword: rememberPassword)
    }

    private func restoreRememberedLogin() {
        guard !didRestoreRememberedLogin else { return }
        didRestoreRememberedLogin = true
        guard rememberPassword else {
            // 上次删除失败时，下次进入仍会重试；关闭状态绝不回填密码。
            viewModel.clearRememberedLogin()
            return
        }
        guard card.isEmpty, password.isEmpty, let record = viewModel.rememberedLogin() else { return }
        card = record.account
        password = record.password
    }

    private func changeClub() {
        dismissKeyboard()
        card = ""
        password = ""
        viewModel.changeClub()
    }

    private func openWebPage(_ address: String) {
        dismissKeyboard()
        // Safari 只接受 HTTP/HTTPS；配置中统一使用 HTTPS，不加载本地旧版文档。
        guard let url = URL(string: address), url.scheme == "https",
              let host = url.host, !host.isEmpty else { return }
        webLink = WebLink(url: url)
    }
}

#Preview {
    LoginView()
}
