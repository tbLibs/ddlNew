//
//  ChatPinActionView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter

struct ChatPinActionView: View {
    let message: ChatMessageRecord
    let context: ChatContext
    let permission: ChatPermission
    let onChange: () -> Void
    @State private var status: ChatPinStatus?
    @State private var error: String?
    @State private var busy = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16.zoom()) {
                VStack(alignment: .leading, spacing: 8.zoom()) { Text(message.senderName).font(.subheadline).foregroundStyle(MessagingTheme.secondaryText); Text(message.displayText).font(.body).lineLimit(6) }.frame(maxWidth: .infinity, alignment: .leading).padding(16.zoom()).background(MessagingTheme.background, in: RoundedRectangle(cornerRadius: 12.zoom()))
                if let status {
                    Group {
                        VStack(alignment: .leading, spacing: 12.zoom()) {
                            Button { Task { await set(global: false, removing: status.personal) } } label: { scopeRow(title: "仅为我置顶", detail: "只出现在你的置顶列表", removing: status.personal) }
                            if context.route.kind == .single || [1, 2].contains(permission.role) {
                                Divider()
                                Button { Task { await set(global: true, removing: status.global) } } label: { scopeRow(title: context.route.kind == .single ? "为双方置顶" : "为所有群成员置顶", detail: context.route.kind == .single ? "同步到双方的置顶列表" : "同步到群成员的置顶列表", removing: status.global) }
                            }
                        }
                    }
                    Text(context.route.kind == .group && ![1, 2].contains(permission.role) ? "普通成员可管理自己的置顶，群主和管理员可管理全群置顶。" : "个人置顶只对自己可见，全局置顶对当前聊天中的所有成员可见。")
                        .font(.subheadline).foregroundStyle(MessagingTheme.secondaryText)
                }
                if error != nil { if status == nil { Button("重试") { Task { await loadStatus() } }.frame(minHeight: 44) } }
            }.padding(20.zoom()).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity).disabled(busy)
        }
        .background(MessagingTheme.surface.ignoresSafeArea())
        .navigationTitle("消息置顶").modifier(MessagingPageChrome())
        .messagingFeedbackToast(error)
        .messagingLoadingToast(busy, title: "正在处理置顶").interactiveDismissDisabled(busy)
        .task { await loadStatus() }
    }
    private func scopeRow(title: String, detail: String, removing: Bool) -> some View {
        HStack(spacing: 16.zoom()) {
            VStack(alignment: .leading, spacing: 8.zoom()) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(MessagingTheme.text)
                Text(detail).font(.subheadline).foregroundStyle(MessagingTheme.secondaryText)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Text(removing ? "取消置顶" : "置顶").font(.subheadline.weight(.medium))
        }.padding(.vertical, 20.zoom()).frame(minHeight: 74.zoom()).contentShape(Rectangle())
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
