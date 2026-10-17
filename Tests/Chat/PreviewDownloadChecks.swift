//
//  PreviewDownloadChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//

import Foundation

/// 离线下载交付真实临时文件，不访问服务器或真实用户缓存。
@MainActor final class URLSession {
    struct Configuration { static let ephemeral = Configuration() }
    static var payload = Data()
    static var downloads: [URL] = []
    init(configuration: Configuration, delegate: ChatTransferSessionDelegate, delegateQueue: OperationQueue?) {}
    func finishTasksAndInvalidate() {}
    func invalidateAndCancel() {}
    func download(for request: URLRequest) async throws -> (URL, URLResponse) {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Self.payload.write(to: file); Self.downloads.append(file)
        return (file, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

/// iOS音频与导航仅提供加载方法需要的形状，不激活系统设备。
@MainActor final class AVAudioPlayer { func stop() {} }
@MainActor final class AVAudioSession {
    struct Options: OptionSet { let rawValue: Int; static let notifyOthersOnDeactivation = Options(rawValue: 1) }
    static let shared = AVAudioSession()
    static func sharedInstance() -> AVAudioSession { shared }
    func setActive(_ active: Bool, options: Options) throws {}
}
struct ChatTransferSessionDelegate { let origin: URL? }
@MainActor final class ChatRuntime {
    static let shared = ChatRuntime()
    func isCurrent(_ context: ChatContext) -> Bool { true }
    func isMessageDeleted(_ message: ChatMessageRecord, context: ChatContext) -> Bool { false }
}
@MainActor final class OSSConnectionBootstrap {
    struct Navigation { var getFileHost: URL? = URL(string: "https://offline.invalid")! }
    static let shared = OSSConnectionBootstrap()
    var current: Navigation? = Navigation()
}

/// 明确暂停在真实解包之前，让取消时序不依赖文件大小或固定yield次数。
enum PreviewDecodeGate {
    static let entered = DispatchSemaphore(value: 0)
    static let release = DispatchSemaphore(value: 0)
    static let cancellations = DispatchSemaphore(value: 0)
    static func decodeFile(_ file: URL) throws -> URL {
        entered.signal()
        guard release.wait(timeout: .now() + 5) == .success else { throw CocoaError(.fileReadUnknown) }
        do { return try LegacyChatMediaCodec.decodeFile(file) }
        catch is CancellationError { cancellations.signal(); throw CancellationError() }
    }
    static func didCancelDecode() -> Bool { cancellations.wait(timeout: .now()) == .success }
    static func waitForEntry() async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async { continuation.resume(returning: entered.wait(timeout: .now() + 5) == .success) }
        }
    }
}

@main struct PreviewDownloadChecks {
    /// 回归取消发生在下载后解包中的边界，缓存发布、临时文件和后续重试均执行生产代码。
    @MainActor static func main() async throws {
        let context = ChatContext(userUID: "offline-preview", tenantID: UUID().uuidString, sessionID: UUID(), route: ChatRoute(id: "peer", kind: .single, title: "", avatarURL: ""))
        defer { try? ProductionPreview.clearCache(context: context); URLSession.downloads.forEach { try? FileManager.default.removeItem(at: $0) } }
        let original = Data((0..<1024).map { UInt8($0 % 251) })
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        try original.write(to: source)
        let encoded = try LegacyChatMediaCodec.prepareUpload(file: source, type: 1)
        defer { try? FileManager.default.removeItem(at: source); try? FileManager.default.removeItem(at: encoded) }
        URLSession.payload = try Data(contentsOf: encoded)
        var message = ChatMessageRecord(localID: "cancelled", conversationID: "peer", senderID: "peer", senderName: "", type: 1, timestamp: 0)
        message.resource = "/anonymous.png"; message.fileName = "anonymous.png"
        let preview = ProductionPreview()
        let alreadyCancelled = Task { [message] in
            withUnsafeCurrentTask { $0?.cancel() }
            await preview.load(message, context: context)
        }
        await alreadyCancelled.value
        precondition(URLSession.downloads.isEmpty && preview.file == nil && !preview.loading, "已取消的任务不能重新发起下载")
        let load = Task { [message] in await preview.load(message, context: context) }
        let decoding = await PreviewDecodeGate.waitForEntry()
        precondition(decoding, "必须先进入解包暂停点")
        load.cancel(); PreviewDecodeGate.release.signal(); await load.value
        precondition(preview.file == nil, "加载任务取消后不能发布解包结果或重新显示附件")
        precondition(PreviewDecodeGate.didCancelDecode(), "加载任务取消必须传递到真实流式解包")
        precondition(!preview.loading && preview.errorMessage == nil, "主动取消不能残留加载态或失败Toast")
        precondition(!FileManager.default.fileExists(atPath: URLSession.downloads[0].path), "取消后必须删除网络交付的临时文件")

        let resuming = Task { [message] in await preview.load(message, context: context) }
        let resumedDecode = await PreviewDecodeGate.waitForEntry()
        precondition(resumedDecode, "取消后同一页面仍应允许重试")
        PreviewDecodeGate.release.signal(); await resuming.value
        guard let resumedFile = preview.file else { preconditionFailure("取消后重试必须恢复附件") }
        let resumedBytes = try Data(contentsOf: resumedFile)
        precondition(resumedBytes == original && preview.errorMessage == nil, "重试必须使用完整解包结果")
        precondition(!preview.loading && !FileManager.default.fileExists(atPath: URLSession.downloads[1].path), "成功解包也必须结束加载并清理下载临时文件")

        // 删除原条使用同一关闭路径，不能让后台解包继续写出旧文件。
        message.localID = "deleted"
        let deleting = Task { [message] in await preview.load(message, context: context) }
        let deletingDecode = await PreviewDecodeGate.waitForEntry()
        precondition(deletingDecode, "删除回归必须发生在解包中")
        preview.invalidateMessage(message, context: context)
        PreviewDecodeGate.release.signal(); await deleting.value
        precondition(preview.file == nil && preview.isInvalidated, "解包期间删除必须保持附件失效")
        precondition(PreviewDecodeGate.didCancelDecode(), "删除关闭必须取消真实解包，不能只丢弃最终显示")
        precondition(!FileManager.default.fileExists(atPath: URLSession.downloads[2].path), "删除取消解包后必须清理下载临时文件")
        let downloadsBeforeReload = URLSession.downloads.count
        await preview.load(message, context: context)
        precondition(preview.isInvalidated && preview.file == nil && URLSession.downloads.count == downloadsBeforeReload, "失效原条不可经重试恢复下载")

        // TCP-only 没有文件Host时仍可使用服务端完整云地址，相对路径则明确不可用。
        OSSConnectionBootstrap.shared.current = .init(getFileHost: nil)
        message.localID = "absolute-cloud"
        message.resource = "https://cloud.example/anonymous.png"
        let cloud = ProductionPreview()
        let cloudLoad = Task { [message] in await cloud.load(message, context: context) }
        let cloudDecoding = await PreviewDecodeGate.waitForEntry()
        precondition(cloudDecoding, "完整云URL不依赖导航HTTP")
        PreviewDecodeGate.release.signal(); await cloudLoad.value
        precondition(cloud.file != nil && cloud.errorMessage == nil, "TCP-only云附件应可预览")
        let relative = ProductionPreview()
        message.localID = "relative-cloud"; message.resource = "/anonymous.png"
        let downloadsBeforeRelative = URLSession.downloads.count
        await relative.load(message, context: context)
        precondition(relative.file == nil && relative.errorMessage != nil && URLSession.downloads.count == downloadsBeforeRelative, "无文件Host不能猜测相对资源地址")
        print("Preview download checks passed: cancelled entry, decode cancellation, retry, deletion invalidation and file cleanup")
    }
}
