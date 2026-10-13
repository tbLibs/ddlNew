//
//  ChatMessageEditorView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

struct ChatMessageEditorView: View {
    let message: ChatMessageRecord
    let context: ChatContext
    @ObservedObject var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @State private var input: String
    @State private var mentions: [ChatMentionSegment]
    @State private var previousInput: String
    @State private var busy = false
    @State private var confirmDiscard = false
    @State private var error: String?

    /// 编辑状态独立于尚未发送的聊天草稿，取消不丢原输入。
    init(message: ChatMessageRecord, context: ChatContext, store: ChatStore) { self.message = message; self.context = context; self.store = store; _input = State(initialValue: message.text); _previousInput = State(initialValue: message.text); _mentions = State(initialValue: message.mentions) }

    var body: some View {
        Form {
            TextEditor(text: $input).frame(minHeight: 200).accessibilityLabel("编辑消息正文")
            if let error { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle("编辑消息")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { if input != message.text { confirmDiscard = true } else { dismiss() } }.disabled(busy) }
            ToolbarItem(placement: .confirmationAction) { Button("保存") { Task { await save() } }.disabled(busy || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
        .interactiveDismissDisabled(busy || input != message.text)
        .confirmationDialog("放弃修改？", isPresented: $confirmDiscard, titleVisibility: .visible) { Button("放弃修改", role: .destructive) { dismiss() } }
        .onChange(of: input) { value in
            guard previousInput != value else { return }
            let result = ChatMentionEngine.editing(old: previousInput, new: value, segments: mentions)
            mentions = result.1; previousInput = result.0; input = result.0
        }
    }

    /// 保留输入直到服务端确认，降权、超时和取消均不替换原消息。
    private func save() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { let result = try await SDKChatActionsClient().edit(message, text: input, mentions: mentions, context: context); guard ChatRuntime.shared.isCurrent(context) else { return }; store.applyOperationMessages([result], context: context); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
