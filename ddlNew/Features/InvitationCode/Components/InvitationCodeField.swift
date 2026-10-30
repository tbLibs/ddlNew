//
//  InvitationCodeField.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import SwiftUI
import UIAdapter

/// 邀请码标题与数字输入框。
struct InvitationCodeField: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10.zoom()) {
            Text("邀请码")
                .font(.footnote.weight(.medium))

            HStack(spacing: 12.zoom()) {
                TextField("请输入邀请码", text: $text)
                    .font(.body)
                    .foregroundStyle(InvitationCodePalette.ink)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .autocorrectionDisabled()
                    .accessibilityLabel("俱乐部邀请码")
                    .accessibilityIdentifier("field.shield")
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 16.zoom())
            .padding(.vertical, 4)
            .background(HomeTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
