import Foundation

@main struct GroupMemberPageChecks {
    /// 使用现场接口键名构造匿名页，禁止把不支持的响应当作已同步空名单。
    static func main() throws {
        let item: [String: Any] = ["userUid": "peer", "role": 0, "isDel": false]
        let actual: [String: Any] = ["currentPage": 1, "items": [item], "pageSize": 100, "pages": 1, "totalCount": 1]
        try expect(ChatGroupMemberPage.rows(from: actual).count == 1, "现场items成员页不能误判为空")
        try expect(ChatGroupMemberPage.rows(from: ["rows": [item]]).count == 1, "兼容既有rows成员页")
        try expect(ChatGroupMemberPage.rows(from: ["items": []]).isEmpty, "明确空items可以结束分页")
        try expect(ChatGroupMemberPage.rows(from: ["items": [item], "rows": []]).count == 1, "现场items优先于旧rows")
        for malformed: [String: Any] in [[:], ["items": "invalid"], ["items": ["invalid"]], ["items": [["role": 0]]]] {
            do { _ = try ChatGroupMemberPage.rows(from: malformed); fatalError("损坏成员页不能标记同步完成") }
            catch is ChatClientError { }
        }
        let numeric: [String: Any] = ["items": [["userUid": NSNumber(value: Int64(2108428960873541633))]]]
        try expect(ChatGroupMemberPage.rows(from: numeric).first?["userUid"] as? String == "2108428960873541633", "数字UID须保留完整精度")
        print("Group member page checks: 9 passed")
    }
    /// 先求值抛错表达式，再断言可观察结果，避免仅检查源码文本。
    private static func expect(_ value: @autoclosure () throws -> Bool, _ note: String) throws {
        let matched = try value(); precondition(matched, note)
    }
}
