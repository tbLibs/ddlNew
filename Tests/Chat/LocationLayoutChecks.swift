//
//  LocationLayoutChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//

import SwiftUI
@MainActor final class LocationUIStore {
    var context: String? = "current"
    var locatedMessageID: String? = "old"
    var isAtBottom = true
    var isVisible = true
}
@MainActor final class LocationRuntime {
    func isCurrent(_ context: String) -> Bool { context == "current" }
}
@MainActor final class LocationProxy {
    var targets: [String] = []
    func scrollTo(_ id: String, anchor: UnitPoint) { targets.append(id) }
}
@main struct LocationLayoutChecks {
    @MainActor static func main() {
        var failures = 0
        func check(_ condition: Bool, _ name: String) { if !condition { failures += 1; print("FAIL: " + name) } }
        let screen = LocationScreen(), proxy = LocationProxy()
        screen.bannerTapped()
        check(screen.requested == ["server-old"] && !screen.showPinnedMessages, "沿旧端点击顶部置顶正文直接定位，列表按钮单独打开列表")
        screen.showPinnedMessages = false
        screen.resizeFollowTask = Task {}
        screen.changed(proxy)
        check(proxy.targets == ["old"] && screen.pendingLocatedMessageID == "old", "目标历史尚未布局时先按ID跳转，使懒加载行生成且保留定位请求")
        proxy.targets.removeAll()
        check(!screen.followsInitialLatest && !screen.store.isAtBottom && screen.resizeFollowTask == nil, "显式定位取消首屏及延迟底部跟随")
        screen.messageFrames = ["old": CGRect(x: 0, y: -600, width: 300, height: 50)]
        screen.showPinnedMessages = true
        screen.layoutReady(proxy)
        check(proxy.targets.isEmpty, "置顶弹层未关闭不滚动底层聊天")
        screen.showPinnedMessages = false; screen.store.isVisible = false
        screen.layoutReady(proxy)
        check(proxy.targets.isEmpty, "页面隐藏时等待恢复")
        screen.store.isVisible = true; screen.layoutReady(proxy)
        check(proxy.targets == ["old"] && screen.pendingLocatedMessageID == nil, "布局完成且弹层关闭后定位到实际消息并消费请求")
        screen.layoutReady(proxy)
        check(proxy.targets == ["old"], "后续几何变化不重复抢滚动")
        screen.changed(proxy)
        check(proxy.targets == ["old", "old"], "重复定位同一条仍主动滚动")
        let sheet = LocationScreen()
        sheet.selectFromSheet("server-old")
        check(sheet.requested.isEmpty, "列表选择等待实际关闭后再发起定位")
        sheet.sheetDismissed()
        check(sheet.requested == ["server-old"], "关闭后消费当前会话的选择")
        sheet.sheetDismissed()
        check(sheet.requested == ["server-old"], "取消或重复关闭不重播定位")
        sheet.selectFromSheet("stale")
        sheet.store.context = "other"
        sheet.sheetDismissed()
        check(sheet.requested == ["server-old"], "旧弹层选择不能定位新会话")
        if failures > 0 { exit(1) }
        print("消息定位布局检查：12项通过")
    }
}
