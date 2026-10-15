import Foundation
@main struct MessageIdentityChecks {
    /// 对实际生产身份判断回归撤回/删除原文泄露与错误会话归属。
    static func main() {
        func peer(_ status: Int = 1, _ type: Int = 0, _ from: String = "A", _ to: String = "B") -> String? {
            GlobalSearchMessageIdentity.peer(status: status, chatType: type, from: from, to: to, userUID: "A")
        }
        precondition(peer(0) == nil, "删除消息不能命中旧正文")
        precondition(peer(2) == nil, "撤回消息不能命中旧正文")
        precondition(peer(9) == nil)
        precondition(peer() == "B")
        precondition(peer(1, 0, "B", "A") == "B")
        precondition(peer(1, 0, "B", "C") == nil, "第三方数据不能归入本人会话")
        precondition(peer(1, 1, "B", "g") == "g")
        precondition(peer(1, 5, "B", "A") == nil)
        precondition(peer(1, 1, "", "g") == nil)
        precondition(peer(1, 0, "A", "") == nil)
        print("Search message identity: 10 passed")
    }
}
