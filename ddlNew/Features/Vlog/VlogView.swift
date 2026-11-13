import SwiftUI
import AVFoundation

struct VlogRoute: Hashable { let id: UUID }
private enum VlogCapture: String, Identifiable { case photo, video; var id: String { rawValue } }

struct VlogView: View {
    @ObservedObject var store: VlogStore = .shared
    @EnvironmentObject private var navigation: ActivityNavigation
    @State private var capture: VlogCapture?
    @State private var library = false
    @State private var information = false
    @State private var needsSettings = false
    @State private var processing = false
    @State private var feedback: String?
    @State private var feedbackRevision = 0
    @State private var work: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("记录这一刻")).font(.largeTitle.bold())
                    Text(L10n.tr("把照片和视频留在这里，分享给在意的人。"))
                        .font(.subheadline).foregroundStyle(MessagingTheme.secondaryText)
                }.padding(.top, 12)
                HStack(spacing: 12) {
                    captureButton("拍照", icon: "camera", kind: .photo)
                    captureButton("录像", icon: "video", kind: .video)
                }.disabled(!store.ready || store.busy || processing)
                if processing || store.busy { ProgressView(L10n.tr("正在处理" )).frame(maxWidth: .infinity).padding() }
                if let error = store.errorMessage {
                    Text(error).foregroundStyle(MessagingTheme.error)
                    if !store.ready { Button(L10n.tr("重试")) { Task { await store.reload() } } }
                }
                if store.ready && store.records.isEmpty && !processing {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled").font(.system(size: 44)).foregroundStyle(MessagingTheme.accent)
                        Text(L10n.tr("还没有作品")).font(.headline)
                        Text(L10n.tr("拍一张照片，或录一段值得收藏的视频。"))
                            .font(.subheadline).foregroundStyle(MessagingTheme.secondaryText).multilineTextAlignment(.center)
                        Button(L10n.tr("从相册选择")) { library = true }.frame(minHeight: 44)
                    }.frame(maxWidth: .infinity).padding(.vertical, 36)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 20) {
                    ForEach(store.records) { record in
                        Button { navigation.open(VlogRoute(id: record.id)) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .bottomTrailing) {
                                    VlogImage(file: store.file(record, thumbnail: true), maximum: 640, fill: true)
                                        .frame(height: 180).frame(maxWidth: .infinity).clipped()
                                        .background(MessagingTheme.surface)
                                    if record.kind == .video {
                                        Label(record.duration.formatted(.number.precision(.fractionLength(0))) + "s", systemImage: "play.fill")
                                            .font(.caption.monospacedDigit()).padding(6).background(.black.opacity(0.65), in: Capsule())
                                            .foregroundStyle(.white).padding(8)
                                    }
                                }.clipShape(RoundedRectangle(cornerRadius: 16))
                                Text(record.createdAt, format: .dateTime.month().day().hour().minute())
                                    .font(.caption).foregroundStyle(MessagingTheme.secondaryText).lineLimit(1)
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .accessibilityLabel(L10n.tr(record.kind == .video ? "视频作品" : "照片作品"))
                            .accessibilityIdentifier("vlog.item.\(record.id)")
                    }
                }
            }.padding(20).frame(maxWidth: 840).frame(maxWidth: .infinity)
        }
        .background(MessagingTheme.background)
        .navigationTitle("Vlog").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { information = true } label: { Image(systemName: "info.circle").frame(width: 44, height: 44) }
                    .accessibilityLabel(L10n.tr("作品存储说明"))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { library = true } label: { Image(systemName: "photo.badge.plus").frame(width: 44, height: 44) }
                    .accessibilityLabel(L10n.tr("从相册选择")).accessibilityIdentifier("vlog.import")
                    .disabled(!store.ready || store.busy || processing)
            }
        }
        .navigationDestination(for: VlogRoute.self) { route in VlogDetailView(id: route.id, store: store) }
        .fullScreenCover(item: $capture) { value in
            let epoch = store.epoch
            VlogCapturePicker(video: value == .video, onLoading: { processing = true }, onResult: { result in
                work = Task { await accept(result, epoch: epoch) }
            }).ignoresSafeArea()
        }
        .sheet(isPresented: $library) {
            let epoch = store.epoch
            VlogLibraryPicker(onLoading: { processing = true }, onResult: { result in
                work = Task { await accept(result, epoch: epoch) }
            })
        }
        .alert(L10n.tr("作品存储说明"), isPresented: $information) {
            Button(L10n.tr("知道了"), role: .cancel) { }
        } message: { Text(L10n.tr("作品按账号保存在当前设备。卸载应用会移除作品，当前不支持云端恢复；发送后的聊天消息不受删除作品影响。")) }
        .alert(L10n.tr("需要相机或麦克风权限"), isPresented: $needsSettings) {
            Button(L10n.tr("取消"), role: .cancel) { }
            Button(L10n.tr("前往设置")) { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
        } message: { Text(L10n.tr("请在系统设置中允许拍摄所需权限后重试。")) }
        .messagingFeedbackToast(feedback, trigger: feedbackRevision)
        .onChange(of: store.epoch) { _ in work?.cancel(); capture = nil; library = false; processing = false }
        .onDisappear { work?.cancel() }
    }
    private func captureButton(_ title: String, icon: String, kind: VlogCapture) -> some View {
        Button { requestCamera(kind) } label: {
            Label(L10n.lookup(title), systemImage: icon).font(.headline)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(MessagingTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain).foregroundStyle(MessagingTheme.accent)
    }
    private func requestCamera(_ kind: VlogCapture) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { show("当前设备无法使用相机"); return }
        let epoch = store.epoch
        processing = true
        work = Task {
            defer { if epoch == store.epoch { processing = false } }
            let video = await AVCaptureDevice.requestAccess(for: .video)
            guard video else { if epoch == store.epoch, !Task.isCancelled { needsSettings = true }; return }
            let audio = kind == .video ? await AVCaptureDevice.requestAccess(for: .audio) : true
            guard !Task.isCancelled, epoch == store.epoch else { return }
            if video && audio { capture = kind } else { needsSettings = true }
        }
    }
    private func accept(_ result: Result<VlogPrepared, Error>, epoch: UUID) async {
        defer { if epoch == store.epoch { processing = false } }
        switch result {
        case .success(let prepared):
            defer { prepared.discard() }
            guard !Task.isCancelled, epoch == store.epoch else { return }
            if await store.importPrepared(prepared, expectedEpoch: epoch) { show("作品已保存") }
        case .failure(let error):
            if epoch == store.epoch, !(error is CancellationError) { show("无法处理该照片或视频，请重新选择并检查存储空间。") }
        }
    }
    private func show(_ key: String) { feedback = L10n.lookup(key); feedbackRevision += 1 }
}

struct VlogImage: View {
    let file: URL?
    let maximum: Int
    var fill = false
    @State private var image: UIImage?
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: fill ? .fill : .fit)
                } else {
                    Image(systemName: "photo").font(.largeTitle).foregroundStyle(MessagingTheme.secondaryText)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
        .task(id: file) {
            image = nil
            guard let file else { return }
            let job = Task.detached { VlogMediaPreparation.thumbnail(file, maximum: maximum) }
            let loaded = await job.value
            guard !Task.isCancelled else { return }; image = loaded
        }
        .onDisappear { image = nil }
    }
}
