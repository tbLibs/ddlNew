//
//  CallCoordinator.swift
//  ddlNew
//
//  Created by taobo on 2026/10/20.
//

import Foundation
import Combine

/// 唯一通话所有者。认证轮次、本次操作和房间 ID 三层隔离，页面消失不释放媒体。
@MainActor final class CallCoordinator: ObservableObject {
    static let shared = CallCoordinator()
    @Published private(set) var session: CallSession?
    @Published var isPresented = false
    @Published var selection: CallSelectionRequest?
    @Published var errorMessage: String?
    @Published private(set) var busy = false
    @Published private(set) var groupRooms: [String: CallGroupRoom] = [:]
    @Published private(set) var videoRevision = 0
    private(set) var media: CallMediaEngine?
    private var identity: (user: String, tenant: String, session: UUID)?
    private var operation = UUID()
    private var configurationObserver: AnyCancellable?
    private var activeConfiguration: CallConfiguration?
    private var descriptor: CallRoomDescriptor?
    private var endedRooms = Set<String>()
    private var pendingSignals: [CallSignal] = []
    private var pendingCreation: (stamp: UUID, context: ChatContext, provider: CallProvider)?
    private var roomContexts: [String: ChatContext] = [:]
    private var refreshIDs: [String: UUID] = [:]
    private var refreshTasks: [String: Task<Void, Never>] = [:]
    private var heartbeat: Task<Void, Never>?
    private var connectDeadline: Task<Void, Never>?
    private var actionTask: Task<Void, Never>?
    private var foreground = true
    private var microphoneChanging = false
    private var cameraChanging = false
    private let configuration: CallConfigurationStore
    private let resources: CallSystemResources
    private let permission: @MainActor (CallKind) async throws -> Void
    private let prepareAudio: @MainActor () -> Void
    private let mediaFactory: @MainActor (CallProvider) -> CallMediaEngine
    private var injectedClient: CallClient?
    private lazy var sdkClient = SDKCallClient(validSession: { [weak self] in self?.isCurrent($0) == true })
    private var client: CallClient { injectedClient ?? sdkClient }

    init(client: CallClient? = nil, configuration: CallConfigurationStore? = nil,
         resources: CallSystemResources? = nil,
         permission: (@MainActor (CallKind) async throws -> Void)? = nil,
         prepareAudio: (@MainActor () -> Void)? = nil,
         mediaFactory: (@MainActor (CallProvider) -> CallMediaEngine)? = nil) {
        injectedClient = client; self.configuration = configuration ?? .shared; self.resources = resources ?? CallSystemResources()
        self.permission = permission ?? CallSystemResources.requestPermission
        self.prepareAudio = prepareAudio ?? { ChatRuntime.shared.prepareForCall() }
        self.mediaFactory = mediaFactory ?? { provider in
            if provider == .liveKit { return LiveKitCallEngine() }
            return ZegoCallEngine()
        }
        configurationObserver = self.configuration.$current.sink { [weak self] config in
            guard let self else { return }
            self.groupRooms = self.groupRooms.filter { _, room in
                config?.enabled == true && config?.tenantID == self.identity?.tenant && config?.provider == room.descriptor.provider
            }
        }
        self.resources.interrupted = { [weak self] in
            guard let self, let callID = self.session?.id else { return }
            self.errorMessage = "通话被系统中断"
            Task { if self.session?.id == callID { await self.hangUp() } }
        }
    }

    func activate(userUID: String, tenantID: String, sessionID: UUID) {
        if identity?.user == userUID, identity?.tenant == tenantID, identity?.session == sessionID { return }
        close()
        identity = (userUID, tenantID, sessionID)
        client.observe(userUID: userUID) { [weak self] signal in
            guard let self, self.identity?.user == userUID, self.identity?.tenant == tenantID, self.identity?.session == sessionID else { return }
            self.receive(signal)
        }
    }

    func close() {
        operation = UUID(); client.stopObserving(); actionTask?.cancel(); actionTask = nil
        finish(); selection = nil; identity = nil; errorMessage = nil; busy = false
        endedRooms.removeAll(); pendingSignals.removeAll(); groupRooms.removeAll(); roomContexts.removeAll()
        refreshTasks.values.forEach { $0.cancel() }; refreshTasks.removeAll(); refreshIDs.removeAll()
    }

