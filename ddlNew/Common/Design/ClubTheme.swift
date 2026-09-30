//
//  ClubTheme.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 消息、通讯录、个人中心等页面共用的配色。
enum ClubTheme {
    static let background = Color(clubHex: 0xFAF8F4)
    static let card = Color(clubHex: 0xFFFDF9)
    static let ink = Color(clubHex: 0x173D3B)
    static let secondary = Color(clubHex: 0x667A77)
    static let teal = Color(clubHex: 0x00B9B1)
    static let darkTeal = Color(clubHex: 0x008C86)
    static let border = Color(clubHex: 0xDDD8CF)
    static let pale = Color(clubHex: 0xD1F2F0)
    static let error = Color(clubHex: 0xB4233F)
    static let wash = LinearGradient(colors: [pale, Color(clubHex: 0xF5F9F8)], startPoint: .leading, endPoint: .trailing)
    static let action = LinearGradient(colors: [Color(clubHex: 0x00C7BE), Color(clubHex: 0x00A69F)], startPoint: .topLeading, endPoint: .bottomTrailing)
}
