//
//  CommunitySearchField.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct CommunitySearchField: View {
    let placeholder: String
    @Binding var text: String
    let focus: FocusState<Bool>.Binding
    let identifier: String
    var body: some View {
        HStack(spacing: 10) {
            ClubIcon(name: "search").foregroundColor(ClubTheme.secondary)
            TextField(placeholder, text: $text).font(.body).focused(focus).submitLabel(.search)
                .autocapitalization(.none).disableAutocorrection(true)
                .accessibilityLabel(placeholder).accessibilityIdentifier(identifier)
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(ClubTheme.secondary).frame(width: 44, height: 44) }
                    .accessibilityLabel("清除搜索").accessibilityIdentifier("clearCommunitySearch")
            }
        }.padding(.leading, 14).padding(.trailing, text.isEmpty ? 14 : 0).frame(minHeight: 52)
            .background(ClubTheme.card).clipShape(RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(ClubTheme.border, lineWidth: 1))
    }
}
