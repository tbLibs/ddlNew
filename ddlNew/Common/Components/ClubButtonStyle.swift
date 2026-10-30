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
        configuration.label.font(.body.weight(.semibold))
            .foregroundColor(MessagingTheme.onPrimaryAction).frame(maxWidth: .infinity).frame(minHeight: 52)
            .background { ClubTheme.action.opacity(isEnabled ? 1 : 0.42) }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
