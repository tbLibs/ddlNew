//
//  TabbarView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/21.
//

import SwiftUI
import TBBasicLib

struct TabbarView: View {
    
    @StateObject var router = RouterTool.shared
    
    var body: some View {
        TabView(selection: $router.selectTab) {
            // 首页
            NavigationStack(path: $router.mainRouterPath) {
                MainView()
            }
            .toolbar(router.mainRouterPath.isEmpty ? .visible : .hidden, for: .tabBar) // 控制tabBar的显隐
            .tabItem {
                Label { Text(TabType.main.title) } icon: { Image(.clubHome) }
            }
            .tag(TabType.main)
            
            
            // 消息
            NavigationStack(path: $router.messageRouterPath) {
                MessageView()
            }
            .toolbar(router.messageRouterPath.isEmpty ? .visible : .hidden, for: .tabBar) // 控制tabBar的显隐
            .tabItem {
                Label { Text(TabType.message.title) } icon: { Image(.clubMessages) }
            }
            .tag(TabType.message)
            
            
            // 通讯录
            NavigationStack(path: $router.contactsRouterPath) {
                ContactsView()
            }
            .toolbar(router.contactsRouterPath.isEmpty ? .visible : .hidden, for: .tabBar) // 控制tabBar的显隐
            .tabItem {
                Label { Text(TabType.contacts.title) } icon: { Image(.clubContacts) }
            }
            .tag(TabType.contacts)
            
            
            // 我的
            NavigationStack(path: $router.mineRouterPath) {
                MineView()
            }
            .toolbar(router.mineRouterPath.isEmpty ? .visible : .hidden, for: .tabBar) // 控制tabBar的显隐
            .tabItem {
                Label { Text(TabType.mine.title) } icon: { Image(.clubUsers) }
            }
            .tag(TabType.mine)
            
        }
        .tint(Color(hex: "00B9B1"))
    }
    
}

#Preview {
    TabbarView()
}
