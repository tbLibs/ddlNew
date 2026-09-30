//
//  SettingsScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var store: ClubStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmLogout = false
    @State private var legalDocument: LegalDocument?
    var body: some View {
        NavigationView {
            Form {
                Section("会员账户") {
                    LabeledContentCompat(title: "昵称", value: "林夏")
                    LabeledContentCompat(title: "会员卡号", value: "YS****18")
                }
                Section("隐私与支持") {
                    Button("隐私政策") { legalDocument = .privacy }
                    Button("使用支持") { legalDocument = .support }
                    Button("开源许可") { legalDocument = .licenses }
                }
                Section {
                    Button("退出登录", role: .destructive) { confirmLogout = true }
                    NavigationLink(destination: DeleteAccountScreen()) {
                        Text("注销账号").foregroundColor(ClubTheme.error)
                    }.accessibilityIdentifier("deleteAccountEntry")
                } footer: { Text("活动空间") }
            }.navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
                .alert("退出会员空间？", isPresented: $confirmLogout) {
                    Button("取消", role: .cancel) { }
                    Button("退出登录", role: .destructive) { dismiss(); Task { await store.signOut() } }
                } message: { Text("活动记录会保留在本机。") }
                .sheet(item: $legalDocument) { LegalDocumentScreen(document: $0) }
        }.navigationViewStyle(.stack).tint(ClubTheme.darkTeal)
    }
}
