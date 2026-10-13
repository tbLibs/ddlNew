//
//  ChatLayoutHost.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

/// 宿主运行真实ChatRoomView与ChatStore，SDK与认证替代仅存在此测试目录。
@main struct ChatLayoutHost: App {
    @StateObject private var business = ContactsBusinessStore(client: LayoutContactClient())
    @State private var showRemark = false
    @State private var showPicker = false
    @State private var pickerAttempts = 0
    @State private var pickerError: String?
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    Text("独立UI宿主 · 匿名数据 · 无真实登录/后端").font(.caption)
                    NavigationLink("真实聊天布局", value: ChatRoute(id: "layout-peer", kind: .single, title: "匿名验收好友", avatarURL: ""))
                    NavigationLink("长群名称与禁言布局", value: ChatRoute(id: "layout-muted", kind: .group, title: "用于窄屏最大字号验收的很长很长测试群名称", avatarURL: ""))
                    Button("真实备注编辑布局") { showRemark = true }
                    Button("真实选人布局") { pickerAttempts = 0; pickerError = nil; showPicker = true }
                }
                .navigationTitle("迁移UI独立验收")
                .navigationDestination(for: ChatRoute.self) { ChatRoomView(route: $0) }
                .sheet(isPresented: $showRemark) { ContactRemarkEditor(businessStore: business, contact: ContactRecord(id: "layout-peer", nickname: "匿名好友", remarks: "原匿名备注", description: "原匿名描述")) }
                .sheet(isPresented: $showPicker) {
                    GroupMemberPickerView(contacts: pickerContacts, recentIDs: pickerContacts.reversed().map(\.id),
                        friendGroups: [FriendBusinessGroup(id: "layout-group", name: "匿名业务分组", order: 0, isDefault: false,
                            members: pickerContacts.prefix(2).map { ContactRecord(id: $0.id, nickname: "旧匿名昵称") })],
                        submissionError: pickerError, onSubmit: submitPicker, onConfirm: { _ in })
                }
                .task { business.prepare(userUID: "layout-me", license: "layout-only"); await business.loadProfile("layout-peer") }
            }
        }
    }

    /// 最新候选与业务分组故意使用不同昵称，验证选择按UID联动。
    private var pickerContacts: [ContactRecord] { (0..<8).map { ContactRecord(id: "layout-peer-\($0)", nickname: "很长很长的匿名验收好友\($0)") } }

    /// 首次失败保留勾选，第二次成功仅表示宿主交互，不代表真实建群。
    @MainActor private func submitPicker(_ contacts: [ContactRecord]) async -> Bool {
        pickerAttempts += 1
        try? await Task.sleep(nanoseconds: 300_000_000)
        if pickerAttempts == 1 { pickerError = "匿名提交失败，请保留选择重试"; return false }
        return true
    }
}

@MainActor final class ChatRuntime: ObservableObject {
    static let shared = ChatRuntime()
    @Published var userUID: String? = "layout-me"
    @Published var revision = UUID()
    private let sessionID = UUID()
    /// 宿主上下文独立于生产身份，禁止把此路径移进App源代码。
    func context(for route: ChatRoute) -> ChatContext? { ChatContext(userUID: "layout-me", tenantID: "layout-only", sessionID: sessionID, route: route) }
    /// 真实Store使用可控本地client，便于验证发送中/失败和输入布局。
    func makeStore() -> ChatStore { ChatStore(client: LayoutChatClient()) }
    /// 媒体工厂只绑定匿名上传客户端，不创建真实网络任务。
    func makeMediaStore() -> ChatMediaStore { ChatMediaStore(client: SDKChatMediaClient()) }
    /// 录音工厂运行生产权限UI，独立验收未启动录制。
    func makeRecorder() -> ChatVoiceRecorder { ChatVoiceRecorder() }
    /// 宿主未启动上传录制，此注册只保持生产依赖合同形状。
    func registerCleanup(owner: AnyObject, conversationID: String, cleanup: @escaping @MainActor () -> Void) {}
    /// 媒体工具只验证宿主身份，生产认证资格不被改变。
    func isCurrent(_ context: ChatContext) -> Bool { context.userUID == userUID && context.sessionID == sessionID }
}

