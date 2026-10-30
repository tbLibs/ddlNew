import SwiftUI

struct AccountRegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AccountRegistrationViewModel()
    @ObservedObject private var connection = IMConnectionCoordinator.shared
    @State private var account = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var inviteCode = ""
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case account, password, confirmation, invite }

    private var context: AccountRegistrationContext? { AccountRegistrationService.currentContext() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("创建俱乐部账号").font(.title2.bold())
                    field("账号", text: $account, focus: .account)
                    Text("6～16位，前两位为英文字母，只支持英文和数字")
                        .font(.footnote).foregroundStyle(LoginPalette.secondary)
                    field("密码", text: $password, focus: .password, secure: true)
                    field("确认密码", text: $confirmation, focus: .confirmation, secure: true)
                    Text(context?.requiresPasswordSymbol == true ? "密码6～16位，须包含字母、数字和英文符号" : "密码6～16位，须包含字母、数字，可使用英文符号")
                        .font(.footnote).foregroundStyle(LoginPalette.secondary)
                    if context?.requiresInviteCode == true {
                        field("邀请码", text: $inviteCode, focus: .invite)
                    }

                    Text(connection.phase.message).font(.footnote).foregroundStyle(LoginPalette.secondary)
                }
                .padding(20).frame(maxWidth: 460).frame(maxWidth: .infinity)
                .disabled(viewModel.phase.isBusy)
            }
            .background(LoginBackground())
            .safeAreaInset(edge: .bottom) {
                    Button(buttonTitle) {
                        focusedField = nil
                        if viewModel.accountWasRegistered {
                            dismiss()
                            return
                        }
                        viewModel.register(AccountRegistrationInput(account: account, password: password,
                            confirmation: confirmation, inviteCode: inviteCode))
                    }
                    .buttonStyle(LoginButtonStyle())
                    .disabled(viewModel.phase.isBusy || viewModel.phase == .succeeded || context == nil)
                    .accessibilityIdentifier("submitAccountRegistration")

                        .frame(maxWidth: 460).padding(20).frame(maxWidth: .infinity).background(LoginPalette.card)
            }
            .messagingLoadingToast(viewModel.phase.isBusy, title: "正在注册")
            .messagingFeedbackToast(registrationFeedback)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("账号注册").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { viewModel.cancel(); dismiss() }
                        .accessibilityIdentifier("cancelAccountRegistration")
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成") { focusedField = nil } }
            }
            .onDisappear {
                viewModel.cancel()
                password = ""
                confirmation = ""
            }
        }
    }

    private var registrationFeedback: String? { if case .failed(let message) = viewModel.phase { return message }; return nil }

    private var buttonTitle: String {
        if viewModel.accountWasRegistered, !viewModel.phase.isBusy, viewModel.phase != .succeeded { return "返回登录" }
        switch viewModel.phase {
        case .idle, .failed: return "注册并登录"
        case .succeeded: return "注册成功"
        default: return viewModel.phase.buttonTitle
        }
    }

    @ViewBuilder private func field(_ title: String, text: Binding<String>, focus: Field, secure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.medium))
            Group {
                if secure { SecureField("请输入\(title)", text: text) }
                else { TextField("请输入\(title)", text: text) }
            }
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .focused($focusedField, equals: focus)
            .padding(15).frame(minHeight: 52).background(HomeTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("registration\(String(describing: focus))")
        }
    }
}
