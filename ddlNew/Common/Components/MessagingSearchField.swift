//
//  MessagingSearchField.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import SwiftUI
import UIAdapter

/// 列表内搜索保留本地筛选，顶部放大镜另走全局搜索。
struct MessagingSearchField: View {
    let placeholder: String
    @Binding var text: String
    let focus: FocusState<Bool>.Binding
    let identifier: String

    var body: some View {
        HStack(spacing: 8.zoom()) {
            Image(systemName: "magnifyingglass").font(.system(size: 18.zoom())).foregroundStyle(MessagingTheme.secondaryText).accessibilityHidden(true)
            TextField(placeholder, text: $text).font(.body).focused(focus).submitLabel(.search)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityLabel(placeholder).accessibilityIdentifier(identifier)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
                }.foregroundStyle(MessagingTheme.secondaryText).accessibilityLabel("清除搜索")
            }
        }
        .padding(.leading, 12.zoom()).padding(.trailing, text.isEmpty ? 12 : 0.zoom())
        .frame(minHeight: max(48, 48.zoom())).background(MessagingTheme.pressed, in: RoundedRectangle(cornerRadius: 12.zoom()))
    }
}