    func isCurrent(_ context: ChatContext) -> Bool {
        identity?.user == context.userUID && identity?.tenant == context.tenantID && identity?.session == context.sessionID
    }
    func canOfferCall(context: ChatContext) -> Bool {
        guard isCurrent(context), let config = configuration.current, config.tenantID == context.tenantID,
              config.enabled, config.provider != nil, context.route.id != context.userUID, context.route.id != "100002" else { return false }
        return client.canOffer(context: context)
    }

    func start(context: ChatContext, kind: CallKind) async {
        guard session == nil, !busy else { errorMessage = "正在通话中，请先结束当前通话"; return }
        guard canOfferCall(context: context) else { errorMessage = "当前不可使用通话"; return }
        let stamp = UUID(); operation = stamp; busy = true; errorMessage = nil
        defer { if operation == stamp { busy = false } }
        do {
            try await client.validateTarget(context: context)
            guard current(stamp, context) else { return }
            if context.route.kind == .group {
                let members = try await client.members(context: context)
                guard current(stamp, context) else { return }
                selection = CallSelectionRequest(id: UUID(), context: context, kind: kind, members: members, selectedIDs: [], isAdditionalInvite: false)
            } else {
                prepareAudio(); try await permission(kind)
                guard current(stamp, context), canOfferCall(context: context) else { return }
                try await create(context: context, kind: kind, members: [client.participant(id: context.route.id, localID: context.userUID)], stamp: stamp)
            }
        } catch { report(error, stamp: stamp, context: context) }
    }

    func submitSelection(_ ids: Set<String>, requestID: UUID) async {
        guard let request = selection, request.id == requestID, !busy, !ids.isEmpty else { return }
        let allowed = Set(request.members.map(\.id)).subtracting(request.selectedIDs).subtracting([request.context.userUID])
        guard ids.isSubset(of: allowed) else { errorMessage = "成员状态已变化，请重新选择"; return }
        let stamp = UUID(); operation = stamp; busy = true; errorMessage = nil
        defer { if operation == stamp { busy = false } }
        do {
            try await client.validateTarget(context: request.context)
            guard current(stamp, request.context), selection?.id == requestID, canOfferCall(context: request.context) else { return }
            let fresh = try await client.members(context: request.context)
            guard current(stamp, request.context), ids.isSubset(of: Set(fresh.map(\.id))) else { throw CallError.unavailable("群成员已变化，请重新选择") }
            if request.isAdditionalInvite {
                guard let room = descriptor, let active = session, active.context == request.context else { throw CancellationError() }
                let connectedIDs = Set(active.participants.filter { $0.stateText == "已加入" || $0.stateText == "呼叫中" }.map(\.id))
                guard ids.isDisjoint(with: connectedIDs) else { throw CallError.unavailable("所选成员已在当前通话中") }
                let response = try await client.perform(.invite, descriptor: room, context: request.context, ids: ids.sorted())
                guard current(stamp, request.context), descriptor?.id == room.id else { return }
                if !response.participants.isEmpty { mergeMembers(response.participants) }
                else { mergeMembers(fresh.filter { ids.contains($0.id) }) }
                selection = nil
            } else {
                prepareAudio(); try await permission(request.kind)
                guard current(stamp, request.context), selection?.id == requestID else { return }
                try await create(context: request.context, kind: request.kind, members: fresh.filter { ids.contains($0.id) }, stamp: stamp)
            }
        } catch { report(error, stamp: stamp, context: request.context, terminate: !request.isAdditionalInvite) }
    }

    func cancelSelection() { selection = nil; operation = UUID(); busy = false; pendingCreation = nil; pendingSignals.removeAll() }

