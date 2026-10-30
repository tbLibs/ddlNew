//
//  HomeTheme.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI
import UIKit

/// 岩白与钴蓝语义色板；旧属性名保留以避免改变页面接口。
enum HomeTheme {
    static let background = adaptive(light: 0xF3F5F9, dark: 0x111923)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x192432)
    static let text = adaptive(light: 0x182536, dark: 0xEDF2FA)
    static let secondaryText = adaptive(light: 0x647184, dark: 0xACB9CC)
    static let forest = adaptive(light: 0x2859BC, dark: 0x9EBDFF)
    static let mintSurface = adaptive(light: 0xEAF0FC, dark: 0x253754)
    static let sandSurface = adaptive(light: 0xF3F5F9, dark: 0x202E3F)
    static let warmAccent = adaptive(light: 0x97611D, dark: 0xE5BD80)
    static let border = adaptive(light: 0xDFE5EE, dark: 0x354459)

    /// 插画与深色活动卡固定使用同一套前景色，避免系统主题改变图层关系。
    static let heroBackground = Color(clubHex: 0x142239)
    static let onHero = Color(clubHex: 0xF3F6FC)
    static let onHeroSecondary = Color(clubHex: 0xB8C9E3)
    static let mountainBack = Color(red: 0.35, green: 0.48, blue: 0.35)
    static let mountainFront = Color(red: 0.22, green: 0.37, blue: 0.27)
    static let sun = Color(red: 0.93, green: 0.79, blue: 0.52)

    static let cardRadius: CGFloat = 12
    static let contentWidth: CGFloat = 640

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
}
