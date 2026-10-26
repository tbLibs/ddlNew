//
//  MassMessageComposerView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/23.
//

import SwiftUI
import UIAdapter
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation

struct MassMessageComposerView: View {
    @StateObject private var store: MassMessageComposerStore
    @ObservedObject private var authority = UserRoleAuthorityStore.shared
    @ObservedObject private var runtime = ChatRuntime.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selecting = false
    @State private var showPhotos = false
    @State private var showFiles = false
    @State private var photo: PhotosPickerItem?
    @State private var preparation: Task<Void, Never>?
    @State private var preparationID = UUID()
    @State private var preparing = false
    @State private var confirming = false
    @State private var discard = false
    @State private var gallery: ChatPhotoBrowserRequest?
    @State private var remoteFile: ChatMessageRecord?
    @State private var localFile: MassMessageLocalPreview?
    let onSent: () -> Void
    init(context: ChatContext, original: MassMessageRecord?, onSent: @escaping () -> Void) {
        _store = StateObject(wrappedValue: MassMessageComposerStore(context: context, reusing: original))
        self.onSent = onSent
    }
    private var count: Int { store.original?.total ?? store.selection.count }
    private var allowed: Bool { authority.current?.allows("groupHairAssistant") == true }
    private var busy: Bool { store.busy || preparing }

