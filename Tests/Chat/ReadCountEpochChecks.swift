import Foundation
#if READ_LEGACY_BASELINE
@main struct ReadCountEpochChecks {
    /// 用当前旧算法重现未知历史扣新计数及页面关闭丢失待扣身份。
    static func main() {
        var errors = 0
        var old = ChatVisibleReadTransitions(); old.saved("old-history")
        if old.remainingUnread(1) != 1 { print("FAIL: old historical false swallows new unread 1"); errors += 1 }
        var closing = ChatVisibleReadTransitions(); closing.saved("new-counted")
        closing = ChatVisibleReadTransitions()
        if closing.remainingUnread(1) != 0 { print("FAIL: close/reopen loses successful body-write pending debit"); errors += 1 }
        if errors != 0 { exit(1) }
    }
}
#else
@main struct ReadCountEpochChecks {
    static func main() {
        var ledger = ChatReadCountLedger()
        let auth = UUID()
        let route = ChatRoute(id: "g", kind: .group, title: "群", avatarURL: "")
        let context = ChatContext(userUID: "A", tenantID: "club", sessionID: auth, route: route)
        ledger.activate(userUID: "A", tenantID: "club", sessionID: auth)
        ledger.observe(context: context, count: 1, latestID: "10")
        let clearing = ledger.beginClear(context: context, boundaryID: "10")!
        ledger.confirmClear(clearing, context: context, count: 0, latestID: "10")
        ledger.received("20", context: context, count: 1, latestID: "20")
        precondition(!ledger.saved("10", context: context), "全清前/未知旧历史不进入当前扣减集合")
        precondition(ledger.plan(context: context, count: 1, latestID: "20") == nil, "旧false读状态不能吞屏外新1")
        precondition(ledger.saved("20", context: context))
        let beforeClose = ledger.plan(context: context, count: 1, latestID: "20")!
        precondition(beforeClose.remaining == 0)
        // 页面关闭不撤销AUTH的ledger；新的页面使用同认证身份生成上下文。
        let reopened = ChatContext(userUID: "A", tenantID: "club", sessionID: auth, route: ChatRoute(id: "g", kind: .group, title: "更新群名", avatarURL: "", targetMessageID: "20"))
        let afterClose = ledger.plan(context: reopened, count: 1, latestID: "20")!
        precondition(afterClose.ids == beforeClose.ids && afterClose.remaining == 0, "正文成功/会话失败后关闭再开仍补扣")
        ledger.commit(afterClose, context: reopened)
        precondition(ledger.plan(context: context, count: 0, latestID: "20") == nil)
        ledger.observe(context: context, count: 5, latestID: "30")
        precondition(!ledger.saved("unknown-initial", context: context))
        ledger.received("40", context: context, count: 6, latestID: "40")
        precondition(ledger.saved("40", context: context))
        precondition(ledger.plan(context: context, count: 6, latestID: "40")!.remaining == 5, "初始未知非零计数原样保留")
        ledger.observe(context: context, count: 0, latestID: "40")
        ledger.received("50", context: context, count: 1, latestID: "50")
        precondition(ledger.plan(context: context, count: 1, latestID: "50") == nil, "SDK全清后的旧债不能扣新epoch")
        precondition(!ledger.saved("40", context: context))
        precondition(ledger.saved("50", context: context))
        let obsolete = ledger.plan(context: context, count: 1, latestID: "50")!
        ledger.observe(context: context, count: 0, latestID: "50")
        ledger.received("60", context: context, count: 1, latestID: "60")
        ledger.commit(obsolete, context: context)
        precondition(ledger.saved("60", context: context), "旧epoch写入回执不能消费新epoch成员")
        let lateClear = ledger.beginClear(context: context, boundaryID: "60")!
        ledger.received("70", context: context, count: 2, latestID: "70")
        ledger.confirmClear(lateClear, context: context, count: 1, latestID: "70")
        precondition(!ledger.saved("60", context: context) && ledger.saved("70", context: context), "全清请求等待期间的新成员保留")
        precondition(ledger.plan(context: context, count: 1, latestID: "70")!.remaining == 0)
        let delayed = ChatContext(userUID: "A", tenantID: "club", sessionID: auth, route: ChatRoute(id: "late", kind: .single, title: "", avatarURL: ""))
        ledger.observe(context: delayed, count: 1, latestID: "100")
        precondition(!ledger.saved("100", context: delayed), "来源事件尚未到达时不预扣")
        ledger.received("100", context: delayed, count: 1, latestID: "100")
        precondition(ledger.plan(context: delayed, count: 1, latestID: "100")!.remaining == 0, "正文先保存/真实来源后到仍恢复待扣")
        let earlier = ledger.beginClear(context: delayed, boundaryID: "100")!
        ledger.observe(context: delayed, count: 0, latestID: "200")
        ledger.confirmClear(earlier, context: delayed, count: 1, latestID: "300")
        ledger.observe(context: delayed, count: 0, latestID: "100")
        ledger.received("150", context: delayed, count: 1, latestID: "150")
        precondition(!ledger.saved("150", context: delayed), "迟到全清回执不能倒退SDK归零的更新边界")
        ledger.received("400", context: delayed, count: 2, latestID: "400")
        precondition(ledger.saved("400", context: delayed))
        ledger.authoritative(context: delayed, count: 1, latestID: "500")
        precondition(ledger.plan(context: delayed, count: 1, latestID: "500") == nil, "权威count替换不把旧债算作新计数成员")
        ledger.received("600", context: delayed, count: 2, latestID: "600")
        ledger.saved("600", context: delayed)
        precondition(ledger.plan(context: delayed, count: 2, latestID: "600")!.remaining == 1)
        let oldAuth = context
        ledger.activate(userUID: "A", tenantID: "club", sessionID: UUID())
        precondition(!ledger.saved("70", context: oldAuth))
        precondition(ledger.plan(context: oldAuth, count: 1, latestID: "70") == nil, "同UID旧AUTH不能读取新计数债")
        ledger.deactivate()
        precondition(ledger.beginClear(context: oldAuth, boundaryID: "70") == nil)
        print("Read count epoch checks: 27 passed")
    }
}
#endif
