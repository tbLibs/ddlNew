import Foundation
@main struct SystemVisibilityChecks {
    /// 旧群通知、定向人员、虚拟成员和静默操作共享显示资格；单聊不套群设置。
    static func main() {
        func visible(_ kind: Int, status: Int? = 1, role: Int? = 0, silence: Bool = false,
                     subtype: Int = 0, scope: Int = 0, ids: [String] = [], actor: String = "", target: String = "", group: Bool = true) -> Bool {
            ChatSystemEventVisibility.shouldDisplay(kind: kind, isGroup: group, userUID: "A", groupInformStatus: status,
                role: role, isSilence: silence, subtype: subtype, informSwitch: scope, informUIDs: ids, actorID: actor, targetID: target)
        }
        precondition(!visible(210, status: 0)); precondition(visible(210)); precondition(!visible(210, status: nil))
        precondition(!visible(215, silence: true, scope: 1, ids: ["A"]))
        precondition(!visible(215, subtype: 5)); precondition(visible(215))
        precondition(visible(215, scope: 1, ids: ["A"]))
        precondition(!visible(215, scope: 1, ids: ["B"]))
        precondition(!visible(215, scope: 1))
        for kind in [203, 204, 206, 211] {
            precondition(!visible(kind, scope: 1, ids: ["B"]))
            precondition(visible(kind, scope: 1, ids: ["A"]))
        }
        precondition(!visible(221)); precondition(visible(221, actor: "A")); precondition(visible(221, target: "A"))
        precondition(visible(221, role: 1)); precondition(visible(221, role: 2)); precondition(!visible(221, status: 0, role: 2))
        precondition(!visible(200)); precondition(visible(200, role: 2)); precondition(!visible(200, role: 2, silence: true))
        precondition(!visible(203, subtype: 2)); precondition(!visible(204, subtype: 2))
        precondition(visible(232, status: 0, group: false)); precondition(!visible(232, status: 0))
        precondition(visible(205, status: nil), "群已删除后的解散提示保留")
        print("System visibility policy checks: 31 passed")
    }
}
