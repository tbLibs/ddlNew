//
//  MiniAppButtonStyle.swift
//  ddlNew
//
//  Created by taobo on 2026/11/9.
//
import SwiftUI

/// 反馈只改变按钮外观，不缩放或动画化List行高；显式样式也隔离同行按钮操作。
struct MiniAppButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.65 : 1) : 0.4)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(MessagingTheme.accent.opacity(isEnabled && configuration.isPressed ? 0.1 : 0))
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
