//
//  ChatPhotoBrowserResources.swift
//  ddlNew
//
//  Created by taobo on 2026/10/19.
//

import Foundation
import Combine

/// 画廊只保留当前和左右各一页；下载不依赖浏览器邻页何时出现。
@MainActor final class ChatPhotoBrowserResources: ObservableObject {
    @Published private(set) var current = ChatRuntime.shared.makePreviewStore()
    private(set) var previews: [String: ChatMediaPreviewStore] = [:]
    private var loads: [String: Task<Void, Never>] = [:]
    private var observations: [String: AnyCancellable] = [:]
    private var warmups: [String: () -> Void] = [:]
    private let warmImage: (URL) -> (() -> Void)

    private let warmVideo: (URL) -> (() -> Void)

    init(warmImage: @escaping (URL) -> (() -> Void), warmVideo: @escaping (URL) -> (() -> Void) = { _ in {} }) {
        self.warmImage = warmImage; self.warmVideo = warmVideo
    }

    /// 按稳定消息身份平移三页窗口；已加载邻页成为当前页时复用同一 Store 和文件。
    func prepare(items: [ChatMessageRecord], currentID: String, context: ChatContext) {
        guard ChatRuntime.shared.isCurrent(context), let index = items.firstIndex(where: { $0.id == currentID }) else { close(); return }
        let window = Array(items[max(0, index - 1)...min(items.count - 1, index + 1)])
        let retained = Set(window.map(\.id))
        for id in Array(previews.keys) where !retained.contains(id) {
            loads.removeValue(forKey: id)?.cancel()
            warmups.removeValue(forKey: id)?()
            observations.removeValue(forKey: id)?.cancel()
            previews.removeValue(forKey: id)?.close()
        }
        for message in window {
            if previews[message.id] == nil {
                let preview = ChatRuntime.shared.makePreviewStore()
                previews[message.id] = preview
                observations[message.id] = preview.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
            }
            // 图片和视频都提前准备，仍限制为当前与左右各一页。
            start(message, context: context)
        }
        if let selected = previews[currentID], current !== selected { current = selected }
        objectWillChange.send()
        ChatRuntime.shared.registerCleanup(owner: self, conversationID: context.route.id) { [weak self] in self?.close() }
    }

    /// 等待已存在的准备任务，不因翻页再次下载；调用者取消不取消仍有用的邻页。
    func waitForLoad(_ id: String) async { await loads[id]?.value }

    /// 只有显式重试才重新加载同一页，删除后的 Store 仍按原规则拒绝恢复附件。
    func retry(_ message: ChatMessageRecord, context: ChatContext) {
        loads.removeValue(forKey: message.id)?.cancel()
        warmups.removeValue(forKey: message.id)?()
        previews[message.id]?.close()
        start(message, context: context)
    }

    private func start(_ message: ChatMessageRecord, context: ChatContext) {
        guard loads[message.id] == nil, let preview = previews[message.id] else { return }
        loads[message.id] = Task { [weak self, weak preview] in
            guard let preview else { return }
            await preview.load(message, context: context)
            guard !Task.isCancelled, ChatRuntime.shared.isCurrent(context), !preview.isInvalidated,
                  let file = preview.file, let self,
                  self.previews[message.id] === preview else { return }
            self.warmups[message.id] = message.type == 2 ? self.warmVideo(file) : self.warmImage(file)
        }
    }

    /// 后台、关闭或会话失效统一取消整个窗口，不能遗留邻页下载。
    func close() {
        loads.values.forEach { $0.cancel() }; loads.removeAll()
        warmups.values.forEach { $0() }; warmups.removeAll()
        observations.removeAll()
        previews.values.forEach { $0.close() }; previews.removeAll()
        current.close()
        objectWillChange.send()
    }
}
