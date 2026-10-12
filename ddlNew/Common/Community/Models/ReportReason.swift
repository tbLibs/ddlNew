//
//  ReportReason.swift
//  ddlNew
//
//  Created by taobo on 2026/10/12.
//

import Foundation

nonisolated enum ReportReason: String, CaseIterable, Codable, Sendable, Identifiable {
    case harassment = "骚扰辱骂"
    case spam = "垃圾广告"
    case fraud = "诈骗诱导"
    case privacy = "泄露隐私"
    case inappropriate = "不当内容"
    case other = "其他"

    var id: Self { self }
}
