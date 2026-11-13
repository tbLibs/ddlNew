import SwiftUI
import Combine

/// 由主Tab持有，消息列表只发送手势；逐帧变化只由覆盖层订阅。
@MainActor final class MessagePullDownState: ObservableObject {
    static let openingDistance: CGFloat = 120
    @Published private(set) var reveal: CGFloat = 0
    @Published private(set) var isOpen = false
    private var height: CGFloat = 1
    var reduceMotion = false

    func resize(to value: CGFloat) {
        guard value > 0 else { return }
        height = value
        if isOpen { reveal = value }
        else { reveal = min(reveal, value) }
    }

    func pull(_ distance: CGFloat) {
        guard !isOpen else { return }
        reveal = min(height, max(0, distance))
    }

    func endPull(cancelled: Bool) {
        settle(open: !cancelled && reveal >= Self.openingDistance)
    }

    func open() { settle(open: true) }
    func close() { settle(open: false) }

    func dragUp(_ translation: CGFloat) {
        guard isOpen else { return }
        reveal = max(0, min(height, height + translation))
    }

    func endDragUp(translation: CGFloat, predicted: CGFloat) {
        settle(open: !(translation <= -80 || (translation < -20 && predicted <= -180)))
    }

    func reset() {
        var transaction = Transaction(animation: nil); transaction.disablesAnimations = true
        withTransaction(transaction) { isOpen = false; reveal = 0 }
    }

    private func settle(open: Bool) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.34, dampingFraction: 0.9)) {
            isOpen = open
            reveal = open ? height : 0
        }
    }
}

/// 覆盖在整个Tab容器上，从屏幕顶部进入；不是系统从底部弹出的sheet。
struct MessagePullDownPresentation: ViewModifier {
    @ObservedObject var state: MessagePullDownState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .accessibilityHidden(state.isOpen)
            .overlay {
                GeometryReader { outer in
                GeometryReader { geometry in
                    ZStack {
                        Rectangle().fill(MessagingTheme.surface)
                            .contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 12, coordinateSpace: .global)
                                .onChanged { state.dragUp($0.translation.height) }
                                .onEnded { state.endDragUp(translation: $0.translation.height,
                                                           predicted: $0.predictedEndTranslation.height) })
                            .accessibilityHidden(true)
                        QuickTranslationView(active: state.isOpen, onClose: state.close)
                            .padding(.top, outer.safeAreaInsets.top)
                            .padding(.bottom, max(0, geometry.size.height - outer.size.height - outer.safeAreaInsets.top))
                    }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(y: state.reveal - geometry.size.height)
                        .accessibilityElement(children: .contain)
                        .accessibilityHidden(!state.isOpen)
                        .onAppear { state.resize(to: geometry.size.height) }
                        .onChange(of: geometry.size.height) { state.resize(to: $0) }
                }
                .clipped()
                .ignoresSafeArea(.container)
                .allowsHitTesting(state.isOpen)
                }
            }
            .onAppear { state.reduceMotion = reduceMotion }
            .onChange(of: reduceMotion) { state.reduceMotion = $0 }
            .onChange(of: scenePhase) { if $0 == .background { state.reset() } }
    }
}
