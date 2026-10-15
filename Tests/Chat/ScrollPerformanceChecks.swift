import SwiftUI

// 只替代SwiftUI状态写入与SDK边界，滚动回调和可见判断执行生产源码。
@MainActor enum ScrollWrites { static var count = 0 }
@propertyWrapper @MainActor struct Tracked<Value> {
    private var value: Value
    init(wrappedValue: Value) { value = wrappedValue }
    var wrappedValue: Value {
        get { value }
        set { value = newValue; ScrollWrites.count += 1 }
    }
}
@MainActor final class ScrollStore {
    var context: Int? = 1
    var isAtBottom = false
    var visible: Set<String> = []
    var marked: [String] = []
    func setVisibleMessageIDs(_ ids: Set<String>) { visible = ids }
    func markVisible(_ id: String) async { marked.append(id) }
}
@main struct ScrollPerformanceChecks {
    @MainActor static func main() async {
        var failures: [String] = []
        func check(_ value: Bool, _ name: String) { if !value { failures.append(name); print("FAIL: " + name) } }
        let screen = ProductionScroll()
        screen.followsInitialLatest = false
        // 100条普通消息：前5条实际可见，其余在视口外。
        func frames(_ offset: CGFloat) -> [String: CGRect] {
            Dictionary(uniqueKeysWithValues: (0..<100).map { index in
                ("m\(index)", CGRect(x: 0, y: CGFloat(index * 110) - offset, width: 358, height: 90))
            })
        }
        screen.framesChanged(frames(0))
        await drain(screen.store, count: 5)
        check(screen.store.visible == ["m0", "m1", "m2", "m3", "m4"], "首个视口保留实际可见正文")
        screen.store.marked.removeAll(); ScrollWrites.count = 0
        for step in 1...240 {
            let offset = CGFloat(step) / 240 * 9
            screen.dragChanged()
            screen.framesChanged(frames(offset))
            screen.latestChanged(.init(frame: CGRect(x: 0, y: 11000 - offset, width: 358, height: 1), lastMessageID: "m99"))
        }
        for _ in 0..<30 { await Task.yield() }
        print("240次同可见集合几何回调：页面状态写入=\(ScrollWrites.count)，重复已读调用=\(screen.store.marked.count)")
        check(ScrollWrites.count == 0, "同一可见集合内的逐像素滚动不触发整页状态更新")
        check(screen.store.marked.isEmpty, "同一可见集合内不逐帧重复创建已读任务")
        screen.framesChanged(frames(110))
        await drain(screen.store, count: 5)
        check(screen.store.visible == ["m1", "m2", "m3", "m4", "m5"], "滚动跨消息边界立即更新可见正文")
        screen.viewport = CGRect(x: 0, y: 0, width: 390, height: 200)
        screen.updateVisibleMessages()
        check(screen.store.visible == ["m1", "m2"], "键盘缩小视口不把屏外正文上报已读")
        screen.initialMessagesReady = false
        screen.updateVisibleMessages()
        check(screen.store.visible.isEmpty, "首屏定位未完成时撤销可见资格")
        let metadata = ProductionScroll()
        metadata.followsInitialLatest = false
        metadata.framesChanged(frames(0))
        await drain(metadata.store, count: 5)
        metadata.store.marked.removeAll()
        metadata.updateVisibleMessages(recheck: true)
        await drain(metadata.store, count: 5)
        check(Set(metadata.store.marked) == ["m0", "m1", "m2", "m3", "m4"], "可见ID未变但服务器身份补齐时仍重查已读")
        metadata.store.marked.removeAll()
        metadata.dragEnded()
        await drain(metadata.store, count: 5)
        check(Set(metadata.store.marked) == ["m0", "m1", "m2", "m3", "m4"], "已读失败后，同一视口内再次滑动结束仍有重试机会")
        let stale = ProductionScroll()
        stale.followsInitialLatest = false
        stale.framesChanged(frames(0))
        stale.store.context = 2
        for _ in 0..<30 { await Task.yield() }
        check(stale.store.marked.isEmpty, "旧可见任务不能进入变化后的会话")
        let dates = ProductionDates()
        dates.records = (0..<100).map { index in
            ChatMessageRecord(id: "m\(index)", timestamp: 1_767_268_800_000 + (index < 50 ? 0 : 86_400_000))
        }
        let divisions = dates.results()
        check(divisions.enumerated().filter { $0.element }.map { $0.offset } == [0, 50], "日期只在首条和跨日处展示")
        print("100条消息日期展示：全量快照读取=\(dates.snapshotReads)")
        check(dates.snapshotReads == 0, "每行日期判断直接使用相邻记录，不重复过滤和扫描全部历史")
        if !failures.isEmpty { exit(1) }
        print("滚动生产回调检查：11项通过")
    }
    @MainActor static func drain(_ store: ScrollStore, count: Int) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while store.marked.count < count && ContinuousClock.now < deadline { await Task.yield() }
    }
}
