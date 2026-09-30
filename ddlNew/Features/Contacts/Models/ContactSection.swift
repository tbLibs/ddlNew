//
//  ContactSection.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

/// 按姓名首字母分组；特殊名称和已注销账号归入最后的 # 分组。
nonisolated struct ContactSection: Identifiable, Equatable, Sendable {
    let id: String
    let contacts: [ContactRecord]
}
