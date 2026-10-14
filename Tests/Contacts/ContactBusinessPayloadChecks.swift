import Foundation
import ObjectMapper

@main struct ContactBusinessPayloadChecks {
    /// 验证旧申请真实字段、混合类型与部分资料回读，不使用SDK或服务器。
    static func main() throws {
        let application = Mapper<ContactBusinessPayload>().map(JSON: [
            "hashKey": "realHash", "sendTime": 12, "fromUserUid": "from", "beUserUid": "to",
            "nickname": "发起方昵称", "beUserNickname": "接收方昵称", "fromUserAvatar": "from.png", "beUserAvatar": "to.png",
            "fromRoleId": "3", "beRoleId": 4, "beStatus": "0", "beDisableStatus": 4
        ])?.application()
        assert(application?.id == "realHash-12")
        assert(application?.name(for: "to") == "发起方昵称")
        assert(application?.avatar(for: "from") == "to.png")
        assert(application?.roleID(for: "to") == 3)
        assert(application?.action(for: "from") == .unavailable)
        let cached = ContactRecord(id: "friend", account: "old", nickname: "旧昵称", remarks: "旧备注", description: "描述", avatar: "old.png", isOnline: true, roleID: 3)
        let partial = Mapper<ContactBusinessPayload>().map(JSON: ["remarks": "新备注", "descRemark": NSNull()])?.contact(fallbackID: "friend", cached: cached)
        assert(partial?.nickname == "旧昵称" && partial?.account == "old" && partial?.avatar == "old.png")
        assert(partial?.remarks == "新备注" && partial?.description == "")
        assert(partial?.isOnline == true && partial?.roleID == 3)
        assert(Mapper<ContactBusinessPayload>().map(JSON: ["nickname": "没有身份"])?.contact() == nil)
        assert(Mapper<ContactBusinessPayload>().map(JSON: [:])?.contact(fallbackID: "friend", cached: cached) == nil, "空响应不能靠fallbackID冒充完整资料")
        for bad in [["nickname": ["bad"]], ["disableStatus": "invalid"], ["onlineStatus": 2], ["avatar": 1], ["roleId": true]] as [[String: Any]] {
            assert(Mapper<ContactBusinessPayload>().map(JSON: bad)?.contact(fallbackID: "friend", cached: cached) == nil, "非法字段不能覆盖缓存")
        }
        let cleared = Mapper<ContactBusinessPayload>().map(JSON: ["nickname": NSNull()])?.contact(fallbackID: "friend", cached: cached)
        assert(cleared?.nickname == "" && cleared?.disableStatus == cached.disableStatus)
        let legacySearch = Mapper<ContactBusinessPayload>().map(JSON: ["userUID": "qa-peer", "userName": "qa-account", "nickname": "匿名好友"])?.contact()
        assert(legacySearch?.id == "qa-peer" && legacySearch?.account == "qa-account", "旧精确搜索userUID字段不能被丢成空结果")
        assert(Mapper<ContactBusinessPayload>().map(JSON: ["userUID": "other", "userUid": "qa-peer"])?.contact() == nil, "不同别名冲突拒绝错误身份")
        assert(Mapper<ContactBusinessPayload>().map(JSON: ["userUID": NSNumber(value: Int64(2108428960873541633))])?.contact()?.id == "2108428960873541633", "旧数字UID保留完整精度")
        let search = try ContactBusinessPayload.searchContacts(from: [["userUID": "qa-peer", "userName": "qa-account"]])
        assert(search.map(\.id) == ["qa-peer"], "旧搜索结果须生成真实UID")
        let emptySearch = try ContactBusinessPayload.searchContacts(from: [] as [[String: Any]])
        assert(emptySearch.isEmpty, "明确空结果可以展示未找到")
        for bad: Any in [["items": []], [["nickname": "没有UID"]], [["userUID": true]], [["userUID": "qa-peer"], ["nickname": "损坏第二条"]]] {
            do { _ = try ContactBusinessPayload.searchContacts(from: bad); assertionFailure("损坏搜索不能当未找到") }
            catch ContactBusinessError.malformedResponse { }
        }
        print("通讯录SDK响应字段/非法类型/部分资料合并25项通过")
    }
}
