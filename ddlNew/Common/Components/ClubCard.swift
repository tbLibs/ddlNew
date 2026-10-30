//
//  ClubCard.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct ClubCard<Content: View>: View {
    var padding: CGFloat = 16
    var highlighted = false
    @ViewBuilder let content: Content
    var body: some View {
        content.padding(.vertical, padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(ClubTheme.card)
            .overlay(alignment: .bottom) { Rectangle().fill(MessagingTheme.divider).frame(height: 1) }
    }
}
