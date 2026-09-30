//
//  Participation.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation

nonisolated enum Participation: String, Codable, Sendable {
    case available, registered, waiting, checkedIn, ended
    var title: String {
        switch self {
        case .available: return "可报名"
        case .registered: return "已报名"
        case .waiting: return "候补中"
        case .checkedIn: return "已签到"
        case .ended: return "已结束"
        }
    }
}
