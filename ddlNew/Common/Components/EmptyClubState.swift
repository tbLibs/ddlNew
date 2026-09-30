//
//  EmptyClubState.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct EmptyClubState: View {
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 16) {
            ClubIcon(name: "calendar", size: 34).foregroundColor(ClubTheme.darkTeal)
                .frame(width: 78, height: 78).background(ClubTheme.wash).clipShape(RoundedRectangle(cornerRadius: 24))
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundColor(ClubTheme.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 44)
    }
}
