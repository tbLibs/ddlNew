//
//  ContactFilter.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation

enum ContactFilter: String, CaseIterable, Identifiable {
    case all = "全部", leaders = "领队", favorites = "常用"
    var id: Self { self }
}
