//
//  HomeActivityRow.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct HomeActivityRow: View {
    let activity: ClubActivity
    let status: Participation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(activity.title).font(.body.weight(.semibold)).foregroundStyle(HomeTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(activity.date) · \(activity.place)")
                        .font(.subheadline).foregroundStyle(HomeTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if status != .available {
                        Text(status.title).font(.caption.weight(.medium)).foregroundStyle(HomeTheme.forest)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    .foregroundStyle(HomeTheme.secondaryText).accessibilityHidden(true)
            }
            .padding(.vertical, 18).frame(minHeight: 64)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(MessagingTheme.divider).frame(height: 1) }
        }
        .buttonStyle(HomePressStyle())
        .accessibilityLabel("\(activity.title)，\(activity.date)，\(activity.place)，\(status.title)")
        .accessibilityHint("查看活动详情")
        .accessibilityIdentifier("home.activity.\(activity.id)")
    }
}
