import SwiftUI
import UIKit

@MainActor
struct LoginVerificationSheet: View {
    let request: LoginVerificationRequest
    let submit: (LoginVerificationAnswer) -> Void
    let cancel: () -> Void

    @State private var input = ""
    @State private var attemptID = UUID()
    @State private var loadState = LoginCaptchaLoadState.loading
    @State private var submitted = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                if !request.message.isEmpty {
                    Text(request.message)
                        .font(.subheadline)
                        .foregroundStyle(LoginPalette.secondary)
                        .multilineTextAlignment(.leading)
                }
                switch request.kind {
                case .imageCaptcha: imageCaptcha
                case .securityCode: securityCode
                case .tencentCaptcha, .aliyunCaptcha: providerCaptcha
                }
                Spacer(minLength: 0)
            }
            .padding(24)
            .background(LoginPalette.card)
            .safeAreaInset(edge: .bottom) {
                if !isProviderCaptcha && (request.kind != .imageCaptcha || request.imageData.flatMap({ UIImage(data: $0) }) != nil) {
                    continueButton.padding(20).background(LoginPalette.card)
                }
            }
            .messagingLoadingToast(isProviderCaptcha && loadState == .loading, title: "正在加载验证")
            .messagingFeedbackToast(verificationFeedback, presentInitial: true)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: cancel)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("cancelLoginVerification")
                }
            }
        }
    }

    /// 只有网页验证码有异步加载；图片和安全码输入不会被loading遮住。
    private var isProviderCaptcha: Bool {
        switch request.kind { case .tencentCaptcha, .aliyunCaptcha: return true; default: return false }
    }
    private var verificationFeedback: String? {
        if request.kind == .imageCaptcha, request.imageData.flatMap({ UIImage(data: $0) }) == nil { return "验证码图片加载失败，请取消后重新登录。" }
        if isProviderCaptcha, case .failed(let message) = loadState { return message }
        return nil
    }

    private var title: String {
        request.kind == .securityCode ? "安全码验证" : "登录验证"
    }

    @ViewBuilder private var imageCaptcha: some View {
        if let data = request.imageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity).frame(height: 90).padding(.horizontal, 16)
                .background(HomeTheme.background, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel("图片验证码")
            Text("图片验证码").font(.footnote.weight(.medium)).foregroundStyle(LoginPalette.secondary)
            TextField("请输入图片中的验证码", text: $input)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 15).padding(.vertical, 8)
                .background(HomeTheme.background, in: RoundedRectangle(cornerRadius: 12))
                .frame(minHeight: 52)
                .accessibilityIdentifier("loginImageCode")
                .onSubmit(submitInput)
        } else {
            Color.clear.frame(height: 100)
        }
    }

    private var securityCode: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("安全码").font(.footnote.weight(.medium)).foregroundStyle(LoginPalette.secondary)
            SecureField("请输入安全码", text: $input)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 15).padding(.vertical, 8)
                .background(HomeTheme.background, in: RoundedRectangle(cornerRadius: 12))
                .frame(minHeight: 44)
                .accessibilityIdentifier("loginSecurityCode")
                .onSubmit(submitInput)
        }
    }

    private var continueButton: some View {
        Button("继续登录", action: submitInput)
            .buttonStyle(LoginButtonStyle())
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || submitted)
            .accessibilityIdentifier("submitLoginVerification")
    }

    private var providerCaptcha: some View {
        // 网页验证统一展示加载、失败和重试状态；每次重试重建 WebView，隔离旧网页回调。
        VStack(spacing: 16) {
            ZStack {
                LoginCaptchaWebView(
                    kind: request.kind,
                    stateChanged: { loadState = $0 },
                    completed: { answer in
                        guard !submitted else { return }
                        submitted = true
                        submit(answer)
                    },
                    cancelled: cancel
                )
                .id(attemptID)
                .opacity(loadState.isFailed ? 0 : 1)


            }
            .frame(minHeight: 340, maxHeight: .infinity)
            if loadState.isFailed {
                Button("重试验证") {
                    loadState = .loading
                    attemptID = UUID()
                }
                .buttonStyle(LoginButtonStyle())
                .accessibilityIdentifier("retryLoginVerification")
            }
        }
    }

    private func submitInput() {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !submitted else { return }
        var answer = LoginVerificationAnswer()
        switch request.kind {
        case .imageCaptcha: answer.imageCode = value
        case .securityCode: answer.securityCode = value
        case .tencentCaptcha, .aliyunCaptcha: return
        }
        submitted = true
        input = ""
        submit(answer)
    }
}
