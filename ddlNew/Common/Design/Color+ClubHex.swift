//
//  Color+ClubHex.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 俱乐部主题使用的整数十六进制颜色转换，避免与字符串版本混淆。
extension Color {
    init(clubHex hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}
