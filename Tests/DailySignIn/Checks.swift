import Foundation

@MainActor final class FakeSignInClient: DailySignInClient {
    var signed = false
    var enabled = true
    var submissions = 0
    var fail = false
    var failAfterSign = false
    var suspend = false
    var suspendSign = false
    var pending: CheckedContinuation<Void, Never>?
    func info(context: ChatContext) async throws -> DailySignInInfo {
        if suspend { await withCheckedContinuation { pending = $0 } }
        if fail { throw DailySignInError.invalidResponse }
        return DailySignInInfo(signed: signed, todayPoints: "3", totalDays: 2, totalPoints: 6, monthDays: 2)
    }
    func records(month: SignInMonth, context: ChatContext) async throws -> DailySignInRecords { DailySignInRecords(total: 6, rows: []) }
    func points(month: SignInMonth, context: ChatContext) async throws -> DailySignInPoints { DailySignInPoints(used: 0, gained: 6, rows: []) }
    func rule(context: ChatContext) async throws -> DailySignInRule { DailySignInRule(enabled: enabled, mode: 1, daily: 0, minimum: 1, maximum: 5, description: "", rewards: []) }
    func sign(context: ChatContext) async throws -> Int64? {
        submissions += 1
        if !enabled { throw DailySignInError.message("系统未开启签到功能") }
        if suspendSign { await withCheckedContinuation { pending = $0 } }
        signed = true; fail = failAfterSign; return 3
    }
    func reminders(sessionID: String, offset: Int, context: ChatContext) throws -> [DailySignInReminder] { [] }
    func cancel() {}
}

