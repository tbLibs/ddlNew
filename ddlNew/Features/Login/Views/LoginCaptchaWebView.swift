import SwiftUI
import WebKit

enum LoginCaptchaLoadState: Equatable {
    case loading
    case ready
    case failed(String)

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}

/// 本地网页加载验证码服务商 SDK，仅接受该网页主框架返回的验证结果。
@MainActor
struct LoginCaptchaWebView: UIViewRepresentable {
    let kind: LoginVerificationKind
    let stateChanged: (LoginCaptchaLoadState) -> Void
    let completed: (LoginVerificationAnswer) -> Void
    let cancelled: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let handler = WeakMessageHandler(target: context.coordinator)
        for name in Coordinator.handlerNames {
            configuration.userContentController.add(handler, name: name)
        }
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        context.coordinator.load(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        // 弹窗销毁时停止加载并移除桥接，避免网页继续回调已经结束的验证。
        coordinator.stop()
        webView.stopLoading()
        webView.navigationDelegate = nil
        for name in Coordinator.handlerNames {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: name)
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        static let handlerNames = ["iosJSBridge", "getVerifyResult", "closeWebView", "captchaStatus"]
        private let parent: LoginCaptchaWebView
        private var pageURL: URL?
        private var loadTimeout: Task<Void, Never>?
        private var stopped = false
        private var receivedAnswer = false

        init(parent: LoginCaptchaWebView) { self.parent = parent }

        func load(in webView: WKWebView) {
            let resource: String
            switch parent.kind {
            case .tencentCaptcha: resource = "noa_captcha_tx"
            case .aliyunCaptcha(let interactive):
                resource = interactive ? "noa_captcha_alitwo" : "noa_captcha_alione"
            case .imageCaptcha, .securityCode:
                fail()
                return
            }
            let bundle = Bundle.main
            // 同时兼容 Xcode 保留资源子目录和将资源平铺到应用包的打包方式。
            pageURL = bundle.url(forResource: resource, withExtension: "html", subdirectory: "Resources/LoginVerification")
                ?? bundle.url(forResource: resource, withExtension: "html", subdirectory: "LoginVerification")
                ?? bundle.url(forResource: resource, withExtension: "html")
            guard let pageURL else {
                fail("验证资源加载失败，请重试。")
                return
            }
            loadTimeout = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: 45_000_000_000) }
                catch { return }
                self?.fail("验证加载超时，请检查网络后重试。")
            }
            webView.loadFileURL(pageURL, allowingReadAccessTo: pageURL.deletingLastPathComponent())
        }

        func stop() {
            stopped = true
            loadTimeout?.cancel()
            loadTimeout = nil
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            // 服务商子框架可以显示验证码，但不能直接提交结果；校验主框架与本地文件来源。
            guard !stopped, !receivedAnswer, message.frameInfo.isMainFrame,
                  message.frameInfo.securityOrigin.protocol == "file",
                  let url = message.frameInfo.request.url, isBundledPage(url) else { return }

            if message.name == "closeWebView" {
                stop()
                parent.cancelled()
                return
            }
            guard let payload = dictionary(from: message.body) else { fail(); return }
            if message.name == "captchaStatus" {
                if payload["state"] as? String == "ready" {
                    loadTimeout?.cancel()
                    loadTimeout = nil
                    parent.stateChanged(.ready)
                } else {
                    fail()
                }
                return
            }

            var answer = LoginVerificationAnswer()
            switch (parent.kind, message.name) {
            case (.tencentCaptcha, "iosJSBridge"):
                // 腾讯仅在成功回调中提供有效凭据；关闭或失败不能继续登录。
                guard (payload["ret"] as? NSNumber)?.intValue == 0,
                      let ticket = payload["ticket"] as? String, !ticket.isEmpty,
                      let randstr = payload["randstr"] as? String, !randstr.isEmpty else {
                    if (payload["ret"] as? NSNumber)?.intValue == 2 {
                        stop()
                        parent.cancelled()
                    } else { fail() }
                    return
                }
                answer.ticket = ticket
                answer.randstr = randstr
            case (.aliyunCaptcha, "getVerifyResult"):
                guard let parameter = payload["data"] as? String, !parameter.isEmpty else { fail(); return }
                answer.captchaVerifyParam = parameter
            default: return
            }
            receivedAnswer = true
            loadTimeout?.cancel()
            loadTimeout = nil
            parent.completed(answer)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
            if navigationAction.targetFrame?.isMainFrame == true {
                let allowed = isBundledPage(url)
                decisionHandler(allowed ? .allow : .cancel)
                if !allowed { fail() }
            } else {
                // 允许服务商通过 HTTPS 子框架显示验证码，上面的来源校验会拒绝其直接桥接消息。
                decisionHandler(url.scheme == "https" || url.absoluteString == "about:blank" ? .allow : .cancel)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail() }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail() }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { fail() }

        private func isBundledPage(_ url: URL) -> Bool {
            url.isFileURL && url.standardizedFileURL == pageURL?.standardizedFileURL
        }

        private func fail(_ message: String = "验证加载失败，请检查网络后重试。") {
            guard !stopped, !receivedAnswer else { return }
            stop()
            // 延后更新 makeUIView 期间产生的错误，避免在视图更新过程中修改 SwiftUI 状态。
            Task { @MainActor [parent] in parent.stateChanged(.failed(message)) }
        }

        private func dictionary(from body: Any) -> [String: Any]? {
            if let dictionary = body as? [String: Any] { return dictionary }
            guard let string = body as? String, let data = string.data(using: .utf8) else { return nil }
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
    }

    @MainActor
    private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
        // WebKit 强持有消息处理器；通过弱引用转发，避免处理器与页面协调对象相互持有。
        weak var target: Coordinator?
        init(target: Coordinator) { self.target = target }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            target?.userContentController(userContentController, didReceive: message)
        }
    }
}
