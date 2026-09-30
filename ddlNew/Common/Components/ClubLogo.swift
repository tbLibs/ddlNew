//
//  ClubLogo.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct ClubLogo: View {
    var size: CGFloat = 72
    var body: some View {
        Image("club-logo").resizable().scaledToFit()
            .frame(width: size * 222 / 142, height: size * 234 / 142)
            .frame(width: size, height: size).accessibilityLabel("活动空间")
    }
}
