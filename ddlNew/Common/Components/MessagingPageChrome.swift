//
//  MessagingPageChrome.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import SwiftUI

/// 关联二级页共用导航样式；底栏由Tab导航容器按路径控制。
struct MessagingPageChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(MessagingTheme.background.ignoresSafeArea())
            .foregroundStyle(MessagingTheme.text)
            .tint(MessagingTheme.accent)
            .controlSize(.large)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(false)
            .toolbarBackground(MessagingTheme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}
