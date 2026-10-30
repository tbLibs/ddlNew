//
//  ClubTheme.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 消息、通讯录、个人中心等页面共用的配色。
enum ClubTheme {
    static let background = HomeTheme.surface
    static let card = HomeTheme.surface
    static let ink = HomeTheme.text
    static let secondary = HomeTheme.secondaryText
    static let teal = HomeTheme.forest
    static let darkTeal = HomeTheme.forest
    static let border = HomeTheme.border
    static let pale = HomeTheme.mintSurface
    static let error = MessagingTheme.error
    static let wash = HomeTheme.background
    static let action = MessagingTheme.primaryAction
}
