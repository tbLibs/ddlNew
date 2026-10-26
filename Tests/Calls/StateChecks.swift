import Foundation
import Combine

// 替代不可在离线宿主运行的 SDK/设备边界，协调器、配置和通话模型使用生产源码。
enum ConversationKind: Sendable { case single, group, other }
struct ChatRoute: Equatable, Sendable { var id: String; var kind: ConversationKind; var title: String; var avatarURL: String }
struct ChatContext: Equatable, Sendable { var userUID: String; var tenantID: String; var sessionID: UUID; var route: ChatRoute }
@MainActor final class ChatRuntime { static let shared = ChatRuntime(); func prepareForCall() {} }
@MainActor final class CallSystemResources {
 var interrupted: (() -> Void)?
 var ringing = false
 var releases = 0
 func startRinging(incoming: Bool) { ringing = true }
 func stopRinging() { ringing = false }
 func retainScreen() {}
 func release() { ringing = false; releases += 1 }
 static func requestPermission(kind: CallKind) async throws {}
}
@MainActor class FakeMedia: CallMediaEngine {
 var onReconnecting: ((Bool) -> Void)?
 var onConnected: (() -> Void)?; var onParticipants: (([CallParticipant]) -> Void)?; var onFailure: ((String) -> Void)?; var onTokenExpired: (() -> Void)?
 var connects = 0; var disconnects = 0; var publishes = 0; var cameras: [Bool] = []
 func connect(descriptor: CallRoomDescriptor, session: CallSession, configuration: CallConfiguration) { connects += 1; cameras.append(session.cameraEnabled) }
 func disconnect() { disconnects += 1 }
 func startPublishing() { publishes += 1 }
 func microphone(_ enabled: Bool, completion: @escaping (Bool) -> Void) { completion(true) }
 func camera(_ enabled: Bool, completion: @escaping (Bool) -> Void) { cameras.append(enabled); completion(true) }
 func speaker(_ enabled: Bool) throws {}
 func switchCamera(completion: @escaping (Bool) -> Void) { completion(true) }
 func renewToken(_ token: String) {}
}
@MainActor final class LiveKitCallEngine: FakeMedia {}
@MainActor final class ZegoCallEngine: FakeMedia {}
@MainActor class FakeClient: CallClient {
 var handler: ((CallSignal) -> Void)?
 var actions: [(CallAction, CallRoomDescriptor, [String])] = []
 var suspendCreate = false
 var createWaiter: CheckedContinuation<CallRoomDescriptor, Error>?
 var allowed = true
 var failing: CallAction?
 var createID = "r1"
 func observe(userUID: String, onSignal: @escaping @MainActor (CallSignal) -> Void) { handler = onSignal }
 func stopObserving() { handler = nil }
 func canOffer(context: ChatContext) -> Bool { allowed }
 func validateTarget(context: ChatContext) async throws { if !allowed { throw CallError.unavailable("禁止") } }
 func members(context: ChatContext) async throws -> [CallParticipant] { [participant(id: "b", localID: "a"), participant(id: "c", localID: "a")] }
 func participant(id: String, localID: String) -> CallParticipant { CallParticipant(id: id, name: id, avatar: "", isLocal: id == localID, isConnected: false, cameraEnabled: false, microphoneEnabled: true) }
 func perform(_ action: CallAction, descriptor: CallRoomDescriptor, context: ChatContext, ids: [String]) async throws -> CallRoomDescriptor {
  actions.append((action, descriptor, ids))
  if action == failing { throw CallError.unavailable("离线故障") }
  if action == .create && suspendCreate { return try await withCheckedThrowingContinuation { createWaiter = $0 } }
  var room = descriptor
  if action == .create { room.id = createID; room.token = "offline-token"; room.endpoint = "wss://invalid.test"; room.roomName = "room" }
  if action == .confirm || action == .token { room.token = "offline-token"; room.endpoint = "wss://invalid.test"; room.roomName = "room" }
  return room
 }
}
@MainActor final class SDKCallClient: FakeClient { init(validSession: @escaping (ChatContext) -> Bool) { super.init() } }

