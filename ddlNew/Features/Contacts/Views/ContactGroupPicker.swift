//
//  ContactGroupPicker.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

/// 移动分组只提交SDK确认的分组ID。
struct ContactGroupPicker: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var businessStore: ContactsBusinessStore
    let contactID: String
    var sourceGroupID: String? = nil
    var body: some View {
        NavigationStack {
            List {
                ForEach(businessStore.groups) { group in
                    Button { Task { if await businessStore.perform(.moveFriend(friendID: contactID, groupID: group.id), sourceGroupID: sourceGroupID) { dismiss() } } } label: { Text(group.name).foregroundStyle(.primary) }
                        .disabled(businessStore.isSubmitting)
                }
                if let error = businessStore.errorMessage { Text(error).foregroundStyle(ClubTheme.error) }
            }
            .navigationTitle("移动到分组").navigationBarTitleDisplayMode(.inline).navigationBarHidden(false)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(businessStore.isSubmitting) } }
            .task { await businessStore.reload() }
            .tint(HomeTheme.forest)
            .interactiveDismissDisabled(businessStore.isSubmitting)
        }
    }
}
