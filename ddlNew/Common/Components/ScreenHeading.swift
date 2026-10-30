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
            Text(title).font(.largeTitle.weight(.bold))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
