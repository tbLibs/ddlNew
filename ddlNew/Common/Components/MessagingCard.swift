//
//  MessagingCard.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import SwiftUI
import UIAdapter

/// 二级资料区使用老项目白色分区，圆角只用于区分内容组。
struct MessagingCard<Content: View>: View {
    var padding: CGFloat = 16.zoom()
    @ViewBuilder let content: Content

    var body: some View {
        content.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(MessagingTheme.surface, in: RoundedRectangle(cornerRadius: 10.zoom()))
    }
}
