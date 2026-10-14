//
//  MessagingScroll.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import SwiftUI
import UIAdapter

/// 资料与表单复用中性滚动背景，宽窗口限制阅读宽度。
struct MessagingScroll<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            content.frame(maxWidth: 640).frame(maxWidth: .infinity).padding(.bottom, 24.zoom())
        }
        .scrollDismissesKeyboard(.interactively)
        .background(MessagingTheme.background.ignoresSafeArea())
        .tint(MessagingTheme.accent)
    }
}
