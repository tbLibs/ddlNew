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
    @Binding var mode: ChatComposerMode
    var focused: Binding<Bool>
    @Binding var inputSelection: NSRange
    @Binding var showCamera: Bool
    var onAtSign: ((NSRange) -> Void)? = nil
    @StateObject private var media = ChatRuntime.shared.makeMediaStore()
    @StateObject private var recorder = ChatRuntime.shared.makeRecorder()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var photos: [PhotosPickerItem] = []
    @State private var showFiles = false
    @State private var preparation: Task<Void, Never>?
    @State private var hasRecorded = false
    @State private var startRecordingTask: Task<Void, Never>?

    /// 面板只替换输入区内容，上传、录音与媒体准备始终由同一组件持有。
    var body: some View {
        VStack(spacing: 0) {
            if mode.panel != .selection {
                inputRow
                tools
                if mode.panel == .stickers {
                    ChatEmojiPanel(chat: chat, selection: $inputSelection)
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? 220.zoom() : 260.zoom())
                } else if mode.panel == .voice { voicePanel }
            }
        }
        .tint(MessagingTheme.accent)
        .task { registerCleanup() }
        .messagingFeedbackToast(media.errorMessage ?? recorder.errorMessage)
        .onChange(of: photos) { values in preparePhotos(values) }
        .fullScreenCover(isPresented: $showCamera) { ChatCameraPicker { key, value in
            if key == .mediaURL, let source = value as? URL { prepareVideo(source) }
            else if let image = value as? UIImage, let data = image.jpegData(compressionQuality: 0.9) { prepareImage(data) }
        }.ignoresSafeArea() }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.item]) { result in
            if case .success(let url) = result { prepareFile(url) }
            else if case .failure(let error) = result { media.errorMessage = error.localizedDescription }
        }
        .onDisappear {
            // 全屏相机只是覆盖聊天，不能取消正在发送的附件。
            if !showCamera { preparation?.cancel(); media.cancel() }
            cancelRecording()
        }
        .onChange(of: mode.panel) { panel in if panel != .voice { cancelRecording() } }
        .onChange(of: focused.wrappedValue) { value in if value { mode.beginTyping() } }
        .onChange(of: chat.permission.canSend) { allowed in if !allowed { cancelRecording(); focused.wrappedValue = false } }
        .onChange(of: scenePhase) { phase in if phase != .active { cancelRecording() } }
    }

    /// 旧版输入框内置表情，右侧在空闲语音与编辑发送间切换，操作区至少44pt。
    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: 8.zoom()) {
            HStack(alignment: .bottom, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if chat.input.isEmpty {
                        Text("发送消息").foregroundStyle(MessagingTheme.secondaryText)
                            .padding(.leading, 12).padding(.top, 10).allowsHitTesting(false).accessibilityHidden(true)
                    }
                    ChatComposerTextInput(text: $chat.input, selection: $inputSelection, focused: focused,
                        maximumLines: dynamicTypeSize.isAccessibilitySize ? 2 : 5, onAtSign: onAtSign)
                }
                Button {
                    if mode.panel == .stickers { mode.beginTyping(); focused.wrappedValue = true }
                    else { focused.wrappedValue = false; mode.toggle(.stickers) }
                } label: {
                    Image(systemName: mode.panel == .stickers ? "keyboard" : "face.smiling")
                        .font(.system(size: 23.zoom())).frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
                }.accessibilityLabel(mode.panel == .stickers ? "切换文字输入" : "展开表情与贴纸")
            }.background(MessagingTheme.background, in: RoundedRectangle(cornerRadius: 14.zoom()))
            primaryButton
        }.disabled(!chat.permission.canSend).padding(.horizontal, 16.zoom()).padding(.top, 6.zoom())
    }

    /// 无文本时不占用一个永久发送按钮；键盘编辑时保留明确发送出口。
    @ViewBuilder private var primaryButton: some View {
        if mode.panel == .voice {
            Button { mode.beginTyping(); focused.wrappedValue = true } label: {
                Image(systemName: "keyboard").font(.system(size: 23.zoom())).frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
            }.accessibilityLabel("切换文字输入")
        } else if ChatComposerMode.primaryAction(input: chat.input, focused: focused.wrappedValue) == .send {
            Button { chat.sendText() } label: {
                Image(systemName: "arrow.up").font(.system(size: 20.zoom(), weight: .semibold))
                    .frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
                    .foregroundStyle(MessagingTheme.onPrimaryAction).background(MessagingTheme.primaryAction, in: RoundedRectangle(cornerRadius: 12.zoom()))
            }.accessibilityLabel("发送消息").disabled(chat.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(chat.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
        } else {
            Button { focused.wrappedValue = false; mode.toggle(.voice) } label: {
                Image(systemName: "mic").font(.system(size: 24.zoom())).frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
            }.accessibilityLabel("展开语音录制")
        }
    }

    /// 相册、拍摄、文件三项等分可用宽度，图标、文字与触点居中对应。
    private var tools: some View {
        HStack(spacing: 0) {
            PhotosPicker(selection: $photos, maxSelectionCount: 9, matching: .any(of: [.images, .videos])) { Label("相册", systemImage: "photo") }
                .frame(maxWidth: .infinity)
            Button { focused.wrappedValue = false; prepareCamera() } label: { Label("拍摄", systemImage: "camera") }
                .frame(maxWidth: .infinity)
            Button { focused.wrappedValue = false; showFiles = true } label: { Label("文件", systemImage: "doc") }
                .frame(maxWidth: .infinity)
        }.labelStyle(ChatComposerToolLabelStyle(equalWidth: true)).buttonStyle(.plain)
            .disabled(!chat.permission.canSend).padding(.horizontal, 12.zoom())
            .frame(minHeight: max(56, 56.zoom()))
    }

    /// 录音展开后由用户点按开始、停止与确认发送，取消不清空文字草稿。
    private var voicePanel: some View {
        VStack(spacing: 12.zoom()) {
            HStack {
                Text(recorder.isRecording ? "正在录音 \(Int(recorder.duration)) / 60秒" : hasRecorded ? "录音已停止，确认后发送" : "点击开始录音，最长60秒").font(.subheadline)
                Spacer()
                Button("关闭") { cancelRecording(); mode.beginTyping() }.frame(minHeight: 44)
            }
            HStack(spacing: 24.zoom()) {
                if hasRecorded && !recorder.isRecording {
                    Button("重录") { cancelRecording() }.frame(minWidth: 60, minHeight: 44)
                    Button { sendRecording() } label: { Label("发送录音", systemImage: "paperplane.fill") }.buttonStyle(MessagingActionButtonStyle())
                } else {
                    Button { toggleRecording() } label: {
                        Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill").font(.system(size: 30.zoom()))
                            .frame(width: 76.zoom(), height: 76.zoom()).foregroundStyle(MessagingTheme.onPrimaryAction).background(MessagingTheme.primaryAction, in: Circle())
                    }.accessibilityLabel(recorder.isRecording ? "停止录音" : "开始录音").disabled(startRecordingTask != nil)
                }
            }
        }.padding(.horizontal, 20.zoom()).padding(.bottom, 20.zoom()).disabled(!chat.permission.canSend)
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
        preparation = Task {
            for item in values.prefix(9) {
                guard !Task.isCancelled, let context = chat.context, ChatRuntime.shared.isCurrent(context) else { break }
                do {
                    let attachment: ChatAttachment
                    if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }), let movie = try await item.loadTransferable(type: ChatPickedMovie.self) {
                        attachment = try await ChatAttachmentPreparation.video(movie.file)
                        try? FileManager.default.removeItem(at: movie.file)
                    } else if let data = try await item.loadTransferable(type: Data.self) { attachment = try await Task.detached { try ChatAttachmentPreparation.image(data) }.value }
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
    private func prepareImage(_ data: Data) { preparation = Task { guard let context = chat.context else { return }; do { let attachment = try await Task.detached { try ChatAttachmentPreparation.image(data) }.value; await send(attachment, context: context) } catch { media.errorMessage = error.localizedDescription } } }
    /// 拍摄视频独立准备封面与原文件。
    private func prepareVideo(_ file: URL) { preparation = Task { guard let context = chat.context else { return }; do { let attachment = try await ChatAttachmentPreparation.video(file); await send(attachment, context: context) } catch { media.errorMessage = error.localizedDescription } } }
    /// 安全书签文件拷贝后才上传，系统取消不触发发送。
    private func prepareFile(_ file: URL) { preparation = Task { guard let context = chat.context else { return }; do { let attachment = try await Task.detached { try ChatAttachmentPreparation.file(file) }.value; await send(attachment, context: context) } catch { media.errorMessage = error.localizedDescription } } }
    /// 录音开始、停止和发送分开，取消保留原文本草稿。
    private func toggleRecording() {
        if recorder.isRecording { recorder.stopRecording(); hasRecorded = true }
        else if let context = chat.context, startRecordingTask == nil {
            startRecordingTask = Task {
                await recorder.start(context: context)
                guard !Task.isCancelled else { return }
                hasRecorded = recorder.isRecording; startRecordingTask = nil
            }
        }
    }
    /// 收起面板、失去权限或后台会取消麦克风授权等待与未发送录音。
    private func cancelRecording() { startRecordingTask?.cancel(); startRecordingTask = nil; recorder.cancel(); hasRecorded = false }
    /// 用户确认发送停止后的录音，资源太短不能入队。
    private func sendRecording() { do { let attachment = try recorder.finish(); hasRecorded = false; if let context = chat.context { preparation = Task { await send(attachment, context: context) } } } catch { recorder.errorMessage = error.localizedDescription } }
    /// 上传取消或退出后不入队，临时附件完成后清理。
    private func send(_ attachment: ChatAttachment, context: ChatContext) async {
        defer { try? FileManager.default.removeItem(at: attachment.file); if let file = attachment.previewFile { try? FileManager.default.removeItem(at: file) } }
        await media.send(attachment, context: context,
            stage: { message in try chat.beginMediaUpload(message) },
            discard: { id in chat.discardMediaUpload(id) },
            enqueue: { message in try chat.sendAttachment(message) })
    }
}
