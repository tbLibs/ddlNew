//
//  ClubBackground.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct ClubBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ClubTheme.wash.overlay(alignment: .topLeading) {
                Circle().fill(ClubTheme.pale.opacity(0.3))
                    .overlay(Circle().stroke(ClubTheme.teal.opacity(0.12), lineWidth: 1))
                    .frame(width: 342, height: 342).offset(x: -139, y: proxy.size.height * 0.14)
            }
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}
