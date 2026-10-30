//
//  InvitationCodeButtonStyle.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import SwiftUI
import UIAdapter

/// “连接俱乐部”按钮的纯视觉样式。
struct InvitationCodeButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(isEnabled ? MessagingTheme.onPrimaryAction : HomeTheme.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(isEnabled ? InvitationCodePalette.action : HomeTheme.border)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
