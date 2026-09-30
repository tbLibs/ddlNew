//
//  ClubKeyboardDismissal.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct ClubKeyboardDismissal: ViewModifier {
    let isFocused: Bool
    let dismiss: () -> Void

    func body(content: Content) -> some View {
        content
            .padding(.bottom, isFocused ? 44 : 0)
            .overlay(alignment: .bottom) {
                if isFocused {
                    HStack {
                        Spacer()
                        Button("完成", action: dismiss)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ClubTheme.darkTeal)
                            .accessibilityIdentifier("keyboardDone")
                            .frame(minWidth: 60, minHeight: 44)
                    }
                    .padding(.horizontal, 16)
                    .background(ClubTheme.card)
                }
            }
            .onSubmit(dismiss)
    }
}