    private func create(context: ChatContext, kind: CallKind, members: [CallParticipant], stamp: UUID) async throws {
        guard let configurationSnapshot = configuration.current, let provider = configurationSnapshot.provider, canOfferCall(context: context) else { throw CallError.unavailable("通话配置已变化，请重试") }
        let room = CallRoomDescriptor(provider: provider, id: "", groupID: context.route.kind == .group ? context.route.id : "", kind: kind, callerID: context.userUID, recipientID: context.route.kind == .single ? context.route.id : "")
        // 与旧端一致，创建请求成功前不建立可展示的通话，也不响铃。
        pendingCreation = (stamp, context, provider)
        pendingSignals.removeAll()
        defer {
            if pendingCreation?.stamp == stamp { pendingCreation = nil; pendingSignals.removeAll() }
        }
        let response = try await client.perform(.create, descriptor: room, context: context, ids: members.map(\.id))
        guard current(stamp, context), session == nil, canOfferCall(context: context), configuration.current?.provider == provider, !endedRooms.contains(roomKey(response)) else {
            if current(stamp, context), endedRooms.contains(roomKey(response)) {
                for case .ended(let ended) in pendingSignals where roomKey(ended) == roomKey(response) { errorMessage = endMessage(ended) }
            }
            // 同认证轮次取消后才补偿；切账号后 SDK 不允许以新身份结束旧房间。
            if isCurrent(context), !response.id.isEmpty { var ended = response; ended.reason = "cancel"; _ = try? await client.perform(.end, descriptor: ended, context: context, ids: []) }
            return
        }
        let buffered = pendingSignals
        pendingCreation = nil; pendingSignals.removeAll()
        begin(context: context, room: response, incoming: false, members: members, configurationSnapshot: configurationSnapshot)
        selection = nil
        descriptor = response
        mergeMembers(response.participants)
        if !room.groupID.isEmpty { connect(response) }
        buffered.forEach(receive)
    }

    private func begin(context: ChatContext, room: CallRoomDescriptor, incoming: Bool, members: [CallParticipant], configurationSnapshot: CallConfiguration? = nil) {
        activeConfiguration = configurationSnapshot ?? configuration.current
        var local = client.participant(id: context.userUID, localID: context.userUID)
        local.name = local.name.isEmpty ? "我" : local.name
        local.cameraEnabled = false
        let all = [local] + members.filter { $0.id != local.id }
        session = CallSession(id: UUID(), context: context, kind: room.kind, phase: incoming ? .incoming : .outgoing, title: context.route.title, isIncoming: incoming, participants: all, connectedAt: nil, microphoneEnabled: true, cameraEnabled: room.kind == .video, speakerEnabled: !room.groupID.isEmpty || room.kind == .video, callerID: room.callerID)
        descriptor = room; isPresented = true
        resources.startRinging(incoming: incoming)
    }

    func accept() async {
        guard let active = session, active.phase == .incoming, let room = descriptor, !busy else { return }
        let stamp = UUID(); operation = stamp; busy = true; errorMessage = nil
        defer { if operation == stamp { busy = false } }
        do {
            prepareAudio(); try await permission(active.kind)
            guard current(stamp, active.context), session?.id == active.id else { return }
            resources.stopRinging(); session?.phase = .connecting
            var response = room
            if room.provider == .zego { response = try await client.perform(.token, descriptor: room, context: active.context, ids: []) }
            guard current(stamp, active.context), session?.id == active.id else { return }
            response = try await client.perform(.accept, descriptor: response, context: active.context, ids: [])
            guard current(stamp, active.context), session?.id == active.id else { return }
            descriptor = response; mergeMembers(response.participants)
            if room.provider == .zego || !room.groupID.isEmpty { connect(response) }
            else { scheduleConnectionDeadline(active.id) }
        } catch { report(error, stamp: stamp, context: active.context) }
    }

    func hangUp() async {
        guard let active = session else { cancelSelection(); return }
        var ended = descriptor
        ended?.reason = CallPolicy.endReason(incoming: active.isIncoming, connected: active.connectedAt != nil)
        operation = UUID(); busy = false
        if let ended, !ended.id.isEmpty { endedRooms.insert(roomKey(ended)) }
        finish()
        guard let ended, !ended.id.isEmpty, isCurrent(active.context) else { return }
        do { _ = try await client.perform(.end, descriptor: ended, context: active.context, ids: []) }
        catch { if isCurrent(active.context), session == nil { errorMessage = "通话已关闭，结束通知发送失败" } }
    }

    func inviteMembers() async {
        guard let active = session, active.context.route.kind == .group, !busy else { return }
        let stamp = UUID(); operation = stamp; busy = true
        defer { if operation == stamp { busy = false } }
        do {
            let members = try await client.members(context: active.context)
            guard current(stamp, active.context), session?.id == active.id else { return }
            let currentIDs = Set(session?.participants.filter { ["已加入", "呼叫中"].contains($0.stateText) }.map(\.id) ?? [])
            selection = CallSelectionRequest(id: UUID(), context: active.context, kind: active.kind, members: members, selectedIDs: currentIDs, isAdditionalInvite: true)
        } catch { report(error, stamp: stamp, context: active.context, terminate: false) }
    }

