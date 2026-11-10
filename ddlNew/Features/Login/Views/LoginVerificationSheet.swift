import SwiftUI
import UIKit

@MainActor
struct LoginVerificationSheet: View {
    @Environment(\.locale) private var localizationLocale
    let request: LoginVerificationRequest
    let submit: (LoginVerificationAnswer) -> Void
    let cancel: () -> Void

    @State private var input = ""
    @State private var loadState = LoginCaptchaLoadState.loading
    @State private var submitted = false
    @State private var refreshedImage: Data?
    @State private var refreshingImage = false
    @State private var refreshRevision = 0
    @State private var imageRefreshError: String?

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
            .messagingLoadingToast(isProviderCaptcha && loadState == .loading, title: L10n.tr("正在加载验证"))
            .messagingFeedbackToast(verificationFeedback, presentInitial: true)
            .task(id: refreshRevision) {
                guard refreshRevision > 0, let reload = request.reloadImage else { return }
                let revision = refreshRevision
                do {
                    let data = try await reload()
                    guard !Task.isCancelled, revision == refreshRevision else { return }
                    guard UIImage(data: data) != nil else { throw AccountLoginError.invalidResponse }
                    refreshedImage = data
                    refreshingImage = false
                } catch {
                    guard !Task.isCancelled, revision == refreshRevision else { return }
                    imageRefreshError = L10n.tr("图片刷新失败，请重试或取消")
                    refreshingImage = false
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("取消"), action: cancel)
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
        if let imageRefreshError { return imageRefreshError }
        if request.kind == .imageCaptcha, captchaImage == nil { return L10n.tr("验证码图片加载失败，请换一张或取消后重试。") }
        if isProviderCaptcha, case .failed(let message) = loadState { return message }
        return nil
    }

    private var title: String {
        request.kind == .securityCode ? L10n.tr("安全码验证") : request.title
    }

    private var captchaImage: UIImage? { (refreshedImage ?? request.imageData).flatMap { UIImage(data: $0) } }

    @ViewBuilder private var imageCaptcha: some View {
        if let image = captchaImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 260, maxHeight: 100)
                .accessibilityLabel(L10n.tr("图片验证码"))
        } else {
            Color.clear.frame(height: 100)
        }
        if request.reloadImage != nil {
            Button(refreshingImage ? L10n.tr("正在刷新…") : L10n.tr("换一张")) {
                input = ""
                imageRefreshError = nil
                refreshingImage = true
                refreshRevision += 1
            }
            .buttonStyle(AuthenticationTextButtonStyle())
            .disabled(refreshingImage || submitted)
            .accessibilityIdentifier("refreshLoginImageCode")
        }
        TextField(L10n.tr("图片验证码"), text: $input,
                  prompt: Text(L10n.tr("请输入图片中的验证码")).foregroundColor(LoginPalette.secondary))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textFieldStyle(.roundedBorder)
            .frame(minHeight: 44)
            .accessibilityIdentifier("loginImageCode")
            .onSubmit(submitInput)
            .disabled(refreshingImage || imageRefreshError != nil || captchaImage == nil)
        continueButton
    }

    private var securityCode: some View {
        VStack(spacing: 16) {
            SecureField(L10n.tr("安全码"), text: $input,
                        prompt: Text(L10n.tr("请输入安全码")).foregroundColor(LoginPalette.secondary))
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
        Button(request.submitTitle, action: submitInput)
            .buttonStyle(LoginButtonStyle())
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || submitted || refreshingImage || imageRefreshError != nil || (request.kind == .imageCaptcha && captchaImage == nil))
            .accessibilityIdentifier("submitLoginVerification")
    }

    private var providerCaptcha: some View {
        // 网页验证失败交回服务层改走图文；主动关闭仍取消本轮。
        VStack(spacing: 16) {
            ZStack {
                LoginCaptchaWebView(
                    kind: request.kind,
                    stateChanged: {
                        loadState = $0
                        if $0.isFailed, !submitted {
                            submitted = true
                            submit(LoginVerificationAnswer(requestsImageFallback: true))
                        }
                    },
                    completed: { answer in
                        guard !submitted else { return }
                        submitted = true
                        submit(answer)
                    },
                    cancelled: cancel
                )
                .opacity(loadState.isFailed ? 0 : 1)


            }
            .frame(minHeight: 340, maxHeight: .infinity)

        }
    }

    private func submitInput() {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !submitted, !refreshingImage, imageRefreshError == nil else { return }
        guard request.kind != .imageCaptcha || captchaImage != nil else { return }
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
