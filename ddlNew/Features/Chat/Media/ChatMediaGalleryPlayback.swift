//
//  ChatMediaGalleryPlayback.swift
//  ddlNew
//
//  Created by taobo on 2026/10/16.
//

import AVFoundation
import Combine

@MainActor final class ChatMediaGalleryPlayback: ObservableObject {
    @Published private(set) var player: AVPlayer?
    private var statusObserver: NSKeyValueObservation?
    private var ownsAudioSession = false

    /// 仅已解包的当前页视频启用音频会话，AVPlayer 就绪后自动播放。
    func play(file: URL, onFailure: @escaping @MainActor () -> Void) throws {
        stop()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .moviePlayback)
        try session.setActive(true)
        ownsAudioSession = true
        let item = AVPlayerItem(url: file)
        let player = AVPlayer(playerItem: item)
        self.player = player
        statusObserver = item.observe(\.status, options: [.new]) { [weak self, weak item] _, _ in
            Task { @MainActor [weak self, weak item] in
                guard let self, let item, self.player?.currentItem === item, item.status == .failed else { return }
                self.stop(); onFailure()
            }
        }
        player.play()
    }

    /// 翻页、后台、原条删除及 AUTH 清理同步停止旧播放器并归还系统音频。
    func stop() {
        statusObserver?.invalidate(); statusObserver = nil
        player?.pause(); player?.replaceCurrentItem(with: nil); player = nil
        if ownsAudioSession { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
        ownsAudioSession = false
    }
}
