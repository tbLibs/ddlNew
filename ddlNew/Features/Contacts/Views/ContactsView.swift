//
//  ContactsView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 真实好友通讯录：读取 SDK 缓存、监听同步、按首字母分组并展示好友资料。
struct ContactsView: View {
    @ObservedObject var store: ContactsStore
    let fileHost: URL?
    @State private var query = ""
    @State private var selectedContact: ContactRecord?
    @FocusState private var searchFocused: Bool

    private var sections: [ContactSection] { ContactSorter.sections(from: store.contacts, matching: query) }

    var body: some View {
        let sections = sections
        ClubScroll {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeading(eyebrow: "一起发现，一起参与", title: "通讯录")
                ClubCard(padding: 18, highlighted: true) {
                    HStack(spacing: 14) {
                        ClubIcon(name: "contacts", size: 26).foregroundColor(ClubTheme.darkTeal)
                            .frame(width: 52, height: 52).background(ClubTheme.card.opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        VStack(alignment: .leading, spacing: 5) {
                            Text("我的好友").font(.headline)
                            Text("\(store.contacts.count) 位好友")
                                .font(.subheadline).foregroundColor(ClubTheme.secondary)
                                .accessibilityIdentifier("contactsCount")
                        }
                        Spacer(minLength: 0)
                        if store.isSyncing { ProgressView().accessibilityLabel("正在同步好友") }
                    }
                }
                CommunitySearchField(placeholder: "搜索备注、昵称、账号", text: $query, focus: $searchFocused, identifier: "contactSearch")
                if let error = store.errorMessage {
                    Text(error).font(.subheadline).foregroundColor(ClubTheme.error)
                        .accessibilityIdentifier("contactsSyncError")
                }
                if sections.isEmpty {
                    EmptyClubState(title: emptyTitle, message: emptyMessage)
                        .accessibilityIdentifier("contactsEmptyState")
                } else {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.id).font(.caption.weight(.semibold)).foregroundColor(ClubTheme.secondary)
                                    .padding(.leading, 4).accessibilityAddTraits(.isHeader)
                                ClubCard(padding: 0) {
                                    LazyVStack(spacing: 0) {
                                        ForEach(section.contacts) { contact in
                                            Button {
                                                searchFocused = false
                                                selectedContact = contact
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
        .task { await store.reload() }
        .sheet(item: $selectedContact) { contact in
            ContactRecordDetailView(store: store, contactID: contact.id, fileHost: fileHost)
        }
    }

    private var emptyTitle: String {
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "没有找到相关好友" }
        if store.isSyncing { return "正在同步好友…" }
        return store.errorMessage == nil ? "暂无好友" : "好友列表暂时不可用"
    }

    private var emptyMessage: String {
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "试试其他备注、昵称或账号。" }
        if store.isSyncing { return "同步完成后，好友将显示在这里。" }
        return store.errorMessage == nil ? "添加好友后，可在这里查看好友资料。" : "已有缓存会保留，网络恢复后将重新同步。"
    }

    private func contactRow(_ contact: ContactRecord) -> some View {
        HStack(spacing: 14) {
            ContactRecordAvatar(contact: contact, fileHost: fileHost, size: 48)
            VStack(alignment: .leading, spacing: 6) {
                Text(contact.displayName).font(.body.weight(.semibold)).foregroundColor(ClubTheme.ink)
                if !contact.isDeleted {
                    Text(contact.account.isEmpty ? contact.id : contact.account)
                        .font(.subheadline).foregroundColor(ClubTheme.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if contact.isOnline && !contact.isDeleted {
                Circle().fill(ClubTheme.darkTeal).frame(width: 7, height: 7).accessibilityLabel("在线")
            }
            Image(systemName: "chevron.right").font(.caption).foregroundColor(ClubTheme.secondary).accessibilityHidden(true)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }
}
