//
//  ClubIcon.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct ClubIcon: View {
    let name: String
    var size: CGFloat = 18
    var body: some View {
        Image("club-\(name)").renderingMode(.template).resizable().scaledToFit()
            .frame(width: size, height: size).accessibilityHidden(true)
    }
}
