//
//  LoginField.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import SwiftUI
import TBBasicLib

/// 账号和密码输入组件，密码显隐状态只在当前组件内保存。
struct LoginField: View {
    let title: String
    let placeholder: String
    /// 使用新项目 Assets 中的图标，不引用旧版图标组件。
    let icon: String
    @Binding var text: String
    var secure = false
    var focus: FocusState<Bool>.Binding
    @State private var passwordVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))

            HStack(spacing: 12) {
                Image("club-\(icon)")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundColor(LoginPalette.darkTeal)
                    .accessibilityHidden(true)

                Group {
                    if secure && !passwordVisible {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(.system(size: 15))
                .foregroundColor(LoginPalette.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(secure ? .password : .username)
                .submitLabel(.done)
                .focused(focus)
                .accessibilityLabel(title)
                .accessibilityIdentifier("field.\(icon)")
                .frame(height: 36)

                if secure {
                    Button {
                        passwordVisible.toggle()
                    } label: {
                        Image("club-eye")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundColor(LoginPalette.darkTeal)
                            .frame(width: 44, height: 44)
                            .background(LoginPalette.wash)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .accessibilityLabel(passwordVisible ? "隐藏密码" : "显示密码")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(LoginPalette.background)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(LoginPalette.border, lineWidth: 1)
            }
        }
    }
}
