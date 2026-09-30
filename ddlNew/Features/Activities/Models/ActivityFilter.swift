//
//  ActivityFilter.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation

enum ActivityFilter: String, CaseIterable, Identifiable {
    case all = "全部", available = "可报名", registered = "已报名", ended = "已结束"
    var id: Self { self }
}
