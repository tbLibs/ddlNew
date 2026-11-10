//
//  ClubScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct ClubScreen: View {
    @Environment(\.locale) private var localizationLocale
    @State private var info: InformationPage?
    var body: some View {
        ClubScroll {
            VStack(spacing: 28) {
                VStack(spacing: 22) {
                    Text(L10n.tr("山")).font(.system(size: 31)).foregroundColor(ClubTheme.darkTeal)
                        .frame(width: 84, height: 84).background(ClubTheme.card.opacity(0.85)).clipShape(RoundedRectangle(cornerRadius: 28))
                    Text(L10n.tr("远山户外俱乐部")).font(.system(size: 30, weight: .bold))
                    Text(L10n.tr("每周走进自然，认真生活，也认真交朋友。")).font(.system(size: 14)).multilineTextAlignment(.center)
                    HStack {
                        statistic("186", label: L10n.tr("会员"))
                        Divider().frame(height: 40)
                        statistic("38", label: L10n.tr("本年活动"))
                        Divider().frame(height: 40)
                        statistic("2019", label: L10n.tr("成立"))
                    }
                }.padding(.horizontal, 20).padding(.top, 30).padding(.bottom, 25).frame(maxWidth: .infinity).background(ClubTheme.wash)
                VStack(spacing: 16) {
                    ClubCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(L10n.tr("如何参与")).font(.system(size: 17, weight: .semibold))
                            ForEach(Array([L10n.tr("选择适合自己的俱乐部活动"), L10n.tr("阅读参与条件与活动须知"), L10n.tr("完成报名或加入候补"), L10n.tr("按时到场并完成个人签到")].enumerated()), id: \.element) { index, text in
                                HStack(spacing: 12) {
                                    Text("\(index + 1)").font(.system(size: 12, weight: .semibold)).foregroundColor(ClubTheme.darkTeal)
                                        .frame(width: 30, height: 30).background(ClubTheme.wash).clipShape(Circle())
                                    Text(text).font(.system(size: 14))
                                }.frame(minHeight: 36)
                                if index < 3 { Divider() }
                            }
                        }
                    }
                    ClubCard {
                        VStack(spacing: 0) {
                            infoRow(L10n.tr("会员权益"), icon: "shield", page: .benefits)
                            Divider()
                            infoRow(L10n.tr("活动规则"), icon: "note", page: .rules)
                            Divider()
                            infoRow(L10n.tr("联系俱乐部"), icon: "person", page: .contact)
                        }
                    }
                }.padding(.horizontal, 20)
            }
        }.sheet(item: $info) { InformationSheet(page: $0) }
    }
    private func statistic(_ number: String, label: String) -> some View {
        VStack(spacing: 6) { Text(number).font(.system(size: 16, weight: .medium)); Text(label).font(.system(size: 12)) }.frame(maxWidth: .infinity)
    }
    private func infoRow(_ title: String, icon: String, page: InformationPage) -> some View {
        Button { info = page } label: { ClubMenuRow(title: title, icon: icon) }.buttonStyle(.plain)
    }
}
