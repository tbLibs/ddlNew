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
    static let background = adaptive(0xF8F9FB, 0x16171C)
    static let surface = adaptive(0xFFFFFF, 0x202127)
    static let text = adaptive(0x111111, 0xF4F5FA)
    static let secondaryText = adaptive(0x62697B, 0xACB1C0)
    static let accent = HomeTheme.forest
    static let divider = adaptive(0xEEF1FA, 0x353740)
    static let border = HomeTheme.border
    static let pressed = adaptive(0xEEEFF5, 0x30323D)
    static let avatarBackground = HomeTheme.mintSurface
    static let error = adaptive(0xC72C41, 0xFF8494)
    static let badge = Color(clubHex: 0xD92D38)
    static let online = adaptive(0x16843B, 0x62D98A)
    static let primaryAction = HomeTheme.forest
    /// 深色主题的森林绿变浅，实色按钮与气泡需配深色文字。
    static let onPrimaryAction = adaptive(0xFFFFFF, 0x20392D)
    static let outgoingBubble = primaryAction
    static let mutedBadge = adaptive(0x62697B, 0x62697B)
    /// 浮层采用低饱和灰绿底，与页面有柔和层次，文字仍保持清晰对比。
    static let toastBackground = adaptive(0xE1E9E3, 0x2F3C34)
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
