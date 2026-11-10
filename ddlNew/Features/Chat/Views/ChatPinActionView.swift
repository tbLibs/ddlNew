//
//  ChatPinActionView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter

struct ChatPinActionView: View {
    @Environment(\.locale) private var localizationLocale
    let message: ChatMessageRecord
    let context: ChatContext
    let permission: ChatPermission
    let onChange: () -> Void
    @State private var status: ChatPinStatus?
    @State private var error: String?
    @State private var busy = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        MessagingScroll {
            VStack(alignment: .leading, spacing: 16.zoom()) {
                MessagingCard { VStack(alignment: .leading, spacing: 8.zoom()) { Text(message.senderName).font(.subheadline).foregroundStyle(MessagingTheme.secondaryText); Text(message.displayText).font(.body).lineLimit(6) } }
                if let status {
                    MessagingCard {
                        VStack(alignment: .leading, spacing: 12.zoom()) {
                            Text(L10n.tr("置顶范围")).font(.headline)
                            Button { Task { await set(global: false, removing: status.personal) } } label: { Label(status.personal ? L10n.tr("取消我的置顶") : L10n.tr("仅为我置顶"), systemImage: status.personal ? "pin.slash" : "pin").frame(maxWidth: .infinity, minHeight: max(44, 44.zoom()), alignment: .leading) }
                            if context.route.kind == .single || [1, 2].contains(permission.role) {
                                Divider()
                                Button { Task { await set(global: true, removing: status.global) } } label: { Label(status.global ? L10n.tr("取消全局置顶") : context.route.kind == .single ? L10n.tr("为双方置顶") : L10n.tr("为所有群成员置顶"), systemImage: status.global ? "pin.slash" : "person.2").frame(maxWidth: .infinity, minHeight: max(44, 44.zoom()), alignment: .leading) }
                            }
                        }
                    }
                    Text(context.route.kind == .group && ![1, 2].contains(permission.role) ? L10n.tr("普通成员可管理自己的置顶，群主和管理员可管理全群置顶。") : L10n.tr("个人置顶只对自己可见，全局置顶对当前聊天中的所有成员可见。"))
                        .font(.subheadline).foregroundStyle(MessagingTheme.secondaryText)
                }
                if error != nil { if status == nil { Button(L10n.tr("重试")) { Task { await loadStatus() } }.frame(minHeight: 44) } }
            }.padding(16.zoom()).disabled(busy)
        }
        .navigationTitle(L10n.tr("消息置顶")).modifier(MessagingPageChrome())
        .messagingFeedbackToast(error)
        .messagingLoadingToast(busy, title: L10n.tr("正在处理置顶")).interactiveDismissDisabled(busy)
        .task { await loadStatus() }
    }
    /// 查询结果只在当前会话有效时展示，失败可重新请求真实状态。
    private func loadStatus() async {
        guard !busy else { return }; busy = true; error = nil; defer { busy = false }
        do { let value = try await SDKChatActionsClient().pinStatus(message, context: context); guard !Task.isCancelled, ChatRuntime.shared.isCurrent(context) else { return }; status = value }
        catch { guard !Task.isCancelled else { return }; self.error = error.localizedDescription }
    }
    /// 当前范围来自真实状态，成功后刷新聊天置顶条。
    private func set(global: Bool, removing: Bool) async {
        guard !busy else { return }; busy = true; error = nil; defer { busy = false }
        do { try await SDKChatActionsClient().pin(message, context: context, global: global, removing: removing); guard ChatRuntime.shared.isCurrent(context) else { return }; onChange(); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
