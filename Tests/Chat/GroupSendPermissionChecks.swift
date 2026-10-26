//
//  GroupSendPermissionChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import Foundation
@main struct GroupSendPermissionChecks {
    /// 用户实际字段形状与旧缓存冲突均执行生产判断，不请求服务器或改真实禁言。
    static func main() {
        let detail: [String: Any] = ["userInGroup": true, "isGroupChat": false]
        let missingPersonal: [String: Any] = ["isGroupChat": false]
        let group = LingIMGroupModel()
        precondition(productionGroupPermission(group: group, detail: detail, mute: missingPersonal).sendInterval == 1, "本地1000毫秒策略应转为1秒发送间隔")
        precondition(productionGroupPermission(group: group, detail: detail, mute: missingPersonal).canSend, "缺省个人禁言的合法当前响应应恢复输入")
        var stale = group; stale.isGroupChat = true
        precondition(productionGroupPermission(group: stale, detail: ["userInGroup": true, "isGroupChat": true], mute: ["isGroupForbid": false, "isGroupChat": false]).canSend, "最新禁言接口已解除时旧群缓存不能继续阻断")
        precondition(!productionGroupPermission(group: group, detail: detail, mute: ["isGroupForbid": true, "isGroupChat": false]).canSend, "真实个人禁言必须保持阻断")
        precondition(!productionGroupPermission(group: group, detail: detail, mute: ["isGroupForbid": false, "isGroupChat": true]).canSend, "最新全员禁言不能被旧群缓存放行")
        var admin = group; admin.userGroupRole = 1
        precondition(productionGroupPermission(group: admin, detail: detail, mute: ["isGroupForbid": false, "isGroupChat": true]).canSend, "管理者沿旧规则豁免全员禁言")
        precondition(!productionGroupPermission(group: admin, detail: detail, mute: ["isGroupForbid": true, "isGroupChat": true]).canSend, "管理者仍校验个人禁言")
        var left = group; left.leaveGroupStatus = 1
        precondition(!productionGroupPermission(group: left, detail: detail, mute: missingPersonal).canSend)
        precondition(!productionGroupPermission(group: nil, detail: detail, mute: missingPersonal).canSend)
        precondition(!productionGroupPermission(group: group, detail: nil, mute: nil).canSend)
        precondition(!productionGroupPermission(group: group, detail: ["userInGroup": false], mute: missingPersonal).canSend)
        precondition(!productionGroupPermission(group: group, detail: detail, mute: ["isGroupForbid": NSNull(), "isGroupChat": false]).canSend)
        print("Group send permission checks: 12 passed")
    }
}