    var body: some View {
        Form {
          Group {
            Section {
                if let original = store.original {
                    NavigationLink { MassMessageRecipientsView(context: store.context, record: original, failures: false) } label: {
                        Label("原接收对象（\(original.total)）", systemImage: "person.2").frame(minHeight: 44)
                    }
                } else {
                    Button { selecting = true } label: {
                        HStack {
                            Label("接收对象", systemImage: "person.2")
                            Spacer()
                            Text(store.selection.isEmpty ? "请选择" : "已选 \(store.selection.count)").foregroundStyle(MessagingTheme.secondaryText)
                            Image(systemName: "chevron.right").font(.caption).accessibilityHidden(true)
                        }.frame(minHeight: 44)
                    }
                    if !store.selection.isEmpty {
                        Text(store.selection.prefix(5).map(\.name).joined(separator: "、") + (store.selection.count > 5 ? "等" : ""))
                            .font(.subheadline).foregroundStyle(MessagingTheme.secondaryText)
                    }
                }
            } header: { Text("发送给") } footer: {
                if store.original != nil { Text("再发一次沿用原接收对象，无法修改成员。") }
                else { Text("可同时选择好友和群聊，重复选择只计一次。") }
            }
            Section {
                TextField("可选，便于区分群发记录", text: $store.label)
                    .accessibilityLabel("群发标签").disabled(store.original != nil)
                HStack { Text("标签长度"); Spacer(); Text("\(store.label.utf16.count)/16") }
                    .font(.caption).foregroundStyle(store.label.utf16.count > 16 ? MessagingTheme.error : MessagingTheme.secondaryText)
                if store.label.utf16.count > 16 { Text("标签过长，请缩短后发送（表情可能占多个长度）。").font(.caption).foregroundStyle(MessagingTheme.error) }
            } header: { Text("标签") }
            Section {
                if store.messageType == 0 {
                    TextEditor(text: $store.text).frame(minHeight: 180.zoom()).accessibilityLabel("群发正文")
                    if store.text.isEmpty { Text("输入要发送给所有接收对象的消息").font(.subheadline).foregroundStyle(MessagingTheme.secondaryText) }
                } else {
                    Button { previewAttachment() } label: {
                        HStack(spacing: 12.zoom()) {
                            Image(systemName: store.messageType == 1 ? "photo" : store.messageType == 2 ? "play.rectangle" : "doc").font(.title2).frame(width: 44, height: 44).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 6.zoom()) {
                                Text(attachmentTitle).font(.body)
                                if let attachment = store.attachment { Text(ByteCountFormatter.string(fromByteCount: attachment.bytes, countStyle: .file)).font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
                                Text("轻点预览").font(.caption).foregroundStyle(MessagingTheme.secondaryText)
                            }
                            Spacer(minLength: 0)
                        }.frame(minHeight: 44)
                    }.buttonStyle(.plain)
                    Button("移除附件，改发文字", role: .destructive) { store.replaceAttachment(nil) }.frame(minHeight: 44)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 24.zoom()) { photoButton; fileButton }
                    VStack(alignment: .leading, spacing: 8.zoom()) { photoButton; fileButton }
                }
            } header: { Text("群发内容") } footer: { Text("每次发送文字，或一张图片、一段视频、一个文件。选择附件后仅发送附件。") }
            if !allowed { Section { Text("当前账号没有群发权限").font(.subheadline).foregroundStyle(MessagingTheme.error) } }
          }.disabled(busy)
        }
        .frame(maxWidth: 720).frame(maxWidth: .infinity)
        .navigationTitle(store.original == nil ? "新建群发" : "再发一次").modifier(MessagingPageChrome())
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { discard = true }.frame(minHeight: 44) } }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8.zoom()) {
                if store.busy && store.attachment != nil { ProgressView(value: store.progress).accessibilityLabel("附件上传进度") }
                Button(store.busy ? "正在提交" : "发送给 \(count) 个对象") { confirming = true }
                    .buttonStyle(MessagingActionButtonStyle(fullWidth: true)).disabled(busy || !allowed || !store.canSubmit)
            }.padding(16.zoom()).background(MessagingTheme.surface)
        }
        .interactiveDismissDisabled(true)
        .onChange(of: runtime.revision) { _ in
            if !runtime.isCurrent(store.context) { close(); dismiss() }
        }
        .messagingLoadingToast(busy, title: preparing ? "正在准备附件" : "正在提交群发")
        .messagingFeedbackToast(store.errorMessage)
        .sheet(isPresented: $selecting) { NavigationStack { MassMessageRecipientPicker(selection: $store.selection) } }
        .photosPicker(isPresented: $showPhotos, selection: $photo, matching: .any(of: [.images, .videos]))
        .onChange(of: photo) { value in if let value { preparePhoto(value) } }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.item]) { result in
            switch result { case .success(let url): prepare { try await Task.detached { try ChatAttachmentPreparation.file(url) }.value }
            case .failure(let error): store.errorMessage = error.localizedDescription }
        }
        .confirmationDialog("确认发送群发消息？", isPresented: $confirming, titleVisibility: .visible) {
            Button("确认发送") { Task { if await store.send() { onSent(); close(); dismiss() } } }.disabled(!store.canSubmit || busy)
            Button("取消", role: .cancel) {}
        } message: { Text("将向 \(count) 个接收对象发送。\(store.original == nil ? "" : "本次使用原接收对象。")") }
        .confirmationDialog(busy ? "停止等待并退出？" : "放弃这次编辑？", isPresented: $discard, titleVisibility: .visible) {
            Button(busy ? "停止并退出" : "放弃编辑", role: .destructive) { close(); dismiss() }
            Button("继续编辑", role: .cancel) {}
        } message: { Text(busy ? "将取消本机准备、上传或等待；若群发已提交服务器，退出不会撤回发送。" : "未发送的内容不会保留。") }
        .chatPhotoBrowser(item: $gallery, context: store.context, includeCachedHistory: false)
        .sheet(item: $remoteFile) { message in NavigationStack {
            ChatMediaDetailView(message: message, context: store.context, onVoicePlayed: {})
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { remoteFile = nil }.frame(minHeight: 44) } }
        } }
        .sheet(item: $localFile) { value in NavigationStack {
            ChatFilePreview(file: value.file).navigationTitle("附件预览").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { localFile = nil }.frame(minHeight: 44) } }
        } }
    }
    private var photoButton: some View { Button { showPhotos = true } label: { Label("图片或视频", systemImage: "photo.on.rectangle").frame(minHeight: 44) }.buttonStyle(.borderless) }
    private var fileButton: some View { Button { showFiles = true } label: { Label("文件", systemImage: "folder").frame(minHeight: 44) }.buttonStyle(.borderless) }
    private var attachmentTitle: String {
        if store.messageType == 1 { return "图片" }; if store.messageType == 2 { return "视频" }
        return store.attachment?.name ?? store.original?.summary ?? "文件"
    }

    /// 准备任务只在当前编辑轮次交付，取消或身份变化后清除迟到文件。
    private func prepare(_ operation: @escaping () async throws -> ChatAttachment) {
        preparation?.cancel(); let run = UUID(); preparationID = run; preparing = true; store.errorMessage = nil
        preparation = Task {
            defer { if preparationID == run { preparing = false; preparation = nil; photo = nil } }
            do {
                let value = try await operation()
                guard !Task.isCancelled, preparationID == run, ChatRuntime.shared.isCurrent(store.context) else { MassMessageComposerStore.remove(value); return }
                store.replaceAttachment(value)
            } catch { if !Task.isCancelled, preparationID == run, ChatRuntime.shared.isCurrent(store.context) { store.errorMessage = error.localizedDescription } }
        }
    }
    private func preparePhoto(_ item: PhotosPickerItem) {
        prepare {
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                guard let movie = try await item.loadTransferable(type: ChatPickedMovie.self) else { throw MassMessageError.message("无法读取所选视频") }
                defer { try? FileManager.default.removeItem(at: movie.file) }
                return try await MassMessageVideoPreparation.prepare(movie.file)
            }
            guard let data = try await item.loadTransferable(type: Data.self) else { throw MassMessageError.message("无法读取所选图片") }
            return try await Task.detached { try ChatAttachmentPreparation.image(data) }.value
        }
    }
    private func previewAttachment() {
        if let attachment = store.attachment { localFile = MassMessageLocalPreview(file: attachment.file); return }
        guard let original = store.original else { return }
        let message = MassMessagePresentation.message(original, context: store.context)
        if message.type == 5 { remoteFile = message } else { gallery = ChatPhotoBrowserRequest(selected: message, messages: [message]) }
    }
    private func close() { preparationID = UUID(); preparation?.cancel(); preparation = nil; preparing = false; store.close() }
}

private struct MassMessageLocalPreview: Identifiable { let id = UUID(); let file: URL }

private enum MassMessageVideoPreparation {
    /// 失败路径同样释放内部拷贝；上传前仅生成本机视频与封面。
    nonisolated static func prepare(_ source: URL) async throws -> ChatAttachment {
        let copied = try await Task.detached { try ChatAttachmentPreparation.file(source) }.value
        var delivered = false
        let preview = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        defer { if !delivered { try? FileManager.default.removeItem(at: copied.file); try? FileManager.default.removeItem(at: preview) } }
        try Task.checkCancellation()
        let asset = AVURLAsset(url: copied.file), duration = try await asset.load(.duration)
        let generator = AVAssetImageGenerator(asset: asset); generator.appliesPreferredTrackTransform = true
        let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
        let image = UIImage(cgImage: cgImage)
        guard let data = image.jpegData(compressionQuality: 0.75) else { throw MassMessageError.message("视频封面转换失败") }
        try data.write(to: preview); try Task.checkCancellation()
        delivered = true
        return ChatAttachment(file: copied.file, type: 2, name: copied.name, bytes: copied.bytes, duration: duration.seconds,
            width: image.size.width, height: image.size.height, previewFile: preview)
    }
}
