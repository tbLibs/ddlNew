//
//  SDKContactsClient.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import Foundation
import ObjectiveC
import NoaChatCore
import ObjectMapper

/// 沿用老项目的 addUserDelegate + toolGetMyFriendList，不维护第二份好友数据库。
@MainActor
final class SDKContactsClient: ContactsClient {
    private var sdk: NoaIMSDKManager { NoaIMSDKManager.sharedTool() }
    private var delegate: SDKContactsDelegate?
    private var generation = UUID()
    private var remarkRequests = ContactRequestVersions()

    func observe(_ onChange: @escaping @MainActor (ContactsChange) -> Void) {
        stopObserving()
        let runID = generation
        let delegate = SDKContactsDelegate { [weak self] change in
            Task { @MainActor [weak self] in
                guard let self, self.generation == runID else { return }
                if case .remarkChanged(let friendUID) = change {
                    self.refreshRemark(for: friendUID, runID: runID, onChange: onChange)
                } else {
                    onChange(change)
                }
            }
        }
        self.delegate = delegate
        sdk.addUserDelegate(delegate)
    }

    func stopObserving() {
        generation = UUID()
        remarkRequests = ContactRequestVersions()
        if let delegate { sdk.removeUserDelegate(delegate) }
        delegate = nil
    }

    func loadContacts(for userUID: String) async throws -> [ContactRecord] {
        try await Task.detached {
            let sdk = NoaIMSDKManager.sharedTool()
            // 与 SDK 用户配置、关闭数据库和同步写入共用锁，防止检查后切换数据库。
            objc_sync_enter(sdk)
            defer { objc_sync_exit(sdk) }
            guard sdk.myUserID() == userUID, sdk.isUserDatabaseReady() else { throw UserSessionError.databaseNotReady }
            // 老项目保留已注销好友，在 # 分组显示，不能使用 OffLogout 接口过滤掉。
            guard let friends = sdk.toolGetMyFriendList() else { throw ContactsClientError.cacheReadFailed }
            return friends.map { friend in
                ContactRecord(id: friend.friendUserUID ?? "", account: friend.userName ?? "",
                              nickname: friend.nickname ?? "", remarks: friend.remarks ?? "",
                              description: friend.descRemark ?? "", avatar: friend.avatar ?? "",
                              isOnline: friend.onlineStatus, disableStatus: friend.disableStatus, userType: friend.userType,
                              nicknamePinyin: friend.nicknamePinyin ?? "", remarksPinyin: friend.remarksPinyin ?? "")
            }
        }.value
    }

    /// 和老项目相同：跨端修改备注后获取最新资料，写回 SDK 再由好友变化代理刷新。
    private func refreshRemark(for friendUID: String, runID: UUID,
                               onChange: @escaping @MainActor (ContactsChange) -> Void) {
        let userUID = sdk.myUserID()
        guard !friendUID.isEmpty, !userUID.isEmpty else { return }
        let version = remarkRequests.begin(for: friendUID)
        let params: NSMutableDictionary = ["userUid": userUID, "friendUserUid": friendUID]
        sdk.getFriendInfo(with: params, onSuccess: { @Sendable [weak self] data, _ in
            let payload = (data as? [String: Any]).flatMap { Mapper<ContactProfilePayload>().map(JSON: $0) }
            Task { @MainActor [weak self] in
                guard let self, self.generation == runID,
                      self.remarkRequests.accepts(version, for: friendUID) else { return }
                defer { self.remarkRequests.finish(version, for: friendUID) }
                guard let payload else {
                    onChange(.syncFailed("好友资料响应格式错误，请稍后重试"))
                    return
                }
                let sdk = self.sdk
                objc_sync_enter(sdk)
                defer { objc_sync_exit(sdk) }
                guard sdk.myUserID() == userUID, sdk.isUserDatabaseReady(),
                      let friend = sdk.toolCheckMyFriend(with: friendUID) else { return }
                if let value = payload.nickname {
                    friend.nickname = value
                    friend.nicknamePinyin = payload.nicknamePinyin ?? ContactSorter.searchPinyin(for: value)
                }
                if let value = payload.account { friend.userName = value }
                if let value = payload.avatar { friend.avatar = value }
                if let value = payload.remarks {
                    friend.remarks = value
                    friend.remarksPinyin = payload.remarksPinyin ?? ContactSorter.searchPinyin(for: value)
                }
                if let value = payload.description { friend.descRemark = value }
                if let value = payload.disableStatus { friend.disableStatus = value }
                friend.showName = (friend.remarks ?? "").isEmpty ? friend.nickname : friend.remarks
                if !self.sdk.toolUpdateMyFriend(with: friend) {
                    onChange(.syncFailed("好友备注保存失败，请稍后重试"))
                }
            }
        }, onFailure: { @Sendable [weak self] _, message, _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == runID, self.sdk.myUserID() == userUID,
                      self.remarkRequests.accepts(version, for: friendUID) else { return }
                self.remarkRequests.finish(version, for: friendUID)
                onChange(.syncFailed(message ?? "好友备注更新失败，请稍后重试"))
            }
        })
    }
}
