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
            VStack(spacing: 20) {
                if !request.message.isEmpty {
                    Text(request.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                switch request.kind {
                case .imageCaptcha: imageCaptcha
                case .securityCode: securityCode
                case .tencentCaptcha, .aliyunCaptcha: providerCaptcha
                }
                Spacer(minLength: 0)
            }
            .padding(24)
            .background(LoginPalette.background)
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

    private var title: String {
        request.kind == .securityCode ? "安全码验证" : "登录验证"
    }

    @ViewBuilder private var imageCaptcha: some View {
        if let data = request.imageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 260, maxHeight: 100)
                .accessibilityLabel("图片验证码")
            TextField("请输入图片中的验证码", text: $input)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 44)
                .accessibilityIdentifier("loginImageCode")
                .onSubmit(submitInput)
            continueButton
        } else {
            Label("验证码图片加载失败，请取消后重新登录。", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        }
    }

    private var securityCode: some View {
        VStack(spacing: 16) {
            SecureField("请输入安全码", text: $input)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 44)
                .accessibilityIdentifier("loginSecurityCode")
                .onSubmit(submitInput)
            continueButton
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

                if loadState == .loading {
                    ProgressView("正在加载验证…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                if case .failed(let message) = loadState {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
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
