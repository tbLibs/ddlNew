//
//  BusinessRequestHeaders.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import Foundation
import SwiftUI

/// 未登录业务请求共用的设备、组织与验签请求头。
@MainActor
enum BusinessRequestHeaders {
    static func make(timestamp: Int64, signature: String, appID: String? = nil) -> [String: String] {
        var headers = [
            "deviceType": "IOS",
            "deviceUuid": BusinessDeviceIdentity.shared.uuid,
            "orgName": businessOrgName,
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            "token": "",
            "timestamp": String(timestamp),
            "signature": signature
        ]
        if let appID, !appID.isEmpty {
            headers["conid"] = appID
            headers["ZTID"] = UUID().uuidString
            headers["loginuseruid"] = ""
        }
        return headers
    }
}

/// 当前安装稳定的设备 UUID，与旧项目 FCUUID 的用途相同。
@MainActor
private final class BusinessDeviceIdentity {
    static let shared = BusinessDeviceIdentity()

    @AppStorage(businessDeviceUUIDAppStorageKey) private var storedUUID = ""

    private init() {}

    var uuid: String {
        if storedUUID.isEmpty {
            storedUUID = UUID().uuidString
        }
        return storedUUID
    }
}
