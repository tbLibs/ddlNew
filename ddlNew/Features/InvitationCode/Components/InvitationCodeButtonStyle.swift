//
//  InvitationCodeButtonStyle.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import SwiftUI
import TBBasicLib
import UIAdapter

/// “连接俱乐部”按钮的纯视觉样式。
struct InvitationCodeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15.zoom(), weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52.zoom())
            .background(InvitationCodePalette.action)
            .clipShape(RoundedRectangle(cornerRadius: 16.zoom(), style: .continuous))
            .shadow(
                color: InvitationCodePalette.teal.opacity(0.14),
                radius: 14.zoom(),
                y: 10.zoom()
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
