//
//  InvitationCodeBackground.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import SwiftUI
import UIAdapter

/// 纯色画布让输入与连接状态保持清晰。
struct InvitationCodeBackground: View {
    var body: some View {
        InvitationCodePalette.background.ignoresSafeArea().accessibilityHidden(true)
    }
}
