import SwiftUI
import AVFoundation

@main struct VlogHost: App {
    @State private var selected: MemberTab = .messages
    init() {
        L10n.use(.simplifiedChinese)
        let reset = ProcessInfo.processInfo.arguments.contains("--reset-vlog")
        if reset, let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? FileManager.default.removeItem(at: support.appendingPathComponent("Vlog"))
        }
        VlogStore.shared.activate(tenantID: "test", userUID: "fixture")
        if reset { Task {
            while !VlogStore.shared.ready { await Task.yield() }
            do {
                let image = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 600)).image { context in
                    UIColor.systemTeal.setFill(); context.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
                }
                let photo = try await Task.detached { try VlogMediaPreparation.image(image) }.value
                _ = await VlogStore.shared.importPrepared(photo, expectedEpoch: VlogStore.shared.epoch); photo.discard()
                let file = try await makeVideo()
                defer { try? FileManager.default.removeItem(at: file) }
                let video = try await VlogMediaPreparation.prepare(file: file, kind: .video)
                _ = await VlogStore.shared.importPrepared(video, expectedEpoch: VlogStore.shared.epoch); video.discard()
            } catch { fatalError("Anonymous media fixture failed: \(error)") }
        } }
    }
    var body: some Scene {
        WindowGroup {
            TabView(selection: $selected) {
                ForEach(MemberTab.allCases) { tab in
                    ActivityNavigationScope {
                        if tab == .vlog { VlogView() }
                        else { Text(tab.displayName).navigationTitle(tab.displayName) }
                    }.tabItem { Label(tab.displayName, systemImage: tab.icon) }.tag(tab)
                }
            }.environment(\.locale, Locale(identifier: "zh-Hans"))
        }
    }
}

@MainActor func makeVideo() async throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 240])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 240])
    writer.add(input); writer.startWriting(); writer.startSession(atSourceTime: .zero)
    for i in 0..<30 {
        while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 5_000_000) }
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 320, 240, kCVPixelFormatType_32ARGB, nil, &buffer)
        guard let buffer else { throw VlogError.invalidMedia }
        CVPixelBufferLockBaseAddress(buffer, [])
        memset(CVPixelBufferGetBaseAddress(buffer), 120, CVPixelBufferGetDataSize(buffer))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(i), timescale: 30)) else { throw writer.error ?? VlogError.invalidMedia }
    }
    input.markAsFinished(); await writer.finishWriting()
    guard writer.status == .completed else { throw writer.error ?? VlogError.invalidMedia }
    return url
}

// Only login/recipient transport boundaries are replaced. Media preparation, persistence,
// navigation, playback, theme and localization are the shipping implementations.
@MainActor final class ChatRuntime {
    static let shared = ChatRuntime(); let revision = UUID()
    func registerCleanup(owner: AnyObject, action: @escaping @MainActor () -> Void) {}
}
@MainActor final class CallCoordinator: ObservableObject {
    static let shared = CallCoordinator()
    @Published var session: String?
}
enum ChatClientError: LocalizedError {
    case unavailable(String)
    var errorDescription: String? { switch self { case .unavailable(let value): value } }
}
nonisolated enum ContactsShareContent { case media(ChatAttachment, sessionRevision: UUID) }
struct ContactsRecipientPickerView: View {
    let content: ContactsShareContent
    @Environment(\.dismiss) var dismiss
    var body: some View { NavigationStack { Text("Recipient transport excluded from UI host")
        .navigationTitle("选择接收人").toolbar { Button("取消") { dismiss() } } } }
}
struct ChatContext: Sendable {}
