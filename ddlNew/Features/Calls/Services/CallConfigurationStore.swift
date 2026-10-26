//
//  CallConfigurationStore.swift
//  ddlNew
//
//  Created by taobo on 2026/10/20.
//

import Foundation
import Combine

struct CallConfiguration: Equatable, Sendable {
    let tenantID: String
    let enabled: Bool
    let provider: CallProvider?
    let zegoAppID: UInt32
}

/// 仅取客户端实际需要的开关、供应商与 appID，服务端密钥不进入持久化或日志。
@MainActor final class CallConfigurationStore: ObservableObject {
    static let shared = CallConfigurationStore()
    @Published private(set) var current: CallConfiguration?

    private let makeConfiguration: (String) -> CallConfiguration

    init(makeConfiguration: @escaping (String) -> CallConfiguration = { tenantID in
        CallConfiguration(tenantID: tenantID,
            enabled: LocalMessagingSettings.audioVideoCallsEnabled,
            provider: CallProvider(rawValue: LocalMessagingSettings.callProvider),
            zegoAppID: LocalMessagingSettings.zegoAppID)
    }) {
        self.makeConfiguration = makeConfiguration
    }

    func configure(tenantID: String) {
        current = makeConfiguration(tenantID)
    }
    func clear() { current = nil }
}
