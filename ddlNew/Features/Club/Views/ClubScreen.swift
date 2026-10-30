//
//  ClubScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct ClubScreen: View {
    @State private var info: InformationPage?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("远山户外俱乐部").font(.title.weight(.bold))
                    Text("每周走进自然，认真生活，也认真交朋友。").font(.subheadline).multilineTextAlignment(.leading)
                    HStack {
                        statistic("186", label: "会员")
                        Divider().frame(height: 40)
                        statistic("38", label: "本年活动")
                        Divider().frame(height: 40)
                        statistic("2019", label: "成立")
                    }
                }.padding(.horizontal, 20).padding(.top, 28)
                VStack(spacing: 16) {
                    Group {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("如何参与").font(.body.weight(.semibold))
                            ForEach(Array(["选择适合自己的俱乐部活动", "阅读参与条件与活动须知", "完成报名或加入候补", "按时到场并完成个人签到"].enumerated()), id: \.element) { index, text in
                                Text(text).font(.subheadline).foregroundStyle(ClubTheme.secondary).frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    Group {
                        VStack(spacing: 0) {
                            infoRow("会员权益", icon: "shield", page: .benefits)
                            Divider()
                            infoRow("活动规则", icon: "note", page: .rules)
                            Divider()
                            infoRow("联系俱乐部", icon: "person", page: .contact)
                        }
                    }
                }.padding(.horizontal, 20)
            }
        }.background(ClubTheme.card.ignoresSafeArea()).foregroundStyle(ClubTheme.ink).tint(ClubTheme.teal).sheet(item: $info) { InformationSheet(page: $0) }
    }
    private func statistic(_ number: String, label: String) -> some View {
        VStack(spacing: 6) { Text(number).font(.body.weight(.medium)); Text(label).font(.subheadline) }.frame(maxWidth: .infinity)
    }
    private func infoRow(_ title: String, icon: String, page: InformationPage) -> some View {
        Button { info = page } label: { HStack { Text(title).font(.body.weight(.semibold)); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(ClubTheme.secondary) }.frame(minHeight: 60).contentShape(Rectangle()) }.buttonStyle(.plain)
    }
}
