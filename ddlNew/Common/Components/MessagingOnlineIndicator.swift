//
//  MessagingOnlineIndicator.swift
//  ddlNew
//
//  Created by taobo on 2026/10/16.
//

import SwiftUI
import UIAdapter

/// 消息与通讯录共用适中的在线圆点，放在头像右下角。
struct MessagingOnlineIndicator: View {
    var body: some View {
        Circle()
            .fill(MessagingTheme.online)
            .frame(width: 12.zoom(), height: 12.zoom())
            .overlay(Circle().strokeBorder(MessagingTheme.surface, lineWidth: 1.zoom()))
            .accessibilityHidden(true)
    }
}
