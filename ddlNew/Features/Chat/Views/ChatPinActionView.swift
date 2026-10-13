//
//  ChatPinActionView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

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
        Form {
            Text(message.text).lineLimit(5)
            if let status {
                Button(status.personal ? "取消我的置顶" : "仅为我置顶") { Task { await set(global: false, removing: status.personal) } }
                if context.route.kind == .single || [1, 2].contains(permission.role) { Button(status.global ? "取消全局置顶" : "为双方或所有群成员置顶") { Task { await set(global: true, removing: status.global) } } }
            }
            if let error { Text(error).foregroundStyle(.red) }
            if busy { ProgressView() }
        }.disabled(busy).navigationTitle("消息置顶")
        .task { do { status = try await SDKChatActionsClient().pinStatus(message, context: context) } catch { self.error = error.localizedDescription } }
    }
    /// 当前范围从真实状态取值，提交后回查并刷新聊天置顶条。
    private func set(global: Bool, removing: Bool) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { try await SDKChatActionsClient().pin(message, context: context, global: global, removing: removing); onChange(); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
