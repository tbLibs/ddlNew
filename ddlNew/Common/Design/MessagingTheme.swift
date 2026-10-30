//
//  MessagingTheme.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import SwiftUI
import UIKit

/// 消息与通讯录沿用 xgd 的中性底色，品牌强调复用首页和我的主题色。
enum MessagingTheme {
    static let background = HomeTheme.background
    static let surface = HomeTheme.surface
    static let text = HomeTheme.text
    static let secondaryText = HomeTheme.secondaryText
    static let accent = HomeTheme.forest
    static let divider = adaptive(0xE8EDF4, 0x303E50)
    static let border = HomeTheme.border
    static let pressed = adaptive(0xF0F3F8, 0x263449)
    static let avatarBackground = HomeTheme.mintSurface
    static let error = adaptive(0xB9413E, 0xFF9B95)
    static let onError = adaptive(0xFFFFFF, 0x142239)
    static let badge = Color(clubHex: 0xB9413E)
    static let online = adaptive(0x16843B, 0x62D98A)
    static let primaryAction = HomeTheme.forest
    /// 实色按钮与浅蓝消息气泡分开定义前景，避免浅底白字。
    static let onPrimaryAction = adaptive(0xFFFFFF, 0x142239)
    static let outgoingBubble = adaptive(0xDCE7FD, 0x2B4165)
    static let onOutgoingBubble = adaptive(0x182536, 0xEDF2FA)
    static let mutedBadge = adaptive(0x62697B, 0x62697B)
    /// 短反馈使用独立中性底色，浅深色均与正文保持对比。
    static let toastBackground = adaptive(0xE5EBF5, 0x2B3A50)
    static let toastText = HomeTheme.text

    /// UIColor 动态解析使导航、列表与弹窗在系统主题变化时同步切换。
    private static func adaptive(_ light: UInt, _ dark: UInt) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((value >> 16) & 0xFF) / 255,
                           green: CGFloat((value >> 8) & 0xFF) / 255,
                           blue: CGFloat(value & 0xFF) / 255, alpha: 1)
        })
    }
}
