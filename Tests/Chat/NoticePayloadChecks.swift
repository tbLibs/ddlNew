import Foundation

@main struct NoticePayloadChecks {
    /// 按xgd真实字段构造匿名样本，捕获正文空白和正常状态误判置顶。
    static func main() throws {
        let body = "群公告中文🙂\n第二行"
        let normal: [String: Any] = ["noticeId": "n1", "content": body, "noticeCreateNickname": "作者", "createTime": 1720000000000, "status": 1, "topStatus": "0"]
        let notice = try ChatGroupNoticePayload.notice(from: normal)
        precondition(notice.content == body, "旧版content正文必须显示，含换行与Unicode")
        precondition(!notice.pinned, "status正常不代表置顶，topStatus0必须不置顶")
        precondition(notice.author == "作者" && notice.timestamp == "1720000000000", "旧版作者和数值时间必须映射")
        precondition(notice.displayTimestamp(timeZone: TimeZone(secondsFromGMT: 0)!) == "2024/07/03 09:46", "公告毫秒时间按xgd年月日时分展示，不把毫秒误当秒")
        precondition(notice.displayTimestamp(timeZone: TimeZone(secondsFromGMT: 8 * 3600)!) == "2024/07/03 17:46", "公告时间遵从当前时区")
        for timestamp in ["", "损坏", "0", "-1"] {
            let invalidTime = ChatGroupNotice(id: "time", content: "正文", author: "", timestamp: timestamp, pinned: false)
            precondition(invalidTime.displayTimestamp().isEmpty, "缺失或损坏时间不泄漏原始数字或伪造1970年")
        }
        var pinned = normal; pinned["topStatus"] = 1
        let pinnedNotice = try ChatGroupNoticePayload.notice(from: pinned)
        precondition(pinnedNotice.pinned, "数字置顶1必须显示")
        let params = ChatGroupNoticePayload.saveParameters(notice: nil, content: body, pinned: false, sendMessage: true, groupID: "g", userUID: "u")
        precondition(params["noticeContent"] as? String == body && params["isTop"] as? String == "0" && params["isSendMsg"] as? String == "1", "正文与两个开关独立传递")
        var numeric = normal; numeric["noticeId"] = NSNumber(value: Int64(2108428960873541633)); numeric["topStatus"] = 0
        let numericNotice = try ChatGroupNoticePayload.notice(from: numeric)
        precondition(numericNotice.id == "2108428960873541633" && !numericNotice.pinned, "大整数UID与数字非置顶兼容")
        var absentTop = normal; absentTop.removeValue(forKey: "topStatus")
        let absentTopNotice = try ChatGroupNoticePayload.notice(from: absentTop)
        precondition(!absentTopNotice.pinned, "缺少置顶字段也不能把正常status1误认置顶")
        var priority = normal; priority["isTop"] = "1"; priority["noticeContent"] = "错误旧字段"
        let priorityNotice = try ChatGroupNoticePayload.notice(from: priority)
        precondition(!priorityNotice.pinned && priorityNotice.content == body, "真实响应content/topStatus优先于兼容别名")
        let alias = try ChatGroupNoticePayload.notice(from: ["noticeId": "alias", "noticeContent": "兼容正文", "isTop": "1", "nickName": "旧作者"])
        precondition(alias.content == "兼容正文" && alias.pinned, "已使用的替代响应字段仍可读取")
        let detail = try ChatGroupNoticePayload.notice(from: ["content": body, "topStatus": "0"], fallback: notice)
        precondition(detail.id == "n1" && detail.author == "作者" && detail.content == body && !detail.pinned, "详情缺元数据时保留稳定身份和作者")
        for invalid: [String: Any] in [["noticeId": "n1", "topStatus": "0"], ["noticeId": "n1", "content": 123]] {
            do { _ = try ChatGroupNoticePayload.notice(from: invalid, fallback: notice); fatalError("详情缺正文时不得以摘要fallback开放编辑") } catch {}
        }
        let editing = ChatGroupNoticePayload.saveParameters(notice: pinnedNotice, content: "编辑正文", pinned: false, sendMessage: false, groupID: "g", userUID: "u")
        precondition(editing["noticeId"] as? String == "n1" && editing["isTop"] as? String == "0" && editing["isSendMsg"] as? String == "0", "已置顶公告关闭开关必须发送取消置顶且不发送群消息")
        let empty = try ChatGroupNoticePayload.notices(from: ["rows": []])
        precondition(empty.isEmpty, "真实空页可正常显示空态")
        precondition(ChatGroupNoticePayload.managementRole(from: ["groupStatus": 1, "userInGroup": true, "userGroupRole": 2]) == 2, "有效群主可管理公告")
        precondition(ChatGroupNoticePayload.managementRole(from: ["groupStatus": "1", "userInGroup": "true", "userGroupRole": "1"]) == 1, "字符串群信息兼容管理员角色")
        for row: [String: Any] in [[:], ["groupStatus": 0, "userInGroup": true, "userGroupRole": 2], ["groupStatus": 1, "userInGroup": false, "userGroupRole": 2], ["groupStatus": 1, "userInGroup": true, "userGroupRole": 3], ["groupStatus": 1, "userInGroup": true, "userGroupRole": "坏值"]] {
            precondition(ChatGroupNoticePayload.managementRole(from: row) == 0, "解散、退群、机器人或坏群信息不能出现管理入口")
        }
        expectInvalid(["rows": [["noticeId": "bad", "topStatus": "0"]]], "缺失正文的非空页不能展示成空白公告")
        expectInvalid(["rows": [["noticeId": "", "content": "正文"]]], "坏ID不能静默跳过导致少页")
        expectInvalid(["rows": [["noticeId": "bad", "content": "正文", "topStatus": "错误值"]]], "坏置顶值必须报告格式错误")
        print("Notice payload checks: 30 passed")
    }
    /// 格式损坏必须抛错，空页与坏页分开处理。
    static func expectInvalid(_ json: [String: Any], _ message: String) {
        do { _ = try ChatGroupNoticePayload.notices(from: json); fatalError(message) } catch {}
    }
}
