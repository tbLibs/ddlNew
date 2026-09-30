//
//  ScreenHeading.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct ScreenHeading: View {
    let eyebrow: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow).font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
            Text(title).font(.system(size: 27, weight: .bold))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
