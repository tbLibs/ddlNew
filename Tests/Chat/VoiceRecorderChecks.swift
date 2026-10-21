import Foundation

@MainActor final class CallCoordinator {
    static let shared = CallCoordinator()
    var session: UUID?
}

let AVFormatIDKey = "format", AVSampleRateKey = "sample", AVNumberOfChannelsKey = "channels", AVEncoderBitRateKey = "rate"
let kAudioFormatMPEG4AAC = 1
let AVAudioSessionInterruptionTypeKey = "interruption"
struct ChatContext: Equatable { let id = UUID() }
struct ChatAttachment { let file: URL; let type: Int; let name: String; let bytes: Int64; let duration: Double }
enum ChatClientError: Error { case sessionExpired, unavailable(String) }
@MainActor final class ChatRuntime {
    static let shared = ChatRuntime()
    var current = true
    func isCurrent(_ context: ChatContext) -> Bool { current }
}
@MainActor final class AVAudioSession {
    enum Category { case playAndRecord }
    enum Mode { case `default` }
    enum InterruptionType: UInt { case began = 1 }
    struct Options: OptionSet {
        let rawValue: Int
        static let defaultToSpeaker = Options(rawValue: 1), allowBluetoothHFP = Options(rawValue: 2), notifyOthersOnDeactivation = Options(rawValue: 4)
    }
    static let interruptionNotification = Notification.Name("OfflineVoiceInterruption")
    static let shared = AVAudioSession()
    var active = false
    var permitted = true
    var pending: ((Bool) -> Void)?
    var delayPermission = false
    static func sharedInstance() -> AVAudioSession { shared }
    func requestRecordPermission(_ action: @escaping (Bool) -> Void) {
        if delayPermission { pending = action } else { action(permitted) }
    }
    func setCategory(_ category: Category, mode: Mode, options: Options) throws {}
    func setActive(_ active: Bool, options: Options = []) throws { self.active = active }
}
@MainActor final class AVAudioRecorder {
    static var last: AVAudioRecorder?
    static var canRecord = true
    weak var delegate: ChatVoiceRecorder?
    var currentTime = 0.0
    var isMeteringEnabled = false
    var isRecording = false
    let url: URL
    init(url: URL, settings: [String: Any]) throws { self.url = url; Self.last = self }
    func record(forDuration: TimeInterval) -> Bool {
        try? Data(repeating: 1, count: 2048).write(to: url)
        isRecording = Self.canRecord
        return isRecording
    }
    func stop() { isRecording = false }
    func updateMeters() {}
    func averagePower(forChannel: Int) -> Float { -20 }
}

