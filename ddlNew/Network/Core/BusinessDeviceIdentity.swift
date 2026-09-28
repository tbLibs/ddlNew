//
//  BusinessDeviceIdentity.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation
import SwiftUI

/// 当前安装稳定的设备 UUID，与旧项目 FCUUID 的用途相同。
@MainActor
final class BusinessDeviceIdentity {
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
