import SwiftUI
import UIKit
import WebKit

enum LegalDocument: String, Identifiable {
    case privacy, support
    var id: String { rawValue }
    var title: String {
        switch self {
        case .privacy: return "隐私政策"
        case .support: return "使用支持"
        }
    }
    var onlineURL: URL? {
        guard let file = Bundle.main.url(forResource: "LegalLinks", withExtension: "json"),
              let data = try? Data(contentsOf: file),
              let links = try? JSONDecoder().decode([String: String].self, from: data),
              let value = links[rawValue], let url = URL(string: value), url.scheme == "https" else { return nil }
        return url
    }
}

struct LegalDocumentScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var loading = true
    @State private var loadFailed = false
    @State private var reloadID = 0
    let document: LegalDocument
    var body: some View {
        NavigationView {
            Group {
                if let url = document.onlineURL {
                    ZStack {
                        RemoteLegalPage(url: url, loading: $loading, loadFailed: $loadFailed)
                            .id(reloadID)
                        if loading {
                            ProgressView("正在加载…")
                                .padding(20).background(ClubTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        if loadFailed {
                            VStack(spacing: 16) {
                                Text("页面加载失败，请检查网络后重试。")
                                    .foregroundColor(ClubTheme.secondary)
                                Button("重新加载") {
                                    loadFailed = false
                                    loading = true
                                    reloadID += 1
                                }
                                .accessibilityIdentifier("reloadLegalDocument")
                            }
                            .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(ClubTheme.background)
                        }
                    }
                } else {
                    Text("暂时无法打开文档，请稍后重试。").padding()
                }
            }
            .navigationTitle(document.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
            }
        }.navigationViewStyle(.stack).tint(ClubTheme.darkTeal)
    }
}

private struct RemoteLegalPage: UIViewRepresentable {
    let url: URL
    @Binding var loading: Bool
    @Binding var loadFailed: Bool

    func makeCoordinator() -> Coordinator { Coordinator(loading: $loading, loadFailed: $loadFailed) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: url))
        return view
    }
    func updateUIView(_ uiView: WKWebView, context: Context) { }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding private var loading: Bool
        @Binding private var loadFailed: Bool

        init(loading: Binding<Bool>, loadFailed: Binding<Bool>) {
            _loading = loading
            _loadFailed = loadFailed
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            loading = true
            loadFailed = false
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loading = false }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail(error) }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail(error) }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url, url.scheme == "mailto" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let response = navigationResponse.response as? HTTPURLResponse, response.statusCode >= 400 {
                loading = false
                loadFailed = true
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
        private func fail(_ error: Error) {
            let failure = error as NSError
            guard !(failure.domain == NSURLErrorDomain && failure.code == NSURLErrorCancelled) else { return }
            loading = false
            loadFailed = true
        }
    }
}

struct LegalEntryLinks: View {
    @State private var document: LegalDocument?
    var body: some View {
        HStack(spacing: 24) {
            Button("隐私政策") { document = .privacy }.accessibilityIdentifier("openPrivacyPolicy")
            Button("使用支持") { document = .support }.accessibilityIdentifier("openSupport")
        }
        .font(.footnote).foregroundColor(ClubTheme.darkTeal)
        .frame(minHeight: 44)
        .sheet(item: $document) { LegalDocumentScreen(document: $0) }
    }
}
