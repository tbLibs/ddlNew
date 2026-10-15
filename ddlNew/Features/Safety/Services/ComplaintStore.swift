//
//  ComplaintStore.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import Foundation
import Combine

@MainActor final class ComplaintStore: ObservableObject {
    @Published private(set) var isSubmitting = false
    @Published private(set) var submitted = false
    @Published private(set) var uploadedCount = 0
    @Published private(set) var errorMessage: String?
    private let client: any ComplaintClient
    private var generation = UUID()
    /// 客户端可注入受控上传以验证失败和迟到回执。
    init(client: any ComplaintClient) { self.client = client }

    /// 顺序上传保留证据顺序，任何失败或取消都禁止用部分图片提交。
    @discardableResult func submit(_ draft: ComplaintDraft, target: ComplaintTarget, context: ChatContext, nickname: String, account: String) async -> Bool {
        guard !isSubmitting, !submitted, !Task.isCancelled else { return false }
        do { try draft.validate(target: target, userUID: context.userUID) }
        catch { errorMessage = error.localizedDescription; return false }
        let run = generation
        isSubmitting = true; errorMessage = nil; uploadedCount = 0
        defer { if generation == run { isSubmitting = false } }
        do {
            var uploaded: [String] = []
            for file in draft.images {
                let resource = try await client.upload(file, context: context)
                guard generation == run, !Task.isCancelled else { return false }
                uploaded.append(resource); uploadedCount = uploaded.count
            }
            let parameters = try draft.parameters(target: target, userUID: context.userUID, nickname: nickname, account: account, uploaded: uploaded)
            try await client.submit(parameters, context: context)
            guard generation == run, !Task.isCancelled else { return false }
            submitted = true; return true
        } catch {
            if generation == run, !Task.isCancelled, !(error is CancellationError) { errorMessage = error.localizedDescription }
            return false
        }
    }
    /// 取消只撤销本轮资格，已经提交的服务器请求不能冒充可撤回。
    func close() { generation = UUID(); client.cancel(); isSubmitting = false; uploadedCount = 0; errorMessage = nil }
}
