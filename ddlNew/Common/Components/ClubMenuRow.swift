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
            ClubIcon(name: icon)
            Text(title).font(.system(size: 15))
            Spacer()
            Text(detail).font(.system(size: 11)).foregroundColor(ClubTheme.secondary)
        }.frame(minHeight: 56).contentShape(Rectangle())
    }
}
