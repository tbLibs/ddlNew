//
//  HomePressStyle.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 账户支持页面共用的按压反馈，不缩放布局，也不引入持续动效。
struct HomePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.72 : 1)
    }
}
