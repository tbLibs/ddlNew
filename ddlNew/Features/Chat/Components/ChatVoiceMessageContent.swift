//
//  ChatVoiceMessageContent.swift
//  ddlNew
//
//  Created by taobo on 2026/10/19.
//

import SwiftUI
import UIAdapter

/// 对齐旧端左右镜像的播放图标、波形和秒数；进度只刷新正在播放的语音行。
struct ChatVoiceMessageContent: View {
    let message: ChatMessageRecord
    let own: Bool
    @ObservedObject var playback: ChatVoicePlayback
    @ObservedObject private var preview: ChatMediaPreviewStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(message: ChatMessageRecord, own: Bool, playback: ChatVoicePlayback) {
        self.message = message; self.own = own; self.playback = playback; self.preview = playback.preview
    }

    private var playing: Bool { playback.messageID == message.id && preview.playing }
    private var duration: Double { message.duration.isFinite ? min(86_400, max(0, message.duration)) : 0 }
    private var foreground: Color { own ? MessagingTheme.onPrimaryAction : MessagingTheme.accent }
    private var width: CGFloat { CGFloat(90 + (duration <= 1 ? 0 : min(60, duration) / 60 * 100)).zoom() }

    var body: some View {
        HStack(spacing: 10.zoom()) {
            if own { seconds }
            if !own { playIcon }
            if playing && !reduceMotion {
                TimelineView(.animation(minimumInterval: 0.1)) { _ in waveform(progress: preview.voiceProgress) }
            } else { waveform(progress: 0) }
            if own { playIcon }
            if !own { seconds }
        }
        .frame(width: width, height: max(24, 24.zoom()))
        .foregroundStyle(foreground)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("语音消息，\(Int(duration.rounded(.up)))秒，" + (playing ? "点击停止播放" : "点击播放"))
    }

    private var seconds: some View {
        Text("\(Int(duration.rounded(.up)))s").font(.system(size: 16.zoom()))
            .monospacedDigit().frame(width: 30.zoom())
    }

    @ViewBuilder private var playIcon: some View {
        if playback.messageID == message.id && preview.loading {
            ProgressView().tint(foreground).frame(width: 22.zoom(), height: 22.zoom())
        } else {
            Image("icon_voice_msg_\(playing ? "play" : "stop")_\(own ? "right" : "left")")
                .resizable().renderingMode(.template).frame(width: 22.zoom(), height: 22.zoom())
        }
    }

    /// 沿用旧端固定幅度和2.5点圆柱，着色进度读取真实播放器时间。
    private func waveform(progress: Double) -> some View {
        Canvas { context, size in
            let heights: [CGFloat] = [0.25, 1, 0.5, 0.7, 0.66, 0.58, 0.85, 0.77, 0.45, 0.45, 0.45, 0.45, 0.45, 0.45, 0.45, 0.9, 0.8, 0.85, 0.75, 0.82, 0.82, 0.82, 0.3, 0.4, 0.55, 0.2]
            var x = 3.zoom(); var index = 0
            while x + 2.5.zoom() <= size.width {
                let height = 16.zoom() * heights[index % heights.count]
                let rect = CGRect(x: x, y: size.height - 3.zoom() - height, width: 2.5.zoom(), height: height)
                let path = Path(roundedRect: rect, cornerRadius: 1.25.zoom())
                context.fill(path, with: .color(x / size.width <= progress ? foreground : own ? foreground.opacity(0.35) : MessagingTheme.secondaryText.opacity(0.4)))
                x += 6.5.zoom(); index += 1
            }
        }.frame(height: 22.zoom()).accessibilityHidden(true)
    }
}
