//
//  ChatMessageEditorView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter

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
    @FocusState private var editorFocused: Bool

    /// 编辑状态独立于尚未发送的聊天草稿，取消不丢原输入。
    init(message: ChatMessageRecord, context: ChatContext, store: ChatStore) { self.message = message; self.context = context; self.store = store; _input = State(initialValue: message.text); _previousInput = State(initialValue: message.text); _mentions = State(initialValue: message.mentions) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16.zoom()) {
                Text("正文").font(.footnote.weight(.medium)).foregroundStyle(MessagingTheme.secondaryText)
                TextEditor(text: $input).font(.body).scrollContentBackground(.hidden)
                    .frame(minHeight: 272.zoom()).focused($editorFocused).accessibilityLabel("编辑消息正文")
                    .padding(12.zoom()).background(MessagingTheme.background, in: RoundedRectangle(cornerRadius: 12.zoom()))
            }.padding(20.zoom()).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(MessagingTheme.surface.ignoresSafeArea()).scrollDismissesKeyboard(.interactively)
        .navigationTitle("编辑消息").modifier(MessagingPageChrome())
        .messagingFeedbackToast(error)
        .messagingLoadingToast(busy, title: "正在保存").navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { cancel() }.frame(minHeight: 44).disabled(busy) }
        }
        .safeAreaInset(edge: .bottom) {
            Button("保存") { editorFocused = false; Task { await save() } }
                .buttonStyle(MessagingActionButtonStyle(fullWidth: true))
                .disabled(busy || input == message.text || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .frame(maxWidth: 640).padding(20.zoom()).frame(maxWidth: .infinity).background(MessagingTheme.surface)
        }
        .interactiveDismissDisabled(busy || input != message.text)
        .confirmationDialog("放弃修改？", isPresented: $confirmDiscard, titleVisibility: .visible) { Button("放弃修改", role: .destructive) { dismiss() }; Button("继续编辑", role: .cancel) {} }
        .task { editorFocused = true }
        .onChange(of: input) { value in
            guard previousInput != value else { return }
            let result = ChatMentionEngine.editing(old: previousInput, new: value, segments: mentions)
            mentions = result.1; previousInput = result.0; input = result.0
        }
    }

    /// 返回先确认未保存的修改，避免系统返回直接丢失正文。
    private func cancel() { if input != message.text { confirmDiscard = true } else { dismiss() } }

    /// 保留输入直到服务端确认，降权、超时和取消均不替换原消息。
    private func save() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { let result = try await SDKChatActionsClient().edit(message, text: input, mentions: mentions, context: context); guard ChatRuntime.shared.isCurrent(context) else { return }; store.applyOperationMessages([result], context: context); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
