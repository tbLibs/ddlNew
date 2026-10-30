//
//  HomeQuickEntry.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct HomeQuickEntry: View {
    let title: String
    let symbol: String
    let detail: String

    var body: some View {
        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(HomeTheme.forest)
            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
            .accessibilityLabel("\(title)，\(detail)")
    }
}
