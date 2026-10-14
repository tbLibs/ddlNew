//
//  PasswordChangeView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

/// 根页面承载安全流程；强制修改不能通过滑动关闭或返回导航绕过。
struct PasswordChangeView: View {
    let request: PasswordSecurityRequest
    @ObservedObject private var connection = IMConnectionCoordinator.shared
    @ObservedObject var coordinator: LoginSecurityCoordinator
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmation = ""

    private var requiresSymbol: Bool { connection.configuration?.checkEnglishSymbol ?? false }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(request.message)
                    if request.isForced { Text("俱乐部要求修改密码后才能继续使用").font(.footnote).foregroundStyle(.secondary) }
                }
                if !coordinator.passwordChanged {
                    if coordinator.oldPasswordVerified {
                        Section("设置新密码") {
                            SecureField("新密码", text: $newPassword).textContentType(.newPassword)
                            SecureField("确认新密码", text: $confirmation).textContentType(.newPassword)
                            Text(requiresSymbol ? "6～16位，包含字母、数字和英文符号" : "6～16位，包含字母和数字，可使用英文符号")
                                .font(.footnote).foregroundStyle(.secondary)
                            Button("修改密码") {
                                coordinator.changePassword(newPassword, confirmation: confirmation, requiresSymbol: requiresSymbol)
                                clearInputs()
                            }
                            .disabled(newPassword.isEmpty || confirmation.isEmpty || coordinator.isBusy)
                        }
                    } else {
                        Section("验证原密码") {
                            SecureField("原密码", text: $oldPassword).textContentType(.password)
                            Button("下一步") {
                                coordinator.verifyOldPassword(oldPassword)
                                oldPassword = ""
                            }
                            .disabled(oldPassword.isEmpty || coordinator.isBusy)
                        }
                    }
                }

                Section {
                    Button(coordinator.passwordChanged ? "退出并重新登录" : "退出登录", role: .destructive) {
                        clearInputs()
                        coordinator.exitToLogin()
                    }
                    .disabled(coordinator.isBusy)
                    if !request.isForced && !coordinator.passwordChanged {
                        Button("稍后修改") { clearInputs(); coordinator.dismiss() }.disabled(coordinator.isBusy)
                    }
                }
            }
            .disabled(coordinator.isBusy)
            .navigationTitle("密码安全")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("passwordSecurityScreen")
        }
        .messagingLoadingToast(coordinator.isBusy, title: "正在处理")
        .messagingFeedbackToast(coordinator.message)
        .interactiveDismissDisabled(request.isForced || coordinator.passwordChanged || coordinator.isBusy)
        .onChange(of: coordinator.inputResetID) { _ in clearInputs() }
        .onDisappear { clearInputs() }
    }

    private func clearInputs() { oldPassword = ""; newPassword = ""; confirmation = "" }
}
