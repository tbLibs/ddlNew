//
//  ContactRecordDetailView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import SwiftUI

/// 只展示 SDK 已同步的好友资料；资料变化时从当前列表重新取得快照。
struct ContactRecordDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ContactsStore
    let contactID: String
    let fileHost: URL?

    private var contact: ContactRecord? { store.contacts.first { $0.id == contactID } }

    var body: some View {
        NavigationView {
            ClubScroll {
                if let contact {
                    VStack(spacing: 24) {
                        ContactRecordAvatar(contact: contact, fileHost: fileHost, size: 88).padding(.top, 24)
                        Text(contact.displayName).font(.title2.bold())
                        ClubCard {
                            VStack(alignment: .leading, spacing: 16) {
                                if contact.isDeleted {
                                    Text("该好友账号已注销").foregroundColor(ClubTheme.secondary)
                                } else {
                                    detail("账号", value: contact.account)
                                    detail("昵称", value: contact.nickname)
                                    detail("备注", value: contact.remarks)
                                    detail("备注描述", value: contact.description)
                                    detail("在线状态", value: contact.isOnline ? "在线" : "离线")
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }.padding(24)
                } else {
                    EmptyClubState(title: "该好友已不在通讯录中", message: "通讯录已更新，请返回查看其他好友。")
                        .padding(24)
                }
            }
            .navigationTitle("好友资料").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }.accessibilityIdentifier("closeSDKContact")
                }
            }
        }.navigationViewStyle(.stack)
    }

    private func detail(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundColor(ClubTheme.secondary)
            Text(value.isEmpty ? "未设置" : value).font(.body).foregroundColor(ClubTheme.ink)
        }
    }
}
