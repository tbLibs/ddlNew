//
//  LoginButtonStyle.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import SwiftUI
import TBBasicLib

/// 登录按钮的纯视觉样式，禁用状态随输入是否为空更新。
struct LoginButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background {
                LoginPalette.action.opacity(isEnabled ? 1 : 0.42)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: LoginPalette.teal.opacity(isEnabled ? 0.14 : 0), radius: 14, y: 10)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
