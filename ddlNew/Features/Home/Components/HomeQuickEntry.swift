//
//  HomeQuickEntry.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 报名、候补及签到的轻量入口，只展示传入的真实本机记录数量。
struct HomeQuickEntry: View {
    let title: String
    let symbol: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 20)).foregroundStyle(HomeTheme.forest)
                .frame(height: 28).accessibilityHidden(true)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(HomeTheme.text)
            Text(detail).font(.caption).foregroundStyle(HomeTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(HomeTheme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(HomeTheme.border, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}
