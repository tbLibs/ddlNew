//
//  InvitationCodeField.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import SwiftUI
import TBBasicLib
import UIAdapter

/// 邀请码标题与数字输入框。
struct InvitationCodeField: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10.zoom()) {
            Text("俱乐部邀请码")
                .font(.system(size: 12.zoom(), weight: .semibold))

            HStack(spacing: 12.zoom()) {
                Image("club-shield")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18.zoom(), height: 18.zoom())
                    .foregroundStyle(InvitationCodePalette.darkTeal)
                    .accessibilityHidden(true)

                TextField("例如 10001", text: $text)
                    .font(.system(size: 15.zoom()))
                    .foregroundStyle(InvitationCodePalette.ink)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .autocorrectionDisabled()
                    .accessibilityLabel("俱乐部邀请码")
                    .accessibilityIdentifier("field.shield")
                    .frame(height: 36.zoom())
            }
            .padding(.horizontal, 16.zoom())
            .padding(.vertical, 14.zoom())
            .background(InvitationCodePalette.background)
            .clipShape(RoundedRectangle(cornerRadius: 17.zoom(), style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17.zoom(), style: .continuous)
                    .stroke(InvitationCodePalette.border, lineWidth: 1.zoom())
            }
        }
    }
}
