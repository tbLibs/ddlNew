//
//  InvitationCodeLogo.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import SwiftUI
import TBBasicLib
import UIAdapter

/// 顶部俱乐部标志。
struct InvitationCodeLogo: View {
    /// 调用方传入的尺寸已经通过 UIAdapter 适配。
    let size: CGFloat

    var body: some View {
        Image("club-logo")
            .resizable()
            .scaledToFit()
            .frame(width: size * 222 / 142, height: size * 234 / 142)
            .frame(width: size, height: size)
            .accessibilityLabel("活动空间")
    }
}
