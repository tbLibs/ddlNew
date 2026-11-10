//
//  MiniAppWebSession.swift
//  ddlNew
//
//  Created by taobo on 2026/11/9.
//
import SwiftUI
import Combine
import WebKit

/// 一个应用拥有一个网页实例，浮窗恢复复用历史及滚动位置；退出时由认证所有者销毁。
@MainActor final class MiniAppWebSession: NSObject, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate {
    let id: String
    let icon: String
    let entryURL: URL
    let webView: WKWebView
    @Published private(set) var title: String
    @Published private(set) var currentURL: URL
    @Published private(set) var isLoading = true
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var errorMessage: String?
    @Published var downloadURL: URL?
    private var observations: [NSKeyValueObservation] = []
    private var closed = false
    private var failedURL: URL?

    init(id: String, title: String, icon: String, url: URL, entryURL: URL? = nil, dataStore: WKWebsiteDataStore) {
        self.id = id; self.title = title; self.icon = icon; currentURL = url; self.entryURL = entryURL ?? url
        let config = WKWebViewConfiguration()
        config.websiteDataStore = dataStore
        config.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self; webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        observations = [webView.observe(\.url, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.updateState() }
        }, webView.observe(\.title, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.updateState() }
        }, webView.observe(\.isLoading, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.updateState() }
        }, webView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.updateState() }
        }, webView.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.updateState() }
        }]
        webView.load(URLRequest(url: url))
    }

    /// 导航失败保留实际失败地址，重试不退回入口网址。
    func reload() { guard !closed else { return }; errorMessage = nil; webView.load(URLRequest(url: failedURL ?? currentURL)) }
    func back() { guard !closed else { return }; webView.goBack() }
    func forward() { guard !closed else { return }; webView.goForward() }
    func suspend(_ suspended: Bool) { guard !closed else { return }; webView.setAllMediaPlaybackSuspended(suspended, completionHandler: nil) }
    func close() {
        closed = true; webView.stopLoading(); webView.setAllMediaPlaybackSuspended(true, completionHandler: nil)
        observations.removeAll(); webView.navigationDelegate = nil; webView.uiDelegate = nil
        webView.loadHTMLString("", baseURL: nil)
    }

    private func updateState() {
        guard !closed else { return }
        if let url = webView.url, let valid = MiniAppWebPolicy.url(url.absoluteString) { currentURL = valid }
        if let name = webView.title, !name.isEmpty { title = name }
        isLoading = webView.isLoading; canGoBack = webView.canGoBack; canGoForward = webView.canGoForward
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard !closed else { return }; errorMessage = nil; failedURL = nil; updateState()
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !closed else { return }
        if let value = webView.url, let valid = MiniAppWebPolicy.url(value.absoluteString) { currentURL = valid }
        if let value = webView.title, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { title = value }
        errorMessage = nil; failedURL = nil; updateState()
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard !closed else { return }; isLoading = false; errorMessage = L10n.tr("网页已暂停，请重新加载")
    }
    private func failed(_ error: Error) {
        guard !closed, (error as NSError).code != NSURLErrorCancelled else { return }
        if let value = (error as NSError).userInfo[NSURLErrorFailingURLStringErrorKey] as? String { failedURL = MiniAppWebPolicy.url(value) }
        isLoading = false; errorMessage = L10n.tr("网页加载失败，请检查网络后重试")
    }
    /// 新窗口链接在当前应用内打开，未向页面注入登录凭据或原生业务桥。
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard !closed, let url = navigationAction.request.url, MiniAppWebPolicy.url(url.absoluteString) != nil else {
            decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }
    /// 下载响应交给用户确认后用系统浏览器处理，不额外发HEAD请求或绕过TLS校验。
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard !closed else { decisionHandler(.cancel); return }
        let disposition = (navigationResponse.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Disposition") ?? ""
        if navigationResponse.isForMainFrame && (!navigationResponse.canShowMIMEType || disposition.lowercased().contains("attachment")),
           let url = navigationResponse.response.url, MiniAppWebPolicy.url(url.absoluteString) != nil {
            downloadURL = url; isLoading = false; decisionHandler(.cancel)
        } else { decisionHandler(.allow) }
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if !closed, navigationAction.targetFrame == nil, let url = navigationAction.request.url,
           MiniAppWebPolicy.url(url.absoluteString) != nil { webView.load(navigationAction.request) }
        return nil
    }
}
