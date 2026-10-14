//
//  MessagingTheme.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import SwiftUI
import UIKit

/// 消息与通讯录沿用 xgd 的中性底色和紫蓝强调，深色值独立配对。
enum MessagingTheme {
    static let background = adaptive(0xF8F9FB, 0x16171C)
    static let surface = adaptive(0xFFFFFF, 0x202127)
    static let text = adaptive(0x111111, 0xF4F5FA)
    static let secondaryText = adaptive(0x62697B, 0xACB1C0)
    static let accent = adaptive(0x5966F2, 0xA2AAFF)
    static let divider = adaptive(0xEEF1FA, 0x353740)
    static let border = adaptive(0xD8D9FF, 0x515575)
    static let pressed = adaptive(0xEEEFF5, 0x30323D)
    static let avatarBackground = adaptive(0xEEEFFF, 0x30334F)
    static let error = adaptive(0xC72C41, 0xFF8494)
    static let badge = Color(clubHex: 0xD92D38)
    static let online = adaptive(0x16843B, 0x62D98A)
    static let primaryAction = adaptive(0x5966F2, 0x505ECC)
    static let outgoingBubble = primaryAction
    static let mutedBadge = adaptive(0x62697B, 0x62697B)

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
