//
//  UserRoleAuthorityStore.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Combine
import ObjectMapper
import SwiftUI

/// 权限缓存绑定用户和邀请码，退出或换账号立即撤销内存权限。
@MainActor
final class UserRoleAuthorityStore: ObservableObject {
    static let shared = UserRoleAuthorityStore()
    @AppStorage(userRoleAuthorityAppStorageKey) private var json = ""
    @Published private(set) var current: UserRoleAuthority?
    private var userUID: String?
    private var license: String?
    private init() {}

    func prepare(userUID: String, lastLiceseId: String) {
        current = nil
        self.userUID = userUID
        license = lastLiceseId
        if let cache = Mapper<UserRoleAuthorityCache>().map(JSONString: json),
           cache.userUID == userUID, cache.license == lastLiceseId { current = cache.authority }
    }

    func update(_ authority: UserRoleAuthority, userUID: String, lastLiceseId: String) {
        guard self.userUID == userUID, license == lastLiceseId,
              let cache = Mapper<UserRoleAuthorityCache>().toJSONString(
                UserRoleAuthorityCache(userUID: userUID, license: lastLiceseId, authority: authority)) else { return }
        json = cache
        current = authority
    }

    func reset(clearCache: Bool = true) {
        userUID = nil
        license = nil
        current = nil
        if clearCache { json = "" }
    }
}

nonisolated private struct UserRoleAuthorityCache: Mappable {
    var userUID = ""
    var license = ""
    var authority: UserRoleAuthority?
    init(userUID: String, license: String, authority: UserRoleAuthority) {
        self.userUID = userUID; self.license = license; self.authority = authority
    }
    init?(map: Map) {}
    mutating func mapping(map: Map) {
        userUID <- map["userUID"]
        license <- map["license"]
        authority <- map["authority"]
    }
}
