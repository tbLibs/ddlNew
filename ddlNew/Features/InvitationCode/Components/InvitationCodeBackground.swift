//
//  InvitationCodeBackground.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import SwiftUI
import TBBasicLib
import UIAdapter

/// 复刻旧页面的渐变背景与圆形装饰。
struct InvitationCodeBackground: View {
    var body: some View {
        GeometryReader { proxy in
            InvitationCodePalette.wash
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(InvitationCodePalette.pale.opacity(0.3))
                        .overlay {
                            Circle()
                                .stroke(InvitationCodePalette.teal.opacity(0.12), lineWidth: 1.zoom())
                        }
                        .frame(width: 342.zoom(), height: 342.zoom())
                        .offset(x: (-139).zoom(), y: proxy.size.height * 0.14)
                }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
