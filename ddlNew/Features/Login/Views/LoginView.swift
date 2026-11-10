import SwiftUI

/// 账号、手机号共用连接、验证及AUTH流程，页面只管理当前表单。
struct LoginView: View {
    @Environment(\.locale) private var localizationLocale
    @StateObject private var viewModel = LoginViewModel()
    @StateObject private var codeSender = AccountCodeViewModel()
    @ObservedObject private var securityNotice = LoginSecurityNoticeStore.shared
    @ObservedObject private var connection = IMConnectionCoordinator.shared
    @ObservedObject private var verification = LoginVerificationCoordinator.shared
    @State private var kind = AccountIdentity.Kind.account
    @State private var accounts: [AccountIdentity.Kind: String] = [:]
    @State private var areaCode = "86"
    @State private var password = ""
    @State private var code = ""
    @State private var usesCode = false
    @AppStorage(loginRememberPasswordAppStorageKey) private var rememberPassword = true
    @State private var didRestoreRememberedLogin = false
    @State private var showingRegistration = false
    @FocusState private var focus: AuthenticationFocus?

    private var identity: AccountIdentity { AccountIdentity(kind: kind, value: accounts[kind] ?? "", areaCode: areaCode) }
    private var scope: String { OSSNavigationStore.shared.lastUsableLiceseId() ?? "" }
    private var busy: Bool { viewModel.loginPhase.isBusy || codeSender.isSending }
    private var accountBinding: Binding<String> {
        Binding(get: { accounts[kind] ?? "" }, set: { accounts[kind] = $0; codeSender.cancel(); code = "" })
    }
    private var verificationBinding: Binding<LoginVerificationRequest?> {
        Binding(get: { showingRegistration ? nil : verification.request }, set: { if !showingRegistration { verification.request = $0 } })
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack { Spacer(); LanguageSelectionButton() }
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.tr("登录叮咚聊")).font(.largeTitle.bold()).foregroundStyle(LoginPalette.ink)
                }.padding(.top, 28)
                VStack(alignment: .leading, spacing: 20) {
                    AuthenticationMethodPicker(selection: Binding(get: { kind }, set: changeKind))
                        .disabled(busy)
                    AccountIdentityField(kind: kind, value: accountBinding, areaCode: $areaCode, focus: $focus)
                        .disabled(busy)
                    if usesCode {
                        AccountCodeField(code: $code, identity: identity, purpose: .login, scope: scope, sender: codeSender, focus: $focus)
                            .disabled(viewModel.loginPhase.isBusy)
                    } else {
                        AuthenticationField(title: L10n.tr("密码"), placeholder: L10n.tr("请输入密码"), text: $password, field: .password, focus: $focus, secure: true, contentType: .password)
                            .disabled(busy)
                    }
                    if kind != .account {
                        Button(usesCode ? L10n.tr("使用密码登录") : L10n.tr("使用验证码登录")) {
                            focus = nil; codeSender.cancel(); code = ""; password = ""; usesCode.toggle()
                            viewModel.cancelLogin()
                        }
                        .buttonStyle(AuthenticationTextButtonStyle())
                        .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                        .disabled(busy).accessibilityIdentifier("toggleCodeLogin")
                    }
                    if !usesCode {
                        Toggle(L10n.tr("记住密码"), isOn: $rememberPassword)
                            .font(.subheadline).frame(minHeight: 44).disabled(busy)
                            .accessibilityIdentifier("rememberPassword")
                    }
                    LegalConsentRow(isAccepted: $viewModel.hasAcceptedLegalDocuments) { focus = nil }
                        .disabled(busy)
                    Button(viewModel.loginPhase.buttonTitle, action: login)
                        .buttonStyle(LoginButtonStyle())
                        .disabled(identity.value.isEmpty || (usesCode ? code.isEmpty : password.isEmpty) || busy || viewModel.loginPhase == .succeeded)
                        .accessibilityIdentifier("login")
                    connectionStatus
                }
                ViewThatFits(in: .horizontal) {
                    HStack { registrationButton; Spacer(minLength: 24); changeClubButton }
                    VStack(alignment: .leading, spacing: 8) { registrationButton; changeClubButton }
                }.font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 24).padding(.bottom, 28)
            .frame(maxWidth: 460).frame(maxWidth: .infinity)
        }
        .background(LoginBackground()).tint(LoginPalette.darkTeal)
        .scrollDismissesKeyboard(.interactively).onSubmit { focus = nil }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if focus != nil {
                HStack { Spacer(); Button(L10n.tr("完成")) { focus = nil }.buttonStyle(AuthenticationTextButtonStyle()) }
                    .padding(.horizontal, 24).background(LoginPalette.card)
            }
        }
        .messagingLoadingToast(viewModel.loginPhase.isBusy && verification.request == nil, title: viewModel.loginPhase.buttonTitle)
        .messagingFeedbackToast(loginFeedback, isEnabled: verification.request == nil && !showingRegistration, presentInitial: true)
        .sheet(item: verificationBinding) { request in
            LoginVerificationSheet(request: request, submit: { verification.submit($0, for: request.id) }, cancel: { verification.cancel(requestID: request.id) })
                .onDisappear { verification.cancel(requestID: request.id) }
        }
        .sheet(isPresented: $showingRegistration) { AccountRegistrationView(initialKind: kind) }
        .alert(L10n.tr("提示"), isPresented: $viewModel.showsLegalConsentAlert) {
            Button(L10n.tr("取消"), role: .cancel) {}
            Button(L10n.tr("同意并继续")) { viewModel.hasAcceptedLegalDocuments = true; login() }
        } message: { Text(L10n.tr("请阅读并同意《隐私政策》和《使用支持》")) }
        .onChange(of: verification.request?.id) { _ in focus = nil }
        .onChange(of: areaCode) { _ in codeSender.cancel(); code = "" }
        .onChange(of: connection.loginConnectionID) { _ in codeSender.cancel() }
        .onChange(of: rememberPassword) { if !$0 { viewModel.clearRememberedLogin() } }
        .onAppear { restoreRememberedLogin(); connection.ensureCachedReconnect() }
        .onDisappear { codeSender.cancel(); viewModel.cancelLogin(); password = ""; code = "" }
        .onChange(of: viewModel.loginPhase) { if $0 == .succeeded { password = ""; code = "" } }
    }
    @ViewBuilder private var connectionStatus: some View {
        if viewModel.loginPhase != .succeeded {
            Text(connection.phase.message).font(.footnote).foregroundStyle(LoginPalette.secondary)
                .accessibilityIdentifier("loginConnectionStatus")
        }
        if case .failed = connection.phase {
            Button(L10n.tr("重试连接")) { codeSender.cancel(); viewModel.cancelLogin(); connection.startCachedReconnect() }
                .frame(minHeight: 44).disabled(busy).accessibilityIdentifier("retryLoginConnection")
        }
    }
    private var registrationButton: some View {
        Button(L10n.tr("注册新账号")) { focus = nil; codeSender.cancel(); viewModel.cancelLogin(); password = ""; code = ""; showingRegistration = true }
            .buttonStyle(AuthenticationTextButtonStyle())
            .frame(minHeight: 44).disabled(busy || verification.request != nil).accessibilityIdentifier("openAccountRegistration")
    }
    private var changeClubButton: some View {
        Button(L10n.tr("更换俱乐部")) {
            focus = nil; codeSender.cancel(); accounts = [:]; password = ""; code = ""; viewModel.changeClub()
        }.buttonStyle(AuthenticationTextButtonStyle()).frame(minHeight: 44).disabled(busy).accessibilityIdentifier("changeClub")
    }
    private var loginFeedback: String? {
        if let feedback = codeSender.feedback { return feedback }
        if case .failed(let message) = viewModel.loginPhase { return message }
        return viewModel.rememberedLoginMessage ?? securityNotice.message
    }
    private func changeKind(_ value: AccountIdentity.Kind) {
        guard value != kind else { return }
        focus = nil; codeSender.cancel(); viewModel.cancelLogin()
        password = ""; code = ""; usesCode = false; kind = value
    }
    private func login() {
        focus = nil
        codeSender.cancel()
        securityNotice.clear()
        viewModel.login(account: identity.value, password: password, rememberPassword: rememberPassword,
            kind: kind, areaCode: areaCode, code: code, usesCode: usesCode)
    }
    private func restoreRememberedLogin() {
        guard !didRestoreRememberedLogin else { return }
        didRestoreRememberedLogin = true
        guard rememberPassword else { viewModel.clearRememberedLogin(); return }
        guard accounts.isEmpty, password.isEmpty, let record = viewModel.rememberedLogin(),
              let restoredKind = AccountIdentity.Kind(rawValue: record.loginType) else { return }
        kind = restoredKind
        accounts[kind] = record.account
        areaCode = record.areaCode.isEmpty ? "86" : record.areaCode
        password = record.password
    }
}

#Preview { LoginView() }
