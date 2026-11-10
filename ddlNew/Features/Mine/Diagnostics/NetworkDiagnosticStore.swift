import Foundation
import Combine
import Network

@MainActor final class NetworkDiagnosticStore: ObservableObject {
    @Published private(set) var results: [NetworkDiagnosticResult] = []
    @Published private(set) var running = false
    @Published private(set) var status = "准备检测"
    @Published private(set) var progress = 0
    @Published private(set) var activeSection: String?
    @Published private(set) var completed = false
    @Published private(set) var license = ""
    @Published private(set) var activeTargets: [String] = []
    @Published private(set) var sources: [DNS1Source] = []
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private let checkDevice: @MainActor () async throws -> Bool
    private let checkInternet: @MainActor (@escaping @MainActor (InternetConnectivityEvent) -> Void) async -> Bool

    init(checkDevice: @escaping @MainActor () async throws -> Bool = NetworkDiagnosticStore.deviceConnected,
         checkInternet: @escaping @MainActor (@escaping @MainActor (InternetConnectivityEvent) -> Void) async -> Bool = NetworkDiagnosticStore.internetReachable) {
        self.checkDevice = checkDevice
        self.checkInternet = checkInternet
    }

    func cancel() {
        generation = UUID()
        task?.cancel(); task = nil
        if running { status = L10n.tr("检测已取消") }
        running = false
        activeSection = nil; activeTargets = []
    }

    func reset() {
        cancel()
        results = []; progress = 0; completed = false; sources = []
        status = "准备检测"
    }

    func start() {
        cancel()
        results = []; progress = 0; completed = false; sources = []
        guard let uid = ChatRuntime.shared.userUID,
              let context = ChatRuntime.shared.context(for: ChatRoute(id: uid, kind: .single, title: "", avatarURL: "")) else {
            status = L10n.tr("登录状态已失效，请重新登录后检测"); return
        }
        license = context.tenantID
        activeSection = "网络连接情况"
        let round = generation
        running = true; status = L10n.tr("正在检测网络连接")
        ChatRuntime.shared.registerCleanup(owner: self) { [weak self] in self?.cancel() }
        task = Task { [weak self] in
            guard let self else { return }
            @MainActor func valid() throws {
                try Task.checkCancellation()
                guard self.generation == round, ChatRuntime.shared.isCurrent(context) else { throw CancellationError() }
            }
            do {
                try valid()
                sources = try DNS1SourceRace.sources(license: context.tenantID, main: dns1MainDomain, backup: dns1BackupDomain, binTemplate: dns1BinURLTemplate)
                let start = Date()
                let connected = try await checkDevice()
                try valid()
                results.append(.init(section: "网络连接情况", title: connected ? L10n.tr("设备已联网") : L10n.tr("设备未联网"), passed: connected, milliseconds: NetworkDiagnosticRunner.elapsed(start)))
                _ = await checkInternet { event in
                    guard self.generation == round, ChatRuntime.shared.isCurrent(context), !Task.isCancelled else { return }
                    switch event {
                    case .started(let address): self.activeTargets = [address]
                    case .finished(let attempt):
                        self.activeTargets = []
                        self.results.append(.init(section: "网络连接情况",
                            title: attempt.passed ? L10n.tr("外网地址可达") : L10n.tr("外网地址未通过检测"),
                            passed: attempt.passed, milliseconds: attempt.milliseconds, targets: [attempt.address]))
                    }
                }
                try valid()
                status = L10n.tr("正在获取节点并检测服务器")
                progress = 33; activeSection = "节点获取检测"
                try await NetworkDiagnosticRunner.run(sources: sources, load: { source in
                    try valid()
                    self.activeSection = "节点获取检测"
                    self.activeTargets = [source.address]
                    return try await DNS1NodeRaceCoordinator.load(source, license: context.tenantID)
                }, probe: { node in
                    try valid()
                    if self.activeSection != "服务器连接检测" { self.activeTargets = [] }
                    self.activeSection = "服务器连接检测"
                    if !self.activeTargets.contains(node.address) { self.activeTargets.append(node.address) }
                    self.progress = 66
                    return try await DNS1NodeRaceCoordinator.probe(node)
                }, emit: { result in
                    guard self.generation == round, ChatRuntime.shared.isCurrent(context), !Task.isCancelled else { return }
                    self.results.append(result)
                    self.activeTargets.removeAll { result.targets.contains($0) }
                })
                try valid()
                let failures = results.filter { !$0.passed }.count
                let hasServer = results.contains { $0.section == "服务器连接检测" && $0.passed }
                status = hasServer ? (failures == 0 ? L10n.tr("检测完成，连接正常") : L10n.tr("检测完成，有 \(failures) 项异常，可用服务器已找到")) : L10n.tr("检测完成，未找到可用服务器")
                progress = 100; completed = true; activeSection = nil; activeTargets = []
                running = false; task = nil
            } catch {
                guard generation == round else { return }
                status = error is CancellationError ? L10n.tr("检测已取消") : L10n.tr("检测失败，请确认当前企业入口后重试")
                activeSection = nil; activeTargets = []
                running = false; task = nil
            }
        }
    }

    static func deviceConnected() async throws -> Bool {
        let monitor = NWPathMonitor()
        let waiter = DNS1CallbackWaiter<Bool>()
        defer { monitor.cancel() }
        do {
            return try await waiter.run(seconds: 3) {
                monitor.pathUpdateHandler = { path in
                    let connected = path.status == .satisfied
                    Task { @MainActor in waiter.finish(.success(connected)) }
                }
                monitor.start(queue: DispatchQueue(label: "mine.network.path"))
            }
        } catch {
            try Task.checkCancellation()
            return false
        }
    }

    static func internetReachable(observe: @escaping @MainActor (InternetConnectivityEvent) -> Void) async -> Bool {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5; configuration.timeoutIntervalForResource = 8
        configuration.urlCache = nil; configuration.httpCookieStorage = nil; configuration.urlCredentialStorage = nil
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        return await InternetConnectivityCheck.run(observe: observe) { url in
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
            request.httpShouldHandleCookies = false
            let (data, response) = try await session.data(for: request)
            return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }
}
