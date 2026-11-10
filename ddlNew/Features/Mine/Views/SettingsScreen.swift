//
//  SettingsScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct SettingsScreen: View {
    @Environment(\.locale) private var localizationLocale
    @EnvironmentObject private var store: ClubStore
    @ObservedObject private var userSession = UserSessionStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var confirmLogout = false
    @State private var legalDocument: LegalDocument?
    var body: some View {
        NavigationView {
            ScrollView {
                SettingsPageContent(
                    displayName: displayName,
                    account: userSession.currentUser?.userName ?? "",
                    deleteDestination: DeleteAccountScreen(),
                    openPrivacyPolicy: { legalDocument = .privacy },
                    openSupport: { legalDocument = .support },
                    logout: { confirmLogout = true }
                )
                .frame(maxWidth: HomeTheme.contentWidth)
                .frame(maxWidth: .infinity)
            }
                .background(HomeTheme.background.ignoresSafeArea())
                .navigationTitle(L10n.tr("设置")).navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(HomeTheme.surface, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.tr("完成")) { dismiss() } } }
                .alert(L10n.tr("退出会员空间？"), isPresented: $confirmLogout) {
                    Button(L10n.tr("取消"), role: .cancel) { }
                    Button(L10n.tr("退出登录"), role: .destructive) { dismiss(); Task { await store.signOut() } }
                } message: { Text(L10n.tr("退出登录后，活动记录会保留。")) }
                .sheet(item: $legalDocument) { LegalDocumentScreen(document: $0) }
        }.navigationViewStyle(.stack).tint(HomeTheme.forest)
    }

    private var displayName: String {
        guard let user = userSession.currentUser else { return L10n.tr("未登录") }
        if !user.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return user.nickname }
        return user.userName.isEmpty ? L10n.tr("未设置昵称") : user.userName
    }
}
