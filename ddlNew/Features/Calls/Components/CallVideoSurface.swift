//
//  CallVideoSurface.swift
//  ddlNew
//
//  Created by taobo on 2026/10/20.
//

import SwiftUI
import LiveKit

/// 页面只绑定当前引擎的真实视频轨道/画布，不承担入房和音频生命周期。
struct CallVideoSurface: UIViewRepresentable {
    let participantID: String
    // 订阅/重订阅可只替换轨道对象；必须观察 videoRevision 等发布变化才能重新绑定。
    @ObservedObject var coordinator: CallCoordinator

    func makeUIView(context: Context) -> CallVideoContainer { CallVideoContainer() }
    func updateUIView(_ view: CallVideoContainer, context: Context) {
        view.bind(participantID: participantID, media: coordinator.media)
    }
    static func dismantleUIView(_ view: CallVideoContainer, coordinator: ()) { view.clear() }
}

final class CallVideoContainer: UIView {
    private var participantID = ""
    private weak var media: CallMediaEngine?
    private var video: VideoView?
    private var canvas: UIView?

    func bind(participantID: String, media: CallMediaEngine?) {
        if self.participantID != participantID || self.media !== media { clear(); self.participantID = participantID; self.media = media }
        if let engine = media as? LiveKitCallEngine {
            if video == nil { let view = VideoView(); view.layoutMode = .fill; video = view; addSubview(view) }
            video?.track = engine.videoTrack(for: participantID)
        } else if let engine = media as? ZegoCallEngine {
            if canvas == nil { let view = UIView(); canvas = view; addSubview(view) }
            if let canvas { engine.attach(canvas, participantID: participantID) }
        }
        setNeedsLayout()
    }
    override func layoutSubviews() { super.layoutSubviews(); video?.frame = bounds; canvas?.frame = bounds }
    func clear() {
        video?.track = nil; video?.removeFromSuperview(); video = nil
        if let canvas { (media as? ZegoCallEngine)?.detach(canvas, participantID: participantID); canvas.removeFromSuperview() }
        canvas = nil; media = nil; participantID = ""
    }
}
