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
        content.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background { if highlighted { ClubTheme.wash } else { ClubTheme.card } }
            .clipShape(RoundedRectangle(cornerRadius: highlighted ? 28 : 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: highlighted ? 28 : 22, style: .continuous)
                .stroke(highlighted ? ClubTheme.teal.opacity(0.2) : ClubTheme.border, lineWidth: 1))
    }
}
