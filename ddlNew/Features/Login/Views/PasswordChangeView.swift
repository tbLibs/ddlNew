//
//  PasswordChangeView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter

/// 根页面承载安全流程；强制修改不能通过滑动关闭或返回导航绕过。
struct PasswordChangeView: View {
    let request: PasswordSecurityRequest
    @ObservedObject var coordinator: LoginSecurityCoordinator
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmation = ""

    private var requiresSymbol: Bool { LocalAccountPolicy.requiresPasswordSymbol }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28.zoom()) {
                    if coordinator.passwordChanged {
                        VStack(spacing: 24.zoom()) {
                            Image(systemName: "checkmark.circle").font(.system(size: 64.zoom(), weight: .regular)).foregroundStyle(HomeTheme.forest).accessibilityHidden(true)
                            Text("密码已更新").font(.title.weight(.bold))
                            Text("请使用新密码重新登录").font(.body).foregroundStyle(HomeTheme.secondaryText)
                        }.frame(maxWidth: .infinity).multilineTextAlignment(.center).padding(.vertical, 64.zoom())
                    } else {
                        VStack(alignment: .leading, spacing: 8.zoom()) {
                            Text(request.message).font(.body).foregroundStyle(HomeTheme.secondaryText)
                            if request.isForced { Text("俱乐部要求修改密码后才能继续使用").font(.footnote).foregroundStyle(HomeTheme.secondaryText) }
                        }
                        if coordinator.oldPasswordVerified {
                            VStack(alignment: .leading, spacing: 12.zoom()) {
                                Text("新密码").font(.subheadline.weight(.semibold)).foregroundStyle(HomeTheme.secondaryText)
                                SecureField("新密码", text: $newPassword).textContentType(.newPassword)
                                    .padding(16.zoom()).frame(minHeight: 52.zoom()).background(HomeTheme.background, in: RoundedRectangle(cornerRadius: 12.zoom()))
                            }
                            VStack(alignment: .leading, spacing: 12.zoom()) {
                                Text("确认新密码").font(.subheadline.weight(.semibold)).foregroundStyle(HomeTheme.secondaryText)
                                SecureField("确认新密码", text: $confirmation).textContentType(.newPassword)
                                    .padding(16.zoom()).frame(minHeight: 52.zoom()).background(HomeTheme.background, in: RoundedRectangle(cornerRadius: 12.zoom()))
                            }
                            Text(requiresSymbol ? "6～16位，包含字母、数字和英文符号" : "6～16位，包含字母和数字，可使用英文符号")
                                .font(.footnote).foregroundStyle(HomeTheme.secondaryText)
                        } else {
                            VStack(alignment: .leading, spacing: 12.zoom()) {
                                Text("原密码").font(.subheadline.weight(.semibold)).foregroundStyle(HomeTheme.secondaryText)
                                SecureField("原密码", text: $oldPassword).textContentType(.password)
                                    .padding(16.zoom()).frame(minHeight: 52.zoom()).background(HomeTheme.background, in: RoundedRectangle(cornerRadius: 12.zoom()))
                            }
                        }
                    }
                }.padding(.horizontal, 20.zoom()).padding(.vertical, 32.zoom())
                    .frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .foregroundStyle(HomeTheme.text)
            .background(HomeTheme.surface)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12.zoom()) {
                    Button(coordinator.passwordChanged ? "退出并重新登录" : "退出登录", role: .destructive) {
                        clearInputs()
                        coordinator.exitToLogin()
                    }
                    .buttonStyle(MessagingActionButtonStyle(fill: coordinator.passwordChanged ? MessagingTheme.primaryAction : .clear,
                        foreground: coordinator.passwordChanged ? MessagingTheme.onPrimaryAction : MessagingTheme.accent, fullWidth: true))
                    .disabled(coordinator.isBusy)
                    if !coordinator.passwordChanged {
                        if !request.isForced && !coordinator.passwordChanged {
                            Button("稍后修改") { clearInputs(); coordinator.dismiss() }.frame(minHeight: 44).disabled(coordinator.isBusy)
                        }
                        if coordinator.oldPasswordVerified {
                            Button("修改密码") {
                                coordinator.changePassword(newPassword, confirmation: confirmation, requiresSymbol: requiresSymbol)
                                clearInputs()
                            }.buttonStyle(MessagingActionButtonStyle(fullWidth: true))
                                .disabled(newPassword.isEmpty || confirmation.isEmpty || coordinator.isBusy)
                        } else {
                            Button("下一步") {
                                coordinator.verifyOldPassword(oldPassword)
                                oldPassword = ""
                            }.buttonStyle(MessagingActionButtonStyle(fullWidth: true))
                                .disabled(oldPassword.isEmpty || coordinator.isBusy)
                        }
                    }
                }.padding(.horizontal, 20.zoom()).padding(.vertical, 16.zoom())
                    .frame(maxWidth: 640).frame(maxWidth: .infinity).background(HomeTheme.surface)
            }
            .tint(HomeTheme.forest)
            .disabled(coordinator.isBusy)
            .navigationTitle(coordinator.passwordChanged ? "修改成功" : "密码安全")
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
