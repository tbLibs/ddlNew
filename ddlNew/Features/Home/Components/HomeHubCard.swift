//
//  HomeHubCard.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 活动和俱乐部的一级入口；卡片整体可点，放大字体时允许纵向展开。
struct HomeHubCard: View {
    let destination: ClubHomeDestination
    let detail: String

    private var isActivities: Bool { destination == .activities }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: isActivities ? "figure.hiking" : "leaf")
                    .font(.system(size: 24, weight: .medium))
                    .frame(width: 44, height: 44)
                    .background(HomeTheme.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right").font(.subheadline.weight(.semibold))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(destination.title).font(.title3.weight(.bold))
                Text(detail).font(.subheadline).foregroundStyle(HomeTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(HomeTheme.forest)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(isActivities ? HomeTheme.mintSurface : HomeTheme.sandSurface,
                    in: RoundedRectangle(cornerRadius: HomeTheme.cardRadius))
        .accessibilityElement(children: .combine)
    }
}