@main struct StateChecks {
 @MainActor static func drain() async { for _ in 0..<20 { await Task.yield() } }
 @MainActor static func main() async {
  var checked = 0
  func check(_ value: @autoclosure () -> Bool, _ label: String) { precondition(value(), label); checked += 1 }
  let localConfig = CallConfigurationStore()
  localConfig.configure(tenantID: "first")
  check(localConfig.current?.enabled == true && localConfig.current?.provider == .zego && localConfig.current?.zegoAppID == 40878197, "local call config preserves enabled Zego and appID")
  localConfig.configure(tenantID: "second")
  check(localConfig.current?.tenantID == "second", "local call config binds new tenant")
  localConfig.clear()
  check(localConfig.current == nil, "logout clears call config identity")
  var fixture = CallConfiguration(tenantID: "t", enabled: true, provider: .liveKit, zegoAppID: 0)
  let config = CallConfigurationStore(makeConfiguration: { _ in fixture })
  config.configure(tenantID: "t")
  let auth = UUID(); let context = ChatContext(userUID: "a", tenantID: "t", sessionID: auth, route: ChatRoute(id: "b", kind: .single, title: "B", avatarURL: ""))
  let client = FakeClient(); var media = FakeMedia(); let resources = CallSystemResources()
  let coordinator = CallCoordinator(client: client, configuration: config, resources: resources, permission: { _ in }, prepareAudio: {}, mediaFactory: { _ in media })
  coordinator.activate(userUID: "a", tenantID: "t", sessionID: auth)
  check(coordinator.canOfferCall(context: context), "current identity and enabled config")
  await coordinator.start(context: context, kind: .audio)
  check(coordinator.session?.phase == .outgoing && media.connects == 0, "create does not fake connected")
  var room = CallRoomDescriptor(provider: .liveKit, id: "r1", kind: .audio, callerID: "a", recipientID: "b")
  client.handler?(.accepted(room)); await drain()
  check(media.connects == 1 && coordinator.session?.phase == .connecting, "accept invokes confirm and connects")
  check(client.actions.contains(where: { $0.0 == .confirm }), "caller confirms livekit")
  media.onConnected?()
  check(coordinator.session?.phase == .connected && coordinator.session?.connectedAt != nil, "only media confirmation connects")
  let connectedAt = coordinator.session?.connectedAt
  coordinator.minimize(); coordinator.restore()
  check(coordinator.session?.connectedAt == connectedAt && media.connects == 1, "minimize restores same room and timer")
  var other = room; other.id = "other"; other.callerID = "c"; other.recipientID = "a"
  client.handler?(.incoming(other)); await drain()
  check(coordinator.session != nil && client.actions.contains(where: { $0.0 == .end && $0.1.id == "other" && $0.1.reason == "refused" }), "busy refuses only new LK room")
  client.handler?(.ended(other))
  check(coordinator.session != nil, "unrelated end does not terminate current")
  await coordinator.hangUp()
  check(coordinator.session == nil && media.disconnects == 1 && !resources.ringing, "end releases media and ringtone")
  client.handler?(.confirmed(room)); check(coordinator.session == nil, "late confirmation cannot resurrect")
  // 来电未接听不申请媒体，拒绝使用 refused。
  room.id = "incoming"; room.callerID = "b"; room.recipientID = "a"
  media = FakeMedia(); client.handler?(.incoming(room)); await drain()
  check(coordinator.session?.phase == .incoming && media.connects == 0, "incoming does not start media")
  check(client.actions.contains(where: { $0.0 == .receive && $0.1.id == room.id }), "incoming LK receive acknowledgment")
  await coordinator.hangUp()
  check(client.actions.last?.1.reason == "refused", "unanswered incoming rejects")
  // 创建请求尚未回执时取消，迟到房间补偿取消但不再弹出。
  client.suspendCreate = true
  let start = Task { await coordinator.start(context: context, kind: .audio) }
  while client.createWaiter == nil { await Task.yield() }
  check(coordinator.session == nil && !coordinator.isPresented && !resources.ringing && coordinator.busy, "pending create keeps chat visible and silent")
  await coordinator.hangUp()
  var late = room; late.id = "late-create"; late.callerID = "a"; late.recipientID = "b"
  client.createWaiter?.resume(returning: late); client.createWaiter = nil
  await start.value
  check(coordinator.session == nil && client.actions.last?.1.id == "late-create" && client.actions.last?.1.reason == "cancel", "late created room is compensated")
  // 对端终态早于创建回执，同样不能留下旧呼出页面。
  let earlyStart = Task { await coordinator.start(context: context, kind: .audio) }
  while client.createWaiter == nil { await Task.yield() }
  late.id = "early-end"; client.handler?(.ended(late))
  client.createWaiter?.resume(returning: late); client.createWaiter = nil
  await earlyStart.value
  check(coordinator.session == nil && !resources.ringing, "end before create reply cleans outgoing page")
  client.suspendCreate = false
  // 创建失败不曾出现通话页面或铃声；音频、视频及两供应商共用此边界。
  for provider in ["0", "1"] {
   fixture = CallConfiguration(tenantID: "t", enabled: true, provider: CallProvider(rawValue: Int(provider)!), zegoAppID: 1); config.configure(tenantID: "t")
   for kind in [CallKind.audio, .video] {
    client.suspendCreate = true
    let pending = Task { await coordinator.start(context: context, kind: kind) }
    while client.createWaiter == nil { await Task.yield() }
    check(coordinator.session == nil && !resources.ringing, "both providers defer outgoing presentation")
    let requests = client.actions.count
    await coordinator.start(context: context, kind: kind)
    check(client.actions.count == requests, "duplicate tap cannot create a second pending call")
    client.createWaiter?.resume(throwing: CallError.unavailable("用户不在线")); client.createWaiter = nil
    await pending.value
    check(coordinator.errorMessage == "用户不在线" && coordinator.session == nil && !coordinator.isPresented && !resources.ringing && !coordinator.busy, "offline failure stays in chat and releases busy state")
   }
  }
  fixture = CallConfiguration(tenantID: "t", enabled: true, provider: .liveKit, zegoAppID: 1); config.configure(tenantID: "t")
  // 对方接听先于建房回执时，仍需在受理后完成确认并连接。
  let acceptedEarly = Task { await coordinator.start(context: context, kind: .video) }
  while client.createWaiter == nil { await Task.yield() }
  late.id = "early-accept"; late.kind = .video; late.token = "offline-token"; late.endpoint = "wss://invalid.test"
  client.handler?(.accepted(late))
  check(coordinator.session == nil && !resources.ringing, "early accepted notification cannot present before create succeeds")
  client.createWaiter?.resume(returning: late); client.createWaiter = nil
  await acceptedEarly.value; await drain()
  check(coordinator.session?.phase == .connecting && client.actions.last?.0 == .confirm, "early accepted notification is replayed after successful create")
  await coordinator.hangUp()
  // 认证退出后，旧建房回执不能显示界面或发送新身份补偿。
  let staleCreate = Task { await coordinator.start(context: context, kind: .audio) }
  while client.createWaiter == nil { await Task.yield() }
  coordinator.close(); coordinator.activate(userUID: "x", tenantID: "t", sessionID: UUID())
  let actionsBeforeStale = client.actions.count
  late.id = "stale-auth-create"; client.createWaiter?.resume(returning: late); client.createWaiter = nil
  await staleCreate.value
  check(coordinator.session == nil && !resources.ringing && client.actions.count == actionsBeforeStale, "old auth create neither presents nor compensates with new identity")
  coordinator.close(); coordinator.activate(userUID: "a", tenantID: "t", sessionID: auth)
  client.suspendCreate = false
  // AUTH退出后排队的旧handler不能接管新身份。
  let oldHandler = client.handler
  coordinator.close(); coordinator.activate(userUID: "x", tenantID: "t", sessionID: UUID())
  oldHandler?(.incoming(room)); await drain()
  check(coordinator.session == nil, "old auth observer cannot deliver to new session")
  coordinator.close(); coordinator.activate(userUID: "a", tenantID: "t", sessionID: auth)
  // 接受事件的异步任务尚未执行时旧通话结束，任务不能确认下一通的descriptor。
  client.createID = "accept-stale-A"; media = FakeMedia()
  await coordinator.start(context: context, kind: .audio)
  let staleAccepted = CallRoomDescriptor(provider: .liveKit, id: "accept-stale-A", kind: .audio, callerID: "a", recipientID: "b")
  let beforeStaleAccept = client.actions.count
  client.handler?(.accepted(staleAccepted))
  client.handler?(.ended(staleAccepted))
  var replacement = room; replacement.id = "accept-replacement-B"; replacement.callerID = "c"
  client.handler?(.incoming(replacement)); await drain()
  check(!client.actions.dropFirst(beforeStaleAccept).contains(where: { $0.0 == .confirm }), "queued accept from old call cannot confirm replacement room")
  check(coordinator.session?.phase == .incoming && coordinator.session?.callerID == "c", "replacement incoming remains pending")
  await coordinator.hangUp()
  // 系统授权等待时取消：迟到授权不可发起网络请求。
  var permissionWaiter: CheckedContinuation<Void, Error>?
  let permissionClient = FakeClient()
  let permissionCoordinator = CallCoordinator(client: permissionClient, configuration: config, resources: CallSystemResources(), permission: { _ in try await withCheckedThrowingContinuation { permissionWaiter = $0 } }, prepareAudio: {}, mediaFactory: { _ in FakeMedia() })
  permissionCoordinator.activate(userUID: "a", tenantID: "t", sessionID: auth)
  let permissionStart = Task { await permissionCoordinator.start(context: context, kind: .video) }
  while permissionWaiter == nil { await Task.yield() }
  await permissionCoordinator.hangUp(); permissionWaiter?.resume(); await permissionStart.value
  check(permissionClient.actions.isEmpty && permissionCoordinator.session == nil, "cancel during permission does not send invite")
  // 群选人创建失败原位保留，重试只在受理后进入通话。
  let groupContext = ChatContext(userUID: "a", tenantID: "t", sessionID: auth, route: ChatRoute(id: "g", kind: .group, title: "G", avatarURL: ""))
  await coordinator.start(context: groupContext, kind: .video)
  let selectionID = coordinator.selection!.id
  await coordinator.submitSelection([], requestID: selectionID)
  check(coordinator.selection?.id == selectionID && coordinator.session == nil, "empty group selection does not create")
  client.failing = .create
  await coordinator.submitSelection(["b"], requestID: selectionID)
  check(coordinator.selection?.id == selectionID && coordinator.session == nil && coordinator.errorMessage != nil, "group create failure preserves selection identity")
  client.failing = nil; client.createID = "group-room"; media = FakeMedia()
  await coordinator.submitSelection(["b"], requestID: selectionID)
  check(coordinator.selection == nil && coordinator.session?.context.route.id == "g" && media.connects == 1, "group create success enters returned room")
  media.onConnected?()
  await coordinator.inviteMembers()
  let additional = coordinator.selection!
  check(additional.isAdditionalInvite && additional.selectedIDs.contains("b"), "additional invitation excludes existing members")
  client.failing = .invite
  await coordinator.submitSelection(["c"], requestID: additional.id)
  await drain()
  check(coordinator.session?.phase == .connected && coordinator.selection?.id == additional.id, "invite failure preserves active room and picker")
  client.failing = nil; coordinator.cancelSelection()
  let groupRoom = CallRoomDescriptor(provider: .liveKit, id: "group-room", groupID: "g", kind: .video, operationIDs: ["b"], reason: "timeout")
  client.handler?(.members(groupRoom))
  check(coordinator.session?.phase == .connected && coordinator.session?.participants.first(where: { $0.id == "b" })?.stateText == "未应答", "one group timeout does not end other members")
  coordinator.setForeground(false)
  check(media.cameras.last == false && coordinator.session?.cameraEnabled == true, "background stops actual camera but preserves user intention")
  coordinator.setForeground(true); coordinator.toggleCamera(); coordinator.setForeground(false); coordinator.setForeground(true)
  check(media.cameras.last == false && coordinator.session?.cameraEnabled == false, "foreground does not reopen manually disabled camera")
  media.onReconnecting?(true)
  check(coordinator.session?.phase == .connecting, "reconnecting is visible")
  media.onReconnecting?(false)
  check(coordinator.session?.phase == .connected, "reconnection restores existing call")
  // A的失败Task已排队时，A终态和B来电不能让旧Task挂断B。
  media.onFailure?("故障")
  client.handler?(.ended(groupRoom))
  var next = room; next.id = "next-incoming"
  client.handler?(.incoming(next)); await drain()
  check(coordinator.session?.phase == .incoming, "queued old media failure cannot hang up new incoming")
  await coordinator.hangUp()
  // Zego 使用独立accept/token/confirmJoin合同，忙线不发送拒绝。
  fixture = CallConfiguration(tenantID: "t", enabled: true, provider: .zego, zegoAppID: 1); config.configure(tenantID: "t")
  client.createID = "zego-outgoing"; media = FakeMedia()
  await coordinator.start(context: context, kind: .audio)
  var zegoRoom = CallRoomDescriptor(provider: .zego, id: "zego-outgoing", kind: .audio, callerID: "a", recipientID: "b", roomName: "zr")
  let beforeAccept = client.actions.count
  client.handler?(.accepted(zegoRoom)); await drain()
  check(media.connects == 1 && !client.actions.dropFirst(beforeAccept).contains(where: { $0.0 == .confirm }), "Zego accepted does not use LK confirm")
  media.onConnected?(); await drain()
  check(client.actions.last?.0 == .confirmJoin && media.publishes == 1, "Zego confirms room before publishing")
  let busyActions = client.actions.count
  var zegoBusy = zegoRoom; zegoBusy.id = "zego-busy"; zegoBusy.callerID = "c"; zegoBusy.recipientID = "a"
  client.handler?(.incoming(zegoBusy)); await drain()
  check(client.actions.count == busyActions && coordinator.session?.phase == .connected, "Zego busy ignores second invitation")
  await coordinator.hangUp()
  zegoRoom.id = "zego-incoming"; zegoRoom.callerID = "b"; zegoRoom.recipientID = "a"
  media = FakeMedia(); client.handler?(.incoming(zegoRoom))
  let beforeIncomingAccept = client.actions.count
  await coordinator.accept()
  let acceptActions = Array(client.actions.dropFirst(beforeIncomingAccept).map { $0.0 })
  check(acceptActions == [.token, .accept] && media.connects == 1, "Zego incoming fetches own token before accept")
  await coordinator.hangUp()
  fixture = CallConfiguration(tenantID: "t", enabled: false, provider: .zego, zegoAppID: 1); config.configure(tenantID: "t")
  check(!coordinator.canOfferCall(context: context), "disabled injected call configuration blocks entry")
  print("Calls: \(checked) coordinator lifecycle checks passed")
 }
}
