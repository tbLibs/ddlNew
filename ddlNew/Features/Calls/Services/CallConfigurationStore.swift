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

    func update(json: String, tenantID: String) {
        guard let data = json.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data), let values = object as? [String: Any] else { return }
        func text(_ key: String) -> String { (values[key] as? String) ?? (values[key] as? NSNumber)?.stringValue ?? "" }
        current = CallConfiguration(tenantID: tenantID, enabled: text("enableAudioAndVideoCalls") == "1", provider: Int(text("video_source_config")).flatMap(CallProvider.init(rawValue:)), zegoAppID: UInt32(text("video_source_config_zg_appId")) ?? 0)
    }
    func clear() { current = nil }
}
