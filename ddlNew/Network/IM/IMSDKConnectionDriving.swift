//
//  IMSDKConnectionDriving.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation

/// SDK 与连接流程之间的边界，便于用替身验证连接顺序和取消行为。
@MainActor
protocol IMSDKConnectionDriving: AnyObject {
    var isConnected: Bool { get }
    func reset()
    func connect(_ plan: OSSConnectionPlan) async throws -> OSSIMTCPNode
    func apply(_ configuration: SystemConfigRecord)
}