@MainActor final class LayoutChatClient: ChatClient {
    var callback: ((ChatEvent) -> Void)?
    var savedDraft = ChatDraft()
    /// 返回明确标记的匿名排版数据，没有真实消息或头像。
    func cached(context: ChatContext, offset: Int) throws -> [ChatMessageRecord] { records(context) }
    /// 首屏不访问后端，固定页面用于截图与滚动验收。
    func history(context: ChatContext, before: String?, offset: Int) async throws -> ChatPage { ChatPage(messages: records(context), hasMore: false) }
    /// 绑定宿主事件，生产客户端仍由另一编译目标管理。
    func observe(context: ChatContext, onEvent: @escaping @MainActor (ChatEvent) -> Void) { callback = onEvent }
    /// 离页释放宿主回调，禁止后台伪造消息。
    func stop() { callback = nil }
    /// 只生成宿主回执，不将UI操作当作真实发送验收。
    func send(_ message: ChatMessageRecord, context: ChatContext) throws {
        Task { try? await Task.sleep(nanoseconds: 300_000_000); callback?(.ack(localID: message.localID, serverID: "layout-ack-" + message.localID, timestamp: message.timestamp)) }
    }
    /// 群场景明确禁言，文字场景允许匿名UI输入。
    func permissions(context: ChatContext) throws -> ChatPermission {
        ChatPermission(canSend: context.route.kind != .group, canDelete: true, reason: context.route.kind == .group ? "测试状态：群内已开启全员禁言。" : "")
    }
    /// 宿主不发送读协议，只测试可见状态和UI稳定性。
    func read(_ messages: [ChatMessageRecord], context: ChatContext) async throws {}
    /// 宿主操作不代表真实后端删除或撤回。
    func perform(_ action: ChatMessageAction, message: ChatMessageRecord, context: ChatContext) async throws {}
    /// 宿主同一Store的草稿保存用于验证设置往返，重启真实持久化另验收。
    func saveDraft(_ draft: ChatDraft, context: ChatContext) throws { savedDraft = draft }
    /// 读取同一匿名Store的最近输入，不读取Keychain或真实缓存。
    func draft(context: ChatContext) throws -> ChatDraft { savedDraft }
    /// 覆盖长文本、emoji、失败与未知消息四类布局。
    private func records(_ context: ChatContext) -> [ChatMessageRecord] {
        var items: [ChatMessageRecord] = []
        for index in 0..<5 {
            var item = ChatMessageRecord(localID: "layout-\(index)", serverID: "layout-server-\(index)", conversationID: context.route.id, senderID: index % 2 == 0 ? "layout-peer" : "layout-me", senderName: "很长很长的匿名测试昵称", text: index == 0 ? String(repeating: "这是匿名排版验收正文🙂。", count: 8) : "匿名验收正文 \(index)", timestamp: 1_790_000_000_000 + Int64(index * 1000), state: .sent)
            if index == 1 { item.state = .failed; item.failure = .timeout }
            if index == 3 { item.type = 9999 }
            items.append(item)
        }
        return items
    }
}

@MainActor final class OSSConnectionBootstrap: ObservableObject {
    static let shared = OSSConnectionBootstrap()
    var current: LayoutConnection? = nil
}
struct LayoutConnection { var getFileHost: URL? = nil }
enum NetworkImageDownloader {
    /// 图片下载器只提供编译形状，宿主不联网。
    static func downloader(for host: URL?) -> Int { 0 }
}
struct ChatSettingsView: View {
    let route: ChatRoute
    var body: some View { Text("宿主导航目标；生产设置功能另验收").navigationTitle("设置返回测试") }
}
struct ChatMediaDetailView: View {
    let message: ChatMessageRecord
    let context: ChatContext
    let onVoicePlayed: () -> Void
    var body: some View { Text("宿主附件导航目标；真实下载与播放另验收").navigationTitle("匿名附件") }
}
struct ChatMessageEditorView: View {
    let message: ChatMessageRecord
    let context: ChatContext
    @ObservedObject var store: ChatStore
    var body: some View { Text("宿主编辑导航目标；真实编辑另验收") }
}
struct ChatForwardRecipientView: View {
    let messages: [ChatMessageRecord]
    let context: ChatContext
    @ObservedObject var chat: ChatStore
    var body: some View { Text("宿主转发导航目标；真实转发另验收") }
}
struct ChatForwardRecordView: View {
    let message: ChatMessageRecord
    let context: ChatContext
    var body: some View { Text("宿主合并记录导航目标；真实记录另验收") }
}
struct ChatLocationDetailView: View {
    let message: ChatMessageRecord
    var body: some View { Text("宿主定位导航目标；真实地图另验收") }
}
struct ChatHistorySearchView: View {
    let context: ChatContext
    let onSelect: (String) -> Void
    var body: some View { Text("宿主历史搜索导航目标；真实搜索另验收") }
}
struct ChatGroupNoticesView: View {
    let route: ChatRoute
    var body: some View { Text("宿主公告导航目标；真实公告另验收") }
}
struct ChatPinnedMessagesView: View {
    let messages: [ChatMessageRecord]
    let onLocate: (String) -> Void
    var body: some View { Text("宿主置顶列表导航目标；真实置顶另验收") }
}
struct ChatPinActionView: View {
    let message: ChatMessageRecord
    let context: ChatContext
    let permission: ChatPermission
    let onChange: () -> Void
    var body: some View { Text("宿主置顶动作导航目标；真实置顶另验收") }
}
struct ChatStickersView: View {
    @ObservedObject var chat: ChatStore
    var body: some View { Text("宿主表情导航目标；真实表情另验收") }
}

