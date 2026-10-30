//
//  HomeFeaturedActivity.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 下一场活动以日期与参与信息组织；继续使用原来的活动和参与状态。
struct HomeFeaturedActivity: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let activity: ClubActivity
    let status: Participation
    let action: () -> Void

    private var isRegistered: Bool { status == .registered }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("下一场活动").font(.headline).foregroundStyle(HomeTheme.text)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 24))
            layout {
                HomeActivityDate(date: activity.date)
                VStack(alignment: .leading, spacing: 12) {
                    Text(activity.title).font(.title2.weight(.semibold))
                        .foregroundStyle(HomeTheme.text).fixedSize(horizontal: false, vertical: true)
                    Text("\(activity.date) · \(activity.place)")
                        .font(.subheadline).foregroundStyle(HomeTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(status.title, systemImage: isRegistered ? "checkmark.circle" : "calendar")
                        .font(.subheadline.weight(.medium)).foregroundStyle(HomeTheme.forest)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Button(isRegistered ? "查看参与信息" : "查看活动详情", action: action)
                .buttonStyle(ClubButtonStyle())
                .accessibilityIdentifier("home.featuredActivity")
        }
        .padding(.vertical, 24)
        .overlay(alignment: .top) { Rectangle().fill(MessagingTheme.divider).frame(height: 1) }
    }
}

/// 仅拆分已有展示日期；格式未知时完整显示原文，不推算年份或星期。
struct HomeActivityDate: View {
    let date: String
    @ScaledMetric(relativeTo: .largeTitle) private var daySize = 44

    private var dateParts: [String] {
        guard let token = date.split(separator: " ").first,
              token.contains("月"), token.hasSuffix("日") else { return [] }
        return token.dropLast().components(separatedBy: "月")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if dateParts.count == 2 {
                Text(dateParts[1]).font(.system(size: daySize, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(HomeTheme.forest)
                Text("\(dateParts[0])月").font(.subheadline).foregroundStyle(HomeTheme.secondaryText)
            } else {
                Text(date).font(.headline).foregroundStyle(HomeTheme.forest)
            }
        }
        .frame(minWidth: 72, alignment: .leading)
        .accessibilityElement(children: .ignore).accessibilityLabel(date)
    }
}
