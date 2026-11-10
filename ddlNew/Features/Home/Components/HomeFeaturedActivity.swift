//
//  HomeFeaturedActivity.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 优先展示已报名的下一场；没有报名时展示可探索的活动，不伪造参与状态。
struct HomeFeaturedActivity: View {
    @Environment(\.locale) private var localizationLocale
    let activity: ClubActivity
    let status: Participation
    let action: () -> Void

    private var isRegistered: Bool { status == .registered }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HomeLandscape()
                    .frame(height: 104)
                    .overlay(alignment: .topLeading) {
                        Label(isRegistered ? L10n.tr("我的下一场") : L10n.tr("下一站，去户外"), systemImage: "sun.max")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(HomeTheme.onHero)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(HomeTheme.heroBackground.opacity(0.85), in: Capsule())
                            .padding(16)
                    }

                VStack(alignment: .leading, spacing: 14) {
                    Text(activity.displayTitle).font(.title2.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 8) {
                        Label(activity.displayDate, systemImage: "calendar")
                        Label(activity.displayPlace, systemImage: "mappin.and.ellipse")
                    }
                    .font(.subheadline).foregroundStyle(HomeTheme.onHeroSecondary)

                    HStack(spacing: 12) {
                        Text(isRegistered ? L10n.tr("查看参与信息") : L10n.tr("查看活动详情"))
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true).layoutPriority(1)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.right").accessibilityHidden(true)
                    }
                    .padding(.top, 10)
                    .overlay(alignment: .top) { Rectangle().fill(HomeTheme.onHero.opacity(0.2)).frame(height: 1) }
                }
                .foregroundStyle(HomeTheme.onHero)
                .padding(20)
            }
            .background(HomeTheme.heroBackground)
            .clipShape(RoundedRectangle(cornerRadius: HomeTheme.cardRadius))
        }
        .buttonStyle(HomePressStyle())
        .accessibilityLabel(L10n.tr("\(isRegistered ? L10n.tr("我的下一场") : L10n.tr("推荐活动"))，\(activity.displayTitle)，\(activity.displayDate)，\(activity.displayPlace)，\(status.title)"))
        .accessibilityHint(L10n.tr("打开活动详情与参与信息"))
        .accessibilityIdentifier("home.featuredActivity")
    }
}
