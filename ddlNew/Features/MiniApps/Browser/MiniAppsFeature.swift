//
//  MiniAppsFeature.swift
//  ddlNew
//
//  Created by taobo on 2026/11/9.
//
import Foundation
import Combine
import WebKit

/// 主界面统一持有应用和浮窗；认证退出通过既有Runtime同步撤销所有网页与等待。
@MainActor final class MiniAppsFeature: ObservableObject {
    static let shared = MiniAppsFeature()
    @Published private(set) var store: MiniAppsStore?
    @Published private(set) var floats: [MiniAppFloatRecord] = []
    @Published var active: MiniAppWebSession?
    @Published var showsFloats = false
    @Published var passwordRequest: MiniAppRecord?
    @Published private(set) var busy = false
    @Published private(set) var feedback: String?
    private var context: ChatContext?
    private let floatClient: any MiniAppFloatClient
    private var dataStore = WKWebsiteDataStore.nonPersistent()
    private var cached: [String: MiniAppWebSession] = [:]
    private var recency: [String] = []
    private var pendingFloat: MiniAppFloatRecord?
    private var restoreTask: Task<Void, Never>?
    private var revision = UUID()

    init(floatClient: (any MiniAppFloatClient)? = nil) { self.floatClient = floatClient ?? SDKMiniAppFloatClient() }

    /// 根Tab可重现，但同一AUTH不会重复创建列表和网页数据空间。
    func activate() {
        let route = ChatRoute(id: "__mini_apps__", kind: .single, title: "我的应用", avatarURL: "")
        guard let current = ChatRuntime.shared.context(for: route) else { close(); return }
        guard context != current else { return }
        close(); context = current
        store = MiniAppsStore(context: current, client: SDKMiniAppClient(), isCurrent: { ChatRuntime.shared.isCurrent($0) })
        ChatRuntime.shared.registerCleanup(owner: self) { [weak self] in self?.close() }
        do { floats = try floatClient.load(context: current) } catch { feedback = error.localizedDescription }
    }

    /// 只接受已验证的记录；网页实例最多保留5个，其余仍可从SDK记录恢复。
    func open(_ record: MiniAppRecord, restoring: MiniAppFloatRecord? = nil) {
        guard valid, let url = MiniAppWebPolicy.entryURL(record.url) else { feedback = "应用链接无效，请编辑后重试"; return }
        feedback = nil
        let target: URL
        if let restoring, let saved = MiniAppWebPolicy.url(restoring.url),
           saved.scheme == url.scheme, saved.host == url.host, saved.port == url.port { target = saved }
        else { target = url }
        if let old = cached[record.id], old.entryURL != url { invalidate(id: record.id) }
        let session = cached[record.id] ?? MiniAppWebSession(id: record.id, title: record.name, icon: record.icon, url: target, entryURL: url, dataStore: dataStore)
        cached[record.id] = session
        recency.removeAll { $0 == record.id }; recency.append(record.id)
        while recency.count > 5 {
            let old = recency.removeFirst(); cached.removeValue(forKey: old)?.close()
        }
        active?.suspend(true); active = session; session.suspend(false)
    }

    /// 关闭和最小化都记住最新地址，最小化还保留本轮网页实例。
    func finish(minimized: Bool) {
        guard valid, let context, let session = active else { return }
        let record = MiniAppFloatRecord(id: session.id, title: session.title, url: session.currentURL.absoluteString, icon: session.icon)
        do {
            try floatClient.save(record, context: context)
            floats.removeAll { $0.id == record.id }; floats.insert(record, at: 0)
        } catch { feedback = "网页记录保存失败，请重试"; if minimized { return } }
        session.suspend(true); active = nil
        if !minimized { cached.removeValue(forKey: session.id)?.close(); recency.removeAll { $0 == session.id } }
    }

    /// 先关闭浮窗列表，等sheet真正退出后才开始下一层呈现。
    func selectFloat(_ record: MiniAppFloatRecord) {
        guard !busy, store?.isLoading == false, store?.isBusy == false else {
            feedback = "应用正在更新，请稍后再试"; return
        }
        pendingFloat = record; showsFloats = false
    }
    func floatListDismissed() {
        guard let selected = pendingFloat else { return }
        restoreTask?.cancel()
        restoreTask = Task { [weak self] in await self?.prepareRestore(selected) }
    }

    /// 浮窗表没有访问密码字段，必须从当前服务端列表重新确认应用资格。
    private func prepareRestore(_ selected: MiniAppFloatRecord) async {
        guard valid, let store, !store.isLoading, !store.isBusy else { pendingFloat = nil; feedback = "应用正在更新，请稍后再试"; return }
        let run = revision; busy = true; feedback = nil
        defer { if run == revision { busy = false } }
        await store.refresh()
        guard run == revision, valid, !Task.isCancelled else { return }
        if let error = store.feedback { feedback = error; pendingFloat = nil; return }
        while store.hasMore && !store.items.contains(where: { $0.id == selected.id }) {
            await store.loadMore()
            guard run == revision, valid, !Task.isCancelled else { return }
            if let error = store.feedback { feedback = error; pendingFloat = nil; return }
        }
        guard let record = store.items.first(where: { $0.id == selected.id }) else {
            feedback = "此应用已不可用，可从浮窗列表移除"; pendingFloat = nil; return
        }
        if record.passwordEnabled { passwordRequest = record }
        else {
            do {
                let detail = try await store.detail(id: record.id)
                guard run == revision, valid, !Task.isCancelled else { return }
                // 查询期间开启密码时仍必须重新验证。
                if detail.passwordEnabled { passwordRequest = detail }
                else { pendingFloat = nil; open(detail, restoring: selected) }
            } catch { if run == revision, valid { feedback = error.localizedDescription; pendingFloat = nil } }
        }
    }

    /// 密码弹层关闭后再恢复网页，避免两个呈现竞争。
    private var unlockedRestore: MiniAppRecord?
    func acceptRestore(_ record: MiniAppRecord) { unlockedRestore = record; passwordRequest = nil }
    func passwordDismissed() {
        defer { unlockedRestore = nil; pendingFloat = nil }
        guard let record = unlockedRestore, valid else { return }
        open(record, restoring: pendingFloat)
    }

    /// 应用删除或编辑后丢弃旧网页，避免再打开已改名/改密/改地址的缓存实例。
    func invalidate(id: String) {
        cached.removeValue(forKey: id)?.close(); recency.removeAll { $0 == id }
        if active?.id == id { active = nil }
    }
    func removeFloat(id: String) {
        guard valid, let context else { return }
        do { try floatClient.delete(id: id, context: context); floats.removeAll { $0.id == id }; invalidate(id: id) }
        catch { feedback = error.localizedDescription }
    }
    func clearFloats() {
        guard valid, let context else { return }
        do {
            try floatClient.clear(context: context); floats = []
            for session in cached.values { session.close() }; cached = [:]; recency = []; active = nil
        } catch { feedback = error.localizedDescription }
    }
    var valid: Bool { context.map { ChatRuntime.shared.isCurrent($0) } == true }

    /// 只销毁本轮内存与Cookie，不在旧身份失效后写入下一账号数据库。
    func close() {
        revision = UUID(); restoreTask?.cancel(); restoreTask = nil
        store?.close(); store = nil; active = nil
        for session in cached.values { session.close() }
        cached = [:]; recency = []; floats = []; context = nil
        pendingFloat = nil; passwordRequest = nil; unlockedRestore = nil; showsFloats = false
        busy = false; feedback = nil; dataStore = WKWebsiteDataStore.nonPersistent()
    }
}
