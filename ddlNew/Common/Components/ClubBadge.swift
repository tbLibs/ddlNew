//
//  ClubBadge.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct ClubBadge: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 11, weight: .semibold)).foregroundColor(ClubTheme.darkTeal)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color(clubHex: 0xEFF9F8)).clipShape(Capsule())
    }
}
