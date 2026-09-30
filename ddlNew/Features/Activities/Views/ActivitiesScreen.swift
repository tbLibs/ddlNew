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
                ScreenHeading(eyebrow: "远山户外俱乐部", title: "活动").padding(.bottom, 6)
                HStack(spacing: 10) {
                    ClubIcon(name: "search")
                    TextField("搜索活动或地点", text: $query).focused($searchFocused).submitLabel(.search).font(.system(size: 14)).accessibilityIdentifier("activitySearch")
                    if !query.isEmpty { Button("清除") { query = "" }.font(.caption) }
                }.padding(12).background(ClubTheme.card).clipShape(RoundedRectangle(cornerRadius: 17))
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(ClubTheme.border, lineWidth: 1))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(ActivityFilter.allCases) { item in
                            Button { filter = item } label: {
                                Text(item.rawValue).font(.system(size: 14))
                                    .foregroundColor(filter == item ? .white : ClubTheme.secondary)
                                    .padding(.horizontal, 16).frame(minHeight: 38)
                                    .background(filter == item ? ClubTheme.teal : ClubTheme.card)
                                    .clipShape(Capsule()).overlay(Capsule().stroke(filter == item ? .clear : ClubTheme.border, lineWidth: 1))
                            }.accessibilityAddTraits(filter == item ? .isSelected : [])
                        }
                    }
                }
                if filtered.isEmpty {
                    EmptyClubState(title: "暂无符合条件的活动", message: "试试其他关键词，或切换活动分类。")
                } else {
                    LazyVStack(spacing: 12) { ForEach(filtered) { ActivityCard(activity: $0) } }
                }
            }.padding(.horizontal, 20).padding(.top, 18)
        }
        .modifier(ClubKeyboardDismissal(isFocused: searchFocused) { searchFocused = false })
    }
}
