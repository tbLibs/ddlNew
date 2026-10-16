//
//  ChatGameStickerBubble.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import SwiftUI
import UIAdapter

/// 只有游戏行订阅可见资格，普通文字跨越视口边缘不再触发整页刷新。
struct ChatVisibleGameStickerBubble: View {
    let message: ChatMessageRecord
    let onComplete: (ChatMessageRecord) -> Void
    let visibility: ChatScrollGeometry
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    var body: some View {
        ChatGameStickerBubble(message: message, onComplete: onComplete, canAnimate: isVisible && scenePhase == .active)
            .onReceive(visibility.updates(for: message.id)) { isVisible = $0 }
    }
}

/// 旧图片动画只演示投掷过程，最终图片始终使用消息中已确定的结果。
struct ChatGameStickerBubble: View {
    let message: ChatMessageRecord
    let onComplete: (ChatMessageRecord) -> Void
    let canAnimate: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frame: Int?

    private var version: String {
        "\(message.id)|\(message.gameType)|\(message.text)|\(message.timestamp)|\(message.state.rawValue)|\(reduceMotion)|\(canAnimate)"
    }

    var body: some View {
        if let game = ChatGameSticker(rawValue: message.gameType), let image = game.resultImage(message.text) {
            Image(frame.map { game.frames[$0 % game.frames.count] } ?? image)
                .resizable().scaledToFit().frame(width: 84.zoom(), height: 84.zoom())
                .accessibilityLabel(game.title + "，" + game.resultName(message.text))
                .task(id: version) {
                    frame = nil
                    guard canAnimate, !message.gameAnimationPlayed else { return }
                    if !reduceMotion {
                        let steps = Int((3 / game.frameInterval).rounded())
                        for index in 0..<steps {
                            guard !Task.isCancelled else { return }
                            frame = index
                            do { try await Task.sleep(nanoseconds: UInt64(game.frameInterval * 1_000_000_000)) }
                            catch { return }
                        }
                    }
                    guard !Task.isCancelled else { return }
                    frame = nil; onComplete(message)
                }
        } else { Text(message.displayText) }
    }
}
