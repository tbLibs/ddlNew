import Foundation
import Combine

@MainActor protocol PushClient: AnyObject {
    func bind(token: String, identity: PushIdentity) async throws
    func unbind(token: String, identity: PushIdentity) async
    func loadPreferences(identity: PushIdentity) async throws -> PushPreferences
    func savePreferences(_ value: PushPreferences, identity: PushIdentity) async throws
    func observe(identity: PushIdentity, received: @escaping @MainActor (PushEvent) -> Void)
    func stopObserving()
}
@MainActor protocol PushSystemClient: AnyObject {
    func requestPermission() async -> String
    func permissionStatus() async -> String
    func registerRemote()
    func post(_ event: PushEvent, identity: PushIdentity, sound: Bool) async
    func remove(_ event: PushEvent, identity: PushIdentity)
    func clear()
    func play(sound: Bool, vibration: Bool)
    func badge(_ count: Int)
}
nonisolated struct PushNavigationRequest: Identifiable, Equatable {
    let id = UUID()
    let payload: PushPayload
    let userUID: String?
    let tenantID: String?
    let sessionID: UUID?
    func matches(_ identity: PushIdentity) -> Bool {
        payload.matches(identity) && (userUID == nil || userUID == identity.userUID)
        && (tenantID == nil || tenantID == identity.tenantID)
        && (sessionID == nil || sessionID == identity.sessionID)
    }
    var hasOwner: Bool { userUID != nil && tenantID != nil }
}

/// 系统与SDK边界可注入。所有业务状态只能由当前认证轮次发布。
@MainActor final class PushCoordinator: ObservableObject {
    @Published private(set) var preferences = PushPreferences()
    @Published private(set) var preferencesReady = false
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var permission = "正在读取系统通知权限…"
    @Published private(set) var registrationError: String?
    @Published private(set) var pendingNavigation: PushNavigationRequest?
    private(set) var identity: PushIdentity?
    var visibleConversation: PushDestination?
    var audioBusy: () -> Bool = { false }
    private let client: any PushClient
    private let system: any PushSystemClient
    private let defaults: UserDefaults
    private var token: String?
    private var bound: (PushIdentity, String)?
    private var bindingTask: Task<Void, Never>?
    private var preferenceTask: Task<Void, Never>?
    private var permissionTask: Task<Void, Never>?
    private var signingOut = false
    private var foreground = false
    private var policy = PushDeliveryPolicy()
    private var lastSound = Date.distantPast
    private var preferenceRevision = UUID()
    private var lastBadge: Int?

    init(client: any PushClient, system: any PushSystemClient, defaults: UserDefaults = .standard) {
        self.client = client; self.system = system; self.defaults = defaults
        token = defaults.string(forKey:"push.apnsToken")
    }

    func activate(identity: PushIdentity) {
        guard self.identity != identity else { retry(); return }
        // 冷启动点击允许跨启动恢复，已建立的旧登录轮次不允许跨重新登录。
        let waiting = self.identity == nil ? pendingNavigation : nil
        close(clearSystem:false)
        self.identity = identity; signingOut = false
        if let waiting, waiting.matches(identity) { pendingNavigation = waiting }
        if let data = defaults.data(forKey:identity.cacheKey), let saved = try? JSONDecoder().decode(PushPreferences.self, from:data) {
            preferences = saved; preferencesReady = true
        }
        client.observe(identity:identity) { [weak self] event in
            guard let self, self.identity == identity, !self.signingOut else { return }
            self.receive(event, owner:identity)
        }
        refreshPreferences(); reconcileBinding()
        permissionTask = Task { [weak self] in
            guard let self else { return }
            let status = await self.system.requestPermission()
            guard self.identity == identity, !Task.isCancelled, !self.signingOut else { return }
            self.permission = status
            self.system.registerRemote()
        }
    }

    func receivedToken(_ token: String) {
        guard !token.isEmpty else { return }
        debugPrint("deviceToken=\(token)")
        self.token = token; defaults.set(token, forKey:"push.apnsToken")
        registrationError = nil; reconcileBinding()
    }
    func registrationFailed() { registrationError = "推送注册失败，回到前台后将重试。" }

    /// 单一泵串行绑定，迟到的旧绑定完成后仍协调到最新身份。
    private func reconcileBinding() {
        guard bindingTask == nil, identity != nil, token != nil, !signingOut else { return }
        bindingTask = Task { [weak self] in
            guard let self else { return }
            defer { self.bindingTask = nil }
            while let owner = self.identity, let token = self.token, !self.signingOut {
                if let bound = self.bound, bound.0 == owner, bound.1 == token { return }
                do {
                    try await self.client.bind(token:token, identity:owner)
                    if self.identity == owner, self.token == token, !self.signingOut {
                        self.bound = (owner,token); self.registrationError = nil
                    }
                } catch {
                    if self.identity == owner, self.token == token {
                        self.registrationError = "推送设备绑定失败，回到前台后将重试。"; return
                    }
                }
            }
        }
    }

