// Created by taobo on 2026/10/13.
import Foundation

/// 群申请状态与好友申请不同：1 待审核、4 已进群、5 已拒绝。
struct GroupApplicationRecord: Identifiable, Sendable {
    let id: String
    let groupID: String
    let nickname: String
    let reason: String
    let status: Int
    var statusText: String {
        switch status { case 1: return "待审核"; case 4: return "已同意"; case 5: return "已拒绝"; default: return "已处理" }
    }
}
