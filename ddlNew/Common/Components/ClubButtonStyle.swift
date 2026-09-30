//
//  ClubButtonStyle.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct ClubButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white).frame(maxWidth: .infinity).frame(minHeight: 52)
            .background { ClubTheme.action.opacity(isEnabled ? 1 : 0.42) }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: ClubTheme.teal.opacity(isEnabled ? 0.14 : 0), radius: 14, y: 10)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
