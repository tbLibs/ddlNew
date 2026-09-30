//
//  ActivityCard.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct ActivityCard: View {
    @EnvironmentObject private var store: ClubStore
    @EnvironmentObject private var navigation: ActivityNavigation
    let activity: ClubActivity
    var body: some View {
        Button { navigation.open(activity) } label: {
            ClubCard(padding: 13) {
                HStack(spacing: 13) {
                    RoundedRectangle(cornerRadius: 16).fill(ClubTheme.wash).frame(width: 88, height: 120)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 7) {
                        ClubBadge(text: store.status(activity).title)
                        Text(activity.title).font(.system(size: 14, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                        metadata(icon: "clock", text: activity.date)
                        metadata(icon: "map", text: activity.place)
                        HStack(spacing: 6) {
                            ClubIcon(name: "users", size: 14)
                            Text("伙伴已加入").font(.system(size: 11))
                            Spacer(minLength: 2)
                            ClubIcon(name: "chevron", size: 10)
                            Text("查看").font(.system(size: 11, weight: .semibold))
                        }.foregroundColor(ClubTheme.darkTeal)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }.buttonStyle(.plain).accessibilityIdentifier("activity.\(activity.id)")
    }
    private func metadata(icon: String, text: String) -> some View {
        HStack(spacing: 4) { ClubIcon(name: icon, size: 13); Text(text).font(.system(size: 11)) }.foregroundColor(ClubTheme.secondary)
    }
}
