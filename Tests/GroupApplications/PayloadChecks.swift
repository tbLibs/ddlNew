//
//  PayloadChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//
import Foundation
import ObjectMapper

@MainActor private final class PayloadClient: GroupApplicationsClient {
    var json: [String: Any] = [:]
    var readCount = 0
    /// 与SDK使用同一真实解码器，坏页在读状态上报之前失败。
    func load(userUID: String, groupID: String?, pendingOnly: Bool, page: Int) async throws -> GroupApplicationsPage {
        guard let payload = Mapper<GroupApplicationsPayload>().map(JSON: json) else { throw URLError(.cannotParseResponse) }
        return GroupApplicationsPage(records: payload.records.map(\.record), total: payload.total)
    }
    /// 测试只观察是否错误清读，不请求真实系统消息。
    func markNotificationsRead(userUID: String, snapshot: GroupNotificationReadSnapshot?) async throws { readCount += 1 }
    /// 本测试只读解码，不执行真实审核。
    func review(userUID: String, records: [GroupApplicationRecord], accept: Bool) async throws -> GroupApplicationOutcome { fatalError("unused") }
}

@main private struct PayloadChecks {
    /// 使用真实ObjectMapper验证混合标量和坏页，不以模拟模型替代接口映射。
    @MainActor static func main() async {
        var checks = 0
        func check(_ condition: Bool, _ reason: String) { precondition(condition, reason); checks += 1 }
        let numericJSON: [String: Any] = ["records": [["memreqUuid": 9007199254740993 as Int64, "groupId": 72, "beStatus": "1", "beInviteUserId": 91, "beInviteNickname": "同名", "userUid": "92", "userNickName": "同名", "beUserAvatarFileName": "inviter.png", "userAvatarFileName": "invitee.png", "roleId": "3", "beDesc": "申请\n加入🌲"]], "total": "1"]
        let numeric = Mapper<GroupApplicationsPayload>().map(JSON: numericJSON)
        check(numeric?.records.first?.record.id == "9007199254740993", "数字申请ID必须保留且不能被静默过滤")
        check(numeric?.total == 1 && numeric?.records.first?.record.status == 1, "字符串状态与总数")
        check(numeric?.records.first?.record.groupID == "72", "数字群ID")
        check(numeric?.records.first?.record.inviterID == "91" && numeric?.records.first?.record.inviteeID == "92", "同名用户必须分别保留真实UID")
        check(numeric?.records.first?.record.inviterAvatar == "inviter.png" && numeric?.records.first?.record.inviteeAvatar == "invitee.png", "双方头像字段不能互换")
        check(numeric?.records.first?.record.roleID == 3 && numeric?.records.first?.record.reason == "申请\n加入🌲", "角色与Unicode附言")
        let data = try! JSONSerialization.data(withJSONObject: numericJSON)
        check(Mapper<GroupApplicationsPayload>().map(JSONString: String(data: data, encoding: .utf8)!)?.records.first?.memreqUuid == "9007199254740993", "真实JSON字节大整数精度")
        let stringRow: [String: Any] = ["memreqUuid": "request-a", "groupId": "g", "beStatus": 4]
        check(Mapper<GroupApplicationsPayload>().map(JSON: ["records": [stringRow], "total": 12])?.total == 12, "数字total保留跨页总数")
        check(Mapper<GroupApplicationPayload>().map(JSON: stringRow)?.record.statusText == "已同意", "状态4")
        check(Mapper<GroupApplicationPayload>().map(JSON: ["memreqUuid": "b", "groupId": "g", "beStatus": "5"])?.record.statusText == "已拒绝", "字符串状态5")
        check(Mapper<GroupApplicationsPayload>().map(JSON: ["records": [], "total": "0"]) != nil, "合法空页")
        let badRows: [[String: Any]] = [
            ["groupId": "g", "beStatus": 1],
            ["memreqUuid": " ", "groupId": "g", "beStatus": 1],
            ["memreqUuid": "a", "groupId": NSNull(), "beStatus": 1],
            ["memreqUuid": true, "groupId": "g", "beStatus": 1],
            ["memreqUuid": 1.5, "groupId": "g", "beStatus": 1],
            ["memreqUuid": "a", "groupId": "g", "beStatus": true],
            ["memreqUuid": "a", "groupId": "g", "beStatus": "pending"]
        ]
        for row in badRows {
            check(Mapper<GroupApplicationsPayload>().map(JSON: ["records": [stringRow, row], "total": 2]) == nil, "任何坏行拒绝整页")
        }
        for badTotal: Any in [true, -1, "unknown", 1.5, NSNull()] {
            check(Mapper<GroupApplicationsPayload>().map(JSON: ["records": [stringRow], "total": badTotal]) == nil, "坏总数不能终止分页")
        }
        check(Mapper<GroupApplicationsPayload>().map(JSON: ["records": ["bad-row"], "total": 1]) == nil, "错误数组元素")
        check(Mapper<GroupApplicationsPayload>().map(JSON: ["records": [stringRow], "total": 0]) == nil, "不一致的非空页与总数")
        check(Mapper<GroupApplicationPayload>().map(JSON: stringRow)?.record.inviteeID.isEmpty == true, "可选UID缺失不编造身份")
        let client = PayloadClient(); client.json = numericJSON
        let store = GroupApplicationsStore(client: client)
        store.prepare(userUID: "current", groupID: nil)
        await store.reload(pendingOnly: false)
        check(store.records.count == 1 && client.readCount == 1, "成功完整页才清通知未读")
        client.json = ["records": [stringRow, badRows[0]], "total": 2]
        await store.reload(pendingOnly: false)
        check(store.records.first?.id == "9007199254740993" && store.errorMessage != nil && client.readCount == 1, "坏非空页保留旧列表及未读")
        print("Group application payload checks passed: \(checks)")
    }
}
