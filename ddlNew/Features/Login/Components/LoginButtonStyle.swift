//
//  LoginButtonStyle.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import SwiftUI

/// 登录按钮的纯视觉样式，禁用状态随输入是否为空更新。
struct LoginButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(isEnabled ? MessagingTheme.onPrimaryAction : HomeTheme.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(isEnabled ? LoginPalette.action : HomeTheme.border)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
