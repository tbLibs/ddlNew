import SwiftUI

struct AccountRegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AccountRegistrationViewModel()
    @StateObject private var codeSender = AccountCodeViewModel()
    @ObservedObject private var connection = IMConnectionCoordinator.shared
    @ObservedObject private var verification = LoginVerificationCoordinator.shared
    @State private var kind: AccountIdentity.Kind
    @State private var accounts: [AccountIdentity.Kind: String] = [:]
    @State private var areaCode = "86"
    @State private var password = ""
    @State private var confirmation = ""
    @State private var code = ""
    @State private var inviteCode = ""
    @FocusState private var focus: AuthenticationFocus?
    init(initialKind: AccountIdentity.Kind = .account) { _kind = State(initialValue: initialKind) }
    private var context: AccountRegistrationContext? { AccountRegistrationService.currentContext() }
    private var identity: AccountIdentity { AccountIdentity(kind: kind, value: accounts[kind] ?? "", areaCode: areaCode) }
    private var scope: String { OSSNavigationStore.shared.lastUsableLiceseId() ?? "" }
    private var busy: Bool { viewModel.phase.isBusy || codeSender.isSending }
    private var accountBinding: Binding<String> {
        Binding(get: { accounts[kind] ?? "" }, set: { accounts[kind] = $0; codeSender.cancel(); code = "" })
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("选择一种方式创建账号").font(.largeTitle.bold())
                    }.padding(.vertical, 8)
                    Group {
                        AuthenticationMethodPicker(selection: Binding(get: { kind }, set: changeKind))
                        AccountIdentityField(kind: kind, value: accountBinding, areaCode: $areaCode, focus: $focus)
                        if kind == .account {
                            Text("6～16位，前两位为英文字母，只支持英文和数字")
                                .font(.footnote).foregroundStyle(LoginPalette.secondary)
                        } else {
                            AccountCodeField(code: $code, identity: identity, purpose: .registration, scope: scope, sender: codeSender, focus: $focus)
                        }
                        AuthenticationField(title: "密码", placeholder: "设置登录密码", text: $password, field: .password, focus: $focus, secure: true, contentType: .newPassword)
                        AuthenticationField(title: "确认密码", placeholder: "再次输入密码", text: $confirmation, field: .confirmation, focus: $focus, secure: true, contentType: .newPassword)
                        Text(context?.requiresPasswordSymbol == true ? "密码6～16位，须包含字母、数字和英文符号" : "密码6～16位，须包含字母、数字，可使用英文符号")
                            .font(.footnote).foregroundStyle(LoginPalette.secondary)
                        if context?.requiresInviteCode == true {
                            AuthenticationField(title: "邀请码", placeholder: "请输入邀请码", text: $inviteCode, field: .invite, focus: $focus)
                        }
                        LegalConsentRow(isAccepted: $viewModel.hasAcceptedLegalDocuments) { focus = nil }
                    }.disabled(busy || viewModel.accountWasRegistered)
                    Button(buttonTitle, action: submit)
                        .buttonStyle(LoginButtonStyle())
                        .disabled(busy || viewModel.phase == .succeeded || (!viewModel.accountWasRegistered && context == nil))
                        .accessibilityIdentifier("submitAccountRegistration")
                    Text(connection.phase.message).font(.footnote).foregroundStyle(LoginPalette.secondary)
                }
                .padding(24).frame(maxWidth: 460).frame(maxWidth: .infinity)
            }
            .foregroundStyle(LoginPalette.ink).background(LoginBackground()).tint(LoginPalette.darkTeal)
            .messagingLoadingToast(viewModel.phase.isBusy && verification.request == nil, title: "正在注册")
            .messagingFeedbackToast(registrationFeedback, isEnabled: verification.request == nil)
            .scrollDismissesKeyboard(.interactively).onSubmit { focus = nil }
            .navigationTitle("注册").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { codeSender.cancel(); viewModel.cancel(); dismiss() }.accessibilityIdentifier("cancelAccountRegistration") }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成") { focus = nil } }
            }
            .sheet(item: $verification.request) { request in
                LoginVerificationSheet(request: request, submit: { verification.submit($0, for: request.id) }, cancel: { verification.cancel(requestID: request.id) })
                    .onDisappear { verification.cancel(requestID: request.id) }
            }
            .alert("提示", isPresented: $viewModel.showsLegalConsentAlert) {
                Button("取消", role: .cancel) {}
                Button("同意并继续") { viewModel.hasAcceptedLegalDocuments = true; submit() }
            } message: { Text("请阅读并同意《隐私政策》和《使用支持》") }
            .onChange(of: areaCode) { _ in codeSender.cancel(); code = "" }
            .onChange(of: connection.loginConnectionID) { _ in codeSender.cancel() }
            .onDisappear { codeSender.cancel(); viewModel.cancel(); password = ""; confirmation = ""; code = "" }
        }
    }
    private func changeKind(_ next: AccountIdentity.Kind) {
        guard next != kind else { return }
        focus = nil; codeSender.cancel(); viewModel.cancel(); kind = next
        password = ""; confirmation = ""; code = ""
    }
    private func submit() {
        focus = nil
        codeSender.cancel()
        if viewModel.accountWasRegistered { dismiss(); return }
        viewModel.register(AccountRegistrationInput(account: identity.value, password: password, confirmation: confirmation,
            inviteCode: inviteCode, kind: kind, areaCode: areaCode, code: code))
    }
    private var registrationFeedback: String? {
        if let feedback = codeSender.feedback { return feedback }
        if case .failed(let message) = viewModel.phase { return message }
        return nil
    }
    private var buttonTitle: String {
        if viewModel.accountWasRegistered, !viewModel.phase.isBusy, viewModel.phase != .succeeded { return "返回登录" }
        switch viewModel.phase {
        case .idle, .failed: return "注册并登录"
        case .succeeded: return "注册成功"
        default: return viewModel.phase.buttonTitle
        }
    }
}
