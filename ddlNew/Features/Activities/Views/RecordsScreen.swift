//
//  RecordsScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct RecordsScreen: View {
    @Environment(\.locale) private var localizationLocale
    @EnvironmentObject private var store: ClubStore
    let kind: RecordKind
    private var records: [ClubActivity] {
        switch kind {
        case .registered: return store.activities(with: [.registered, .checkedIn])
        case .waiting: return store.activities(with: [.waiting])
        case .checkedIn, .past: return store.activities(with: [.checkedIn])
        }
    }
    var body: some View {
        ClubScroll {
            VStack(spacing: 12) {
                if records.isEmpty {
                    EmptyClubState(title: L10n.tr("还没有相关记录"), message: L10n.tr("参加一场感兴趣的活动，留下新的回忆。"))
                    NavigationLink(L10n.tr("发现活动"), value: ClubHomeDestination.activities).buttonStyle(ClubButtonStyle())
                } else { ForEach(records) { ActivityCard(activity: $0) } }
            }.padding(20)
        }.toolbar(.visible, for: .navigationBar).navigationTitle(kind.displayName).navigationBarTitleDisplayMode(.inline)
    }
}
