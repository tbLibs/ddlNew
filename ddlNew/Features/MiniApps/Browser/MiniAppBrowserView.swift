//
//  MiniAppBrowserView.swift
//  ddlNew
//
//  Created by taobo on 2026/11/9.
//
import SwiftUI
import WebKit

/// 小应用的独立浏览容器；关闭离开网页，后退优先回到上一网页。
struct MiniAppBrowserView: View {
    @Environment(\.locale) private var localizationLocale
    @ObservedObject var session: MiniAppWebSession
    let close: () -> Void
    let minimize: () -> Void
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var phase
    @State private var feedback: String?

    var body: some View {
        NavigationStack {
            ZStack {
                MiniAppWebContent(session: session)
                if let error = session.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.exclamationmark").font(.largeTitle).accessibilityHidden(true)
                        Text(error).multilineTextAlignment(.center)
                        Button(L10n.tr("重新加载")) { session.reload() }.buttonStyle(.borderedProminent).frame(minHeight: 44)
                    }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).background(MessagingTheme.background)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack(spacing: 24) {
                    Button(action: session.back) { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .disabled(!session.canGoBack).accessibilityLabel(L10n.tr("网页后退"))
                    Button(action: session.forward) { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                        .disabled(!session.canGoForward).accessibilityLabel(L10n.tr("网页前进"))
                    Text(session.currentURL.host ?? "").font(.caption).foregroundStyle(MessagingTheme.secondaryText).lineLimit(1).frame(maxWidth: .infinity)
                    Button(action: session.reload) { Image(systemName: "arrow.clockwise").frame(width: 44, height: 44) }.accessibilityLabel(L10n.tr("刷新网页"))
                }.padding(.horizontal, 12).background(MessagingTheme.surface)
            }
            .navigationTitle(session.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.tr("关闭"), action: close).frame(minHeight: 44) }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: minimize) { Label(L10n.tr("浮窗"), systemImage: "rectangle.inset.filled") }
                        Button { openURL(session.currentURL) } label: { Label(L10n.tr("在浏览器打开"), systemImage: "safari") }
                        Button { UIPasteboard.general.string = session.currentURL.absoluteString; feedback = L10n.tr("链接已复制") } label: { Label(L10n.tr("复制链接"), systemImage: "doc.on.doc") }
                    } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }.accessibilityLabel(L10n.tr("网页更多操作"))
                }
            }
            .overlay(alignment: .top) {
                if session.isLoading { ProgressView().padding(8).background(MessagingTheme.surface, in: Capsule()).accessibilityLabel(L10n.tr("正在加载网页")) }
            }
            .alert(L10n.tr("在浏览器下载文件？"), isPresented: Binding(get: { session.downloadURL != nil }, set: { if !$0 { session.downloadURL = nil } })) {
                Button(L10n.tr("取消"), role: .cancel) { session.downloadURL = nil }
                Button(L10n.tr("在浏览器打开")) { if let url = session.downloadURL { openURL(url) }; session.downloadURL = nil }
            } message: { Text(L10n.tr("此文件将交由系统浏览器打开。")) }
            .messagingFeedbackToast(feedback)
        }
        .tint(MessagingTheme.accent)
        .onAppear { session.suspend(phase != .active) }
        .onChange(of: phase) { session.suspend($0 != .active) }
        .onDisappear { session.suspend(true) }
    }
}

private struct MiniAppWebContent: UIViewRepresentable {
    @Environment(\.locale) private var localizationLocale
    let session: MiniAppWebSession
    func makeUIView(context: Context) -> WKWebView { session.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
