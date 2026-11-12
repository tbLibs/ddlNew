import UIKit

/// 本地消息完成布局后，让其提交到屏幕，再放行SDK远端历史的同步准备阶段。
/// 按屏幕刷新回调推进，不依赖固定毫秒延迟；离开页面会释放等待和display link。
@MainActor final class ChatCachedPresentation: NSObject {
    private var completed = false
    private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]
    private var displayLink: CADisplayLink?
    private var frames = 0

    func wait() async {
        guard !completed, !Task.isCancelled else { return }
        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if completed || Task.isCancelled { continuation.resume() }
                else { waiters[id] = continuation }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.waiters.removeValue(forKey: id)?.resume() }
        }
    }

    func rendered() {
        guard !completed, displayLink == nil else { return }
        frames = 0
        let link = CADisplayLink(target: self, selector: #selector(frame))
        displayLink = link
        link.add(to: .main, forMode: .common)
    }

    @objc private func frame() {
        frames += 1
        guard frames >= 2 else { return }
        completed = true
        finish()
    }

    func reset() { completed = false; finish() }

    private func finish() {
        displayLink?.invalidate(); displayLink = nil
        let pending = waiters.values; waiters.removeAll()
        for waiter in pending { waiter.resume() }
    }
}
