//
//  DeleteAccountScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct DeleteAccountScreen: View {
    @EnvironmentObject private var store: ClubStore
    @EnvironmentObject private var community: ClubCommunity
    @State private var acknowledged = false
    @State private var confirming = false
    @State private var deleting = false
    @State private var errorMessage: String?

    var body: some View {
        ClubScroll {
            VStack(alignment: .leading, spacing: 24) {
                Text("注销前，请确认以下事项").font(.title2.weight(.semibold))
                    .foregroundColor(ClubTheme.ink).fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 18) {
                        explanation("清除账号记录", "清除登录状态、俱乐部连接、报名、候补和签到记录。")
                        Divider()
                        explanation("结束聊天会话", "清除本次会话中的聊天记录、草稿和常用联系人。")
                        Divider()
                        explanation("账号无法再次登录", "注销后不可撤销，账号无法再次登录。")
                    }
                }

            }.padding(20).disabled(deleting)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 16) {
                Toggle("我已了解注销后果", isOn: $acknowledged)
                    .font(.body).tint(ClubTheme.darkTeal).frame(minHeight: 44)
                    .accessibilityIdentifier("acknowledgeAccountDeletion")

                Button { confirming = true } label: {
                    HStack {
                        Text("确认注销账号")
                    }.frame(maxWidth: .infinity)
                }
                .buttonStyle(MessagingActionButtonStyle(fill: ClubTheme.error, foreground: MessagingTheme.onError))
                .disabled(!acknowledged || deleting)
                .accessibilityIdentifier("confirmAccountDeletion")
            }.frame(maxWidth: 600).padding(20).frame(maxWidth: .infinity).background(ClubTheme.card).disabled(deleting)
        }
        .messagingLoadingToast(deleting, title: "正在注销")
        .messagingFeedbackToast(errorMessage)
        .navigationTitle("注销账号").navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(deleting)
        .alert("确定注销账号？", isPresented: $confirming) {
            Button("取消", role: .cancel) { }
            Button("注销账号", role: .destructive) {
                deleting = true
                errorMessage = nil
                Task {
                    do {
                        try await store.deleteAccount()
                        community.eraseSession()
                    } catch {
                        errorMessage = "注销未完成，请重试。"
                        deleting = false
                    }
                }
            }.accessibilityIdentifier("executeAccountDeletion")
        } message: {
            Text("将清除账号相关记录并退出会员空间，该账号将无法再次登录。此操作不可撤销。")
        }
    }

    private func explanation(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundColor(ClubTheme.secondary).lineSpacing(4)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
