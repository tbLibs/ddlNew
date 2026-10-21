import Foundation
import CoreGraphics

// Replace SDK transport/rendering only; execute production stream callbacks and container binding.
enum CallKind { case audio, video }
struct CallParticipant {
    let id: String
    var name: String
    var avatar: String
    var isLocal: Bool
    var isConnected: Bool
    var cameraEnabled: Bool
    var microphoneEnabled: Bool
    var stateText: String
}
@MainActor protocol CallMediaEngine: AnyObject {}
@MainActor class UIView {
    var frame = CGRect.zero
    var bounds: CGRect { CGRect(origin: .zero, size: frame.size) }
    var subviews: [UIView] = []
    weak var superview: UIView?
    func addSubview(_ view: UIView) { view.removeFromSuperview(); subviews.append(view); view.superview = self }
    func removeFromSuperview() { superview?.subviews.removeAll { $0 === self }; superview = nil }
    func setNeedsLayout() {}
    func layoutSubviews() {}
}
final class VideoTrack {}
@MainActor final class VideoView: UIView {
    enum LayoutMode { case fill }
    var layoutMode = LayoutMode.fill
    var track: VideoTrack?
}
@MainActor final class LiveKitCallEngine: CallMediaEngine {
    var tracks: [String: VideoTrack] = [:]
    func videoTrack(for id: String) -> VideoTrack? { tracks[id] }
}
@MainActor struct ZegoCanvas { let view: UIView }
@MainActor final class ZegoExpressEngine {
    var playing: [String: ZegoCanvas] = [:]
    var audioOnly = Set<String>()
    var stopped: [String] = []
    func startPlayingStream(_ stream: String, canvas: ZegoCanvas?) {
        playing[stream] = canvas
        if canvas == nil { audioOnly.insert(stream) } else { audioOnly.remove(stream) }
    }
    func stopPlayingStream(_ stream: String) { playing[stream] = nil; audioOnly.remove(stream); stopped.append(stream) }
    func startPreview(_ canvas: ZegoCanvas) {}
    func stopPreview() {}
}
enum ZegoUpdateType { case add, delete }
enum ZegoRemoteDeviceState { case open, mute, genericError }
struct ZegoUser { let userID: String; let userName: String }
struct ZegoStream {
    let streamID: String
    let user: ZegoUser
    init(_ streamID: String, userID: String = "peer") { self.streamID = streamID; user = ZegoUser(userID: userID, userName: userID) }
}

@main struct VideoChecks {
    @MainActor static func main() async {
        var failures = 0, count = 0
        func check(_ value: Bool, _ name: String) {
            count += 1; if !value { failures += 1 }
            print("\(value ? "PASS" : "FAIL") \(name)")
        }
        func drain() async { for _ in 0..<30 { await Task.yield() } }
        let engine = ZegoCallEngine(); engine.prepareForChecks()
        engine.onRoomStreamUpdate(.add, streamList: [.init("stream")], extendedData: nil, roomID: "room")
        await drain()
        check(engine.participants["peer"]?.cameraEnabled == true, "video stream enables canvas without waiting for camera callback")
        let surface = CallVideoContainer()
        // Model the production tile's camera gate.
        if engine.participants["peer"]?.cameraEnabled == true { surface.bind(participantID: "peer", media: engine) }
        check(engine.engine?.playing["stream"] != nil, "remote stream receives a video canvas instead of audio-only playback")
        engine.onRemoteCameraStateUpdate(.mute, streamID: "stream"); await drain()
        check(engine.participants["peer"]?.cameraEnabled == false, "explicit remote camera off hides video")
        engine.onRemoteCameraStateUpdate(.open, streamID: "stream"); await drain()
        engine.onRoomStreamUpdate(.add, streamList: [.init("stream")], extendedData: nil, roomID: "room"); await drain()
        check(engine.participants["peer"]?.cameraEnabled == true, "duplicate stream notification preserves known open camera")
        engine.onRemoteCameraStateUpdate(.mute, streamID: "early-off"); await drain()
        engine.onRoomStreamUpdate(.add, streamList: [.init("early-off", userID: "off-peer")], extendedData: nil, roomID: "room"); await drain()
        check(engine.participants["off-peer"]?.cameraEnabled == false, "camera-off before stream mapping is retained")
        engine.onRoomStreamUpdate(.add, streamList: [.init("replacement")], extendedData: nil, roomID: "room"); await drain()
        engine.onRoomStreamUpdate(.delete, streamList: [.init("stream")], extendedData: nil, roomID: "room"); await drain()
        check(engine.remoteStreams["peer"] == "replacement" && engine.participants["peer"]?.cameraEnabled == true,
              "late deletion of old stream cannot hide replacement video")
        check(engine.engine?.stopped.contains("stream") == true && engine.engine?.playing["replacement"] != nil,
              "replacement stream releases old player and reuses current canvas")
        surface.clear()
        check(engine.engine?.audioOnly.contains("replacement") == true && engine.surfaces["peer"] == nil,
              "minimized surface releases canvas while keeping audio")
        surface.bind(participantID: "peer", media: engine)
        check(engine.engine?.playing["replacement"] != nil, "restoring surface reattaches remote video")
        engine.onRoomStreamUpdate(.delete, streamList: [.init("replacement")], extendedData: nil, roomID: "room"); await drain()
        check(engine.remoteStreams["peer"] == nil && engine.participants["peer"]?.cameraEnabled == false,
              "current stream deletion clears camera state")
        engine.onRoomStreamUpdate(.add, streamList: [.init("wrong-room")], extendedData: nil, roomID: "other"); await drain()
        check(engine.remoteStreams["peer"] == nil, "other-room stream cannot attach")
        let audio = ZegoCallEngine(); audio.prepareForChecks(video: false)
        audio.onRoomStreamUpdate(.add, streamList: [.init("audio")], extendedData: nil, roomID: "room"); await drain()
        audio.onRemoteCameraStateUpdate(.open, streamID: "audio"); await drain()
        check(audio.participants["peer"]?.cameraEnabled == false, "audio calls never expose camera")
        engine.onRoomStreamUpdate(.add, streamList: [.init("old-owner")], extendedData: nil, roomID: "room"); await drain()
        check(engine.remoteStreams["peer"] == nil, "previous engine callbacks cannot affect replacement call")

        let liveKit = LiveKitCallEngine(), first = VideoTrack(), second = VideoTrack()
        liveKit.tracks["peer"] = first
        surface.bind(participantID: "peer", media: liveKit)
        let renderer = surface.subviews.first as? VideoView
        check(renderer?.track === first, "LiveKit binds subscribed remote track")
        liveKit.tracks["peer"] = second
        surface.bind(participantID: "peer", media: liveKit)
        check(renderer?.track === second && surface.subviews.count == 1, "LiveKit rebinds replacement track without recreating renderer")
        liveKit.tracks["peer"] = nil
        surface.bind(participantID: "peer", media: liveKit)
        check(renderer?.track == nil, "LiveKit unsubscribe clears prior track")
        surface.clear()
        check(surface.subviews.isEmpty, "teardown removes video renderer")
        print("\(count - failures)/\(count) video checks passed")
        if failures > 0 { exit(1) }
    }
}
