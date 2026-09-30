//
//  ClubDetailChrome.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct ClubDetailChrome: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            content.toolbar(.hidden, for: .tabBar)
        } else {
            content
        }
    }
}
