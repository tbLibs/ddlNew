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
    var identifier: String? = nil
    var contentType: UITextContentType? = nil
    @FocusState private var localFocus: Bool
    @State private var passwordVisible = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.medium))
            HStack(spacing: 12) {
                ClubIcon(name: icon).foregroundColor(ClubTheme.darkTeal)
                Group {
                    if secure && !passwordVisible {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                    .font(.body)
                    .foregroundColor(ClubTheme.ink)
                    .keyboardType(keyboard).submitLabel(.done).autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused(focus ?? $localFocus)
                    .textContentType(contentType ?? (secure ? .password : (keyboard == .numberPad ? .oneTimeCode : .username)))
                    .accessibilityLabel(title).accessibilityIdentifier(identifier ?? "field.\(icon)")
                    .frame(minHeight: 36)
                if secure {
                    Button { passwordVisible.toggle() } label: {
                        Image(systemName: passwordVisible ? "eye.slash" : "eye").frame(width: 44, height: 44)

                    }
                    .accessibilityLabel(passwordVisible ? "隐藏密码" : "显示密码")
                    .accessibilityIdentifier("\(identifier ?? "field.\(icon)").visibility")
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 4)
            .frame(minHeight: 52)
            .background(HomeTheme.background).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ClubTheme.border, lineWidth: 1))
        }
    }
}
