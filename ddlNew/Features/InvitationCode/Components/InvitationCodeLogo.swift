//
//  InvitationCodeLogo.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import SwiftUI
import UIAdapter

/// 叮咚聊应用品牌标志。
struct InvitationCodeLogo: View {
    /// 调用方传入的尺寸已经通过 UIAdapter 适配。
    let size: CGFloat

    var body: some View {
        Image("DingDongMark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("叮咚聊")
    }
}
