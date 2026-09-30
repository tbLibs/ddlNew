//
//  ContactsView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 通讯录列表，支持搜索、分类与发起聊天。
struct ContactsView: View {
    @EnvironmentObject private var community: ClubCommunity
    @State private var query = ""
    @State private var filter: ContactFilter = .all
    @State private var selectedConversation: ClubMessage?
    @State private var showingChat = false
    @FocusState private var searchFocused: Bool

    private var filtered: [ClubContact] {
        community.contacts.filter {
            (query.isEmpty || ($0.name + $0.initial + $0.role + $0.interests).localizedCaseInsensitiveContains(query)) &&
            (filter == .all || (filter == .leaders && $0.isLeader) || (filter == .favorites && community.favorites.contains($0.id)))
        }
    }
    private var initials: [String] { Array(Set(filtered.map(\.initial))).sorted() }

    var body: some View {
        ClubScroll {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeading(eyebrow: "一起发现，一起参与", title: "通讯录")
                ClubCard(padding: 18, highlighted: true) {
                    HStack(spacing: 14) {
                        ClubIcon(name: "contacts", size: 26).foregroundColor(ClubTheme.darkTeal)
                            .frame(width: 52, height: 52).background(ClubTheme.card.opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        VStack(alignment: .leading, spacing: 5) {
                            Text("认识同行的伙伴").font(.headline)
                            Text("\(community.contacts.count) 位伙伴 · \(community.contacts.filter(\.isLeader).count) 位领队")
                                .font(.subheadline).foregroundColor(ClubTheme.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
                CommunitySearchField(placeholder: "搜索姓名、兴趣", text: $query, focus: $searchFocused, identifier: "contactSearch")
                CommunityFilters(selection: $filter)
                if filtered.isEmpty {
                    EmptyClubState(title: "暂无符合条件的联系人", message: filter == .favorites ? "在成员资料中添加常用联系人，方便下次找到。" : "试试其他姓名或兴趣关键词。")
                } else {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(initials, id: \.self) { initial in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(initial).font(.caption.weight(.semibold)).foregroundColor(ClubTheme.secondary)
                                    .padding(.leading, 4).accessibilityAddTraits(.isHeader)
                                ClubCard(padding: 0) {
                                    VStack(spacing: 0) {
                                        ForEach(filtered.filter { $0.initial == initial }) { contact in
                                            Button {
                                                searchFocused = false
                                                selectedConversation = community.openConversation(with: contact)
                                                showingChat = true
                                            } label: { contactRow(contact) }
                                            .buttonStyle(CommunityRowStyle())
                                            .accessibilityIdentifier("contact.\(contact.id)")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }.padding(.horizontal, 20).padding(.top, 18)
        }
        .modifier(ClubKeyboardDismissal(isFocused: searchFocused) { searchFocused = false })
        .background {
            NavigationLink(isActive: $showingChat) {
                if let selectedConversation { ChatScreen(conversation: selectedConversation).id(selectedConversation.id) }
            } label: { EmptyView() }.hidden()
        }
    }

    private func contactRow(_ contact: ClubContact) -> some View {
        HStack(spacing: 14) {
            ContactAvatar(contact: contact, size: 48)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(contact.name).font(.body.weight(.semibold)).foregroundColor(ClubTheme.ink)
                    if contact.isLeader { Text("领队").font(.caption.weight(.medium)).foregroundColor(ClubTheme.darkTeal) }
                    if community.favorites.contains(contact.id) {
                        Image(systemName: "star.fill").font(.caption2).foregroundColor(ClubTheme.darkTeal).accessibilityLabel("常用联系人")
                    }
                }
                Text(contact.interests).font(.subheadline).foregroundColor(ClubTheme.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundColor(ClubTheme.secondary).accessibilityHidden(true)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }
}
