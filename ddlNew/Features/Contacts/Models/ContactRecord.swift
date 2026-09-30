//
//  ContactRecord.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import Foundation

/// SDK 好友的不可变展示快照，页面不直接修改数据库模型。
nonisolated struct ContactRecord: Identifiable, Equatable, Sendable {
    /// 好友 UID，同时作为列表和资料页的稳定标识。
    let id: String
    let account: String
    let nickname: String
    /// 完整拼音用于搜索；首字母排序仍沿用老项目规则。
    let nicknamePinyin: String
    let remarksPinyin: String
    /// 有备注时优先展示备注，和老项目保持一致。
    let remarks: String
    let description: String
    /// SDK 返回的头像地址，可能是完整 URL 或文件 Host 下的相对路径。
    let avatar: String
    let isOnline: Bool
    /// 服务端账号状态：0 正常、1 封禁、3 注销中、4 已注销。
    let disableStatus: Int
    /// 0 为普通好友，1 为文件助手等系统账号。
    let userType: Int
    /// 映射时一次性生成排序键，避免列表比较时反复执行中文转换。
    let sortName: String

    init(id: String, account: String = "", nickname: String = "", remarks: String = "",
         description: String = "", avatar: String = "", isOnline: Bool = false,
         disableStatus: Int = 0, userType: Int = 0,
         nicknamePinyin: String = "", remarksPinyin: String = "") {
        self.id = id
        self.account = account
        self.nickname = nickname
        self.nicknamePinyin = nicknamePinyin.isEmpty ? ContactSorter.searchPinyin(for: nickname) : nicknamePinyin
        self.remarksPinyin = remarksPinyin.isEmpty ? ContactSorter.searchPinyin(for: remarks) : remarksPinyin
        self.remarks = remarks
        self.description = description
        self.avatar = avatar
        self.isOnline = isOnline
        self.disableStatus = disableStatus
        self.userType = userType
        let name = [remarks, nickname, account, id].first { !$0.isEmpty } ?? id
        self.sortName = ContactSorter.sortName(for: name + account)
    }

    var isDeleted: Bool { disableStatus == 4 }
    var displayName: String {
        if isDeleted { return "账号已注销" }
        return [remarks, nickname, account, id].first { !$0.isEmpty } ?? id
    }
    var initial: String {
        guard !isDeleted, let first = sortName.first, ("A"..."Z").contains(String(first)) else { return "#" }
        return String(first)
    }
    var searchText: String { [displayName, nickname, account, remarks, id, sortName, nicknamePinyin, remarksPinyin].joined(separator: " ") }

    /// 相对头像使用导航的文件 Host；已注销账号统一显示本地占位头像。
    func avatarURL(relativeTo fileHost: URL?) -> URL? {
        guard !isDeleted, !avatar.isEmpty else { return nil }
        let url = URL(string: avatar, relativeTo: fileHost)?.absoluteURL
        guard let url, ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
        return url
    }
}
