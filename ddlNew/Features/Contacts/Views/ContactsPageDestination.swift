//
//  ContactsPageDestination.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

/// 各Tab注册一次统一通讯录页面路由，不创建嵌套push导航栈。
struct ContactsPageDestination: View {
    let route: ContactsPageRoute
    @ObservedObject var businessStore: ContactsBusinessStore
    let fileHost: URL?
    var body: some View {
        Group {
        switch route {
        case .addFriend: AddFriendView(businessStore: businessStore, fileHost: fileHost)
        case .newFriends: NewFriendsView(businessStore: businessStore, fileHost: fileHost)
        case .qrCode(let groupID, let title): BusinessQRCodeView(businessStore: businessStore, groupID: groupID, title: title)
        case .scanner: BusinessQRScannerView(businessStore: businessStore)
        case .globalSearch: GlobalSearchView()
        case .groupAssistant: GroupApplicationsView()
        }
        }.modifier(MessagingPageChrome())
    }
}
