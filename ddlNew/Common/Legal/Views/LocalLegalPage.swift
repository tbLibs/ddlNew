//
//  LocalLegalPage.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI
import WebKit

struct LocalLegalPage: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return view
    }
    func updateUIView(_ uiView: WKWebView, context: Context) { }
}
