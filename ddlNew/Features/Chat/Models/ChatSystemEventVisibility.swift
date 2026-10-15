//
//  ChatSystemEventVisibility.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//
import Foundation

/// 群系统提示的显示资格与事件处理分离；静默或定向通知仍可刷新成员与权限。
nonisolated enum ChatSystemEventVisibility {
    static func shouldDisplay(kind: Int, isGroup: Bool, userUID: String, groupInformStatus: Int?, role: Int?,
                              isSilence: Bool = false, subtype: Int = 0, informSwitch: Int = 0,
                              informUIDs: [String] = [], actorID: String = "", targetID: String = "") -> Bool {
        guard isGroup else { return true }
        if [200, 215].contains(kind), isSilence { return false }
        if kind == 215 && subtype == 5 || [203, 204].contains(kind) && subtype == 2 { return false }
        if kind == 200 { return role.map { $0 > 0 } == true }
        let controlled = [203, 204, 206, 207, 208, 210, 211, 213, 215, 219, 221, 230, 231, 232, 237, 238]
        if controlled.contains(kind), groupInformStatus != 1 { return false }
        if [203, 204, 206, 211, 215].contains(kind), informSwitch == 1 {
            return informUIDs.contains(userUID)
        }
        if kind == 221 {
            return actorID == userUID || targetID == userUID || role.map { $0 > 0 } == true
        }
        return true
    }
}
