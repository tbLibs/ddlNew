//
//  ChatPhotoBrowserPlayback.swift
//  ddlNew
//
//  Created by taobo on 2026/10/16.
//

import AVFoundation
import Combine

/// 播放器与三页文件窗口同寿命，视频间翻页只暂停；进入图片或退出时归还音频会话。
@MainActor final class ChatPhotoBrowserPlayback: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var preparedPlayers: [URL: AVPlayer] = [:]
    private var statusObserver: NSKeyValueObservation?
    private var ownsAudioSession = false

    /// 邻页提前创建暂停的播放器，挂载后可准备首帧，不启动声音。
    func prepare(file: URL) {
        guard preparedPlayers[file] == nil else { return }
        preparedPlayers[file] = AVPlayer(playerItem: AVPlayerItem(url: file))
    }

    func play(file: URL, onFailure: @escaping @MainActor () -> Void) throws {
        guard CallCoordinator.shared.session == nil else { throw ChatClientError.unavailable("通话中暂不能播放视频") }
        pause()
        if !ownsAudioSession {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
            ownsAudioSession = true
        }
        prepare(file: file)
        guard let player = preparedPlayers[file], let item = player.currentItem else { return }
        self.player = player
        // 邻页准备期间也可能失败，必须检查已经发生的状态。
        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self, weak item] _, _ in
            Task { @MainActor [weak self, weak item] in
                guard let self, let item, self.player?.currentItem === item, item.status == .failed else { return }
                self.pause(); onFailure()
            }
        }
        player.play()
    }

    /// 保留旧页的 AVPlayerItem 和最后一帧，滑动途中不退回封面或黑屏。
    func pause(releaseAudioSession: Bool = false) {
        statusObserver?.invalidate(); statusObserver = nil
        player?.pause(); player = nil
        if releaseAudioSession, ownsAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            ownsAudioSession = false
        }
    }

    func release(file: URL) {
        guard let released = preparedPlayers.removeValue(forKey: file) else { return }
        if player === released { pause() }
        released.pause(); released.replaceCurrentItem(with: nil)
    }

    func stop() {
        pause(releaseAudioSession: true)
        for file in Array(preparedPlayers.keys) { release(file: file) }
    }
}
