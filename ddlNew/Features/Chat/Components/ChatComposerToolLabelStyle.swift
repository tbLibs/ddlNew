//
//  ChatComposerToolLabelStyle.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import SwiftUI
import UIAdapter

/// 展开的聊天工具面板采用上图标下文字。
struct ChatComposerToolLabelStyle: LabelStyle {
    var equalWidth = false
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 3.zoom()) {
            configuration.icon.font(.system(size: 21.zoom()))
                .foregroundStyle(MessagingTheme.text)
                .frame(height: 24.zoom())
            configuration.title.font(.caption).foregroundStyle(MessagingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }.frame(minWidth: equalWidth ? 0 : max(56, 56.zoom()), maxWidth: equalWidth ? .infinity : nil, minHeight: max(52, 52.zoom())).contentShape(Rectangle())
    }
}

/// 按压反馈只作用于按钮内容，外部触点与布局保持不变。
struct ChatComposerButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 17.0, *) {
            configuration.label
                .foregroundStyle(MessagingTheme.accent)
                .animation(.easeOut(duration: reduceMotion ? 0.08 : 0.12)) { label in
                    label.scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
                        .opacity(configuration.isPressed ? 0.68 : 1)
                }
                .contentShape(Rectangle())
        } else {
            // 旧系统只提供直接按压反馈，避免局部动画覆盖面板的位置动画。
            configuration.label.foregroundStyle(MessagingTheme.accent)
                .opacity(configuration.isPressed ? 0.68 : 1)
                .contentShape(Rectangle())
        }
    }
}