    func retry() {
        guard identity != nil, !signingOut else { return }
        system.registerRemote(); reconcileBinding()
        if !preferencesReady || errorMessage != nil { refreshPreferences() }
    }
    func setForeground(_ active: Bool) {
        foreground = active
        if active {
            Task { [weak self] in
                guard let self else { return }
                self.permission = await self.system.permissionStatus()
            }
            retry()
        }
    }
    func refreshPreferences() {
        guard let owner = identity, !signingOut, !isSaving else { return }
        preferenceTask?.cancel(); let revision = UUID(); preferenceRevision = revision; isLoading = true
        preferenceTask = Task { [weak self] in
            guard let self else { return }
            do {
                let value = try await self.client.loadPreferences(identity:owner)
                guard self.identity == owner, self.preferenceRevision == revision, !Task.isCancelled else { return }
                self.preferences = value; self.preferencesReady = true; self.persist(value, owner:owner); self.errorMessage = nil
            } catch {
                guard self.identity == owner, self.preferenceRevision == revision, !Task.isCancelled else { return }
                self.errorMessage = "通知设置读取失败，请重试。"
            }
            self.isLoading = false
        }
    }
    func savePreferences(_ value: PushPreferences) async {
        guard let owner = identity, !signingOut, preferencesReady, !isSaving else { return }
        preferenceTask?.cancel(); preferenceRevision = UUID(); isLoading = false; isSaving = true; errorMessage = nil
        do {
            try await client.savePreferences(value, identity:owner)
            guard identity == owner, !signingOut else { return }
            preferences = value; persist(value, owner:owner)
        } catch {
            guard identity == owner, !signingOut else { return }
            errorMessage = "通知设置保存失败，已保留原设置。"
        }
        isSaving = false
    }
    private func persist(_ value: PushPreferences, owner: PushIdentity) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey:owner.cacheKey) }
    }

    private func receive(_ event: PushEvent, owner: PushIdentity) {
        guard preferencesReady, policy.accept(event, preferences:preferences, foreground:foreground, visible:visibleConversation) else { return }
        if foreground {
            guard !audioBusy(), Date().timeIntervalSince(lastSound) >= 1 else { return }
            lastSound = Date(); system.play(sound:preferences.sound, vibration:preferences.vibration)
        } else {
            let sound = preferences.sound
            Task { [weak self] in
                guard let self, self.identity == owner, !self.signingOut else { return }
                await self.system.post(event, identity:owner, sound:sound)
                if self.identity != owner || self.signingOut { self.system.remove(event, identity:owner) }
            }
        }
    }

    func receiveClick(_ payload: PushPayload, cachedOwner: (userUID:String, tenantID:String)?) {
        guard !signingOut else { return }
        if let identity, !payload.matches(identity) { return }
        let user = identity?.userUID ?? cachedOwner?.userUID
        let tenant = identity?.tenantID ?? cachedOwner?.tenantID
        if let expected = payload.userUID, let user, expected != user { return }
        if let expected = payload.tenantID, let tenant, expected != tenant { return }
        pendingNavigation = PushNavigationRequest(payload:payload, userUID:user, tenantID:tenant, sessionID:identity?.sessionID)
    }
    func consumeNavigation(_ id: UUID) { if pendingNavigation?.id == id { pendingNavigation = nil } }
    func updateBadge(messages: Int?, friends: Int?) {
        guard identity != nil, !signingOut, let messages, let friends else { return }
        let count = max(0,messages) + max(0,friends)
        if lastBadge != count { lastBadge = count; system.badge(count) }
    }

    func prepareSignOut() async {
        guard let owner = identity else { return }
        signingOut = true; client.stopObserving(); preferenceTask?.cancel(); permissionTask?.cancel()
        pendingNavigation = nil; system.clear()
        // 请求本身有有限超时；等待已发送绑定后再解绑，避免随后绑定复活旧账号。
        await bindingTask?.value
        guard identity == owner else { return }
        if let token { await client.unbind(token:token, identity:owner) }
        if identity == owner { bound = nil }
    }
    func close(clearSystem: Bool = true) {
        identity = nil; signingOut = false; client.stopObserving()
        preferenceTask?.cancel(); permissionTask?.cancel(); preferenceRevision = UUID()
        preferences = PushPreferences(); preferencesReady = false; isLoading = false; isSaving = false
        errorMessage = nil; bound = nil; visibleConversation = nil; pendingNavigation = nil
        policy.reset(); lastSound = .distantPast; lastBadge = nil
        if clearSystem { system.clear() }
    }
}
