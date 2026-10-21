import Foundation

@MainActor final class CallCoordinator {
    static let shared = CallCoordinator()
    var session: UUID?
}
enum ChatClientError: Error { case unavailable(String) }

final class AVPlayerItem: NSObject, @unchecked Sendable {
    @objc enum Status: Int { case unknown, readyToPlay, failed }
    @objc dynamic var status = Status.unknown
    init(url: URL) { super.init() }
}
final class AVPlayer {
    var currentItem: AVPlayerItem?
    var rate: Float = 0
    init(playerItem: AVPlayerItem) { currentItem = playerItem }
    func play() { rate = 1 }
    func pause() { rate = 0 }
    func replaceCurrentItem(with item: AVPlayerItem?) { currentItem = item }
}
final class AVAudioSession {
    enum Category { case playback }
    enum Mode { case moviePlayback }
    struct SetActiveOptions: OptionSet {
        let rawValue: Int
        static let notifyOthersOnDeactivation = Self(rawValue: 1)
    }
    static let shared = AVAudioSession()
    var activations = 0
    var deactivations = 0
    static func sharedInstance() -> AVAudioSession { shared }
    func setCategory(_ category: Category, mode: Mode) throws {}
    func setActive(_ active: Bool, options: SetActiveOptions = []) throws {
        if active { activations += 1 } else { deactivations += 1 }
    }
}

@main struct GalleryPlaybackChecks {
    @MainActor static func main() async throws {
        var failures = 0
        var checks = 0
        func check(_ value: Bool, _ title: String) {
            checks += 1
            print("\(value ? "PASS" : "FAIL") \(title)")
            if !value { failures += 1 }
        }
        let playback = ChatPhotoBrowserPlayback()
        let firstURL = URL(fileURLWithPath: "/tmp/first.mp4")
        let secondURL = URL(fileURLWithPath: "/tmp/second.mp4")
        playback.prepare(file: secondURL)
        let preparedSecond = playback.preparedPlayers[secondURL]!
        check(preparedSecond.rate == 0 && playback.player == nil && AVAudioSession.shared.activations == 0,
              "邻页准备不播放也不抢占系统音频")
        try playback.play(file: firstURL, onFailure: {})
        let first = playback.player!
        try playback.play(file: secondURL, onFailure: {})
        check(playback.player === preparedSecond, "切换视频使用已准备的播放器")
        check(first.rate == 0 && first.currentItem != nil, "视频翻页暂停旧页但不清空画面")
        check(AVAudioSession.shared.activations == 1 && AVAudioSession.shared.deactivations == 0, "连续视频不反复启停系统音频会话")
        try playback.play(file: firstURL, onFailure: {})
        check(playback.player === first, "返回相邻视频复用原播放器")
        playback.release(file: secondURL)
        check(preparedSecond.currentItem == nil && playback.player === first, "释放窗口外视频不影响当前播放")
        playback.stop()
        check(first.currentItem == nil && playback.player == nil && AVAudioSession.shared.deactivations == 1, "关闭画廊释放播放器及音频会话")
        playback.prepare(file: firstURL)
        playback.preparedPlayers[firstURL]?.currentItem?.status = .failed
        var failed = false
        try playback.play(file: firstURL) { failed = true }
        let deadline = Date().addingTimeInterval(3)
        while !failed && Date() < deadline { await Task.yield() }
        check(failed && playback.player == nil, "预加载期间已失败的视频选中后仍反馈错误并停播")
        playback.stop()
        var staleFailure = false
        try playback.play(file: firstURL) { staleFailure = true }
        playback.player?.currentItem?.status = .failed
        try playback.play(file: secondURL, onFailure: {})
        for _ in 0..<20 { await Task.yield() }
        check(!staleFailure && playback.player === playback.preparedPlayers[secondURL], "旧页迟到失败不能停止新页视频")
        let beforePhoto = AVAudioSession.shared.deactivations
        let retainedVideo = playback.player!
        playback.pause(releaseAudioSession: true)
        check(retainedVideo.currentItem != nil && retainedVideo.rate == 0 && AVAudioSession.shared.deactivations == beforePhoto + 1,
              "进入图片归还音频会话但保留邻页视频画面")
        playback.stop()
        let activations = AVAudioSession.shared.activations
        CallCoordinator.shared.session = UUID()
        do { try playback.play(file: firstURL, onFailure: {}); check(false, "通话中不能启动视频") }
        catch { check(playback.player == nil && AVAudioSession.shared.activations == activations, "通话中视频不能接管音频会话") }
        CallCoordinator.shared.session = nil
        print("Gallery playback checks: \(checks - failures)/\(checks)")
        if failures > 0 { exit(1) }
    }
}
