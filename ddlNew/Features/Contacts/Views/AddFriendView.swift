//
//  AddFriendView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

/// 精确查找当前俱乐部账号，结果进入真实资料后再提交好友申请。
struct AddFriendView: View {
    @ObservedObject var businessStore: ContactsBusinessStore
    let fileHost: URL?
    @State private var query = ""
    @State private var copyNotice: String?
    @ObservedObject private var session = UserSessionStore.shared
    @State private var searched = false
    @FocusState private var focused: Bool

    var body: some View {
        ClubScroll {
            VStack(spacing: 20) {
                ScreenHeading(eyebrow: "建立新的联系", title: "添加好友")
                if let user = session.currentUser {
                    Button { copyAccount(user.userName) } label: { Label("我的账号：\(user.userName)", systemImage: "doc.on.doc") }
                        .onLongPressGesture(minimumDuration: 0.8) { copyAccount(user.userName) }
                }
                if let copyNotice { Text(copyNotice).font(.caption).foregroundStyle(ClubTheme.secondary) }
                CommunitySearchField(placeholder: "请输入用户账号", text: $query, focus: $focused, identifier: "addFriendAccount")
                    .onSubmit { search() }
                Button("查找") { search() }.buttonStyle(.borderedProminent).tint(HomeTheme.forest)
                    .disabled(businessStore.isSearching || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                HStack {
                    NavigationLink("我的二维码", value: ContactsPageRoute.qrCode(groupID: nil, title: "我的二维码"))
                    Spacer()
                    NavigationLink("扫一扫", value: ContactsPageRoute.scanner)
                }.font(.subheadline)
                if businessStore.isSearching { ProgressView("正在查找用户") }
                if searched && !businessStore.isSearching && businessStore.errorMessage == nil && businessStore.searchResults.isEmpty {
                    EmptyClubState(title: "没有找到用户", message: "请核对用户账号，或扫描对方的业务二维码。")
                }
                ForEach(businessStore.searchResults) { contact in
                    NavigationLink(value: ContactsRoute(contactID: contact.id)) {
                        ClubCard { HStack { ContactRecordAvatar(contact: contact, fileHost: fileHost, size: 48); Text(contact.displayName).foregroundStyle(ClubTheme.ink); Spacer(); Image(systemName: "chevron.right").accessibilityHidden(true) } }
                    }.buttonStyle(.plain)
                }
                if let error = businessStore.errorMessage { Text(error).foregroundStyle(ClubTheme.error) }
            }.padding(20)
        }
        .navigationTitle("添加好友").navigationBarTitleDisplayMode(.inline).navigationBarHidden(false)
        .onChange(of: query) { value in if value.isEmpty { searched = false; Task { await businessStore.search("") } } }
    }

    /// 复制当前公开账号，给出可见反馈。
    private func copyAccount(_ account: String) { guard !account.isEmpty else { return }; UIPasteboard.general.string = account; copyNotice = "账号已复制" }

    /// 收起键盘并请求精确账号。
    private func search() {
        guard !businessStore.isSearching else { return }
        focused = false; searched = true
        let submitted = query
        Task { await businessStore.search(submitted) }
    }
}
