//
//  HomeTheme.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI
import UIKit

/// 首页专用的自然色板；不改变尚未重设计的旧版业务页面。
enum HomeTheme {
    static let background = adaptive(light: 0xF7F7F2, dark: 0x151D19)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x202D25)
    static let text = adaptive(light: 0x20392D, dark: 0xF0F5EC)
    static let secondaryText = adaptive(light: 0x58665C, dark: 0xB9C9BD)
    static let forest = adaptive(light: 0x285B43, dark: 0xAED5B5)
    static let mintSurface = adaptive(light: 0xE6EDE2, dark: 0x2B4031)
    static let sandSurface = adaptive(light: 0xF1EBDD, dark: 0x3A3428)
    static let warmAccent = adaptive(light: 0x986127, dark: 0xEBC38D)
    static let border = adaptive(light: 0xD8DED5, dark: 0x425449)

    /// 插画与深色活动卡固定使用同一套前景色，避免系统主题改变图层关系。
    static let heroBackground = Color(red: 0.13, green: 0.25, blue: 0.19)
    static let onHero = Color(red: 0.97, green: 0.98, blue: 0.94)
    static let onHeroSecondary = Color(red: 0.79, green: 0.87, blue: 0.79)
    static let mountainBack = Color(red: 0.35, green: 0.48, blue: 0.35)
    static let mountainFront = Color(red: 0.22, green: 0.37, blue: 0.27)
    static let sun = Color(red: 0.93, green: 0.79, blue: 0.52)

    static let cardRadius: CGFloat = 24
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
