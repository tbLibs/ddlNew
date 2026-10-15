//
//  RowPresentationChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import Foundation

@main private struct RowPresentationChecks {
    /// 验证备注恢复等实际显示变化使行重建，导航仍使用原UID且隐藏字段不触发无意义重建。
    static func main() {
        var checks = 0
        func check(_ condition: Bool, _ reason: String) { precondition(condition, reason); checks += 1 }
        let peer = "peer-id"
        let before = ContactRecord(id: peer, nickname: "昵称", remarks: "QA1014_A_备注🙂", avatar: "avatar.png", isOnline: true)
        let restored = ContactRecord(id: peer, nickname: "昵称", remarks: "Affff", avatar: "avatar.png", isOnline: true)
        let host = URL(string: "https://files.example.invalid")!
        func identity(_ contact: ContactRecord, host: URL? = host, role: String? = nil) -> ContactRowPresentationIdentity {
            ContactRowPresentationIdentity(contact: contact, fileHost: host, roleName: role)
        }
        check(before.initial == "Q" && restored.initial == "A", "分区键随真实备注恢复")
        check(identity(before) != identity(restored), "相同UID备注变化必须刷新行标签")
        check(before.id == restored.id, "资料导航目标保持原UID")
        check(identity(restored) == identity(restored), "相同显示快照身份稳定")
        let avatar = ContactRecord(id: peer, nickname: "昵称", remarks: "Affff", avatar: "new-avatar.png", isOnline: true)
        check(identity(restored) != identity(avatar), "头像变更刷新")
        let offline = ContactRecord(id: peer, nickname: "昵称", remarks: "Affff", avatar: "avatar.png", isOnline: false)
        check(identity(restored) != identity(offline), "在线状态变更刷新")
        let deleted = ContactRecord(id: peer, nickname: "昵称", remarks: "Affff", avatar: "avatar.png", isOnline: true, disableStatus: 4)
        check(identity(restored) != identity(deleted), "注销状态变更刷新")
        check(identity(restored, role: "管理员") != identity(restored, role: nil), "角色标签权限变化刷新")
        check(identity(restored) != identity(restored, host: URL(string: "https://other-files.example.invalid")), "相对头像Host变化刷新")
        let hiddenOnly = ContactRecord(id: peer, account: "新账号", nickname: "新昵称", remarks: "Affff", description: "新描述", avatar: "avatar.png", isOnline: true)
        check(identity(restored) == identity(hiddenOnly), "未展示字段更新不重建相同标签")
        let sameNameOtherID = ContactRecord(id: "other-peer-id", nickname: "昵称", remarks: "Affff", avatar: "avatar.png", isOnline: true)
        check(identity(restored) != identity(sameNameOtherID), "同名不同UID保持独立身份")
        print("Contact row presentation checks passed: \(checks)")
    }
}
