//
//  ClubField.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct ClubField: View {
    let title: String
    let placeholder: String
    let icon: String
    @Binding var text: String
    var secure = false
    var keyboard: UIKeyboardType = .default
    var focus: FocusState<Bool>.Binding? = nil
    @FocusState private var localFocus: Bool
    @State private var passwordVisible = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 12, weight: .semibold))
            HStack(spacing: 12) {
                ClubIcon(name: icon).foregroundColor(ClubTheme.darkTeal)
                Group {
                    if secure && !passwordVisible {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                    .font(.system(size: 15))
                    .foregroundColor(ClubTheme.ink)
                    .keyboardType(keyboard).submitLabel(.done).autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused(focus ?? $localFocus)
                    .textContentType(secure ? .password : (keyboard == .numberPad ? .oneTimeCode : .username))
                    .accessibilityLabel(title).accessibilityIdentifier("field.\(icon)")
                    .frame(height: 36)
                if secure {
                    Button { passwordVisible.toggle() } label: {
                        ClubIcon(name: "eye").frame(width: 44, height: 44)
                            .background(ClubTheme.wash).clipShape(RoundedRectangle(cornerRadius: 14))
                    }.accessibilityLabel(passwordVisible ? "隐藏密码" : "显示密码")
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(ClubTheme.background).clipShape(RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(ClubTheme.border, lineWidth: 1))
        }
    }
}
