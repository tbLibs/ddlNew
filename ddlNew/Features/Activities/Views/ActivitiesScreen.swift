//
//  ActivitiesScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct ActivitiesScreen: View {
    @EnvironmentObject private var store: ClubStore
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var filter: ActivityFilter = .all
    private var filtered: [ClubActivity] {
        store.activities.filter { activity in
            let matchesQuery = query.isEmpty || (activity.title + activity.place).localizedCaseInsensitiveContains(query)
            let status = store.status(activity)
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .available: matchesFilter = status == .available
            case .registered: matchesFilter = status == .registered || status == .checkedIn
            case .ended: matchesFilter = status == .ended
            }
            return matchesQuery && matchesFilter
        }
    }
    var body: some View {
        ClubScroll {
            VStack(alignment: .leading, spacing: 14) {
                CommunitySearchField(placeholder: "搜索活动或地点", text: $query,
                                     focus: $searchFocused, identifier: "activitySearch")
                ScrollView(.horizontal, showsIndicators: false) {
                    MessagingTabs(selection: $filter)
                }
                if filtered.isEmpty {
                    EmptyClubState(title: "暂无符合条件的活动", message: "试试其他关键词，或切换活动分类。")
                } else {
                    LazyVStack(spacing: 0) { ForEach(filtered) { ActivityCard(activity: $0) } }
                }
            }.padding(.horizontal, 20).padding(.top, 18)
        }
        .navigationTitle("活动").navigationBarTitleDisplayMode(.inline)
        .modifier(ClubKeyboardDismissal(isFocused: searchFocused) { searchFocused = false })
    }
}
