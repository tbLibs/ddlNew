//
//  ChatPhotoBrowser.swift
//  ddlNew
//

import SwiftUI
import JXPhotoBrowser

/// 按官方 SwiftUI 桥接方式使用 JXPhotoBrowser；业务状态仍由 SwiftUI 持有。
struct ChatPhotoBrowser: UIViewControllerRepresentable {
    let items: [ChatMessageRecord]
    let currentID: String
    let resources: ChatPhotoBrowserResources
    let playback: ChatPhotoBrowserPlayback
    let isActive: Bool
    let onSelect: (String) -> Void
    let onTapImage: () -> Void
    let onClose: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> ChatPhotoBrowserController {
        let browser = ChatPhotoBrowserController()
        let coordinator = context.coordinator
        browser.delegate = coordinator
        browser.initialIndex = items.firstIndex(where: { $0.id == currentID }) ?? 0
        browser.isLoopingEnabled = false
        browser.isAutoPlayEnabled = false
        browser.transitionType = .none
        browser.itemSpacing = 16
        browser.overrideUserInterfaceStyle = .dark
        browser.onClose = { [weak coordinator] in coordinator?.parent.onClose() }
        browser.register(ChatPhotoBrowserImageCell.self, forReuseIdentifier: ChatPhotoBrowserImageCell.cellIdentifier)
        browser.register(ChatPhotoBrowserVideoCell.self, forReuseIdentifier: ChatPhotoBrowserVideoCell.cellIdentifier)
        let observer = ChatPhotoBrowserPageObserver()
        observer.onChange = { [weak coordinator] index in coordinator?.didSelect(index) }
        browser.addOverlay(observer)
        return browser
    }

    func updateUIViewController(_ browser: ChatPhotoBrowserController, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        // 缓存历史插到前面时按消息身份定位；下载/进度变化只更新可见 Cell，不重载分页。
        if coordinator.selection.ids != items.map(\.id) {
            coordinator.selection.replace(items.map(\.id))
            coordinator.items = items
            coordinator.isReloading = true
            browser.initialIndex = coordinator.selection.index
            browser.reloadData(preservingCurrentPage: false)
            coordinator.isReloading = false
            if coordinator.selection.selectedID != currentID { coordinator.publishSelection(coordinator.selection.selectedID) }
        } else {
            coordinator.items = items
        }
        coordinator.refreshVisibleCells(in: browser)
    }

    static func dismantleUIViewController(_ browser: ChatPhotoBrowserController, coordinator: Coordinator) {
        coordinator.isAttached = false
        browser.isDismissGestureEnabled = false
        browser.delegate = nil
        browser.onClose = nil
        for cell in browser.collectionView.visibleCells {
            (cell as? ChatPhotoBrowserImageCell)?.clear()
            (cell as? ChatPhotoBrowserVideoCell)?.clear()
        }
    }

    @MainActor final class Coordinator: NSObject, @preconcurrency JXPhotoBrowserDelegate {
        var parent: ChatPhotoBrowser
        var items: [ChatMessageRecord]
        var selection: ChatPhotoBrowserSelection
        var isReloading = false
        var isAttached = true

        init(_ parent: ChatPhotoBrowser) {
            self.parent = parent
            items = parent.items
            selection = ChatPhotoBrowserSelection(ids: parent.items.map(\.id), selectedID: parent.currentID)
        }

        func numberOfItems(in browser: JXPhotoBrowserViewController) -> Int { items.count }

        func photoBrowser(_ browser: JXPhotoBrowserViewController, cellForItemAt index: Int, at indexPath: IndexPath) -> JXPhotoBrowserAnyCell {
            let identifier = items[index].type == 2 ? ChatPhotoBrowserVideoCell.cellIdentifier : ChatPhotoBrowserImageCell.cellIdentifier
            let cell = browser.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath)
            configure(cell, index: index, browser: browser)
            return cell
        }

        func photoBrowser(_ browser: JXPhotoBrowserViewController, willDisplay cell: JXPhotoBrowserAnyCell, at index: Int) {
            configure(cell, index: index, browser: browser)
        }

        func photoBrowser(_ browser: JXPhotoBrowserViewController, didEndDisplaying cell: JXPhotoBrowserAnyCell, at index: Int) {
            (cell as? ChatPhotoBrowserImageCell)?.clear()
            (cell as? ChatPhotoBrowserVideoCell)?.clear()
        }

        func didSelect(_ index: Int) {
            guard isAttached, !isReloading, let id = selection.select(index: index) else { return }
            publishSelection(id)
        }

        func publishSelection(_ id: String) {
            guard !id.isEmpty else { return }
            // 框架会在布局/重载时同步通知，下一主线程任务才写回 SwiftUI；丢弃快滑的旧页回调。
            Task { @MainActor [weak self] in
                guard let self, self.isAttached, self.selection.selectedID == id else { return }
                self.parent.onSelect(id)
            }
        }

        func refreshVisibleCells(in browser: JXPhotoBrowserViewController) {
            for cell in browser.collectionView.visibleCells {
                guard let indexPath = browser.collectionView.indexPath(for: cell),
                      let mediaCell = cell as? JXPhotoBrowserAnyCell else { continue }
                configure(mediaCell, index: browser.realIndex(fromVirtual: indexPath.item), browser: browser)
            }
        }

        private func configure(_ cell: JXPhotoBrowserAnyCell, index: Int, browser: JXPhotoBrowserViewController) {
            guard items.indices.contains(index) else { return }
            let message = items[index]
            let preview = parent.resources.previews[message.id]
            let active = parent.isActive && message.id == selection.selectedID
            if let image = cell as? ChatPhotoBrowserImageCell {
                image.onTap = parent.onTapImage
                image.configure(message: message, preview: preview, isActive: active, isForeground: parent.isActive)
            } else if let video = cell as? ChatPhotoBrowserVideoCell {
                let player = preview.flatMap { $0.isInvalidated ? nil : $0.file }.flatMap { parent.playback.preparedPlayers[$0] }
                video.configure(message: message, player: player, isActive: active,
                                isHidden: !parent.isActive || preview?.isInvalidated == true, browser: browser)
            }
        }
    }
}

/// 库的下拉关闭回写 SwiftUI 绑定，由透明呈现容器统一退出。
final class ChatPhotoBrowserController: JXPhotoBrowserViewController {
    var onClose: (() -> Void)?
    override func dismissSelf() { onClose?() }
}

/// 框架使用 Overlay 发布落定页码；只监听事件，不增加可见页码控件。
private final class ChatPhotoBrowserPageObserver: UIView, JXPhotoBrowserOverlay {
    var onChange: ((Int) -> Void)?
    func setup(with browser: JXPhotoBrowserViewController) { isUserInteractionEnabled = false; isHidden = true }
    func reloadData(numberOfItems: Int, pageIndex: Int) { if numberOfItems > 0 { onChange?(pageIndex) } }
    func didChangedPageIndex(_ index: Int) { onChange?(index) }
}
