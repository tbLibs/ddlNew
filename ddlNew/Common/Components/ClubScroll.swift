//
//  ClubScroll.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI
import SwiftUIIntrospect

struct ClubScroll<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        ScrollView {
            content.frame(maxWidth: 600).frame(maxWidth: .infinity).padding(.bottom, 28)
        }
        .introspect(.scrollView, on: .iOS(.v15, .v16, .v17, .v18, .v26, .v27)) {
            $0.keyboardDismissMode = .interactive
        }
        .background(ClubTheme.background.ignoresSafeArea())
    }
}
