import Foundation
import CoreGraphics

@main struct ViewportChecks {
    /// 不依赖容器出现事件，直接验证最新锚点和缩小前后可见区关系。
    static func main() {
        let viewport = CGRect(x: 0, y: 0, width: 390, height: 500)
        precondition(ChatViewportPolicy.isAtBottom(latest: CGRect(x: 0, y: 485, width: 358, height: 1), viewport: viewport))
        precondition(ChatViewportPolicy.isAtBottom(latest: CGRect(x: 0, y: 515, width: 358, height: 1), viewport: viewport))
        precondition(!ChatViewportPolicy.isAtBottom(latest: CGRect(x: 0, y: 900, width: 358, height: 1), viewport: viewport))
        precondition(!ChatViewportPolicy.isAtBottom(latest: CGRect(x: 0, y: -10, width: 358, height: 1), viewport: viewport))
        precondition(!ChatViewportPolicy.isAtBottom(latest: .zero, viewport: viewport))
        precondition(!ChatViewportPolicy.isAtBottom(latest: CGRect(x: 0, y: 485, width: 358, height: 1), viewport: .zero))
        precondition(!ChatViewportPolicy.isAtBottom(latest: CGRect(x: 0, y: 485, width: 358, height: 1), viewport: CGRect(x: 0, y: 0, width: 390, height: 250)))
        print("Viewport checks: 7 passed")
    }
}
