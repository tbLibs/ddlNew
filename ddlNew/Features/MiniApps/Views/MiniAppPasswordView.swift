//
//  MiniAppPasswordView.swift
//  ddlNew
//
//  Created by taobo on 2026/11/9.
//
import SwiftUI

/// 密码只属于本次验证弹层，取消或关闭即释放，不写入模型或浮窗数据库。
struct MiniAppPasswordView: View {
    @Environment(\.locale) private var localizationLocale
    @ObservedObject var store: MiniAppsStore
    let record: MiniAppRecord
    let onUnlock: (MiniAppRecord, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?
    @State private var task: Task<Void, Never>?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) { MiniAppIcon(resource: record.icon); Text(record.name).font(.headline) }
                    SecureField(L10n.tr("访问密码"), text: $password, prompt: Text(L10n.tr("访问密码")).foregroundColor(MessagingTheme.secondaryText)).textContentType(.password).submitLabel(.go).onSubmit(verify)
                        .accessibilityLabel(L10n.tr("访问密码")).disabled(busy)
                    if let error { Text(error).foregroundStyle(MessagingTheme.error).font(.callout) }
                } footer: { Text(L10n.tr("此应用已设置访问密码，验证后可继续。")).foregroundStyle(MessagingTheme.secondaryText) }
            }
            .navigationTitle(L10n.tr("验证访问密码")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.tr("取消")) { task?.cancel(); password = ""; dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("继续"), action: verify).disabled(password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
                }
            }
            .overlay { if busy { ProgressView(L10n.tr("正在验证")).padding(20).background(MessagingTheme.surface, in: RoundedRectangle(cornerRadius: 12)) } }
        }.tint(MessagingTheme.accent).interactiveDismissDisabled(busy)
            .onDisappear { task?.cancel(); password = "" }
    }
    private func verify() {
        guard !busy, !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }; busy = true; error = nil
        // 空白校验不改写密码，验证必须与创建时输入的原文一致。
        let value = password
        task = Task { @MainActor in
            let unlocked = await store.unlock(record, password: value)
            guard !Task.isCancelled else { return }; busy = false
            if let unlocked { onUnlock(unlocked, value) }
            else { error = store.feedback ?? L10n.tr("密码验证失败，请重试") }
        }
    }
}
