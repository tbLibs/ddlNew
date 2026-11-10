//
//  MiniAppsDisclosure.swift
//  ddlNew
//
//  Created by taobo on 2026/11/9.
//
import SwiftUI

/// 标题独立占据固定高度的List行，内容展开只改变其下方的行。
struct MiniAppsDisclosure: View {
    @Environment(\.locale) private var localizationLocale
    @Binding var expanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { expanded.toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.2x2").foregroundStyle(MessagingTheme.accent).accessibilityHidden(true)
                Text(L10n.tr("我的应用")).font(.body.weight(.medium)).foregroundStyle(MessagingTheme.text)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold)).foregroundStyle(MessagingTheme.secondaryText)
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(expanded ? 180 : 0), anchor: .center)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }.frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(MiniAppButtonStyle())
        .accessibilityValue(expanded ? L10n.tr("已展开") : L10n.tr("已收起"))
        .padding(.horizontal, 16).padding(.vertical, 4)
    }
}
