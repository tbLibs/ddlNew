//
//  ContactDetailSheet.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 本地演示成员详情；真实好友详情使用 ContactRecordDetailView。
struct ContactDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ClubStore
    @EnvironmentObject private var community: ClubCommunity
    @State private var confirmBlock = false
    @State private var blocking = false
    @State private var errorMessage: String?
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
                    if store.isBlocked(contact.id) {
                        Text("这位好友已在黑名单中，可在“我的 > 黑名单”移出。")
                            .font(.subheadline).foregroundColor(ClubTheme.secondary)
                    } else {
                        Button(community.favorites.contains(contact.id) ? "移出常用联系人" : "添加为常用联系人") {
                            community.toggleFavorite(contact.id)
                        }.buttonStyle(ClubButtonStyle()).accessibilityIdentifier("toggleFavoriteContact")
                        Button("拉黑好友", role: .destructive) { confirmBlock = true }
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(ClubTheme.error)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .accessibilityIdentifier("blockContact")
                    }
                    if let errorMessage {
                        Text(errorMessage).font(.subheadline).foregroundColor(ClubTheme.error)
                    }
                }.padding(24)
            }.navigationTitle("成员资料").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() }.accessibilityIdentifier("closeContact") } }
                .disabled(blocking)
                .alert("拉黑\(contact.name)？", isPresented: $confirmBlock) {
                    Button("取消", role: .cancel) { }
                    Button("确认拉黑", role: .destructive) {
                        blocking = true
                        Task {
                            do { try await store.blockContact(contact.id); dismiss() }
                            catch {
                                errorMessage = "保存黑名单失败，请重试。"
                                blocking = false
                            }
                        }
                    }.accessibilityIdentifier("confirmBlockContact")
                } message: { Text("私聊会话将从消息列表隐藏，也不能继续向这位好友发送消息。移出黑名单后会恢复显示。") }
        }.navigationViewStyle(.stack)
    }
}
