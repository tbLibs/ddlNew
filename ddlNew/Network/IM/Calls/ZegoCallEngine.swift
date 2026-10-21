//
//  ZegoCallEngine.swift
//  ddlNew
//
//  Created by taobo on 2026/10/20.
//

import Foundation
import UIKit
import ZegoExpressEngine

/// Zego 是进程单例；等待旧引擎销毁后才能建新引擎，回调再核对实例所有权。
@MainActor final class ZegoCallEngine: NSObject, CallMediaEngine, ZegoEventHandler {
    private static weak var owner: ZegoCallEngine?
    var onConnected: (() -> Void)?
    var onParticipants: (([CallParticipant]) -> Void)?
    var onFailure: ((String) -> Void)?
    var onReconnecting: ((Bool) -> Void)?
    var onTokenExpired: (() -> Void)?
    private var engine: ZegoExpressEngine?
    private var active = false
    private var setup: Task<Void, Never>?
    private var roomID = ""
    private var localID = ""
    private var kind: CallKind = .audio
    private var cameraEnabled = false
    private var microphoneEnabled = true
    private var front = true
    private var publishing = false
    private var remoteStreams: [String: String] = [:]
    private var remoteCameraStates: [String: Bool] = [:]
    private var participants: [String: CallParticipant] = [:]
    private var surfaces: [String: UIView] = [:]

    func connect(descriptor: CallRoomDescriptor, session: CallSession, configuration: CallConfiguration) {
        active = true; roomID = descriptor.roomName; localID = session.context.userUID; kind = session.kind
        cameraEnabled = session.cameraEnabled && kind == .video; microphoneEnabled = session.microphoneEnabled
        setup = Task { [weak self] in
            await CallMediaTransition.pending?.value
            guard let self, self.active, !Task.isCancelled else { return }
            let profile = ZegoEngineProfile()
            profile.appID = configuration.zegoAppID; profile.scenario = .default
            let engine = ZegoExpressEngine.createEngine(with: profile, eventHandler: self)
            self.engine = engine; Self.owner = self
            engine.enableCamera(self.cameraEnabled)
            engine.muteMicrophone(!self.microphoneEnabled)
            engine.setAudioRouteToSpeaker(session.speakerEnabled)
            let config = ZegoRoomConfig(); config.isUserStatusNotify = true; config.token = descriptor.token
            let name = session.participants.first(where: \.isLocal)?.name ?? session.context.userUID
            let user = ZegoUser(userID: self.localID, userName: name.isEmpty ? self.localID : name)
            engine.loginRoom(self.roomID, user: user, config: config) { [weak self] code, _ in
                Task { @MainActor in
                    guard let self, self.active, Self.owner === self else { return }
                    if code == 0 { self.onConnected?() }
                    else { self.onFailure?("通话房间登录失败，请重试") }
                }
            }
        }
    }

    func startPublishing() {
        guard active, Self.owner === self, !publishing, let engine else { return }
        publishing = true
        let config = ZegoPublisherConfig(); config.streamCensorshipMode = kind == .audio ? .audio : .audioAndVideo
        engine.startPublishingStream(localID, config: config, channel: .main)
        participants[localID] = CallParticipant(id: localID, name: "我", avatar: "", isLocal: true, isConnected: true, cameraEnabled: cameraEnabled, microphoneEnabled: microphoneEnabled, stateText: "已加入")
        if let surface = surfaces[localID], cameraEnabled { engine.startPreview(ZegoCanvas(view: surface)) }
        publishSnapshot()
    }

