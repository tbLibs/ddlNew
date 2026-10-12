//
//  BlacklistScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/10/12.
//

import SwiftUI

/// 保留旧演示黑名单，不影响 SDK 真实好友记录。
struct BlacklistScreen: View {
    @EnvironmentObject private var store: ClubStore
    @State private var removingID: String?
    @State private var errorMessage: String?

    private var blockedContacts: [ClubContact] {
        ClubContact.samples.filter { store.isBlocked($0.id) }
    }

    var body: some View {
        ClubScroll {
            VStack(alignment: .leading, spacing: 16) {
                Text("拉黑的好友不会出现在通讯录和私聊消息列表中。")
                    .font(.subheadline).foregroundColor(ClubTheme.secondary)
                if let errorMessage {
                    Text(errorMessage).font(.subheadline).foregroundColor(ClubTheme.error)
                }
                if blockedContacts.isEmpty {
                    EmptyClubState(title: "黑名单为空", message: "在成员资料中可以拉黑好友。")
                } else {
                    ForEach(blockedContacts) { contact in
                        ClubCard {
                            HStack(spacing: 14) {
                                ContactAvatar(contact: contact, size: 44)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(contact.name).font(.body.weight(.semibold))
                                    Text(contact.role).font(.caption).foregroundColor(ClubTheme.secondary)
                                }
                                Spacer()
                                Button("移出黑名单") {
                                    removingID = contact.id
                                    errorMessage = nil
                                    Task {
                                        do { try await store.unblockContact(contact.id) }
                                        catch { errorMessage = "移出失败，请重试。" }
                                        removingID = nil
                                    }
                                }
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(ClubTheme.darkTeal)
                                .disabled(removingID != nil)
                                .accessibilityIdentifier("unblock.\(contact.id)")
                            }
                        }
                    }
                }
            }.padding(20)
        }
        .navigationTitle("黑名单").navigationBarTitleDisplayMode(.inline)
        .modifier(ClubDetailChrome())
    }
}
