import SwiftUI

struct PositionMessage { let id: String }
struct PositionRoute { var targetMessageID: String? }
struct ChatLatestLayout: Equatable {
    var frame = CGRect.zero
    var lastMessageID: String?
}
@MainActor final class PositionStore {
    var isAtBottom = true
    var isVisible = true
    var isForeground = true
    var messages = [PositionMessage(id: "latest")]
    func returnToLatest() { isAtBottom = true }
}
@MainActor final class PositionProxy {
    var targets: [String] = []
    func scrollTo(_ id: String, anchor: UnitPoint) { targets.append(id) }
}
@main struct InitialPositionChecks {
    @MainActor static func main() {
        var failed: [String] = []
        func check(_ value: Bool, _ name: String) {
            if !value { failed.append(name); print("FAIL: " + name) }
        }
        let screen = ProductionInitialPosition(); let proxy = PositionProxy()
        screen.changed("latest", proxy: proxy)
        check(!screen.didInitialScroll, "收到消息不等于首次布局已定位")
        screen.resizeFollowTask?.cancel(); screen.resizeFollowTask = nil
        screen.accept(ChatLatestLayout(frame: CGRect(x: 0, y: 1400, width: 358, height: 1), lastMessageID: "latest"), proxy: proxy)
        check(proxy.targets == ["latest"], "拿到实际布局后立即定位，无350毫秒等待")
        check(!screen.didInitialScroll, "底部未进入视口前不宣告已定位")
        screen.accept(ChatLatestLayout(frame: CGRect(x: 0, y: 485, width: 358, height: 1), lastMessageID: "old-batch"), proxy: proxy)
        check(!screen.didInitialScroll, "旧批次几何不能揭示新批次正文")
        screen.accept(ChatLatestLayout(frame: CGRect(x: 0, y: 485, width: 358, height: 1), lastMessageID: "latest"), proxy: proxy)
        check(screen.didInitialScroll && screen.store.isAtBottom, "当前批次底部就绪才完成首次定位")
        let count = proxy.targets.count
        screen.followsInitialLatest = false; screen.store.isAtBottom = false
        screen.accept(ChatLatestLayout(frame: CGRect(x: 0, y: 1800, width: 358, height: 1), lastMessageID: "latest"), proxy: proxy)
        check(proxy.targets.count == count, "用户翻历史后布局变化不拉回末尾")
        let search = ProductionInitialPosition(); let searchProxy = PositionProxy()
        search.route.targetMessageID = "target"
        search.accept(ChatLatestLayout(frame: CGRect(x: 0, y: 1400, width: 358, height: 1), lastMessageID: "latest"), proxy: searchProxy)
        check(searchProxy.targets.isEmpty, "显式搜索定位不被首次末尾对齐抢走")
        let hidden = ProductionInitialPosition(); let hiddenProxy = PositionProxy()
        hidden.store.isVisible = false
        hidden.accept(ChatLatestLayout(frame: CGRect(x: 0, y: 1400, width: 358, height: 1), lastMessageID: "latest"), proxy: hiddenProxy)
        check(hiddenProxy.targets.isEmpty, "离开页面后的布局不能滚动旧页")
        hidden.resume(proxy: hiddenProxy)
        check(hiddenProxy.targets == ["latest"], "隐藏时布局完成，返回同一会话仍主动重试定位")
        let sent = ProductionInitialPosition(); let sentProxy = PositionProxy()
        sent.pendingSendSuccessScroll = true
        sent.latestLayout = ChatLatestLayout(frame: CGRect(x: 0, y: 1400, width: 358, height: 1), lastMessageID: "latest")
        sent.positionSendSuccess(sentProxy)
        check(sentProxy.targets == ["latest"] && sent.pendingSendSuccessScroll,
              "发送成功后先跳到懒加载末尾，实际底部尚未进入视口时保留请求")
        sent.latestLayout = ChatLatestLayout(frame: CGRect(x: 0, y: 485, width: 358, height: 1), lastMessageID: "latest")
        sent.positionSendSuccess(sentProxy)
        check(sent.store.isAtBottom && !sent.pendingSendSuccessScroll,
              "末尾实际进入视口后才完成发送成功定位")
        screen.resizeFollowTask?.cancel(); search.resizeFollowTask?.cancel(); hidden.resizeFollowTask?.cancel()
        if !failed.isEmpty { exit(1) }
        print("首次定位生产回调检查：11项通过")
    }
}
