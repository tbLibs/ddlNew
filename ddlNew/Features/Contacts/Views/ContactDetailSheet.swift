//
//  ContactDetailSheet.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct ContactDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var community: ClubCommunity
    let contact: ClubContact
    var body: some View {
        NavigationView {
            ClubScroll {
                VStack(spacing: 24) {
                    ContactAvatar(contact: contact, size: 88).padding(.top, 24)
                    VStack(spacing: 10) {
                        Text(contact.name).font(.title2.bold())
                        ClubBadge(text: "远山户外俱乐部 · \(contact.role)")
                    }
                    ClubCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("关于我").font(.headline)
                            Text(contact.introduction).font(.body).lineSpacing(6)
                            Divider()
                            Text("兴趣爱好").font(.headline)
                            Text(contact.interests).font(.subheadline).foregroundColor(ClubTheme.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button(community.favorites.contains(contact.id) ? "移出常用联系人" : "添加为常用联系人") {
                        community.toggleFavorite(contact.id)
                    }.buttonStyle(ClubButtonStyle()).accessibilityIdentifier("toggleFavoriteContact")
                }.padding(24)
            }.navigationTitle("成员资料").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() }.accessibilityIdentifier("closeContact") } }
        }.navigationViewStyle(.stack)
    }
}