@main struct DailySignInChecks {
    @MainActor static func main() async throws {
        var count = 0
        func check(_ condition: Bool, _ label: String) { precondition(condition, label); count += 1 }
        let info: [String: Any] = ["isSignIn": "1", "loyalty": "12", "signTotalDay": 10, "signTotalLoyalty": "9223372036854775806", "monthTotalDay": "3"]
        let parsed = try DailySignInInfo.parse(info)
        check(parsed.signed && parsed.totalPoints == 9223372036854775806, "数字字符串及64位积分")
        // 真机捕获：随机模式未签到时，loyalty是展示区间，不是整型奖励。
        var randomInfo = info
        randomInfo["isSignIn"] = 0
        randomInfo["loyalty"] = "100-200"
        do {
            let random = try DailySignInInfo.parse(randomInfo)
            check(!random.signed && String(random.todayPoints) == "100-200", "随机模式保留服务端积分区间")
        } catch {
            print("FAIL: 打开随机签到详情：\(error.localizedDescription)")
            exit(1)
        }
        check(try SignInPayload.pointsText(100) == "100", "固定积分兼容JSON数字")
        check(try SignInPayload.pointsText("100") == "100", "已签到积分兼容数字字符串")
        check((try? SignInPayload.pointsText(NSNull())) == nil && (try? SignInPayload.pointsText(" ")) == nil, "空积分展示值仍拒绝")
        check((try? SignInPayload.pointsText(true)) == nil, "布尔不能伪造积分展示")
        var badTotal = randomInfo; badTotal["signTotalLoyalty"] = "100-200"
        check((try? DailySignInInfo.parse(badTotal)) == nil, "区间仅限今日可领展示，不放宽累计积分")
        check((try? DailySignInInfo.parse([:])) == nil, "空详情不能伪造未签到")
        check((try? SignInPayload.integer(true)) == nil, "布尔不能作为积分")
        check(try SignInPayload.flag(true), "开关兼容JSON布尔")
        check((try? SignInPayload.integer(1.5)) == nil, "非法小数不能截断")
        check(try SignInPayload.receipt(["loyalty": "bad"]) == nil, "成功受理的坏奖励不误报失败")
        do { _ = try SignInPayload.receipt(false); preconditionFailure("拒绝回执被接受") } catch { count += 1 }
        check((try? DailySignInRecords.parse(["signInRecords": [[:]], "totalLoyalty": 0])) == nil, "坏记录不能静默丢弃")
        let rule = try DailySignInRule.parse(["signInSwitch": 1, "signMode": 2, "signDayMoney": "2", "signContinueReward": "{\"10\":20,\"2\":3}"])
        check(rule.rewards.map(\.days) == [2, 10], "连签奖励按数值排序")
        check(try DailySignInRule.parse(["signInSwitch": 0]).enabled == false, "关闭不要求奖励字段")
        let disabledRule = try DailySignInRule.parse(["signInSwitch": 0, "signMode": 1, "signMinMoney": 100, "signMaxMoney": 200, "signRandomRule": "服务端自定义文本"])
        check(!disabledRule.enabled && disabledRule.content == "1、每日签到积分由管理员设置一个最低值和最高值（例如区间值100～200），点击签到按钮后，即可获得本日签到积分。\n2、每日最多可签到1次，重复签到不会重复计数。\n3、积分只限本人使用，不可转移至其他账户。", "关闭时仍按xgd展示随机规则完整三条及配置区间")
        check(rule.content == "1、每日签到可以获得固定日签积分(2分)，连续签到可以获得连签奖励。\n2、每日最多可签到1次，重复签到不会重复计数。\n3、当连续签到中断后，之前攒下的积分会保留，不会清零，但会重新累计连续签到天数。\n4、只要连签天数满足当月连续签到成功天数设置最大值，之后用户连签的每一天都将额外获得连签最大值的奖励积分。\n5、积分只限用户本人使用，不可转移至其他账户。", "连签规则逐字对齐xgd五条")
        let point = try DailySignInPoints.parse(["useIntegral": 2, "gainIntegral": 4, "integralRecordVos": [["createTime": "1794240000000", "money": 2, "opeType": 18]]])
        check(point.rows.first?.amount == "−2", "系统扣减显示负数")
        let context = ChatContext(userUID: "a", tenantID: "t", sessionID: UUID(), route: ChatRoute(id: "a", kind: .single, title: "", avatarURL: ""))
        let client = FakeSignInClient(), store = DailySignInStore(context: context, client: FakeSignInClient(), isCurrent: { _ in true })
        check(!store.canSign, "未加载不允许签到")
        let subject = DailySignInStore(context: context, client: client, isCurrent: { _ in true })
        await subject.refresh(); check(subject.canSign, "真实配置就绪允许签到")
        await subject.sign(); await subject.sign()
        check(client.submissions == 1 && subject.signed, "成功后不重复提交")
        client.signed = false; await subject.refresh()
        check(subject.signed && !subject.canSign, "同日旧详情不能撤销刚受理的签到")
        let failingClient = FakeSignInClient(), failing = DailySignInStore(context: context, client: failingClient, isCurrent: { _ in true })
        await failing.refresh(); let originalMonth = failing.month
        failingClient.fail = true; await failing.refresh(month: originalMonth.shifted(-1))
        check(failing.month == originalMonth && failing.info != nil && failing.error != nil, "失败保留旧月及旧数据")
        failingClient.fail = false; await failing.refresh(); failingClient.failAfterSign = true; await failing.sign()
        check(failing.signed && !failing.canSign && failing.error != nil && failing.feedback != nil, "受理后刷新失败不误报提交失败")
        let disabledClient = FakeSignInClient(); disabledClient.enabled = false
        let disabled = DailySignInStore(context: context, client: disabledClient, isCurrent: { _ in true })
        await disabled.refresh()
        check(disabled.canSign, "与xgd一致，由签到接口判断是否开放")
        await disabled.sign()
        check(disabledClient.submissions == 1 && disabled.feedback == "系统未开启签到功能" && !disabled.signed, "服务端未开启时提示原始原因且不伪造成功")
        await disabled.sign()
        check(disabledClient.submissions == 2 && disabled.canSign && !disabled.signed && disabled.feedbackRevision == 2, "重复失败再次Toast且可重试，不锁成已签到")
        let lateClient = FakeSignInClient(); lateClient.suspend = true
        var valid = true
        let late = DailySignInStore(context: context, client: lateClient, isCurrent: { _ in valid })
        let task = Task { await late.refresh() }
        while lateClient.pending == nil { await Task.yield() }
        valid = false; late.close(); lateClient.pending?.resume(); await task.value
        check(late.info == nil && late.error == nil && !late.busy, "退出及新AUTH拒绝旧回执")
        let duplicateClient = FakeSignInClient(); duplicateClient.suspend = true
        let duplicate = DailySignInStore(context: context, client: duplicateClient, isCurrent: { _ in true })
        let loading = Task { await duplicate.refresh() }
        while duplicateClient.pending == nil { await Task.yield() }
        await duplicate.sign(); check(duplicateClient.submissions == 0, "加载中不能签到")
        duplicateClient.pending?.resume(); await loading.value
        duplicate.loadReminders(sessionID: "s", reset: true)
        check(!duplicate.hasMoreReminders, "空提醒页停止分页")
        let writingClient = FakeSignInClient()
        let writer = DailySignInStore(context: context, client: writingClient, isCurrent: { _ in true })
        await writer.refresh(); writingClient.suspendSign = true
        let submission = Task { await writer.sign() }
        while writingClient.pending == nil { await Task.yield() }
        await writer.sign(); check(writingClient.submissions == 1, "在途签到互斥")
        writer.close(); writingClient.pending?.resume(); await submission.value
        check(writer.info == nil && writer.feedback == nil, "退出后签到成功不发布旧用户反馈")
        print("PASS: \(count) daily sign-in checks")
    }
}
