//
//  MiniAppRecord.swift
//  ddlNew
//
//  Created by taobo on 2026/11/09.
//
import Foundation

struct MiniAppRecord: Identifiable, Equatable {
    let id: String
    let name: String
    let url: String
    let icon: String
    let passwordEnabled: Bool
    let appType: Int
    let allowUserDelete: Int
    var canEdit: Bool { appType == 1 }
    var canDelete: Bool { appType == 1 || (appType == 0 && allowUserDelete == 1) }
}
struct MiniAppDraft {
    var name = ""
    var url = ""
    var icon = ""
    var password = ""
    var passwordBefore = ""
    var passwordEnabled = false
    init(record: MiniAppRecord? = nil) {
        if let record { name = record.name; url = record.url; icon = record.icon; passwordEnabled = record.passwordEnabled }
    }
    var validationMessage: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return L10n.tr("请输入应用名称") }
        guard MiniAppWebPolicy.entryURL(url) != nil else { return L10n.tr("请输入有效的网站地址") }
        if passwordEnabled && password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return L10n.tr("请输入访问密码") }
        return nil
    }
}
enum MiniAppError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let value) = self { return value }; return nil }
}
struct MiniAppFloatRecord: Identifiable, Equatable {
    let id: String
    var title: String
    var url: String
    var icon: String
}

struct MiniAppPage {
    let items: [MiniAppRecord]
    let hasMore: Bool
    static func record(_ raw: Any) throws -> MiniAppRecord {
        guard let d = raw as? [String: Any] else { throw MiniAppError.invalid(L10n.tr("应用数据无效")) }
        func text(_ key: String) -> String { (d[key] as? String) ?? (d[key] as? NSNumber)?.stringValue ?? "" }
        guard !text("qaUuid").isEmpty else { throw MiniAppError.invalid(L10n.tr("应用标识无效")) }
        return MiniAppRecord(id: text("qaUuid"), name: text("qaName"), url: text("qaAppUrl"), icon: text("qaAppPic"), passwordEnabled: text("qaPwdOpen") == "1", appType: Int(text("appType")) ?? -1, allowUserDelete: Int(text("allowUserDelete")) ?? 0)
    }
    static func parse(_ raw: Any, page: Int) throws -> MiniAppPage {
        guard let d = raw as? [String: Any], let rows = d["items"] as? [Any],
              let pages = Int((d["pages"] as? String) ?? (d["pages"] as? NSNumber)?.stringValue ?? ""), pages >= 0 else { throw MiniAppError.invalid(L10n.tr("应用列表无效")) }
        return MiniAppPage(items: try rows.map(record), hasMore: page < pages)
    }
}
