import Foundation

@MainActor final class CallCoordinator {
    static let shared = CallCoordinator()
    var session: UUID?
}

let AVAudioSessionInterruptionTypeKey = "type"
enum ChatClientError: Error { case unavailable(String) }
@MainActor final class AVAudioPlayer {
    weak var delegate: ProductionVoiceAudio?
    static var canPlay = false
    init(contentsOf: URL) throws {}
    func play() -> Bool { Self.canPlay }
    func stop() {}
}
@MainActor final class AVAudioSession {
    enum Category { case playAndRecord, playback }
    enum Mode { case voiceChat, spokenAudio }
    enum Port { case none }
    enum InterruptionType: UInt { case began = 1 }
    struct Options: OptionSet {
        let rawValue: Int
        static let allowBluetoothHFP = Options(rawValue: 1), notifyOthersOnDeactivation = Options(rawValue: 2)
    }
    static let interruptionNotification = Notification.Name("OfflineVoiceInterruption")
    static let shared = AVAudioSession()
    var active = false
    static func sharedInstance() -> AVAudioSession { shared }
    func setCategory(_ category: Category, mode: Mode, options: Options = []) throws {}
    func overrideOutputAudioPort(_ port: Port) throws {}
    func setActive(_ active: Bool, options: Options = []) throws { self.active = active }
}
@main struct VoiceAudioChecks {
    @MainActor static func main() async {
        let voice = ProductionVoiceAudio()
        do { _ = try voice.playVoice() } catch {}
        precondition(!voice.playing && !AVAudioSession.shared.active, "play返回false时必须归还已激活的音频会话")
        AVAudioPlayer.canPlay = true
        let success = try? voice.playVoice()
        precondition(success == true && AVAudioSession.shared.active)
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil,
                                        userInfo: [AVAudioSessionInterruptionTypeKey: NSNumber(value: 1)])
        while voice.playing { await Task.yield() }
        precondition(!AVAudioSession.shared.active, "系统中断停止播放后须归还会话")
        CallCoordinator.shared.session = UUID()
        do { _ = try voice.playVoice(); fatalError("通话中不能播放语音") } catch {}
        precondition(!voice.playing && !AVAudioSession.shared.active, "语音不能接管通话的音频会话")
        print("Voice audio failure and interruption checks: passed")
    }
}
