//
//  MemberAvatar.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct MemberAvatar: View {
    @EnvironmentObject private var store: ClubStore
    var body: some View {
        Text(store.snapshot.activeAccount.map { String($0.prefix(2)).uppercased() } ?? "LX")
            .font(.system(size: 12)).foregroundColor(.white).frame(width: 40, height: 40)
            .background(ClubTheme.teal).clipShape(Circle()).accessibilityHidden(true)
    }
}
