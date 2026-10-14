//
//  MessagingPageChrome.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import SwiftUI

/// 关联二级页共用旧版导航层级，push 后隐藏底栏并保留系统返回手势。
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
            .toolbar(.hidden, for: .tabBar)
            .toolbarBackground(MessagingTheme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}
