import SwiftUI
import AVKit

struct VlogDetailView: View {
    let id: UUID
    @ObservedObject var store: VlogStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var playback = ChatPhotoBrowserPlayback()
    @State private var sharing = false
    @State private var shareRevision = UUID()
    @State private var deleting = false
    @State private var playbackError: String?
    @State private var previewing = false
    private var record: VlogRecord? { store.records.first { $0.id == id } }

    var body: some View {
        Group {
            if let record, let file = store.file(record) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ZStack {
                            Color.black
                            if record.kind == .video, previewing, let player = playback.player {
                                VideoPlayer(player: player)
                            } else {
                                VlogImage(file: record.kind == .video ? store.file(record, thumbnail: true) : file, maximum: 2048)
                                if record.kind == .video {
                                    Button { play(file) } label: {
                                        Image(systemName: "play.circle.fill").font(.system(size: 64))
                                            .foregroundStyle(.white).shadow(radius: 4).padding(16)
                                    }.accessibilityLabel(L10n.tr("播放视频"))
                                }
                            }
                        }.frame(height: 360).clipShape(RoundedRectangle(cornerRadius: 20))
                        Text(record.createdAt, format: .dateTime.year().month().day().hour().minute()).font(.headline)
                        Text(L10n.tr(record.kind == .video ? "视频作品" : "照片作品"))
                            .font(.subheadline).foregroundStyle(MessagingTheme.secondaryText)
                        if let error = playbackError ?? store.errorMessage { Text(error).foregroundStyle(MessagingTheme.error) }
                        Button { stop(); shareRevision = ChatRuntime.shared.revision; sharing = true } label: {
                            Label(L10n.tr("发送给好友或群"), systemImage: "paperplane")
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }.buttonStyle(MessagingActionButtonStyle()).disabled(store.busy)
                            .accessibilityIdentifier("vlog.share")
                    }.padding(20).frame(maxWidth: 840).frame(maxWidth: .infinity)
                }
                .sheet(isPresented: $sharing) {
                    if let thumbnail = store.file(record, thumbnail: true) {
                        ContactsRecipientPickerView(content: .media(ChatAttachment(file: file,
                            type: record.kind == .photo ? 1 : 2, name: record.filename, bytes: record.bytes,
                            duration: record.duration, width: record.width, height: record.height,
                            previewFile: record.kind == .video ? thumbnail : nil), sessionRevision: shareRevision))
                    }
                }
            } else {
                Text(L10n.tr("作品已不存在")).foregroundStyle(MessagingTheme.secondaryText)
            }
        }
        .navigationTitle(L10n.tr("作品详情")).navigationBarTitleDisplayMode(.inline)
        .background(MessagingTheme.background)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) { stop(); deleting = true } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                    .accessibilityLabel(L10n.tr("删除作品")).accessibilityIdentifier("vlog.delete").disabled(store.busy || record == nil)
            }
        }
        .alert(L10n.tr("删除这份作品？"), isPresented: $deleting) {
            Button(L10n.tr("取消"), role: .cancel) { }
            Button(L10n.tr("删除"), role: .destructive) {
                let epoch = store.epoch
                Task { if await store.remove(id, expectedEpoch: epoch) { dismiss() } }
            }
        } message: { Text(L10n.tr("删除后无法恢复，已发送的聊天消息不会被删除。")) }
        .onAppear {
            let owner = playback
            ChatRuntime.shared.registerCleanup(owner: owner) { [weak owner] in owner?.stop() }
        }
        .onDisappear { stop() }
        .onChange(of: scenePhase) { if $0 != .active { stop() } }
        .onChange(of: store.epoch) { _ in stop(); sharing = false; dismiss() }
        .onReceive(CallCoordinator.shared.$session) { if $0 != nil { stop() } }
    }
    private func play(_ file: URL) {
        do {
            guard FileManager.default.fileExists(atPath: file.path) else { throw VlogError.missing }
            try playback.play(file: file) { playbackError = L10n.tr("视频无法播放，请检查文件是否完整。") }
            previewing = true; playbackError = nil
        } catch { playbackError = (error as? ChatClientError)?.localizedDescription ?? L10n.tr("视频无法播放，请检查文件是否完整。") }
    }
    private func stop() { playback.stop(); previewing = false }
}
