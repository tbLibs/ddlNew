import Foundation

@main
struct MaintenanceChecks {
    @MainActor static func main() async {
        var count = 0
        func check(_ value: Bool, _ label: String) {
            precondition(value, label); count += 1
        }
        func settle() async { for _ in 0..<20 { await Task.yield() }; try? await Task.sleep(nanoseconds: 5_000_000) }
        var requests = 0
        var validities: [@MainActor () -> Bool] = []
        let engine = SessionMaintenanceEngine(interval: { 60_000_000_000 }) { current in
            requests += 1
            validities.append(current)
        }
        engine.setAuthenticated(true)
        engine.start(identity: "club:user1", requiresAuthentication: true)
        await settle()
        check(requests == 1, "AUTH 后立即刷新")
        engine.refreshNow(); await settle()
        check(requests == 2, "主动刷新立即唤醒周期等待")
        check(!validities[0](), "主动新轮撤销旧结果权限")
        engine.setForegroundActive(false); await settle()
        check(!validities.last!(), "后台使旧回调失效")
        engine.refreshNow(); await settle()
        check(requests == 2, "后台不发请求")
        engine.setForegroundActive(true); await settle()
        check(requests == 3, "回前台立即刷新")
        engine.setAuthenticated(false); await settle()
        check(!validities.last!(), "断开 AUTH 撤销旧结果")
        engine.refreshNow(); await settle()
        check(requests == 3, "未 AUTH 不刷新用户资料")
        engine.setAuthenticated(true); await settle()
        check(requests == 4, "AUTH 恢复立即刷新")
        let old = validities.last!
        engine.start(identity: "club:user2", requiresAuthentication: true); await settle()
        check(!old(), "换账号撤销旧轮次")
        check(requests == 5, "新账号单独启动")
        engine.stop(); await settle()
        check(!validities.last!(), "退出撤销结果")
        engine.refreshNow(); await settle()
        check(requests == 5, "退出不重启任务")
        engine.setAuthenticated(false)
        engine.start(identity: "guest", requiresAuthentication: false); await settle()
        check(requests == 6, "访客配置刷新无需 AUTH")
        engine.stop()
        var delayedRequests = 0
        var pending: CheckedContinuation<Void, Never>?
        let delayed = SessionMaintenanceEngine(interval: { 60_000_000_000 }) { _ in
            delayedRequests += 1
            if delayedRequests == 1 { await withCheckedContinuation { pending = $0 } }
        }
        delayed.start(identity: "guest", requiresAuthentication: false); await settle()
        delayed.refreshNow(); delayed.refreshNow(); await settle()
        check(delayedRequests == 1, "多个通知不重叠请求")
        pending?.resume(); pending = nil; await settle()
        check(delayedRequests == 2, "重叠通知合并一轮补读")
        delayed.stop()
        var periodic = 0
        let timer = SessionMaintenanceEngine(interval: { 10_000_000 }) { _ in periodic += 1 }
        timer.start(identity: "guest", requiresAuthentication: false)
        try? await Task.sleep(nanoseconds: 50_000_000)
        check(periodic >= 2, "定时周期确实再次触发")
        timer.stop()
        print("SessionMaintenance: \(count) checks passed")
    }
}
