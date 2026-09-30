//
//  ContactAvatar.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct ContactAvatar: View {
    let contact: ClubContact
    let size: CGFloat
    private var color: Color {
        switch contact.tone { case 1: return ClubTheme.border.opacity(0.5); case 2: return ClubTheme.pale.opacity(0.4); default: return ClubTheme.pale }
    }
    var body: some View {
        Text(String(contact.name.prefix(1))).font(.system(size: size * 0.36, weight: .medium, design: .rounded))
            .foregroundColor(ClubTheme.ink).frame(width: size, height: size)
            .background(color).clipShape(RoundedRectangle(cornerRadius: size * 0.35)).accessibilityHidden(true)
    }
}
