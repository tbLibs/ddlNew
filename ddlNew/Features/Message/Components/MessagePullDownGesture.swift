import SwiftUI
import UIKit

/// 观察List原有的pan，不替换delegate、不增加抢占横向菜单的识别器。
struct MessagePullDownGesture: UIViewRepresentable {
    let state: MessagePullDownState
    let onBegin: () -> Void

    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ view: Probe, context: Context) {
        context.coordinator.state = state
        context.coordinator.onBegin = onBegin
        view.attach()
    }

    func makeCoordinator() -> Coordinator { Coordinator(state: state, onBegin: onBegin) }
    static func dismantleUIView(_ view: Probe, coordinator: Coordinator) { coordinator.detach() }

    final class Probe: UIView {
        weak var coordinator: Coordinator?
        override func didMoveToWindow() { super.didMoveToWindow(); attach() }
        override func didMoveToSuperview() { super.didMoveToSuperview(); attach() }
        override func layoutSubviews() { super.layoutSubviews(); attach() }
        func attach() {
            guard window != nil else { coordinator?.detach(); return }
            var ancestor = superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView { coordinator?.attach(to: scroll); return }
                ancestor = view.superview
            }
        }
    }

    @MainActor final class Coordinator: NSObject {
        var state: MessagePullDownState
        var onBegin: () -> Void
        private weak var scroll: UIScrollView?
        private var originalBounce = false
        private var eligible = false
        private var pulling = false

        init(state: MessagePullDownState, onBegin: @escaping () -> Void) {
            self.state = state; self.onBegin = onBegin
        }

        func attach(to scroll: UIScrollView) {
            guard self.scroll !== scroll else { return }
            detach()
            self.scroll = scroll
            originalBounce = scroll.alwaysBounceVertical
            scroll.alwaysBounceVertical = true
            scroll.panGestureRecognizer.addTarget(self, action: #selector(panChanged(_:)))
        }

        func detach() {
            scroll?.panGestureRecognizer.removeTarget(self, action: #selector(panChanged(_:)))
            if let scroll { scroll.alwaysBounceVertical = originalBounce }
            scroll = nil; eligible = false
            if pulling { state.endPull(cancelled: true) }
            pulling = false
        }

        @objc private func panChanged(_ pan: UIPanGestureRecognizer) {
            guard let scroll else { return }
            let translation = pan.translation(in: scroll.window)
            switch pan.state {
            case .began:
                eligible = !state.isOpen && scroll.contentOffset.y + scroll.adjustedContentInset.top <= 1
                pulling = false
            case .changed:
                guard eligible, !state.isOpen else { return }
                if !pulling {
                    guard abs(translation.y) > 8 || abs(translation.x) > 8 else { return }
                    guard translation.y > abs(translation.x) else { eligible = false; return }
                    pulling = true
                    onBegin()
                }
                state.pull(translation.y)
            case .ended, .cancelled, .failed:
                if pulling { state.endPull(cancelled: pan.state != .ended) }
                eligible = false; pulling = false
            default: break
            }
        }
    }
}