@MainActor final class LayoutContactClient: ContactBusinessClient {
    /// 备注宿主资料使用匿名好友，提交只验证表单交互。
    func request(_ operation: ContactBusinessOperation, identity: ContactsIdentity) async throws -> ContactBusinessResponse {
        if case .profile(let id) = operation { return ContactBusinessResponse(profile: ContactRecord(id: id, nickname: "匿名好友"), isFriend: true) }
        return ContactBusinessResponse()
    }
    /// 不订阅真实申请或关系事件。
    func observe(_ onChange: @escaping @MainActor () -> Void) {}
    /// 无网络等待，宿主清理不触碰真实账号。
    func reset() {}
}
enum ClubTheme {
    static let error = Color.red
    static let secondary = Color.secondary
    static let ink = Color.primary
    static let darkTeal = Color.green
}
struct LayoutRoleAuthority {
    /// 宿主未提供后端已读展示配置，不伪造权限开启。
    func allows(_ key: String) -> Bool { false }
}
@MainActor final class UserRoleAuthorityStore {
    static let shared = UserRoleAuthorityStore()
    var current: LayoutRoleAuthority? = nil
}
struct LegacyRemoteImageProcessor {}
struct LegacyRemoteImageCacheSerializer {}
@MainActor final class SDKChatMediaClient: ChatMediaClient {
    /// 宿主上传回执为匿名资源，只用于取消和权限UI，不访问服务器。
    func upload(_ attachment: ChatAttachment, context: ChatContext, progress: @escaping @MainActor (Double) -> Void) async throws -> ChatUploadedAttachment {
        progress(1); return ChatUploadedAttachment(resource: "layout-only-resource", thumbnail: "")
    }
    /// 宿主没有真实HTTP任务，不触碰生产上传客户端。
    func cancel() {}
}
@MainActor final class SDKChatSettingsClient {
    /// 宿主不返回真实群资料，此处只满足聊天页面依赖形状。
    func load(context: ChatContext) async throws -> ChatSettingsSnapshot { ChatSettingsSnapshot(isPinned: false, isMuted: false, canClear: false, group: nil) }
    /// 关闭匿名宿主等待，不影响生产SDK。
    func close() {}
}
@MainActor final class SDKChatActionsClient {
    /// 宿主没有消息置顶后端，不将此导航合同记为实际置顶通过。
    func pin(_ message: ChatMessageRecord, context: ChatContext, global: Bool, removing: Bool) async throws {}
    /// 匿名宿主没有置顶条，不读取真实SDK缓存。
    func pinned(context: ChatContext) async throws -> [ChatMessageRecord] { [] }
}
@MainActor final class SDKChatNoticesClient {
    /// 仅提供依赖形状，宿主不绑定真实群。
    func open(_ context: ChatContext) {}
    /// 空公告是匿名fixture，不代表服务器没有公告。
    func load(page: Int) async throws -> [ChatGroupNotice] { [] }
    /// 宿主关闭不操作SDK会话。
    func close() {}
}
