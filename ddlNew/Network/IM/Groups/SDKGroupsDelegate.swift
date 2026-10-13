//
//  SDKGroupsDelegate.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import NoaChatCore

/// 将群同步与增删改代理交回群列表Store。
nonisolated final class SDKGroupsDelegate: NSObject, CIMToolGroupDelegate {
    let change: @Sendable () -> Void
    /// 单个代理由群客户端持有并在退出时释放。
    init(change: @escaping @Sendable () -> Void) { self.change = change }
    /// 首次群同步完成才回读完整列表。
    func imSdkGroupSyncFinish() { change() }
    /// 加群后刷新缓存。
    func cimToolGroupReceive(with model: LingIMGroupModel) { change() }
    /// 群名称头像角色变化后刷新列表。
    func cimToolGroupUpdate(with model: LingIMGroupModel) { change() }
    /// 退出或解散后从真实库移除。
    func cimToolGroupDelete(with model: LingIMGroupModel) { change() }
}
