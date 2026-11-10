//
//  ComplaintReason.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import Foundation

/// 编码保持旧系统投诉协议，欺诈为8、其他为7，不按显示顺序重新编号。
nonisolated enum ComplaintReason: String, CaseIterable, Identifiable, Sendable {
    case harmful = "1", advertising = "2", racism = "3", discrimination = "4", harassment = "5", stolen = "6", fraud = "8", other = "7"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .harmful: return L10n.tr("发布违法有害信息")
        case .advertising: return L10n.tr("发布垃圾广告")
        case .racism: return L10n.tr("种族歧视")
        case .discrimination: return L10n.tr("存在文化歧视")
        case .harassment: return L10n.tr("辱骂骚扰")
        case .stolen: return L10n.tr("帐号可能被盗")
        case .fraud: return L10n.tr("存在欺诈行为")
        case .other: return L10n.tr("其他")
        }
    }
}
