//
//  ChatVoiceRecordButton.swift
//  ddlNew
//
//  Created by taobo on 2026/10/19.
//

import SwiftUI
import UIKit

/// UIControl保留旧端touchDown/dragExit/dragEnter/upOutside和系统取消语义。
struct ChatVoiceRecordButton: UIViewRepresentable {
    let holding: Bool
    let onBegin: () -> Void
    let onMove: (Bool) -> Void
    let onEnd: (Bool) -> Void
    let onCancel: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    func makeUIView(context: Context) -> VoiceControl { VoiceControl() }

    func updateUIView(_ view: VoiceControl, context: Context) {
        view.isEnabled = isEnabled; view.holding = holding
        view.onBegin = onBegin; view.onMove = onMove; view.onEnd = onEnd; view.onCancel = onCancel
        view.isAccessibilityElement = true; view.accessibilityTraits = .button
        view.accessibilityLabel = holding ? "结束并发送语音" : "开始录音"
        view.accessibilityHint = "按住说话，松开发送，移出按钮松开取消。旁白模式下双击开始，再次双击发送。"
        view.accessibilityCustomActions = holding ? [UIAccessibilityCustomAction(name: "取消录音", target: view, selector: #selector(VoiceControl.cancelAccessibleRecording))] : []
    }

    final class VoiceControl: UIControl {
        var holding = false
        var onBegin: (() -> Void)?
        var onMove: ((Bool) -> Void)?
        var onEnd: ((Bool) -> Void)?
        var onCancel: (() -> Void)?

        override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            guard isEnabled else { return false }
            onBegin?(); return true
        }
        override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            onMove?(bounds.contains(touch.location(in: self))); return true
        }
        override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
            onEnd?(touch.map { bounds.contains($0.location(in: self)) } ?? false)
        }
        override func cancelTracking(with event: UIEvent?) { onCancel?() }
        override func accessibilityActivate() -> Bool {
            guard isEnabled else { return false }
            if holding { onEnd?(true) } else { onBegin?() }; return true
        }
        @objc func cancelAccessibleRecording() -> Bool { onCancel?(); return true }
    }
}
