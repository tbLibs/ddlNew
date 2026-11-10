//
//  SDKMiniAppFloatClient.swift
//  ddlNew
//
//  Created by taobo on 2026/11/09.
//
import Foundation
import NoaChatCore
@MainActor final class SDKMiniAppFloatClient: MiniAppFloatClient {
    private func prefix(_ context: ChatContext) -> String { Data(context.tenantID.utf8).base64EncodedString() + ":" }
    private func validate(_ context: ChatContext) throws {
        let sdk = NoaIMSDKManager.sharedTool()
        guard ChatRuntime.shared.isCurrent(context), sdk.myUserID() == context.userUID,
              sdk.isUserDatabaseReady(), OSSConnectionBootstrap.shared.current?.lastLiceseId == context.tenantID else { throw CancellationError() }

    }
    func load(context: ChatContext) throws -> [MiniAppFloatRecord] {
        try validate(context)
        return NoaIMSDKManager.sharedTool().imSdkGetMyFloatMiniAppList().compactMap { value in
            guard let id = value.floladId, id.hasPrefix(prefix(context)) else { return nil }
            return MiniAppFloatRecord(id: String(id.dropFirst(prefix(context).count)), title: value.title ?? "", url: value.url ?? "", icon: value.headerUrl ?? "")
        }
    }
    func save(_ record: MiniAppFloatRecord, context: ChatContext) throws {
        try validate(context)
        let value = NoaFloatMiniAppModel(); value.floladId = prefix(context) + record.id; value.title = record.title; value.url = record.url; value.headerUrl = record.icon
        guard NoaIMSDKManager.sharedTool().imSdkInsertFloatMiniApp(with: value) else { throw MiniAppError.invalid(L10n.tr("浮窗保存失败")) }
    }
    func delete(id: String, context: ChatContext) throws {
        try validate(context)
        guard NoaIMSDKManager.sharedTool().imSdkDeleteFloatMiniApp(with: prefix(context) + id) else { throw MiniAppError.invalid(L10n.tr("浮窗删除失败")) }
    }
    func clear(context: ChatContext) throws {
        try validate(context)
        for record in try load(context: context) { try delete(id: record.id, context: context) }
    }
}
