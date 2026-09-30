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
            ClubScroll {
                ClubCard(padding: 22) {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(page.paragraphs, id: \.self) { Text($0).font(.system(size: 15)).lineSpacing(6).textSelection(.enabled) }
                    }
                }.padding(20)
            }.navigationTitle(page.rawValue).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.navigationViewStyle(.stack).tint(ClubTheme.darkTeal)
    }
}
