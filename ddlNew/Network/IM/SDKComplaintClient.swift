//
//  SDKComplaintClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import Foundation
import NoaChatCore

/// 投诉复用SDK验签和通用证据上传，不生成聊天消息或本地举报记录。
@MainActor final class SDKComplaintClient: ComplaintClient {
    private let transfer = SDKChatMediaClient()
    private var generation = UUID()
    private var waiter: SDKChatRequestWaiter<Bool>?

    /// 通用目录与旧端一致；权限绑定当前认证，不套用聊天图片发送配额。
    func upload(_ file: URL, context: ChatContext) async throws -> String {
        let run = generation
        try validate(context, run: run)
        let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        let attachment = ChatAttachment(file: file, type: ChatAttachment.complaintEvidenceType, name: file.lastPathComponent, bytes: Int64(size))
        let result = try await transfer.upload(attachment, context: context) { _ in }
        try validate(context, run: run)
        guard !result.resource.isEmpty else { throw ComplaintError.invalidInput("图片上传失败，请重试") }
        return result.resource
    }

    /// 仅系统投诉接口；SDK业务成功回调才受理，明确false仍按拒绝处理。
    func submit(_ parameters: [String: String], context: ChatContext) async throws {
        let run = generation
        try validate(context, run: run)
        guard parameters["userUid"] == context.userUID else { throw ChatClientError.sessionExpired }
        let waiter = SDKChatRequestWaiter<Bool>(); self.waiter = waiter
        defer { if generation == run { self.waiter = nil } }
        let accepted = try await waiter.run {
            NoaIMSDKManager.sharedTool().userAddFeedBack(with: NSMutableDictionary(dictionary: parameters), onSuccess: { data, _ in
                let accepted = (data as? NSNumber)?.boolValue ?? true
                Task { @MainActor in waiter.finish(.success(accepted)) }
            }, onFailure: { code, message, _ in
                let detail = message.flatMap { $0.isEmpty ? nil : $0 } ?? "投诉提交失败，请稍后重试"
                let text = code == 44016 ? "申请提交成功，系统稍后处理" : code == 44017 ? "已提交申请，请等待审核" : detail
                Task { @MainActor in waiter.finish(.failure(ComplaintError.invalidInput(text))) }
            })
        }
        try validate(context, run: run)
        guard accepted else { throw ComplaintError.invalidInput("服务器未受理投诉，请稍后重试") }
    }

    /// 退出及表单关闭立即终止Swift等待，SDK迟到回调不能改变新会话页面。
    func cancel() { generation = UUID(); transfer.cancel(); waiter?.cancel(); waiter = nil }

    /// 每次等待前后确认完整认证轮次，群来源资料限制不因打开投诉而绕过。
    private func validate(_ context: ChatContext, run: UUID) throws {
        try Task.checkCancellation()
        let sdk = NoaIMSDKManager.sharedTool()
        guard generation == run, ChatRuntime.shared.isCurrent(context), sdk.myUserID() == context.userUID,
              sdk.isUserDatabaseReady(), OSSConnectionBootstrap.shared.current?.lastLiceseId == context.tenantID else { throw ChatClientError.sessionExpired }
        if context.route.kind == .group {
            let cached: LingIMGroupModel? = sdk.toolCheckMyGroup(with: context.route.id)
            guard let group = cached, group.groupStatus == 1, group.leaveGroupStatus == 0 else { throw ComplaintError.invalidInput("当前已不在该群中") }
        }
        if let id = context.route.sourceGroupID {
            let cached: LingIMGroupModel? = sdk.toolCheckMyGroup(with: id)
            guard let group = cached, group.groupStatus == 1, group.leaveGroupStatus == 0,
                  group.userGroupRole > 0 || !group.isPrivateChat || UserRoleAuthorityStore.shared.current?.allows("groupSecurity") == true else { throw ComplaintError.invalidInput("来源群当前不允许访问成员资料") }
        }
    }
}
