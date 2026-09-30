//
//  LegalEntryLinks.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct LegalEntryLinks: View {
    @State private var document: LegalDocument?
    var body: some View {
        HStack(spacing: 24) {
            Button("隐私政策") { document = .privacy }.accessibilityIdentifier("openPrivacyPolicy")
            Button("使用支持") { document = .support }.accessibilityIdentifier("openSupport")
        }
        .font(.footnote).foregroundColor(ClubTheme.darkTeal)
        .frame(minHeight: 44)
        .sheet(item: $document) { LegalDocumentScreen(document: $0) }
    }
}
