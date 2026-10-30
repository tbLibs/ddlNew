//
//  ClubMenuRow.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct ClubMenuRow: View {
    let title: String
    let icon: String
    var detail: String = ""
    var body: some View {
        HStack(spacing: 10) {
            ClubIcon(name: icon).foregroundStyle(ClubTheme.secondary)
            Text(title).font(.body)
            Spacer()
            Text(detail).font(.subheadline).foregroundColor(ClubTheme.secondary)
        }.frame(minHeight: 56).contentShape(Rectangle())
    }
}
