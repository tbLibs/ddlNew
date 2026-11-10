//
//  DeleteAccountScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct DeleteAccountScreen: View {
    @Environment(\.locale) private var localizationLocale
    @EnvironmentObject private var store: ClubStore
    @EnvironmentObject private var community: ClubCommunity
    @State private var acknowledged = false
    @State private var confirming = false
    @State private var deleting = false
    @State private var errorMessage: String?

    var body: some View {
        ClubScroll {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "person.crop.circle.badge.minus")
                    .font(.system(size: 36)).foregroundColor(ClubTheme.error)
                    .frame(width: 76, height: 76).background(ClubTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 24)).accessibilityHidden(true)
                Text(L10n.tr("注销前，请确认以下事项")).font(.title2.bold())
                    .font(.body).foregroundColor(ClubTheme.secondary).lineSpacing(5)
                ClubCard {
                    VStack(alignment: .leading, spacing: 18) {
                        explanation(L10n.tr("清除账号记录"), L10n.tr("清除登录状态、俱乐部连接、报名、候补和签到记录。"))
                        Divider()
                        explanation(L10n.tr("结束聊天会话"), L10n.tr("清除本次会话中的聊天记录、草稿和常用联系人。"))
                        Divider()
                        explanation(L10n.tr("账号无法再次登录"), L10n.tr("注销后不可撤销，账号无法再次登录。"))
                    }
                }
                Toggle(L10n.tr("我已了解注销后果"), isOn: $acknowledged)
                    .font(.body).tint(ClubTheme.darkTeal)
                    .accessibilityIdentifier("acknowledgeAccountDeletion")

                Button { confirming = true } label: {
                    HStack {
                        Text(L10n.tr("确认注销账号"))
                    }.frame(maxWidth: .infinity)
                }
                .buttonStyle(MessagingActionButtonStyle(fill: ClubTheme.error, foreground: .white))
                .disabled(!acknowledged || deleting)
                .accessibilityIdentifier("confirmAccountDeletion")
            }.padding(24).disabled(deleting)
        }
        .messagingLoadingToast(deleting, title: L10n.tr("正在注销"))
        .messagingFeedbackToast(errorMessage)
        .navigationTitle(L10n.tr("注销账号")).navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(deleting)
        .alert(L10n.tr("确定注销账号？"), isPresented: $confirming) {
            Button(L10n.tr("取消"), role: .cancel) { }
            Button(L10n.tr("注销账号"), role: .destructive) {
                deleting = true
                errorMessage = nil
                Task {
                    do {
                        try await store.deleteAccount()
                        community.eraseSession()
                    } catch {
                        errorMessage = L10n.tr("注销未完成，请重试。")
                        deleting = false
                    }
                }
            }.accessibilityIdentifier("executeAccountDeletion")
        } message: {
            Text(L10n.tr("将清除账号相关记录并退出会员空间，该账号将无法再次登录。此操作不可撤销。"))
        }
    }

    private func explanation(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundColor(ClubTheme.secondary).lineSpacing(4)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
