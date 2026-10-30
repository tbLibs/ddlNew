//
//  LoginBackground.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import SwiftUI

/// 纯色画布让输入与连接状态保持清晰。
struct LoginBackground: View {
    var body: some View {
        LoginPalette.background.ignoresSafeArea().accessibilityHidden(true)
    }
}
