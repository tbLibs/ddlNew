//
//  ChatComposerToolLabelStyle.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import SwiftUI
import UIAdapter

/// 旧聊天工具栏采用上图标下文字，常用功能在输入框下方保持可见。
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
