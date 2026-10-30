//
//  ChatVoiceRecordButton.swift
//  ddlNew
//
//  Created by taobo on 2026/10/19.
//

import SwiftUI
import UIKit

/// UIControl跟踪整条按住区域；相对按下位置上滑取消，避免边缘轻微抖动误取消。
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
        view.accessibilityLabel = holding ? "结束并发送语音" : "按住说话"
        view.accessibilityHint = "按住说话，松开发送，上滑取消。旁白模式下双击开始，再次双击发送，可使用取消录音操作。"
        view.accessibilityCustomActions = holding ? [UIAccessibilityCustomAction(name: "取消录音", target: view, selector: #selector(VoiceControl.cancelAccessibleRecording))] : []
    }

    final class VoiceControl: UIControl {
        var holding = false
        var onBegin: (() -> Void)?
        var onMove: ((Bool) -> Void)?
        var onEnd: ((Bool) -> Void)?
        var onCancel: (() -> Void)?
        private var touchOrigin: CGPoint?

        private func isInsideSendArea(_ touch: UITouch) -> Bool {
            guard let touchOrigin else { return false }
            return touch.location(in: self).y > touchOrigin.y - 60
        }

        override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            guard isEnabled else { return false }
            touchOrigin = touch.location(in: self)
            onBegin?(); return true
        }
        override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            onMove?(isInsideSendArea(touch)); return true
        }
        override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
            let inside = touch.map(isInsideSendArea) ?? false
            touchOrigin = nil
            onEnd?(inside)
        }
        override func cancelTracking(with event: UIEvent?) { touchOrigin = nil; onCancel?() }
        override func accessibilityActivate() -> Bool {
            guard isEnabled else { return false }
            if holding { onEnd?(true) } else { onBegin?() }; return true
        }
        @objc func cancelAccessibleRecording() -> Bool { onCancel?(); return true }
    }
}
