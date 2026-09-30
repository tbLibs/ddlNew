//
//  LegalDocumentScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct LegalDocumentScreen: View {
    @Environment(\.dismiss) private var dismiss
    let document: LegalDocument
    var body: some View {
        NavigationView {
            Group {
                if let url = document.fileURL {
                    LocalLegalPage(url: url)
                } else {
                    Text("暂时无法打开文档，请稍后重试。").padding()
                }
            }
            .navigationTitle(document.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
            }
        }.navigationViewStyle(.stack).tint(ClubTheme.darkTeal)
    }
}
