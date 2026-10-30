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
    var onBeginRecording: () -> Void = {}
    var onAtSign: ((NSRange) -> Void)? = nil
    @ObservedObject private var calls = CallCoordinator.shared
    @ObservedObject private var callConfiguration = CallConfigurationStore.shared
    @StateObject private var media = ChatRuntime.shared.makeMediaStore()
    @StateObject private var recorder = ChatRuntime.shared.makeRecorder()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var photos: [PhotosPickerItem] = []
    @State private var showFiles = false
    @State private var showsTools = false
    @State private var preparation: Task<Void, Never>?
    @State private var voicePress = ChatVoicePressState()
    @State private var recordingGestureID = UUID()
    @State private var startRecordingTask: Task<Void, Never>?

    /// 面板只替换输入区内容，上传、录音与媒体准备始终由同一组件持有。
    var body: some View {
        VStack(spacing: 0) {
            if mode.panel != .selection {
                inputRow
                VStack(spacing: 0) {
                    if showsTools && mode.panel == .text {
                        tools.transition(panelTransition)
                    } else if mode.panel == .stickers {
                        ChatEmojiPanel(chat: chat, selection: $inputSelection)
                            .frame(height: dynamicTypeSize.isAccessibilitySize ? 220.zoom() : 260.zoom())
                            .transition(panelTransition)
                    }
                }
                .clipped()
            }
        }
        .animation(panelAnimation, value: showsTools)
        .animation(panelAnimation, value: mode.panel)
        .overlay(alignment: .bottom) {
            VStack {
                if voicePress.isHolding {
                    voiceFeedback
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
                }
            }
            .padding(.horizontal, 24.zoom()).padding(.bottom, 76.zoom())
            .allowsHitTesting(false)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: voicePress.isHolding)
        }
        .tint(MessagingTheme.accent)
        .task { registerCleanup() }
        .onChange(of: chat.context) { _ in registerCleanup() }
        .messagingFeedbackToast(media.errorMessage ?? recorder.errorMessage)
        .onChange(of: recorder.errorMessage) { error in if error != nil && !recorder.isRecording { cancelRecording() } }
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
            if !showCamera && !calls.isPresented && calls.selection == nil { preparation?.cancel(); media.cancel() }
            cancelRecording()
        }
        .onChange(of: mode.panel) { panel in
            if panel != .voice { cancelRecording() }
            if panel != .text { showsTools = false }
        }
        .onChange(of: focused.wrappedValue) { value in
            if value { withAnimation(panelAnimation) { showsTools = false; mode.beginTyping() } }
        }
        .onChange(of: chat.permission.canSend) { allowed in if !allowed { cancelRecording(); focused.wrappedValue = false } }
        .onChange(of: scenePhase) { phase in if phase != .active { cancelRecording() } }
    }

    private var panelAnimation: Animation? { reduceMotion ? nil : .easeOut(duration: 0.24) }
    private var controlAnimation: Animation { .easeOut(duration: reduceMotion ? 0.1 : 0.24) }
    private var panelTransition: AnyTransition {
        reduceMotion ? .identity : .opacity.combined(with: .offset(y: 12.zoom()))
    }
    private var primaryRole: String {
        mode.panel == .voice ? "keyboard" :
            (ChatComposerMode.primaryAction(input: chat.input, focused: focused.wrappedValue) == .send ? "send" : "voice")
    }

    /// 左侧展开附件，右侧沿现有状态切换语音／发送，操作区至少44pt。
    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: 8.zoom()) {
            Button {
                withAnimation(panelAnimation) {
                    focused.wrappedValue = false
                    mode.beginTyping()
                    showsTools.toggle()
                }
            } label: {
                Image(systemName: reduceMotion && showsTools ? "xmark.circle" : "plus.circle")
                    .font(.system(size: 25.zoom()))
                    .frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
                    .rotationEffect(.degrees(showsTools && !reduceMotion ? 45 : 0))
            }
            .accessibilityLabel(showsTools ? "收起更多功能" : "展开更多功能")
            .accessibilityIdentifier("chatComposerMore")
            ZStack {
                if mode.panel == .voice { voicePressBar.transition(.identity) }
                else { textInput.transition(.identity) }
            }
            // identity避免旧控件残留；位置跟随外层收展事务，不单独禁用动画。
            ZStack {
                primaryButton.id(primaryRole).transition(.opacity)
            }
            .frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
            .animation(controlAnimation, value: primaryRole)
            .disabled(!chat.permission.canSend)

        }.buttonStyle(ChatComposerButtonStyle())
            .padding(.horizontal, 12.zoom()).padding(.vertical, 6.zoom())
    }

    private var textInput: some View {
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
                withAnimation(panelAnimation) {
                    if mode.panel == .stickers { mode.beginTyping(); focused.wrappedValue = true }
                    else { focused.wrappedValue = false; mode.toggle(.stickers) }
                }
            } label: {
                ZStack {
                    Image(systemName: mode.panel == .stickers ? "keyboard" : "face.smiling")
                        .id(mode.panel == .stickers).transition(.opacity)
                }
                .font(.system(size: 23.zoom())).frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
            }.accessibilityLabel(mode.panel == .stickers ? "切换文字输入" : "展开表情与贴纸")
        }.background(MessagingTheme.background, in: RoundedRectangle(cornerRadius: 14.zoom()))
            .disabled(!chat.permission.canSend)
    }

    /// 无文本时不占用一个永久发送按钮；键盘编辑时保留明确发送出口。
    @ViewBuilder private var primaryButton: some View {
        if mode.panel == .voice {
            Button { withAnimation(panelAnimation) { mode.beginTyping(); focused.wrappedValue = true } } label: {
                Image(systemName: "keyboard").font(.system(size: 23.zoom())).frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
            }.accessibilityLabel("切换文字输入")
        } else if ChatComposerMode.primaryAction(input: chat.input, focused: focused.wrappedValue) == .send {
            Button { chat.sendText() } label: {
                Image(systemName: "arrow.up").font(.system(size: 20.zoom(), weight: .semibold))
                    .frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
                    .foregroundStyle(MessagingTheme.onPrimaryAction).background(MessagingTheme.primaryAction, in: RoundedRectangle(cornerRadius: 12.zoom()))
            }.accessibilityLabel("发送消息").disabled(chat.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(chat.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                .animation(controlAnimation, value: chat.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } else {
            Button { withAnimation(panelAnimation) { focused.wrappedValue = false; mode.toggle(.voice) } } label: {
                Image(systemName: "mic").font(.system(size: 24.zoom())).frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
            }.accessibilityLabel("展开语音录制")
        }
    }

    /// 通话资格独立于文字禁言；大字时自适应换行，保持触点大小。
    private var tools: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0),
                                 count: dynamicTypeSize.isAccessibilitySize ? 2 : 4), spacing: 16.zoom()) {
            PhotosPicker(selection: $photos, maxSelectionCount: 9, matching: .any(of: [.images, .videos])) { Label("相册", systemImage: "photo") }
                .frame(maxWidth: .infinity).disabled(!chat.permission.canSend)
            Button { focused.wrappedValue = false; prepareCamera() } label: { Label("拍摄", systemImage: "camera") }
                .frame(maxWidth: .infinity).disabled(!chat.permission.canSend || calls.session != nil)
            Button { focused.wrappedValue = false; showFiles = true } label: { Label("文件", systemImage: "doc") }
                .frame(maxWidth: .infinity).disabled(!chat.permission.canSend)
            if offersCalls {
                Button { beginCall(.video) } label: { Label("视频通话", systemImage: "video") }
                    .disabled(calls.busy)
                Button { beginCall(.audio) } label: { Label("语音通话", systemImage: "phone") }
                    .disabled(calls.busy)
            }
        }.labelStyle(ChatComposerToolLabelStyle(equalWidth: true)).buttonStyle(ChatComposerButtonStyle())
            .padding(.horizontal, 12.zoom())
            .padding(.vertical, 12.zoom())
    }

    private var offersCalls: Bool {
        guard let context = chat.context else { return false }
        return calls.canOfferCall(context: context)
    }

    private func beginCall(_ kind: CallKind) {
        guard let context = chat.context else { return }
        showsTools = false
        focused.wrappedValue = false; mode.beginTyping()
        cancelRecording(); onBeginRecording()
        Task { await calls.start(context: context, kind: kind) }
    }

    /// 按住触点始终留在输入栏，录音反馈不参与布局，防止手势中途位移。
    private var voicePressBar: some View {
        ZStack {
            Text(voicePress.isHolding ? (voicePress.isInside && recorder.isRecording ? "松开发送" : "松开取消") : "按住说话")
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: max(48, 48.zoom()))
                .foregroundStyle(voicePress.isHolding && !voicePress.isInside ? MessagingTheme.error : MessagingTheme.text)
                .background(voicePress.isHolding
                    ? (voicePress.isInside ? HomeTheme.mintSurface : MessagingTheme.error.opacity(0.12))
                    : MessagingTheme.background, in: RoundedRectangle(cornerRadius: 12.zoom()))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: voicePress.isInside)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: voicePress.isHolding)
                .accessibilityHidden(true)
            ChatVoiceRecordButton(holding: voicePress.isHolding, onBegin: beginRecording,
                onMove: { voicePress.move(inside: $0) }, onEnd: releaseRecording, onCancel: cancelRecording)
        }
        .frame(height: max(48, 48.zoom()))
        .disabled(!chat.permission.canSend)
    }

    /// 仅展示真实录音电平和时长；授权等待不冒充正在录音。
    private var voiceFeedback: some View {
        VStack(spacing: 12.zoom()) {
            HStack(spacing: 12.zoom()) {
                if !voicePress.isInside {
                    Image(systemName: "xmark").font(.system(size: 26.zoom(), weight: .medium))
                        .frame(width: 60.zoom(), height: 32.zoom())
                } else if recorder.isRecording {
                    ChatVoiceRecordingMeter(level: recorder.level)
                        .frame(width: 60.zoom(), height: 32.zoom())
                        .animation(reduceMotion ? nil : .linear(duration: 0.1), value: recorder.level)
                } else {
                    ProgressView().tint(MessagingTheme.onPrimaryAction)
                        .frame(width: 60.zoom(), height: 32.zoom())
                }
                Text(recorder.isRecording ? "\(Int(recorder.duration))秒" : "准备中")
                    .font(.title3.weight(.semibold)).monospacedDigit()
            }
            Text(voicePress.isInside ? (recorder.isRecording ? "松开发送，上滑取消" : "正在准备录音…") : "松开取消")
                .font(.body.weight(.medium))
            if !voicePress.isInside {
                Text("向下滑回，继续录音").font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 20.zoom()).padding(.horizontal, 16.zoom())
        .foregroundStyle(voicePress.isInside ? MessagingTheme.onPrimaryAction : MessagingTheme.onError)
        .background(voicePress.isInside ? MessagingTheme.primaryAction : MessagingTheme.error,
                    in: RoundedRectangle(cornerRadius: 16.zoom()))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: voicePress.isInside)
    }

    /// 同步清理捕获独立弱对象，避免SwiftUI页面被根runtime长期持有。
    private func registerCleanup() {
        chat.mediaRetryClient = media
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
    /// 按下即请求录音；权限弹窗期间松手会撤销该轮，不迟到启动麦克风。
    private func beginRecording() {
        guard chat.permission.canSend, let context = chat.context, startRecordingTask == nil else { return }
        guard calls.session == nil else { recorder.errorMessage = "通话中暂不能录制语音"; return }
        media.errorMessage = nil
        guard !media.isUploading else { recorder.errorMessage = "附件正在发送，请稍后再试"; return }
        guard voicePress.begin() else { return }
        onBeginRecording()
        let run = UUID(); recordingGestureID = run
        startRecordingTask = Task {
            await recorder.start(context: context, onLimitReached: {
                guard recordingGestureID == run, voicePress.reachLimit() else { return }
                sendRecording()
            })
            guard !Task.isCancelled, recordingGestureID == run else { return }
            startRecordingTask = nil
            if !recorder.isRecording { voicePress.cancel() }
        }
    }

    /// 松手时采用手势组件的上滑判定；录满自动发送后的松手被状态机消费。
    private func releaseRecording(inside: Bool) {
        guard let shouldSend = voicePress.release(inside: inside) else { return }
        if shouldSend && recorder.isRecording { sendRecording() } else { cancelRecording() }
    }

    /// 收起、上滑松手、系统取消、失去权限和后台统一清理未发送录音。
    private func cancelRecording() {
        recordingGestureID = UUID(); startRecordingTask?.cancel(); startRecordingTask = nil
        recorder.cancel(); voicePress.cancel()
    }

    /// 松手与60秒上限共用一次交付；上传和最终SDK ACK继续走原发送链路。
    private func sendRecording() {
        recordingGestureID = UUID(); startRecordingTask?.cancel(); startRecordingTask = nil
        voicePress.cancel()
        do {
            guard chat.permission.canSend, let context = chat.context else { cancelRecording(); return }
            let attachment = try recorder.finish()
            preparation = Task { await send(attachment, context: context) }
        } catch { recorder.cancel(); recorder.errorMessage = error.localizedDescription }
    }
    /// 上传取消或退出后不入队，临时附件完成后清理。
    private func send(_ attachment: ChatAttachment, context: ChatContext) async {
        defer { try? FileManager.default.removeItem(at: attachment.file); if let file = attachment.previewFile { try? FileManager.default.removeItem(at: file) } }
        await media.send(attachment, context: context,
            stage: { message in try chat.beginMediaUpload(message) },
            discard: { id in chat.discardMediaUpload(id) },
            failed: { message in chat.failMediaUpload(message) },
            enqueue: { message in try chat.sendAttachment(message) })
    }
}
