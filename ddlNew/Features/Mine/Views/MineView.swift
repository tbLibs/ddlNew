//
//  MineView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI
import Kingfisher
import UIAdapter
import AlertToast

/// 个人中心，提供活动记录、设置和更换俱乐部入口。
struct MineView: View {
    @EnvironmentObject private var store: ClubStore
    @ObservedObject private var userSession = UserSessionStore.shared
    @ObservedObject private var connection = OSSConnectionBootstrap.shared
    @State private var showSettings = false
    @State private var showingCopyToast = false
    @State private var showSwitch = false
    @State private var showingComplaint = false
    @State private var complaintSubmitted = false
    @State private var feedback: String?
    var body: some View {
        ScrollView {
            MinePageContent(
                displayName: profileDisplayName,
                account: userSession.currentUser?.userName ?? "",
                isSignedIn: userSession.currentUser != nil,
                avatar: profileAvatar,
                copyAccount: copyAccount,
                switchClub: { showSwitch = true },
                openComplaint: { feedback = nil; showingComplaint = true }
            )
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(HomeTheme.background.ignoresSafeArea())
        .tint(HomeTheme.forest)
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 21.zoom())).foregroundStyle(HomeTheme.forest)
                        .frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
                }.accessibilityLabel("打开设置")
            }
        }
        .toolbarBackground(HomeTheme.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showSettings) { SettingsScreen() }
        .sheet(isPresented: $showingComplaint, onDismiss: { if complaintSubmitted { feedback = "投诉已提交"; complaintSubmitted = false } }) {
            ComplaintView(target: .general, targetName: "系统投诉") { complaintSubmitted = true }
        }
        .messagingFeedbackToast(feedback, isEnabled: !showingComplaint)
        .toast(isPresenting: $showingCopyToast, duration: 2) {
            AlertToast(displayMode: .alert, type: .regular, title: "账号已复制",
                       style: .style(backgroundColor: MessagingTheme.toastBackground,
                                     titleColor: MessagingTheme.toastText))
        }
        .onChange(of: userSession.currentUser?.userUID) { _ in showingCopyToast = false }
        .alert("更换俱乐部？", isPresented: $showSwitch) {
            Button("取消", role: .cancel) { }
            Button("更换", role: .destructive) { Task { await store.signOut(changeClub: true) } }
        } message: { Text("将退出当前会员空间，已保存的活动记录会保留。") }
    }

    /// 昵称与账号均来自当前登录资料，缺省时不回退到活动演示账号。
    private var profileDisplayName: String {
        guard let user = userSession.currentUser else { return "未登录" }
        if !user.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return user.nickname }
        return user.userName.isEmpty ? "未设置昵称" : user.userName
    }

    /// 沿用真实头像的地址解析和解包方式，资料或文件节点变化时同步刷新。
    private var profileAvatar: some View {
        let host = connection.current?.getFileHost
        let url = RemoteAvatarURL.resolve(userSession.currentUser?.avatar ?? "", relativeTo: host)
        return KFImage(url)
            .downloader(NetworkImageDownloader.downloader(for: host))
            .setProcessor(LegacyRemoteImageProcessor() |> DownsamplingImageProcessor(size: CGSize(width: 72.zoom(), height: 72.zoom())))
            .cancelOnDisappear(true)
            .placeholder {
                ZStack {
                    HomeTheme.mintSurface
                    Image(systemName: "person")
                        .font(.system(size: 38.zoom(), weight: .regular))
                        .foregroundStyle(HomeTheme.forest)
                }
            }
            .resizable().scaledToFill()
            .frame(width: 72.zoom(), height: 72.zoom())
            .clipShape(RoundedRectangle(cornerRadius: 24.zoom(), style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24.zoom(), style: .continuous)
                .stroke(HomeTheme.border, lineWidth: 1))
            .id(userSession.currentUser?.userUID)
            .accessibilityHidden(true)
    }

    /// 复制当前会话的公开账号，反馈复用资料页的居中提示。
    private func copyAccount() {
        guard let account = userSession.currentUser?.userName, !account.isEmpty else { return }
        UIPasteboard.general.string = account
        showingCopyToast = true
    }
}
