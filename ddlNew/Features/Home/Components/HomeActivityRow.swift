//
//  HomeActivityRow.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 首页推荐列表，活动详情仍由现有报名流程处理。
struct HomeActivityRow: View {
    @Environment(\.locale) private var localizationLocale
    let activity: ClubActivity
    let status: Participation
    let action: () -> Void

    private var symbol: String {
        if activity.category.contains("骑行") { return "figure.outdoor.cycle" }
        if activity.category.contains("自然") { return "leaf" }
        return "figure.hiking"
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 24)).foregroundStyle(HomeTheme.forest)
                    .frame(width: 52, height: 60)
                    .background(HomeTheme.mintSurface, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    Text(activity.displayTitle).font(.headline).foregroundStyle(HomeTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(activity.displayDate) · \(activity.displayPlace)")
                        .font(.subheadline).foregroundStyle(HomeTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(status.title).font(.caption.weight(.semibold))
                        .foregroundStyle(HomeTheme.forest)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(HomeTheme.mintSurface, in: Capsule())
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold)).foregroundStyle(HomeTheme.secondaryText)
                    .padding(.top, 8).accessibilityHidden(true)
            }
            .padding(16)
            .background(HomeTheme.surface, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(HomePressStyle())
        .accessibilityLabel("\(activity.displayTitle)，\(activity.displayDate)，\(activity.displayPlace)，\(status.title)")
        .accessibilityHint(L10n.tr("查看活动详情"))
        .accessibilityIdentifier("home.activity.\(activity.id)")
    }
}