    func refreshGroupRoom(context: ChatContext) async {
        guard context.route.kind == .group, canOfferCall(context: context), let provider = configuration.current?.provider else { groupRooms[context.route.id] = nil; return }
        roomContexts[context.route.id] = context
        let refreshID = UUID(); refreshIDs[context.route.id] = refreshID
        do {
            try await client.validateTarget(context: context)
            let room = try await client.perform(.groupInfo, descriptor: CallRoomDescriptor(provider: provider, id: "", groupID: context.route.id, kind: .audio), context: context, ids: [])
            guard isCurrent(context), canOfferCall(context: context), refreshIDs[context.route.id] == refreshID, configuration.current?.provider == provider else { return }
            let members = enriched(room.participants)
            if room.id.isEmpty || members.isEmpty || session?.context.route.id == context.route.id { groupRooms[context.route.id] = nil }
            else { groupRooms[context.route.id] = CallGroupRoom(id: context.route.id, roomID: room.id, kind: room.kind, participants: members, descriptor: room) }
        } catch { if isCurrent(context), refreshIDs[context.route.id] == refreshID { groupRooms[context.route.id] = nil } }
    }

    func joinGroupRoom(context: ChatContext) async {
        guard session == nil, !busy else { errorMessage = "正在通话中，请先结束当前通话"; return }
        let stamp = UUID(); operation = stamp; busy = true; errorMessage = nil
        defer { if operation == stamp { busy = false } }
        do {
            try await client.validateTarget(context: context)
            await refreshGroupRoom(context: context)
            guard current(stamp, context), let currentRoom = groupRooms[context.route.id] else { throw CallError.unavailable("当前通话已结束") }
            prepareAudio(); try await permission(currentRoom.kind)
            guard current(stamp, context), canOfferCall(context: context) else { return }
            begin(context: context, room: currentRoom.descriptor, incoming: false, members: currentRoom.participants)
            resources.stopRinging(); session?.phase = .connecting
            var result = try await client.perform(.join, descriptor: currentRoom.descriptor, context: context, ids: [])
            guard current(stamp, context), session != nil else { return }
            if result.provider == .zego, result.token.isEmpty { result = try await client.perform(.token, descriptor: result, context: context, ids: []) }
            guard current(stamp, context), session != nil else { return }
            descriptor = result; connect(result)
        } catch { report(error, stamp: stamp, context: context) }
    }

    /// 只处理当前房间的事件；创建回执前的确认按顺序暂存，终态立即留下墓碑。
    private func receive(_ signal: CallSignal) {
        guard identity != nil else { return }
        if case .groupChanged(let groupID) = signal {
            guard let context = roomContexts[groupID] else { return }
            refreshTasks[groupID]?.cancel()
            refreshTasks[groupID] = Task { [weak self] in await self?.refreshGroupRoom(context: context) }
            return
        }
        let room: CallRoomDescriptor
        switch signal { case .incoming(let value), .accepted(let value), .confirmed(let value), .ended(let value), .members(let value): room = value; case .groupChanged: return }
        guard !room.id.isEmpty else { return }
        if case .incoming = signal { incoming(room); return }
        if case .ended = signal { endedRooms.insert(roomKey(room)) }
        if let pending = pendingCreation, current(pending.stamp, pending.context), room.provider == pending.provider,
           (pending.context.route.kind == .group ? room.groupID == pending.context.route.id :
                room.groupID.isEmpty && (room.recipientID == pending.context.route.id || room.callerID == pending.context.route.id || room.callerID == pending.context.userUID)) {
            if pendingSignals.count < 30 { pendingSignals.append(signal) }
            return
        }
        guard let active = session, isCurrent(active.context) else { return }
        guard descriptor?.id == room.id, descriptor?.provider == room.provider else {
            if descriptor?.id.isEmpty == true, room.provider == descriptor?.provider, (room.groupID == active.context.route.id || room.recipientID == active.context.route.id || room.callerID == active.context.route.id || room.callerID == active.context.userUID) {
                if pendingSignals.count < 30 { pendingSignals.append(signal) }
            }
            return
        }
        guard room.groupID == (descriptor?.groupID ?? "") else { return }
        switch signal {
        case .ended:
            operation = UUID(); busy = false; errorMessage = endMessage(room); finish()
        case .members:
            applyMembers(room)
        case .accepted:
            guard !active.isIncoming, active.phase == .outgoing else { return }
            session?.phase = .connecting; resources.stopRinging()
            let id = active.id
            actionTask = Task { [weak self] in
                guard let self, self.session?.id == id, self.isCurrent(active.context), let currentRoom = self.descriptor, currentRoom.id == room.id, currentRoom.provider == room.provider else { return }
                do {
                    let response: CallRoomDescriptor
                    if room.provider == .liveKit { response = try await self.client.perform(.confirm, descriptor: currentRoom, context: active.context, ids: []) }
                    else { response = currentRoom }
                    guard self.session?.id == id, self.isCurrent(active.context), !self.endedRooms.contains(self.roomKey(room)) else { return }
                    self.descriptor = response; self.connect(response)
                } catch { if self.session?.id == id { self.fail("通话连接失败，请重试") } }
            }
        case .confirmed:
            guard active.isIncoming, active.phase == .connecting else { return }
            var result = descriptor ?? room
            result.endpoint = room.endpoint; result.token = room.token; result.roomName = room.roomName
            descriptor = result; connect(result)
        default: break
        }
    }

