//
//  SDKOwnProfileClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/28.
//
import Foundation
import NoaChatCore

/// 个人资料复用SDK受理接口、既有媒体运输及唯一登录资料缓存。
@MainActor final class SDKOwnProfileClient: OwnProfileClient {
    private let transfer = SDKChatMediaClient()
    private var waiter: SDKChatRequestWaiter<Bool>?
    private var revision = UUID()

    /// 个人头像使用独立目录和旧图片包装，不生成会话或聊天消息。
    func upload(_ file: URL, context: ChatContext) async throws -> String {
        let run = revision
        try validate(context, run: run)
        let bytes = Int64(try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        guard bytes > 0, bytes <= 50 * 1024 else { throw OwnProfileError.invalid("头像图片无效，请重新选择") }
        let result = try await transfer.upload(ChatAttachment(file: file, type: ChatAttachment.userAvatarType,
            name: file.lastPathComponent, bytes: bytes), context: context) { _ in }
        try validate(context, run: run)
        return result.resource
    }

    /// 参数沿旧端userUid和nickname/avatar，空成功回执接受，明确false拒绝。
    func save(_ change: OwnProfileChange, context: ChatContext) async throws {
        let run = revision
        try validate(context, run: run)
        let parameters = NSMutableDictionary(dictionary: change.fields.merging(["userUid": context.userUID]) { _, new in new })
        let waiter = SDKChatRequestWaiter<Bool>(); self.waiter = waiter
        defer { if revision == run { self.waiter = nil } }
        let accepted = try await waiter.run {
            let success: LingIMSuccessCallback = { data, _ in
                let accepted: Bool
                if let number = data as? NSNumber { accepted = number.boolValue }
                else if let text = data as? String { accepted = !["false", "0"].contains(text.lowercased()) }
                else { accepted = true }
                Task { @MainActor in waiter.finish(.success(accepted)) }
            }
            let failure: LingIMFailureCallback = { code, message, _ in
                let text = message.flatMap { $0.isEmpty ? nil : $0 } ?? "资料保存失败（\(code)），请重试"
                Task { @MainActor in waiter.finish(.failure(OwnProfileError.invalid(text))) }
            }
            switch change {
            case .nickname: NoaIMSDKManager.sharedTool().userNicknameChange(with: parameters, onSuccess: success, onFailure: failure)
            case .avatar: NoaIMSDKManager.sharedTool().userAvatarChange(with: parameters, onSuccess: success, onFailure: failure)
            }
        }
        try validate(context, run: run)
        guard accepted else { throw OwnProfileError.invalid("服务器未接受资料修改，请重试") }
    }

    /// 在主线程同步提交最新资料，昵称同时供SDK后续发送使用。
    func apply(_ change: OwnProfileChange, context: ChatContext) throws {
        try validate(context, run: revision)
        try UserSessionStore.shared.updateProfile(change.fields, userUID: context.userUID, lastLiceseId: context.tenantID)
        if case .nickname(let value) = change { NoaIMSDKManager.sharedTool().configNewUserNickName(value) }
    }

    /// 页面与根AUTH退出均可立即结束等待及上传。
    func cancel() { revision = UUID(); transfer.cancel(); waiter?.cancel(); waiter = nil }

    /// 同UID重新登录也不得消费上一认证轮次的回包。
    private func validate(_ context: ChatContext, run: UUID) throws {
        try Task.checkCancellation()
        let sdk = NoaIMSDKManager.sharedTool()
        guard revision == run, ChatRuntime.shared.isCurrent(context), sdk.myUserID() == context.userUID,
              sdk.isUserDatabaseReady(), UserSessionStore.shared.currentUser?.userUID == context.userUID,
              OSSConnectionBootstrap.shared.current?.lastLiceseId == context.tenantID else { throw CancellationError() }
    }
}
