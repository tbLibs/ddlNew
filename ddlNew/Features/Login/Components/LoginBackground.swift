//
//  LoginBackground.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import SwiftUI
import TBBasicLib

/// 登录页渐变背景和圆形装饰，与其他页面没有代码依赖。
struct LoginBackground: View {
    var body: some View {
        GeometryReader { proxy in
            LoginPalette.wash
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(LoginPalette.pale.opacity(0.3))
                        .overlay {
                            Circle().stroke(LoginPalette.teal.opacity(0.12), lineWidth: 1)
                        }
                        .frame(width: 342, height: 342)
                        .offset(x: -139, y: proxy.size.height * 0.14)
                }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