    private func incoming(_ room: CallRoomDescriptor) {
        guard let identity, let config = configuration.current, config.tenantID == identity.tenant, config.enabled, config.provider == room.provider, !endedRooms.contains(roomKey(room)) else { return }
        if descriptor?.id == room.id, descriptor?.provider == room.provider { return }
        let target = room.groupID.isEmpty ? room.callerID : room.groupID
        guard !target.isEmpty, room.callerID != identity.user else { return }
        let peer = client.participant(id: room.callerID, localID: identity.user)
        let context = ChatContext(userUID: identity.user, tenantID: identity.tenant, sessionID: identity.session, route: ChatRoute(id: target, kind: room.groupID.isEmpty ? .single : .group, title: room.groupID.isEmpty ? peer.name : "群通话", avatarURL: peer.avatar))
        if session != nil || busy {
            if room.provider == .liveKit {
                var rejected = room; rejected.reason = "refused"
                Task { [weak self] in _ = try? await self?.client.perform(.end, descriptor: rejected, context: context, ids: []) }
            }
            return
        }
        operation = UUID(); selection = nil; errorMessage = nil; prepareAudio()
        var members = enriched(room.participants)
        if !members.contains(where: { $0.id == peer.id }) { members.insert(peer, at: 0) }
        begin(context: context, room: room, incoming: true, members: room.groupID.isEmpty ? [peer] : members)
        if room.provider == .liveKit && room.groupID.isEmpty {
            let id = session?.id
            actionTask = Task { [weak self] in
                guard let self, self.session?.id == id, self.descriptor?.id == room.id, self.isCurrent(context) else { return }
                do { _ = try await self.client.perform(.receive, descriptor: room, context: context, ids: []) }
                catch { if self.session?.id == id { self.fail("来电确认失败，请稍后重试") } }
            }
        }
    }

