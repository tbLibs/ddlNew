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

    func stopObserving() {
        generation = UUID()
        if let delegate {
            delegate.invalidate()
            sdk.removeSessionDelegate(delegate)
        }
        delegate = nil
    }

    func loadConversations(for userUID: String) async throws -> [ConversationRecord] {
        try await Task.detached {
            let sdk = NoaIMSDKManager.sharedTool()
            // 与 SDK 用户配置、关闭数据库及预览写库共用锁，避免检查后读到另一账号的库。
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
                let preview = isDraft ? draft : ConversationPreview.text(for: message)
                let millis = model.sessionLatestTime
                return ConversationRecord(
                    id: id, title: model.sessionName?.isEmpty == false ? model.sessionName! : id,
                    avatarURL: model.sessionAvatar ?? "", kind: kind,
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
    nonisolated static func text(for message: NoaIMChatMessageModel?) -> String {
        guard let message else { return "暂无消息" }
        switch Int(message.messageType.rawValue) {
        case 0: return message.textContent ?? ""
        case 1: return "[图片]"
        case 2: return "[视频]"
        case 3, 7: return "[位置]"
        case 4: return "[语音]"
        case 5: return message.showFileName ?? message.fileName ?? "[文件]"
        case 6: return "[名片]"
        case 8: return "[消息已撤回]"
        case 10: return message.showContent ?? message.atContent ?? "[@消息]"
        case 12, 21: return "[表情]"
        case 16: return message.groupNoticeContent ?? "[群公告]"
        case 18: return "[聊天记录]"
        case 20: return "[通话]"
        case 1000: return message.systemNoticeContent ?? "[系统通知]"
        default: return "[消息]"
        }
    }
}
