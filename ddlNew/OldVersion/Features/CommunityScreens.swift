import SwiftUI

private enum MessageFilter: String, CaseIterable, Identifiable {
    case all = "全部", unread = "未读", notices = "通知"
    var id: Self { self }
}

struct MessagesScreen: View {
    @EnvironmentObject private var community: ClubCommunity
    @State private var query = ""
    @State private var filter: MessageFilter = .all
    @State private var selected: ClubMessage?
    @State private var showingChat = false
    @FocusState private var searchFocused: Bool

    private var filtered: [ClubMessage] {
        community.messages.filter {
            (query.isEmpty || ($0.title + $0.preview + $0.body).localizedCaseInsensitiveContains(query)) &&
            (filter == .all || (filter == .unread && $0.unread) || (filter == .notices && $0.isNotice))
        }
    }

    var body: some View {
        ClubScroll {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    ScreenHeading(eyebrow: "远山户外俱乐部", title: "消息")
                    Button("全部已读") { community.markAllRead() }
                        .font(.subheadline.weight(.medium)).foregroundColor(ClubTheme.darkTeal)
                        .frame(minHeight: 44).disabled(community.unreadCount == 0)
                        .opacity(community.unreadCount == 0 ? 0.45 : 1)
                        .accessibilityIdentifier("markAllMessagesRead")
                }
                HStack(spacing: 8) {
                    ClubIcon(name: "messages", size: 16)
                    Text(community.unreadCount == 0 ? "消息都已读，期待下一次相聚" : "有 \(community.unreadCount) 条未读消息，看看伙伴们的新动态")
                        .font(.subheadline)
                }.foregroundColor(ClubTheme.secondary)
                CommunitySearchField(placeholder: "搜索消息", text: $query, focus: $searchFocused, identifier: "messageSearch")
                CommunityFilters(selection: $filter)
                if filtered.isEmpty {
                    EmptyClubState(title: filter == .unread && query.isEmpty ? "暂时没有未读消息" : "没有找到相关消息", message: "试试其他关键词，或切换消息分类。")
                } else {
                    ClubCard(padding: 0) {
                        LazyVStack(spacing: 0) {
                            ForEach(filtered) { message in
                                Button {
                                    searchFocused = false
                                    community.markRead(message.id)
                                    selected = message
                                    showingChat = true
                                } label: {
                                    messageRow(message)
                                }
                                .buttonStyle(CommunityRowStyle())
                                .accessibilityIdentifier("message.\(message.id)")
                                .accessibilityLabel("\(message.title)，\(message.unread ? "未读" : "已读")，\(message.preview)，\(message.time)")
                                if message.id != filtered.last?.id {
                                    Divider().overlay(ClubTheme.border.opacity(0.4)).padding(.leading, 82)
                                }
                            }
                        }
                    }
                }
                Text("每一次相聚，都从一条消息开始")
                    .font(.footnote).foregroundColor(ClubTheme.secondary)
                    .frame(maxWidth: .infinity).padding(.top, 8)
            }.padding(.horizontal, 20).padding(.top, 18)
        }
        .modifier(ClubKeyboardDismissal(isFocused: searchFocused) { searchFocused = false })
        .background {
            NavigationLink(isActive: $showingChat) {
                if let selected { ChatScreen(conversation: selected).id(selected.id) }
            } label: { EmptyView() }.hidden()
        }
    }

    private func messageRow(_ message: ClubMessage) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ClubIcon(name: message.icon, size: 23)
                .foregroundColor(ClubTheme.darkTeal)
                .frame(width: 48, height: 48)
                .background(message.isNotice ? ClubTheme.pale.opacity(0.55) : ClubTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 17))
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(message.title).font(.body.weight(message.unread ? .semibold : .medium))
                        .foregroundColor(ClubTheme.ink).lineLimit(1)
                    Spacer(minLength: 0)
                    Text(message.time).font(.caption).foregroundColor(ClubTheme.secondary).fixedSize()
                }
                HStack(alignment: .top, spacing: 8) {
                    Text(message.preview).font(.subheadline).foregroundColor(ClubTheme.secondary)
                        .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    if message.unread {
                        Circle().fill(ClubTheme.darkTeal).frame(width: 8, height: 8).padding(.top, 5)
                    }
                }
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }
}

private enum ContactFilter: String, CaseIterable, Identifiable {
    case all = "全部", leaders = "领队", favorites = "常用"
    var id: Self { self }
}

struct ContactsScreen: View {
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

private struct ContactAvatar: View {
    let contact: ClubContact
    let size: CGFloat
    private var color: Color {
        switch contact.tone { case 1: return ClubTheme.border.opacity(0.5); case 2: return ClubTheme.pale.opacity(0.4); default: return ClubTheme.pale }
    }
    var body: some View {
        Text(String(contact.name.prefix(1))).font(.system(size: size * 0.36, weight: .medium, design: .rounded))
            .foregroundColor(ClubTheme.ink).frame(width: size, height: size)
            .background(color).clipShape(RoundedRectangle(cornerRadius: size * 0.35)).accessibilityHidden(true)
    }
}

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

private struct CommunitySearchField: View {
    let placeholder: String
    @Binding var text: String
    let focus: FocusState<Bool>.Binding
    let identifier: String
    var body: some View {
        HStack(spacing: 10) {
            ClubIcon(name: "search").foregroundColor(ClubTheme.secondary)
            TextField(placeholder, text: $text).font(.body).focused(focus).submitLabel(.search)
                .autocapitalization(.none).disableAutocorrection(true)
                .accessibilityLabel(placeholder).accessibilityIdentifier(identifier)
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(ClubTheme.secondary).frame(width: 44, height: 44) }
                    .accessibilityLabel("清除搜索").accessibilityIdentifier("clearCommunitySearch")
            }
        }.padding(.leading, 14).padding(.trailing, text.isEmpty ? 14 : 0).frame(minHeight: 52)
            .background(ClubTheme.card).clipShape(RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(ClubTheme.border, lineWidth: 1))
    }
}

private struct CommunityFilters<Filter: CaseIterable & Identifiable & RawRepresentable & Hashable>: View where Filter.RawValue == String, Filter.AllCases: RandomAccessCollection {
    @Binding var selection: Filter
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
            ForEach(Filter.allCases) { item in
                Button { selection = item } label: {
                    Text(item.rawValue).font(.subheadline.weight(selection == item ? .semibold : .regular))
                        .foregroundColor(selection == item ? .white : ClubTheme.secondary)
                        .padding(.horizontal, 22).frame(minHeight: 44)
                        .background(selection == item ? ClubTheme.darkTeal : ClubTheme.card)
                        .clipShape(Capsule())
                }.accessibilityAddTraits(selection == item ? .isSelected : [])
            }
            }
        }
    }
}

private struct CommunityRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(configuration.isPressed ? ClubTheme.pale.opacity(0.35) : .clear)
    }
}
