//
//  InformationSheet.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct InformationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let page: InformationPage
    var body: some View {
        NavigationView {
            ScrollView {
                Group {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(Array(page.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                            Text(paragraph).font(index == 0 ? .title3.weight(.semibold) : .body)
                                .foregroundStyle(index == 0 ? ClubTheme.ink : ClubTheme.secondary).lineSpacing(6).textSelection(.enabled)
                        }
                    }
                }.padding(20).frame(maxWidth: 600, alignment: .leading).frame(maxWidth: .infinity)
            }.background(ClubTheme.card.ignoresSafeArea()).foregroundStyle(ClubTheme.ink).navigationTitle(page.rawValue).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() }.buttonStyle(.plain).foregroundStyle(ClubTheme.teal).frame(minHeight: 44) } }
        }.navigationViewStyle(.stack).tint(ClubTheme.darkTeal)
    }
}
