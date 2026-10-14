//
//  MessagingStatusToast.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import SwiftUI
import AlertToast

extension View {
    /// loading只观察真实任务状态，不通过Toast关闭请求。
    func messagingLoadingToast(_ isLoading: Bool, title: String = "正在加载") -> some View {
        toast(isPresenting: Binding(get: { isLoading }, set: { _ in }), duration: 0, tapToDismiss: false) {
            AlertToast(type: .loading, title: title,
                       style: .style(backgroundColor: MessagingTheme.toastBackground, titleColor: MessagingTheme.toastText))
        }
    }

    /// 只提示新发生的业务结果，返回页面不重播Store遗留提示。
    func messagingFeedbackToast(_ message: String?, isEnabled: Bool = true, presentInitial: Bool = false) -> some View {
        modifier(MessagingFeedbackToast(message: message, isEnabled: isEnabled, presentInitial: presentInitial))
    }
}

private struct MessagingFeedbackToast: ViewModifier {
    let message: String?
    let isEnabled: Bool
    let presentInitial: Bool
    @State private var feedback: String?
    @State private var revision = UUID()

    func body(content: Content) -> some View {
        content
            .overlay {
                if let feedback {
                    let presentedRevision = revision
                    MessagingFeedbackPresenter(message: feedback) {
                        if revision == presentedRevision { self.feedback = nil }
                    }.id(presentedRevision).allowsHitTesting(false)
                }
            }
            .onChange(of: message) { value in
                guard isEnabled else { return }
                revision = UUID()
                feedback = value.flatMap { $0.isEmpty ? nil : $0 }
            }
            .onChange(of: isEnabled) { enabled in if !enabled { feedback = nil } }
            .onAppear { if presentInitial && isEnabled { feedback = message } }
            .onDisappear { feedback = nil }
    }
}

/// 浮层独立持有定时器，新反馈不重建页面及输入框状态。
private struct MessagingFeedbackPresenter: View {
    let message: String
    let onDismiss: () -> Void
    @State private var showing = false

    var body: some View {
        Color.clear
            .toast(isPresenting: $showing, duration: 3, alert: {
                AlertToast(type: .regular, title: message,
                           style: .style(backgroundColor: MessagingTheme.toastBackground, titleColor: MessagingTheme.toastText))
            }, completion: onDismiss)
            .onAppear { showing = true }
    }
}