    private func connect(_ room: CallRoomDescriptor) {
        guard let active = session, let config = activeConfiguration, isCurrent(active.context), media == nil else { return }
        guard (room.provider == .liveKit && !room.endpoint.isEmpty && !room.token.isEmpty) || (room.provider == .zego && !room.roomName.isEmpty && !room.token.isEmpty && config.zegoAppID != 0) else { fail("通话房间信息不完整，请重试"); return }
        resources.stopRinging(); resources.retainScreen(); session?.phase = .connecting
        groupRooms[active.context.route.id] = nil
        let engine = mediaFactory(room.provider); media = engine
        let id = active.id
        engine.onConnected = { [weak self, weak engine] in
            guard let self, let engine, self.session?.id == id, self.media === engine else { return }
            if room.provider == .zego {
                self.actionTask = Task { [weak self] in
                    guard let self, self.session?.id == id, self.descriptor?.id == room.id, self.isCurrent(active.context) else { return }
                    do {
                        _ = try await self.client.perform(.confirmJoin, descriptor: room, context: active.context, ids: [])
                        guard self.session?.id == id else { return }
                        self.connected(id: id)
                    } catch { if self.session?.id == id { self.fail("通话入房确认失败，请重试") } }
                }
            } else { self.connected(id: id) }
        }
        engine.onParticipants = { [weak self] values in guard let self, self.session?.id == id else { return }; self.mergeMembers(values, mediaUpdate: true); self.videoRevision += 1 }
        engine.onFailure = { [weak self] message in if self?.session?.id == id { self?.fail(message) } }
        engine.onReconnecting = { [weak self] reconnecting in
            guard let self, self.session?.id == id, self.session?.connectedAt != nil else { return }
            self.session?.phase = reconnecting ? .connecting : .connected
            if reconnecting { self.scheduleConnectionDeadline(id) }
            else { self.connectDeadline?.cancel(); self.connectDeadline = nil }
        }
        engine.onTokenExpired = { [weak self, weak engine] in
            guard let self, let engine else { return }
            Task {
                guard self.session?.id == id, self.descriptor?.id == room.id, self.isCurrent(active.context) else { return }
                do {
                    let renewed = try await self.client.perform(.token, descriptor: room, context: active.context, ids: [])
                    guard self.session?.id == id, !renewed.token.isEmpty else { return }
                    engine.renewToken(renewed.token)
                } catch { if self.session?.id == id { self.fail("通话凭据更新失败") } }
            }
        }
        scheduleConnectionDeadline(id)
        var mediaSession = active
        mediaSession.cameraEnabled = active.cameraEnabled && foreground
        engine.connect(descriptor: room, session: mediaSession, configuration: config)
    }

