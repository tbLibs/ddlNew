//
//  LiveKitCallEngine.swift
//  ddlNew
//
//  Created by taobo on 2026/10/20.
//

import Foundation
import AVFoundation
import LiveKit
import Promises
import NoaChatCore

/// 每通电话使用独立 Room，避免旧房间断开回调影响新房间。
@MainActor final class LiveKitCallEngine: NSObject, CallMediaEngine, RoomDelegate {
    var onConnected: (() -> Void)?
    var onParticipants: (([CallParticipant]) -> Void)?
    var onFailure: ((String) -> Void)?
    var onReconnecting: ((Bool) -> Void)?
    var onTokenExpired: (() -> Void)?
    private(set) var room: Room?
    private var localID = ""
    private var kind: CallKind = .audio
    private var setup: Task<Void, Never>?
    private var active = false
    private var cameraDesired = false
    private var cameraRevision = 0
    private var cameraInFlight = false
    private var cameraCallbacks: [(Bool) -> Void] = []

    func connect(descriptor: CallRoomDescriptor, session: CallSession, configuration: CallConfiguration) {
        localID = session.context.userUID; kind = session.kind; active = true; cameraDesired = session.cameraEnabled && session.kind == .video
        setup = Task { [weak self] in
            await CallMediaTransition.pending?.value
            guard let self, self.active, !Task.isCancelled else { return }
            self.connectRoom(descriptor: descriptor, session: session)
        }
    }

    private func connectRoom(descriptor: CallRoomDescriptor, session: CallSession) {
        let options = LingIMCallOptionsManager.sharedManager()
        let room = Room(delegate: self, connectOptions: options.configConnectOptions(), roomOptions: options.configRoomOptions())
        self.room = room
        AudioManager.shared.preferSpeakerOutput = session.speakerEnabled
        room.connect(descriptor.endpoint, descriptor.token).then { [weak self, weak room] _ in
            Task { @MainActor in
                guard let self, let room, self.active, self.room === room, let local = room.localParticipant else { return }
                local.setMicrophone(enabled: session.microphoneEnabled).then { [weak self, weak room] _ in
                    Task { @MainActor in
                        guard let self, let room, self.active, self.room === room else { return }
                        if self.cameraDesired {
                            self.camera(true) { [weak self] success in
                                guard let self, self.active else { return }
                                if success { self.publishSnapshot(); self.onConnected?() }
                                else { self.onFailure?("无法开启通话摄像头") }
                            }
                        } else { self.publishSnapshot(); self.onConnected?() }
                    }
                }.catch { [weak self] _ in Task { @MainActor in if self?.active == true { self?.onFailure?("无法开启通话麦克风") } } }
            }
        }.catch { [weak self] _ in Task { @MainActor in if self?.active == true { self?.onFailure?("通话房间连接失败") } } }
    }

