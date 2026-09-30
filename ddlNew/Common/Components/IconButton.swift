//
//  IconButton.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct IconButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ClubIcon(name: icon, size: 21).foregroundColor(ClubTheme.teal)
                .frame(width: 44, height: 44).background(ClubTheme.wash)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }.accessibilityLabel(label)
    }
}
