//
//  AddFriendView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter

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
        MessagingScroll {
            VStack(spacing: 16.zoom()) {
                HStack(spacing: 8.zoom()) {
                    MessagingSearchField(placeholder: "请输入用户账号", text: $query, focus: $focused, identifier: "addFriendAccount")
                        .onSubmit { search() }
                    Button("查找") { search() }
                        .frame(minWidth: 44, minHeight: 44)
                        .disabled(businessStore.isSearching || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if businessStore.searchResults.isEmpty, let user = session.currentUser {
                    // 与旧版一致：点击账号行查看二维码，长按或菜单复制公开账号。
                    NavigationLink(value: ContactsPageRoute.qrCode(groupID: nil, title: "我的二维码")) {
                        HStack(spacing: 12.zoom()) {
                            Text("我的账号：\(user.userName)").font(.subheadline).foregroundStyle(MessagingTheme.text)
                            Image(systemName: "qrcode").foregroundStyle(MessagingTheme.accent).accessibilityHidden(true)
                        }.frame(maxWidth: .infinity).frame(minHeight: max(44, 44.zoom()))
                    }
                    .buttonStyle(.plain)
                    .onLongPressGesture(minimumDuration: 0.8) { copyAccount(user.userName) }
                    .contextMenu { Button { copyAccount(user.userName) } label: { Label("复制账号", systemImage: "doc.on.doc") } }
                    .accessibilityHint("查看我的二维码，也可通过操作菜单复制账号")
                }
                if let copyNotice { Text(copyNotice).font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
                if businessStore.isSearching { ProgressView("正在查找用户").frame(minHeight: 80.zoom()) }
                if searched && !businessStore.isSearching && businessStore.errorMessage == nil && businessStore.searchResults.isEmpty {
                    EmptyClubState(title: "没有找到用户", message: "请核对用户账号，或扫描对方的业务二维码。")
                }
                VStack(spacing: 0) {
                    ForEach(businessStore.searchResults) { contact in
                        NavigationLink(value: ContactsRoute(contactID: contact.id)) {
                            HStack(spacing: 12.zoom()) {
                                ContactRecordAvatar(contact: contact, fileHost: fileHost, size: 48.zoom())
                                VStack(alignment: .leading, spacing: 4.zoom()) {
                                    Text(contact.displayName).font(.body).foregroundStyle(MessagingTheme.text)
                                    Text("账号：\(contact.account.isEmpty ? contact.id : contact.account)").font(.caption).foregroundStyle(MessagingTheme.secondaryText)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(MessagingTheme.secondaryText).accessibilityHidden(true)
                            }.padding(16.zoom()).frame(minHeight: max(64, 72.zoom()))
                        }.buttonStyle(MessagingRowStyle())
                    }
                }.clipShape(RoundedRectangle(cornerRadius: 10.zoom()))
                if let error = businessStore.errorMessage { Text(error).foregroundStyle(MessagingTheme.error).frame(maxWidth: .infinity, alignment: .leading) }
            }.padding(16.zoom())
        }
        .navigationTitle("添加好友")
        .modifier(MessagingPageChrome())
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: ContactsPageRoute.scanner) { Image(systemName: "qrcode.viewfinder").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("扫一扫")
            }
        }
        .onChange(of: query) { value in if value.isEmpty { searched = false; Task { await businessStore.search("") } } }
    }

    /// 复制当前公开账号，给出可见反馈。
    private func copyAccount(_ account: String) { guard !account.isEmpty else { return }; UIPasteboard.general.string = account; copyNotice = "账号已复制" }

    /// 收起键盘并请求精确账号。
    private func search() {
        guard !businessStore.isSearching else { return }
        focused = false; searched = true; copyNotice = nil
        let submitted = query
        Task { await businessStore.search(submitted) }
    }
}
