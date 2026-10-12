//
//  ReportHistoryScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/10/12.
//

import SwiftUI

struct ReportHistoryScreen: View {
    @EnvironmentObject private var store: ClubStore

    var body: some View {
        ClubScroll {
            VStack(alignment: .leading, spacing: 16) {
                if store.reportRecords.isEmpty {
                    EmptyClubState(title: "暂无举报记录", message: "在聊天中打开消息操作，即可举报具体消息。")
                } else {
                    ForEach(store.reportRecords) { report in
                        ClubCard {
                            VStack(alignment: .leading, spacing: 9) {
                                HStack {
                                    Text(report.reason.rawValue).font(.headline)
                                    Spacer()
                                    Text(report.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption).foregroundColor(ClubTheme.secondary)
                                }
                                Text(report.sourceTitle).font(.subheadline.weight(.medium))
                                Text(report.messageText).font(.subheadline).foregroundColor(ClubTheme.secondary)
                                    .lineLimit(3)
                                if !report.details.isEmpty {
                                    Divider()
                                    Text(report.details).font(.subheadline).foregroundColor(ClubTheme.secondary)
                                }
                            }
                        }
                        .accessibilityIdentifier("reportRecord.\(report.id.uuidString)")
                    }
                }
            }.padding(20)
        }
        .navigationTitle("举报记录").navigationBarTitleDisplayMode(.inline)
        .modifier(ClubDetailChrome())
    }
}
