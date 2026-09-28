//
//  LoginPalette.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import SwiftUI
import TBBasicLib

/// 登录页专属配色，使用新项目的颜色转换能力。
enum LoginPalette {
    static let background = Color(hex: "FAF8F4")
    static let card = Color(hex: "FFFDF9")
    static let ink = Color(hex: "173D3B")
    static let secondary = Color(hex: "667A77")
    static let teal = Color(hex: "00B9B1")
    static let darkTeal = Color(hex: "008C86")
    static let border = Color(hex: "DDD8CF")
    static let pale = Color(hex: "D1F2F0")
    static let wash = LinearGradient(
        colors: [pale, Color(hex: "F5F9F8")],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let action = LinearGradient(
        colors: [Color(hex: "00C7BE"), Color(hex: "00A69F")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
