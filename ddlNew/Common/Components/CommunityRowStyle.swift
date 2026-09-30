//
//  CommunityRowStyle.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct CommunityRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(configuration.isPressed ? ClubTheme.pale.opacity(0.35) : .clear)
    }
}