@main struct VoiceRecorderChecks {
    @MainActor static func main() async throws {
        let recorder = ChatVoiceRecorder()
        let context = ChatContext()
        await recorder.start(context: context)
        AVAudioRecorder.last!.currentTime = 0.6
        var rejected = false
        do { let value = try recorder.finish(); try? FileManager.default.removeItem(at: value.file) } catch { rejected = true }
        precondition(rejected, "不足1秒，即使文件超过1024字节，也必须拒绝发送")
        precondition(!AVAudioSession.shared.active, "短录音必须释放音频会话")
        recorder.cancel()

        await recorder.start(context: context)
        let acceptedFile = AVAudioRecorder.last!.url
        AVAudioRecorder.last!.currentTime = 1.2
        let attachment = try recorder.finish()
        precondition(attachment.duration == 1.2 && attachment.type == 4 && attachment.file == acceptedFile)
        var duplicated = false
        do { _ = try recorder.finish(); duplicated = true } catch {}
        precondition(!duplicated, "一次录音只能交付一个附件")
        recorder.cancel()
        precondition(FileManager.default.fileExists(atPath: acceptedFile.path), "已交付文件归上传流程清理")
        try? FileManager.default.removeItem(at: acceptedFile)

        AVAudioSession.shared.delayPermission = true
        let permissionWait = Task { await recorder.start(context: context) }
        while AVAudioSession.shared.pending == nil { await Task.yield() }
        recorder.cancel()
        AVAudioSession.shared.pending?(true); AVAudioSession.shared.pending = nil
        await permissionWait.value
        precondition(!recorder.isRecording && !AVAudioSession.shared.active, "授权等待时松手后不得迟到开麦")
        AVAudioSession.shared.delayPermission = false

        await recorder.start(context: context)
        let cancelledFile = AVAudioRecorder.last!.url
        recorder.cancel()
        precondition(!FileManager.default.fileExists(atPath: cancelledFile.path) && !recorder.isRecording)
        AVAudioSession.shared.permitted = false
        await recorder.start(context: context)
        precondition(!recorder.isRecording && recorder.errorMessage != nil)
        AVAudioSession.shared.permitted = true

        var limitCount = 0
        await recorder.start(context: context, onLimitReached: { limitCount += 1 })
        let limitRecorder = AVAudioRecorder.last!
        limitRecorder.currentTime = 60
        recorder.audioRecorderDidFinishRecording(limitRecorder, successfully: true)
        while limitCount == 0 { await Task.yield() }
        precondition(!recorder.isRecording && recorder.duration == 60, "60秒完成须发布发送意图")
        let full = try recorder.finish()
        precondition(full.duration == 60)
        try? FileManager.default.removeItem(at: full.file)
        recorder.audioRecorderDidFinishRecording(limitRecorder, successfully: true)
        for _ in 0..<5 { await Task.yield() }
        precondition(limitCount == 1, "已交付的迟到回调不能重复发送")

        var press = ChatVoicePressState()
        _ = press.begin()
        var automaticallySent: ChatAttachment?
        await recorder.start(context: context, onLimitReached: {
            guard press.reachLimit() else { return }
            automaticallySent = try? recorder.finish()
        })
        let deadlineRecorder = AVAudioRecorder.last!
        deadlineRecorder.currentTime = 60
        recorder.audioRecorderDidFinishRecording(deadlineRecorder, successfully: true)
        while automaticallySent == nil { await Task.yield() }
        precondition(!press.isHolding && press.release(inside: true) == nil, "上限回调须在同轮同步消费按住状态，随后松手不能取消或重发")
        try? FileManager.default.removeItem(at: automaticallySent!.file)

        AVAudioRecorder.canRecord = false
        await recorder.start(context: context)
        precondition(!recorder.isRecording && !AVAudioSession.shared.active)
        precondition(!FileManager.default.fileExists(atPath: AVAudioRecorder.last!.url.path), "开录失败不得遗留临时文件")
        AVAudioRecorder.canRecord = true
        await recorder.start(context: context)
        let interrupted = AVAudioRecorder.last!
        recorder.audioRecorderEncodeErrorDidOccur(interrupted, error: nil)
        while recorder.isRecording { await Task.yield() }
        precondition(!FileManager.default.fileExists(atPath: interrupted.url.path) && recorder.errorMessage != nil)

        AVAudioSession.shared.active = true
        recorder.cancel()
        precondition(AVAudioSession.shared.active, "空闲录音器取消不能停掉其他语音播放")
        AVAudioSession.shared.active = false
        recorder.cancel()
        CallCoordinator.shared.session = UUID()
        await recorder.start(context: context)
        precondition(!recorder.isRecording && !AVAudioSession.shared.active, "通话中不能启动录音或抢占音频")
        CallCoordinator.shared.session = nil
        AVAudioSession.shared.delayPermission = true
        let callDuringPermission = Task { await recorder.start(context: context) }
        while AVAudioSession.shared.pending == nil { await Task.yield() }
        CallCoordinator.shared.session = UUID()
        AVAudioSession.shared.pending?(true); AVAudioSession.shared.pending = nil
        await callDuringPermission.value
        precondition(!recorder.isRecording && !AVAudioSession.shared.active, "授权等待期间来电后不能迟到录音")
        CallCoordinator.shared.session = nil
        print("Voice recorder checks: passed")
    }
}
