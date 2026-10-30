//
//  MessagingTabs.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import SwiftUI
import UIAdapter

/// 分类只通过点击切换，避免与列表滑动和系统返回手势竞争。
struct MessagingTabs<Selection: RawRepresentable & CaseIterable & Hashable>: View where Selection.RawValue == String, Selection.AllCases: RandomAccessCollection {
    @Binding var selection: Selection

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 24.zoom()) { options; Spacer(minLength: 0) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24.zoom()) { options }
            }
        }
    }

    private var options: some View {
        Group {
            ForEach(Array(Selection.allCases), id: \.self) { item in
                Button { selection = item } label: {
                    VStack(spacing: 0.zoom()) {
                        Text(item.rawValue).font(.subheadline.weight(selection == item ? .semibold : .regular)).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                            .padding(.vertical, 12.zoom())
                        Capsule().fill(selection == item ? MessagingTheme.accent : .clear).frame(width: 18.zoom(), height: 3.zoom())
                    }.frame(minWidth: max(44, 44.zoom()), minHeight: max(44, 44.zoom())).contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(selection == item ? MessagingTheme.accent : MessagingTheme.secondaryText)
                .accessibilityAddTraits(selection == item ? .isSelected : [])
            }
        }
    }
}
