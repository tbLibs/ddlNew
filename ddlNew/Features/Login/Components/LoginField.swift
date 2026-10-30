//
//  LoginField.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import SwiftUI

/// 账号和密码输入组件，密码显隐状态只在当前组件内保存。
struct LoginField: View {
    let title: String
    let placeholder: String
    /// 保留字段标识，用于无障碍与自动化定位。
    let icon: String
    @Binding var text: String
    var secure = false
    var focus: FocusState<Bool>.Binding
    @State private var passwordVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.medium))

            HStack(spacing: 12) {
                Group {
                    if secure && !passwordVisible {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(.body)
                .foregroundColor(LoginPalette.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(secure ? .password : .username)
                .submitLabel(.done)
                .focused(focus)
                .accessibilityLabel(title)
                .accessibilityIdentifier("field.\(icon)")
                .frame(minHeight: 44)

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
                            .background(Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .accessibilityLabel(passwordVisible ? "隐藏密码" : "显示密码")
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 4)
            .background(HomeTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
