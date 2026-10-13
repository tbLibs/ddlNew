//
//  SDKConversationsClient.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import Foundation
import ObjectiveC
import NoaChatCore

@MainActor
final class SDKConversationsClient: ConversationsClient {
    private var sdk: NoaIMSDKManager { NoaIMSDKManager.sharedTool() }
    private var delegate: SDKConversationsDelegate?
    private var generation = UUID()

    /// 操作适配器通过同一订阅轮次拒绝退出后迟到的请求。
    var observationGeneration: UUID { generation }

    /// AUTH 前注册会话事件，并绑定这一轮用户会话。
    func observe(for userUID: String, _ onChange: @escaping @MainActor (ConversationsChange) -> Void) {
        stopObserving()
        let runID = generation
        let delegate = SDKConversationsDelegate(userUID: userUID) { [weak self] change in
            Task { @MainActor [weak self] in
                guard let self, self.generation == runID else { return }
                onChange(change)
            }
        }
        self.delegate = delegate
        sdk.addSessionDelegate(delegate)
    }

    /// 失效旧轮次并移除 SDK 代理。
    func stopObserving() {
        generation = UUID()
        if let delegate {
            delegate.invalidate()
            sdk.removeSessionDelegate(delegate)
        }
        delegate = nil
    }

    /// 在数据库锁内读取当前用户的会话、草稿和消息预览。
    func loadConversations(for userUID: String) async throws -> [ConversationRecord] {
        try await Task.detached {
            let sdk = NoaIMSDKManager.sharedTool()
            // 与本适配层的预览写库和失效处理共用锁，并校验当前 UID 与数据库就绪状态。
            objc_sync_enter(sdk)
            defer { objc_sync_exit(sdk) }
            guard sdk.myUserID() == userUID, sdk.isUserDatabaseReady() else { throw UserSessionError.databaseNotReady }
            guard let models = sdk.toolGetMySessionListExcept("") as? [LingIMSessionModel] else {
                throw ConversationsClientError.cacheReadFailed
            }
            return models.compactMap { model -> ConversationRecord? in
                // SDK 查询没有过滤展示状态，未知类型也不应进入当前只读列表。
                guard model.sessionStatus == 1, let id = model.sessionID, !id.isEmpty,
                      let kind = ConversationKind(sdkType: Int(model.sessionType.rawValue)) else { return nil }
                let draft = (model.draftDict as? [String: Any])?["draftContent"] as? String ?? ""
                let isDraft = !draft.isEmpty
                // 最新消息不随会话模型入库；同步预览写入消息表后从该表补读。
                let message = model.sessionLatestMessage ?? sdk.toolGetLatestChatMessage(withSessionID: id)
                let preview = isDraft ? draft : ConversationPreview.text(for: message, kind: kind, userUID: userUID, sdk: sdk)
                let millis = model.sessionLatestTime
                // 旧项目单聊优先读好友库最新头像；会话头像只在好友记录缺失时兜底。
                let avatar: String
                if kind == .single, let friend = sdk.toolCheckMyFriend(with: id) {
                    avatar = friend.disableStatus == 4 ? "" : (friend.avatar ?? "")
                } else {
                    avatar = model.sessionAvatar ?? ""
                }
                return ConversationRecord(
                    id: id, title: model.sessionName?.isEmpty == false ? model.sessionName! : id,
                    avatarURL: avatar, kind: kind,
                    preview: preview, latestTime: millis > 0 ? Date(timeIntervalSince1970: TimeInterval(millis) / 1000) : nil,
                    unreadCount: max(0, model.sessionUnreadCount), isMarkedUnread: model.readTag > 0,
                    isPinned: model.sessionTop, isMuted: model.sessionNoDisturb, isDraft: isDraft
                )
            }
        }.value
    }
}

private enum ConversationsClientError: LocalizedError {
    case cacheReadFailed
    var errorDescription: String? { "无法读取 SDK 会话缓存" }
}

private extension ConversationKind {
    /// 将 SDK 类型转换为明确的业务类型，未知类型不进入列表。
    nonisolated init?(sdkType: Int) {
        switch sdkType {
        case 1: self = .single
        case 2: self = .group
        case 3: self = .massMessage
        case 5: self = .systemMessage
        case 6: self = .signInReminder
        case 7: self = .paymentAssistant
        default: return nil
        }
    }
}

private enum ConversationPreview {
    /// 为不同消息生成列表摘要，正文仍由真实聊天页呈现。
    nonisolated static func text(for message: NoaIMChatMessageModel?, kind: ConversationKind, userUID: String,
                                 sdk: NoaIMSDKManager) -> String {
        guard let message else { return "暂无消息" }
        let type = Int(message.messageType.rawValue)
        let text = body(for: message, type: type, userUID: userUID)
        var senderName = message.fromNickname ?? ""
        if kind == .group, let sender = message.fromID, !sender.isEmpty {
            let cached: LingIMGroupMemberModel? = sdk.imSdkCheckGroupMember(with: sender, groupID: message.toID ?? "")
            if let member = cached {
                senderName = member.disableStatus == 4 ? "账号已注销" : [member.remarks ?? "", member.showName ?? "", senderName].first { !$0.isEmpty } ?? senderName
            }
        }
        let mentions = message.atUsersInfoList as? [[String: Any]] ?? []
        let mentionsMe = type == 10 && mentions.contains { $0[userUID] != nil || $0["-1"] != nil }
        return ConversationPreviewText.render(text, kind: kind, senderName: senderName, senderUID: message.fromID ?? "",
            userUID: userUID, mentionsMe: mentionsMe, includeSender: ![8, 9, 13, 15, 16, 1000].contains(type))
    }

    /// @正文复用聊天解析器，资源类型使用摘要而不泄露内部文件路径。
    nonisolated private static func body(for message: NoaIMChatMessageModel, type: Int, userUID: String) -> String {
        switch type {
        case 0: return message.textContent ?? ""
        case 1: return "[图片]"
        case 2: return "[视频]"
        case 3, 7: return "[位置]"
        case 4: return "[语音]"
        case 5: return message.showFileName ?? message.fileName ?? "[文件]"
        case 6: return "[名片]"
        case 8: return "[消息已撤回]"
        case 10: return SDKChatMessageMapper.record(message, userUID: userUID).text
        case 12, 21: return "[表情]"
        case 16: return message.groupNoticeContent ?? "[群公告]"
        case 18: return "[聊天记录]"
        case 20: return "[通话]"
        case 1000: return message.systemNoticeContent ?? "[系统通知]"
        default: return "[消息]"
        }
    }
}
