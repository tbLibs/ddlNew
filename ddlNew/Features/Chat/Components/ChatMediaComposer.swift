//
//  ChatMediaComposer.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation

struct ChatMediaComposer: View {
    @ObservedObject var chat: ChatStore
    var compact = false
    @StateObject private var media = ChatRuntime.shared.makeMediaStore()
    @StateObject private var recorder = ChatRuntime.shared.makeRecorder()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var photos: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var showFiles = false
    @State private var showStickers = false
    @State private var originalImage = false
    @State private var preparation: Task<Void, Never>?
    @State private var hasRecorded = false

    /// 收拢工具只改变控件布局，组件与上传、录音所有者保持同一身份。
    var body: some View {
        VStack(spacing: 6) {
            if media.isUploading { HStack { Button("取消上传") { media.cancel() } } }
            if !compact {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 2 : 4), spacing: 8.zoom()) {
                PhotosPicker(selection: $photos, maxSelectionCount: 9, matching: .any(of: [.images, .videos])) { Label("相册", systemImage: "photo").frame(minHeight: 44) }.disabled(!chat.permission.canSend)
                Button { prepareCamera() } label: { Label("拍摄", systemImage: "camera").frame(minHeight: 44) }.disabled(!chat.permission.canSend)
                Button { showFiles = true } label: { Label("文件", systemImage: "doc").frame(minHeight: 44) }.disabled(!chat.permission.canSend)
                Button { toggleRecording() } label: { Label(recorder.isRecording ? "停止" : "语音", systemImage: recorder.isRecording ? "stop.circle" : "mic").frame(minHeight: 44) }.disabled(!chat.permission.canSend)
            }.labelStyle(ChatComposerToolLabelStyle()).buttonStyle(.plain)
            HStack { Button("表情与贴纸") { showStickers = true }.frame(minHeight: 44); Spacer(); Toggle("原图", isOn: $originalImage).fixedSize() }.font(.caption)
            }
            if hasRecorded || recorder.isRecording {
                HStack { Text("录音 \(Int(recorder.duration)) / 60秒"); Spacer(); Button("取消录音") { recorder.cancel(); hasRecorded = false }; Button("发送录音") { sendRecording() }.disabled(recorder.isRecording) }
            }
        }
        .tint(MessagingTheme.accent)
        .task { registerCleanup() }
        .messagingLoadingToast(media.isUploading, title: "正在上传附件")
        .messagingFeedbackToast(media.errorMessage ?? recorder.errorMessage)
        .onChange(of: photos) { values in preparePhotos(values) }
        .sheet(isPresented: $showStickers) { NavigationStack { ChatStickersView(chat: chat) } }
        .sheet(isPresented: $showCamera) { ChatCameraPicker { key, value in
            if key == .mediaURL, let source = value as? URL { prepareVideo(source) }
            else if let image = value as? UIImage, let data = image.jpegData(compressionQuality: 0.9) { prepareImage(data) }
        } }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.item]) { result in
            if case .success(let url) = result { prepareFile(url) }
            else if case .failure(let error) = result { media.errorMessage = error.localizedDescription }
        }
        .onDisappear { preparation?.cancel(); media.cancel(); recorder.cancel() }
        .onChange(of: scenePhase) { phase in if phase != .active { recorder.cancel(); hasRecorded = false } }
    }

    /// 同步清理捕获独立弱对象，避免SwiftUI页面被根runtime长期持有。
    private func registerCleanup() {
        guard let context = chat.context else { return }
        let mediaStore = media; let recordingStore = recorder
        ChatRuntime.shared.registerCleanup(owner: mediaStore, conversationID: context.route.id) { [weak mediaStore] in mediaStore?.cancel() }
        ChatRuntime.shared.registerCleanup(owner: recordingStore, conversationID: context.route.id) { [weak recordingStore] in recordingStore?.cancel() }
    }

    /// 图片视频分别准备，最多9份按用户选择顺序提交。
    private func preparePhotos(_ values: [PhotosPickerItem]) {
        preparation?.cancel()
        let preserveOriginal = originalImage
        preparation = Task {
            for item in values.prefix(9) {
                guard !Task.isCancelled, let context = chat.context, ChatRuntime.shared.isCurrent(context) else { break }
                do {
                    let attachment: ChatAttachment
                    if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }), let movie = try await item.loadTransferable(type: ChatPickedMovie.self) {
                        attachment = try await ChatAttachmentPreparation.video(movie.file)
                        try? FileManager.default.removeItem(at: movie.file)
                    } else if let data = try await item.loadTransferable(type: Data.self) { attachment = try await Task.detached { try ChatAttachmentPreparation.image(data, original: preserveOriginal) }.value }
                    else { throw ChatClientError.unavailable("无法读取所选媒体，请重试") }
                    await send(attachment, context: context)
                } catch { media.errorMessage = error.localizedDescription }
            }
            photos = []
        }
    }
    /// 相机拒权给出系统设置路径，模拟器无相机不会崩溃。
    private func prepareCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { media.errorMessage = "当前设备没有可用相机"; return }
        Task { let allowed = await AVCaptureDevice.requestAccess(for: .video); if allowed { showCamera = true } else { media.errorMessage = "相机权限未开启，请在系统设置中允许拍摄" } }
    }
    /// 用户拍摄的图片只准备真实字节，不乐观生成消息。
    private func prepareImage(_ data: Data) { let preserveOriginal = originalImage; preparation = Task { guard let context = chat.context else { return }; do { let attachment = try await Task.detached { try ChatAttachmentPreparation.image(data, original: preserveOriginal) }.value; await send(attachment, context: context) } catch { media.errorMessage = error.localizedDescription } } }
    /// 拍摄视频独立准备封面与原文件。
    private func prepareVideo(_ file: URL) { preparation = Task { guard let context = chat.context else { return }; do { let attachment = try await ChatAttachmentPreparation.video(file); await send(attachment, context: context) } catch { media.errorMessage = error.localizedDescription } } }
    /// 安全书签文件拷贝后才上传，系统取消不触发发送。
    private func prepareFile(_ file: URL) { preparation = Task { guard let context = chat.context else { return }; do { let attachment = try await Task.detached { try ChatAttachmentPreparation.file(file) }.value; await send(attachment, context: context) } catch { media.errorMessage = error.localizedDescription } } }
    /// 录音开始、停止和发送分开，取消保留原文本草稿。
    private func toggleRecording() {
        if recorder.isRecording { recorder.stopRecording(); hasRecorded = true }
        else if let context = chat.context { Task { await recorder.start(context: context); hasRecorded = true } }
    }
    /// 用户确认发送停止后的录音，资源太短不能入队。
    private func sendRecording() { do { let attachment = try recorder.finish(); hasRecorded = false; if let context = chat.context { preparation = Task { await send(attachment, context: context) } } } catch { recorder.errorMessage = error.localizedDescription } }
    /// 上传取消或退出后不入队，临时附件完成后清理。
    private func send(_ attachment: ChatAttachment, context: ChatContext) async {
        defer { try? FileManager.default.removeItem(at: attachment.file); if let file = attachment.previewFile { try? FileManager.default.removeItem(at: file) } }
        await media.send(attachment, context: context) { message in try chat.sendAttachment(message) }
    }
}
