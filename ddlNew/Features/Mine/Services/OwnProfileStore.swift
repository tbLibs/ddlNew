//
//  OwnProfileStore.swift
//  ddlNew
//
//  Created by taobo on 2026/10/28.
//
import Foundation
import Combine

/// 编辑稿与认证快照绑定，只有服务器受理且页面仍有效才发布资料。
@MainActor final class OwnProfileStore: ObservableObject {
    @Published var nickname: String
    @Published private(set) var busy = false
    @Published private(set) var feedback: String?
    private var originalNickname: String
    private let context: ChatContext
    private let client: any OwnProfileClient
    private let isCurrent: (ChatContext) -> Bool
    private var revision = UUID()
    private var closed = false

    /// 页面拥有草稿；客户端边界可在离线检查中替换。
    init(context: ChatContext, nickname: String, client: any OwnProfileClient, isCurrent: @escaping (ChatContext) -> Bool) {
        self.context = context; self.nickname = nickname; originalNickname = nickname
        self.client = client; self.isCurrent = isCurrent
    }

    /// 保留旧端引号规则，提交时去首尾空白，避免修改中文输入法组词内容。
    var normalizedNickname: String {
        nickname.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "’", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    var canSaveNickname: Bool {
        !busy && !closed && isCurrent(context) && !normalizedNickname.isEmpty
            && normalizedNickname.utf16.count <= 30 && normalizedNickname != originalNickname
    }

    /// 每次打开昵称编辑使用当前资料，外部刷新不自动改写正在输入的草稿。
    func beginNickname(_ value: String) {
        guard !busy, !closed else { return }
        nickname = value; originalNickname = value; feedback = nil
    }

    /// 保存捕获不可变昵称，等待期间的草稿变化不影响已提交值。
    func saveNickname() async -> Bool {
        guard canSaveNickname else { return false }
        let value = normalizedNickname
        let success = await submit(.nickname(value))
        if success { originalNickname = value; nickname = value }
        return success
    }

    /// 接管裁剪后文件所有权，上传失败或取消均清理，不提前替换旧头像。
    func saveAvatar(_ file: URL) async -> Bool {
        defer { try? FileManager.default.removeItem(at: file) }
        guard !busy, !closed, isCurrent(context) else { return false }
        let run = revision
        busy = true; feedback = nil
        defer { if revision == run { busy = false } }
        do {
            let resource = try await client.upload(file, context: context)
            try validate(run)
            guard !resource.isEmpty else { throw OwnProfileError.invalid("头像上传失败，请重试") }
            let change = OwnProfileChange.avatar(resource)
            try await client.save(change, context: context)
            try validate(run)
            try client.apply(change, context: context)
            feedback = "头像已更新"
            return true
        } catch { report(error, run: run); return false }
    }

    /// 主动修改成功后同步发布；失败保留原资料与当前编辑稿。
    private func submit(_ change: OwnProfileChange) async -> Bool {
        let run = revision
        busy = true; feedback = nil
        defer { if revision == run { busy = false } }
        do {
            try validate(run)
            try await client.save(change, context: context)
            try validate(run)
            try client.apply(change, context: context)
            feedback = "昵称已更新"
            return true
        } catch { report(error, run: run); return false }
    }

    /// 根退出和关闭编辑页面使在途回执失效。
    func close() { closed = true; revision = UUID(); client.cancel(); busy = false; feedback = nil }

    /// 每个等待边界都复核页面及完整认证身份。
    private func validate(_ run: UUID) throws {
        try Task.checkCancellation()
        guard !closed, revision == run, isCurrent(context) else { throw CancellationError() }
    }

    /// 旧页面或取消不向新账号显示结果。
    private func report(_ error: Error, run: UUID) {
        guard revision == run, !closed, isCurrent(context), !(error is CancellationError) else { return }
        feedback = error.localizedDescription
    }
}