    func disconnect() {
        active = false; setup?.cancel(); setup = nil
        guard Self.owner === self, let engine else { surfaces.removeAll(); return }
        Self.owner = nil; self.engine = nil
        engine.setEventHandler(nil)
        engine.enableCamera(false); engine.muteMicrophone(true); engine.stopPreview(); engine.stopPublishingStream()
        for stream in remoteStreams.values { engine.stopPlayingStream(stream) }
        remoteStreams.removeAll(); remoteCameraStates.removeAll(); surfaces.removeAll(); participants.removeAll()
        engine.logoutRoom(roomID)
        CallMediaTransition.pending = Task {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                ZegoExpressEngine.destroy { continuation.resume() }
            }
        }
    }
    func microphone(_ enabled: Bool, completion: @escaping (Bool) -> Void) {
        guard active, let engine, Self.owner === self else { completion(false); return }
        microphoneEnabled = enabled; engine.muteMicrophone(!enabled); participants[localID]?.microphoneEnabled = enabled; publishSnapshot(); completion(true)
    }
    func camera(_ enabled: Bool, completion: @escaping (Bool) -> Void) {
        cameraEnabled = enabled && kind == .video
        guard active, let engine, Self.owner === self else { completion(false); return }
        engine.enableCamera(cameraEnabled); engine.mutePublishStreamVideo(!cameraEnabled)
        if cameraEnabled, publishing, let view = surfaces[localID] { engine.startPreview(ZegoCanvas(view: view)) }
        else { engine.stopPreview() }
        participants[localID]?.cameraEnabled = cameraEnabled; publishSnapshot(); completion(true)
    }
    func speaker(_ enabled: Bool) throws {
        guard active, let engine, Self.owner === self else { throw CallError.unavailable("通话未连接") }
        engine.setAudioRouteToSpeaker(enabled)
    }
    func switchCamera(completion: @escaping (Bool) -> Void) { guard active, kind == .video, Self.owner === self else { completion(false); return }; front.toggle(); engine?.useFrontCamera(front); completion(true) }
    func renewToken(_ token: String) { guard active, Self.owner === self else { return }; engine?.renewToken(token, roomID: roomID) }

    /// 同一参与者的渲染容器移动时更新画布；离屏只移除画面，不停止语音订阅。
    func attach(_ view: UIView, participantID: String) {
        guard active, surfaces[participantID] !== view else { return }
        surfaces[participantID] = view
        guard let engine, Self.owner === self else { return }
        if participantID == localID {
            if cameraEnabled && publishing { engine.startPreview(ZegoCanvas(view: view)) }
        } else if let stream = remoteStreams[participantID] {
            engine.startPlayingStream(stream, canvas: ZegoCanvas(view: view))
        }
    }
    func detach(_ view: UIView, participantID: String) {
        guard surfaces[participantID] === view else { return }
        surfaces[participantID] = nil
        guard active, let engine, Self.owner === self else { return }
        if participantID == localID { engine.stopPreview() }
        else if let stream = remoteStreams[participantID] { engine.startPlayingStream(stream, canvas: nil) }
    }
    private func publishSnapshot() { if active { onParticipants?(Array(participants.values)) } }

    nonisolated func onRoomStreamUpdate(_ updateType: ZegoUpdateType, streamList: [ZegoStream], extendedData: [AnyHashable: Any]?, roomID: String) {
        let values = streamList.map { ($0.streamID, $0.user.userID, $0.user.userName) }
        let add = updateType == .add
        Task { @MainActor [weak self] in
            guard let self, self.active, Self.owner === self, self.roomID == roomID, let engine = self.engine else { return }
            for (stream, id, name) in values {
                if add {
                    if let previous = self.remoteStreams[id], previous != stream {
                        engine.stopPlayingStream(previous)
                        self.remoteCameraStates[previous] = nil
                    }
                    self.remoteStreams[id] = stream
                    // 与旧端一致：视频流到达即建立画布，设备状态回调只修正开关。
                    // 部分推流方式没有摄像头状态回调，不能以该回调作为显示视频的前置条件。
                    let cameraEnabled = self.kind == .video && (self.remoteCameraStates[stream] ?? true)
                    self.participants[id] = CallParticipant(id: id, name: name, avatar: "", isLocal: false, isConnected: true, cameraEnabled: cameraEnabled, microphoneEnabled: true, stateText: "已加入")
                    engine.startPlayingStream(stream, canvas: self.surfaces[id].map(ZegoCanvas.init(view:)))
                } else {
                    engine.stopPlayingStream(stream); self.remoteCameraStates[stream] = nil
                    guard self.remoteStreams[id] == stream else { continue }
                    self.remoteStreams[id] = nil
                    self.participants[id]?.isConnected = false; self.participants[id]?.cameraEnabled = false; self.participants[id]?.stateText = "已离开"
                }
            }
            self.publishSnapshot()
        }
    }
    nonisolated func onRemoteCameraStateUpdate(_ state: ZegoRemoteDeviceState, streamID: String) {
        let enabled = state == .open
        Task { @MainActor [weak self] in
            guard let self, self.active, Self.owner === self else { return }
            // 状态可能先于成员/流映射到达，保留显式关闭，避免流新增时误打开。
            self.remoteCameraStates[streamID] = enabled
            guard let id = self.remoteStreams.first(where: { $0.value == streamID })?.key else { return }
            self.participants[id]?.cameraEnabled = enabled && self.kind == .video; self.publishSnapshot()
        }
    }
    nonisolated func onRemoteMicStateUpdate(_ state: ZegoRemoteDeviceState, streamID: String) {
        let enabled = state == .open
        Task { @MainActor [weak self] in
            guard let self, self.active, Self.owner === self, let id = self.remoteStreams.first(where: { $0.value == streamID })?.key else { return }
            self.participants[id]?.microphoneEnabled = enabled; self.publishSnapshot()
        }
    }
    nonisolated func onRoomStateChanged(_ reason: ZegoRoomStateChangedReason, errorCode: Int32, extendedData: [AnyHashable: Any], roomID: String) {
        Task { @MainActor [weak self] in
            guard let self, self.active, Self.owner === self, self.roomID == roomID else { return }
            if reason == .reconnecting { self.onReconnecting?(true) }
            else if reason == .reconnected { self.onReconnecting?(false) }
            else if [.loginFailed, .reconnectFailed, .kickOut].contains(reason) { self.onFailure?("通话连接已中断") }
        }
    }
    nonisolated func onRoomTokenWillExpire(_ remainTimeInSecond: Int32, roomID: String) {
        Task { @MainActor [weak self] in guard let self, self.active, Self.owner === self, self.roomID == roomID else { return }; self.onTokenExpired?() }
    }
    nonisolated func onPublisherStateUpdate(_ state: ZegoPublisherState, errorCode: Int32, extendedData: [AnyHashable: Any]?, streamID: String) {
        guard state == .noPublish, errorCode != 0 else { return }
        Task { @MainActor [weak self] in guard let self, self.active, Self.owner === self, self.localID == streamID else { return }; self.onFailure?("通话音视频发送失败") }
    }
}
