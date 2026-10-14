//
//  ChatViewportPolicy.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import CoreGraphics

/// 底部判定独立于消息加载，支持iOS16的真实视口几何。
enum ChatViewportPolicy {
    /// 空视口和屏外锚点不算末尾，允许末尾正文的正常底部留白。
    static func isAtBottom(latest: CGRect, viewport: CGRect) -> Bool {
        guard viewport.width > 0, viewport.height > 0, latest.width > 0 else { return false }
        return latest.maxY >= viewport.minY && latest.minY <= viewport.maxY + 20
    }
}