    func disconnect() {
        active = false; setup?.cancel(); setup = nil; cameraCallbacks.removeAll(); cameraInFlight = false
        guard let room else { return }
        self.room = nil; room.remove(delegate: self)
        CallMediaTransition.pending = Task {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                room.disconnect().then { continuation.resume() }.catch { _ in continuation.resume() }
            }
        }
    }
    func startPublishing() { /* LiveKit 在连接流程中等待本地轨道发布完成。 */ }
    func microphone(_ enabled: Bool, completion: @escaping (Bool) -> Void) {
        guard active, let room, let local = room.localParticipant else { completion(false); return }
        local.setMicrophone(enabled: enabled).then { [weak self, weak room] _ in Task { @MainActor in
            guard let self, let room, self.active, self.room === room else { return }; self.publishSnapshot(); completion(true)
        } }.catch { _ in Task { @MainActor in completion(false) } }
    }
    func camera(_ enabled: Bool, completion: @escaping (Bool) -> Void) {
        cameraDesired = enabled && kind == .video; cameraRevision += 1
        guard active, room?.localParticipant != nil else { completion(false); return }
        cameraCallbacks.append(completion)
        applyCameraIfNeeded()
    }
    private func applyCameraIfNeeded() {
        guard !cameraInFlight, active, let room, let local = room.localParticipant else { return }
        cameraInFlight = true
        let revision = cameraRevision
        local.setCamera(enabled: cameraDesired).then { [weak self, weak room] _ in Task { @MainActor in
            guard let self, let room, self.active, self.room === room else { return }
            self.cameraInFlight = false
            if self.cameraRevision != revision { self.applyCameraIfNeeded(); return }
            self.publishSnapshot()
            let callbacks = self.cameraCallbacks; self.cameraCallbacks.removeAll()
            callbacks.forEach { $0(true) }
        } }.catch { [weak self] _ in Task { @MainActor in
            guard let self, self.active else { return }
            self.cameraInFlight = false
            let callbacks = self.cameraCallbacks; self.cameraCallbacks.removeAll()
            callbacks.forEach { $0(false) }
        } }
    }
    func speaker(_ enabled: Bool) throws {
        AudioManager.shared.preferSpeakerOutput = enabled
        try AVAudioSession.sharedInstance().overrideOutputAudioPort(enabled ? .speaker : .none)
    }
    func switchCamera(completion: @escaping (Bool) -> Void) {
        guard let track = room?.localParticipant?.videoTracks.first?.track as? LocalVideoTrack, let capturer = track.capturer as? CameraCapturer else { completion(false); return }
        capturer.switchCameraPosition().then { _ in Task { @MainActor in completion(true) } }.catch { _ in Task { @MainActor in completion(false) } }
    }
    func renewToken(_ token: String) { /* LiveKit 信令自动维护房间凭据。 */ }

    func videoTrack(for id: String) -> VideoTrack? {
        guard active, let room else { return nil }
        let participant: Participant? = id == localID ? room.localParticipant : room.remoteParticipants.values.first { $0.identity == id }
        return participant?.videoTracks.first(where: { !$0.muted })?.track as? VideoTrack
    }
    private func publishSnapshot() {
        guard active, let room else { return }
        var participants: [Participant] = Array(room.remoteParticipants.values)
        if let local = room.localParticipant { participants.insert(local, at: 0) }
        onParticipants?(participants.map { person in
            CallParticipant(id: person.identity, name: person.name.isEmpty ? person.identity : person.name, avatar: "", isLocal: person.identity == localID, isConnected: true,
                            cameraEnabled: person.videoTracks.contains { !$0.muted && $0.track != nil }, microphoneEnabled: person.audioTracks.contains { !$0.muted && $0.track != nil }, stateText: "已加入")
        })
    }
    nonisolated private func refresh(_ room: Room) { Task { @MainActor [weak self] in guard let self, self.room === room else { return }; self.publishSnapshot() } }
    nonisolated func room(_ room: Room, didUpdate connectionState: ConnectionState, oldValue: ConnectionState) {
        guard connectionState == .reconnecting else { return }
        Task { @MainActor [weak self] in guard let self, self.active, self.room === room else { return }; self.onReconnecting?(true) }
    }
    nonisolated func room(_ room: Room, didConnect isReconnect: Bool) {
        guard isReconnect else { return }
        Task { @MainActor [weak self] in guard let self, self.active, self.room === room else { return }; self.onReconnecting?(false) }
    }
    nonisolated func room(_ room: Room, didDisconnect error: Error?) {
        Task { @MainActor [weak self] in guard let self, self.active, self.room === room else { return }; self.onFailure?("通话连接已断开") }
    }
    nonisolated func room(_ room: Room, participantDidJoin participant: RemoteParticipant) { refresh(room) }
    nonisolated func room(_ room: Room, participantDidLeave participant: RemoteParticipant) {
        let id = participant.identity
        Task { @MainActor [weak self] in guard let self, self.active, self.room === room else { return }; self.onParticipants?([CallParticipant(id: id, name: id, avatar: "", isLocal: false, isConnected: false, cameraEnabled: false, microphoneEnabled: false, stateText: "已离开")]); self.publishSnapshot() }
    }
    nonisolated func room(_ room: Room, participant: RemoteParticipant, didSubscribe publication: RemoteTrackPublication, track: Track) { refresh(room) }
    nonisolated func room(_ room: Room, participant: RemoteParticipant, didUnsubscribe publication: RemoteTrackPublication, track: Track) { refresh(room) }
    nonisolated func room(_ room: Room, localParticipant: LocalParticipant, didPublish publication: LocalTrackPublication) { refresh(room) }
    nonisolated func room(_ room: Room, participant: Participant, didUpdate publication: TrackPublication, muted: Bool) { refresh(room) }
}
