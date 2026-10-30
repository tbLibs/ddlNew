//
//  MessagingCard.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import SwiftUI
import UIAdapter

/// 二级资料以平整内容面和分隔线分区，保留各页自己的内容层级。
struct MessagingCard<Content: View>: View {
    var padding: CGFloat = 16.zoom()
    @ViewBuilder let content: Content

    var body: some View {
        content.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(MessagingTheme.surface)
            .overlay(alignment: .bottom) { Rectangle().fill(MessagingTheme.divider).frame(height: 1) }
    }
}