    private func connected(id: UUID) {
        guard session?.id == id else { return }
        connectDeadline?.cancel(); connectDeadline = nil
        media?.startPublishing()
        session?.phase = .connected
        if session?.connectedAt == nil { session?.connectedAt = Date() }
        if let index = session?.participants.firstIndex(where: \.isLocal) { session?.participants[index].isConnected = true; session?.participants[index].stateText = "已加入" }
        if !foreground { media?.camera(false) { _ in } }
        guard descriptor?.provider == .zego else { return }
        heartbeat?.cancel()
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 10_000_000_000) } catch { return }
                guard let self, self.session?.id == id, let room = self.descriptor, let context = self.session?.context else { return }
                _ = try? await self.client.perform(.heartbeat, descriptor: room, context: context, ids: [])
            }
        }
    }

    private func scheduleConnectionDeadline(_ id: UUID) {
        connectDeadline?.cancel()
        connectDeadline = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 30_000_000_000) } catch { return }
            guard let self, self.session?.id == id, self.session?.phase == .connecting else { return }
            self.fail("连接通话房间超时，请重试")
        }
    }

    func toggleMicrophone() {
        guard let active = session, active.phase == .connected, !microphoneChanging, let media else { return }
        microphoneChanging = true; let enabled = !active.microphoneEnabled
        media.microphone(enabled) { [weak self] success in
            guard let self, self.session?.id == active.id else { return }; self.microphoneChanging = false
            if success { self.session?.microphoneEnabled = enabled } else { self.errorMessage = "麦克风切换失败，请重试" }
        }
    }
    func toggleCamera() {
        guard let active = session, active.kind == .video, active.phase == .connected, !cameraChanging, let media else { return }
        cameraChanging = true; let enabled = !active.cameraEnabled
        media.camera(enabled && foreground) { [weak self] success in
            guard let self, self.session?.id == active.id else { return }; self.cameraChanging = false
            if success { self.session?.cameraEnabled = enabled } else { self.errorMessage = "摄像头切换失败，请重试" }
        }
    }
    func toggleSpeaker() {
        guard let active = session, active.phase == .connected, let media else { return }
        do { try media.speaker(!active.speakerEnabled); session?.speakerEnabled.toggle() }
        catch { errorMessage = "音频输出切换失败，请重试" }
    }
    func switchCamera() {
        guard let active = session, active.kind == .video, active.cameraEnabled, foreground else { return }
        media?.switchCamera { [weak self] success in
            if !success, self?.session?.id == active.id { self?.errorMessage = "切换摄像头失败，请重试" }
        }
    }
    func setForeground(_ foreground: Bool) {
        guard self.foreground != foreground else { return }; self.foreground = foreground
        if let active = session, active.kind == .video { media?.camera(foreground && active.cameraEnabled) { _ in } }
    }
    func minimize() { if session != nil { isPresented = false } }
    func restore() { if session != nil { isPresented = true } }

    private func enriched(_ values: [CallParticipant]) -> [CallParticipant] {
        guard let identity else { return [] }
        return values.map { value in
            var result = value; let cached = client.participant(id: value.id, localID: identity.user)
            if result.name.isEmpty || result.name == result.id { result.name = cached.name }
            if result.avatar.isEmpty { result.avatar = cached.avatar }
            result.isLocal = result.id == identity.user
            return result
        }
    }
    private func mergeMembers(_ values: [CallParticipant], mediaUpdate: Bool = false) {
        guard session != nil else { return }
        for incoming in enriched(values) {
            var member = incoming
            if let index = session?.participants.firstIndex(where: { $0.id == member.id }), let old = session?.participants[index] {
                if member.name == member.id && old.name != old.id { member.name = old.name }
                if member.avatar.isEmpty { member.avatar = old.avatar }
                if !mediaUpdate {
                    member.cameraEnabled = old.cameraEnabled; member.microphoneEnabled = old.microphoneEnabled
                    if old.isConnected { member.isConnected = true; member.stateText = "已加入" }
                }
                session?.participants[index] = member
            } else { session?.participants.append(member) }
        }
    }
    private func applyMembers(_ room: CallRoomDescriptor) {
        mergeMembers(room.participants)
        if [6, 10].contains(room.status) {
            for id in room.operationIDs {
                var participant = client.participant(id: id, localID: session?.context.userUID ?? "")
                participant.isConnected = true; participant.stateText = "已加入"
                mergeMembers([participant])
            }
        }
        if [3,4,5,7,8,12].contains(room.status) || !room.reason.isEmpty {
            for id in room.operationIDs {
                if let index = session?.participants.firstIndex(where: { $0.id == id }) {
                    session?.participants[index].isConnected = false; session?.participants[index].cameraEnabled = false
                    session?.participants[index].stateText = room.status == 4 || room.reason == "refused" ? "已拒绝" : room.status == 3 || room.status == 12 || room.reason == "timeout" ? "未应答" : "已离开"
                }
            }
        }
    }
    private func current(_ stamp: UUID, _ context: ChatContext) -> Bool { operation == stamp && isCurrent(context) && !Task.isCancelled }
    private func roomKey(_ room: CallRoomDescriptor) -> String { "\(room.provider.rawValue):\(room.id)" }
    private func report(_ error: Error, stamp: UUID, context: ChatContext, terminate: Bool = true) {
        guard current(stamp, context), !(error is CancellationError) else { return }
        let message = (error as? CallError)?.localizedDescription ?? "通话请求失败，请稍后重试"
        errorMessage = message
        if terminate, session != nil { fail(message) }
    }
    private func fail(_ message: String) {
        errorMessage = message
        guard let id = session?.id else { return }
        Task { [weak self] in if self?.session?.id == id { await self?.hangUp() } }
    }
    private func finish() {
        heartbeat?.cancel(); heartbeat = nil; connectDeadline?.cancel(); connectDeadline = nil; actionTask?.cancel(); actionTask = nil
        media?.onConnected = nil; media?.onParticipants = nil; media?.onFailure = nil; media?.onTokenExpired = nil; media?.onReconnecting = nil
        media?.disconnect(); media = nil; resources.release()
        session = nil; descriptor = nil; activeConfiguration = nil; selection = nil; isPresented = false; microphoneChanging = false; cameraChanging = false; videoRevision += 1
        pendingCreation = nil; pendingSignals.removeAll()
    }
    private func endMessage(_ room: CallRoomDescriptor) -> String? {
        if room.reason == "accept" || room.status == 8 { return "已在其他设备接听" }
        if room.reason == "missed" || room.reason == "timeout" || room.status == 3 || room.status == 12 { return "对方未应答" }
        if room.reason == "refused" || room.status == 4 { return "对方已拒绝" }
        if room.reason == "disconnect" || room.status == 7 { return "通话已中断" }
        return nil
    }
}
