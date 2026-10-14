//
//  MessagingRowStyle.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import SwiftUI

/// 按压只变背景，不缩放或挪动列表内容。
struct MessagingRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(minHeight: 44).contentShape(Rectangle()).background(configuration.isPressed ? MessagingTheme.pressed : MessagingTheme.surface)
    }
}
