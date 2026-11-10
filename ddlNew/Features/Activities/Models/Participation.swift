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
        case .available: return L10n.tr("可报名")
        case .registered: return L10n.tr("已报名")
        case .waiting: return L10n.tr("候补中")
        case .checkedIn: return L10n.tr("已签到")
        case .ended: return L10n.tr("已结束")
        }
    }
}
