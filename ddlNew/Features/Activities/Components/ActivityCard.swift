//
//  ActivityCard.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct ActivityCard: View {
    @EnvironmentObject private var store: ClubStore
    @EnvironmentObject private var navigation: ActivityNavigation
    let activity: ClubActivity
    var body: some View {
        HomeActivityRow(activity: activity, status: store.status(activity)) { navigation.open(activity) }
            .accessibilityIdentifier("activity.\(activity.id)")
    }
}
