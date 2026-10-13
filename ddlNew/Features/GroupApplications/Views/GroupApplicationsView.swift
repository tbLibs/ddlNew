// Created by taobo on 2026/10/13.
import SwiftUI
import Combine

/// 群助手和单群共用页面，好友申请不复用群审核协议。
struct GroupApplicationsView: View {
    let groupID: String?
    @StateObject private var store = GroupApplicationsStore(client: SDKGroupApplicationsClient())
    @ObservedObject private var session = UserSessionStore.shared
    @ObservedObject private var conversations = LoginSessionService.shared.conversations
    @State private var pendingOnly = false
    @State private var confirmation: Bool?
    @Environment(\.scenePhase) private var scenePhase

    /// 无群ID表示全局群通知，有群ID表示本群管理审核。
    init(groupID: String? = nil) { self.groupID = groupID }

    var body: some View {
        List {
            Picker("审核状态", selection: $pendingOnly) {
                Text("全部").tag(false); Text("待审核").tag(true)
            }.pickerStyle(.segmented)
            if let error = store.errorMessage { Text(error).foregroundStyle(ClubTheme.error) }
            if let notice = store.notice { Text(notice).font(.subheadline) }
            if store.records.isEmpty && !store.isLoading && store.errorMessage == nil { Text("暂无群申请") }
            ForEach(store.records) { record in applicationRow(record) }
            if store.isLoading { ProgressView("正在加载") }
            else if store.hasMore { Button("加载更多") { Task { await store.loadMore() } }.frame(minHeight: 44) }
        }
        .navigationTitle(groupID == nil ? "群通知" : "入群审核")
        .navigationBarTitleDisplayMode(.inline).navigationBarHidden(false)
        .refreshable { await store.reload(pendingOnly: pendingOnly) }
        .safeAreaInset(edge: .bottom) {
            if pendingOnly && !store.records.isEmpty {
                HStack {
                    Button("全选") { store.selectAll() }
                    Spacer()
                    Button("同意（\(store.selectedIDs.count)）") { confirmation = true }
                        .disabled(store.selectedIDs.isEmpty || store.isReviewing)
                    Button("拒绝", role: .destructive) { confirmation = false }
                        .disabled(store.selectedIDs.isEmpty || store.isReviewing)
                }.padding().background(HomeTheme.surface)
                    .disabled(store.isReviewing)
            }
        }
        .confirmationDialog(confirmation == true ? "同意所选入群申请？" : "拒绝所选入群申请？",
            isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }), titleVisibility: .visible) {
                Button(confirmation == true ? "同意" : "拒绝", role: confirmation == true ? nil : .destructive) {
                    if let accept = confirmation { Task { await store.review(accept: accept) } }
                    confirmation = nil
                }
                Button("取消", role: .cancel) { confirmation = nil }
        }
        .task {
            if let uid = session.currentUser?.userUID { store.prepare(userUID: uid, groupID: groupID); await store.reload(pendingOnly: pendingOnly) }
        }
        .onChange(of: pendingOnly) { value in Task { await store.reload(pendingOnly: value) } }
        .onChange(of: scenePhase) { phase in if phase == .active { Task { await store.refresh() } } }
        .onChange(of: session.currentUser?.userUID) { _ in store.reset() }
        .onChange(of: notificationVersions) { _ in
            // 群系统会话收到变更后回查申请，不把系统消息正文冒充审核结果。
            Task { await store.refresh() }
        }
        .onDisappear { store.reset() }
    }

    /// 仅群系统会话的新消息触发回查，普通聊天或本页已读回写不重刷申请。
    private var notificationVersions: [String] {
        conversations.conversations.filter { $0.kind == .systemMessage }.map {
            "\($0.id)|\($0.latestTime?.timeIntervalSince1970 ?? 0)|\($0.preview)"
        }.sorted()
    }

    /// 待审核行支持勾选与确认，已处理行显示服务器状态。
    private func applicationRow(_ record: GroupApplicationRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(record.nickname.isEmpty ? "群申请" : record.nickname).font(.headline)
            Text("群：\(record.groupID)").font(.caption).foregroundStyle(.secondary)
            if !record.reason.isEmpty { Text(record.reason).font(.subheadline) }
            if record.status == 1 {
                Toggle("选择此申请", isOn: Binding(get: { store.selectedIDs.contains(record.id) }, set: {
                    if $0 { store.selectedIDs.insert(record.id) } else { store.selectedIDs.remove(record.id) }
                })).disabled(store.isReviewing)
                HStack {
                    Button("同意") { store.selectedIDs = [record.id]; confirmation = true }
                    Button("拒绝", role: .destructive) { store.selectedIDs = [record.id]; confirmation = false }
                }.buttonStyle(.bordered).disabled(store.isReviewing)
            } else { Text(record.statusText).foregroundStyle(.secondary) }
        }.padding(.vertical, 6).accessibilityIdentifier("groupApplication.\(record.id)")
    }
}
