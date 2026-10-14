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
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 6.zoom()) {
            configuration.icon.font(.system(size: 23.zoom()))
                .foregroundStyle(MessagingTheme.text)
                .frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
                .background(MessagingTheme.surface, in: RoundedRectangle(cornerRadius: 12.zoom()))
            configuration.title.font(.caption).foregroundStyle(MessagingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, minHeight: 68.zoom())
    }
}
