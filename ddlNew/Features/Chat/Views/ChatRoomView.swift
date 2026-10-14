//
//  ChatRoomView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter
import UIKit

/// 使用所在Tab的NavigationStack，页面不创建第二个聊天导航所有者。
struct ChatRoomView: View {
    let route: ChatRoute
    @StateObject private var store: ChatStore
    @ObservedObject private var runtime = ChatRuntime.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var confirmAction: ChatMessageAction?
    @State private var actionMessageID: String?
    @State private var pinnedNotice: ChatGroupNotice?
    @State private var showNotices = false
    @State private var pinnedMessages: [ChatMessageRecord] = []
    @State private var pinningMessage: ChatMessageRecord?
    @State private var showPinnedMessages = false
    @State private var pinRefreshTask: Task<Void, Never>?
    @State private var showMentionPicker = false
    @State private var mentionMembers: [ChatGroupMember] = []
    @State private var showStickers = false
    @State private var selectedProfile: ContactsRoute?
    @State private var showSettings = false
    @State private var showAttachments = true
    @State private var showDeleteSelection = false
    @State private var forwardRecord: ChatMessageRecord?
    @State private var locationMessage: ChatMessageRecord?
    @State private var editingMessage: ChatMessageRecord?
    @State private var forwardingMessages: [ChatMessageRecord] = []
    @State private var showForward = false
    @State private var mediaMessage: ChatMessageRecord?
    @State private var viewport = CGRect.zero
    @State private var messageFrames: [String: CGRect] = [:]
    @State private var latestFrame = CGRect.zero
    @State private var resizeFollowTask: Task<Void, Never>?
    @State private var didInitialScroll = false
    @State private var showFullHistorySearch = false
    @FocusState private var composerFocused: Bool

    /// 创建页面独立Store，根runtime统一管理退出和认证轮次。
    init(route: ChatRoute) { self.route = route; _store = StateObject(wrappedValue: ChatRuntime.shared.makeStore()) }

    /// 聊天正文与输入共用原状态，键盘交互只切焦点不修改文字或引用。
    private var chatViewport: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0.zoom()) {
                if !store.permission.isActive || !store.permission.canSend { Text(store.permission.reason.isEmpty ? "当前会话暂不能发送消息" : store.permission.reason).font(.callout).foregroundStyle(.secondary).padding(10.zoom()) }
                if let notice = pinnedNotice { Button { showNotices = true } label: { Label("群公告：" + notice.content, systemImage: "megaphone").lineLimit(2).padding(10.zoom()) }.accessibilityLabel("查看置顶群公告 " + notice.content) }
                if let pinned = pinnedMessages.first {
                    Button { showPinnedMessages = true } label: { HStack { Image(systemName: "pin.fill"); Text(pinned.text).lineLimit(1); Spacer(); Text("\(pinnedMessages.count)条") }.padding(10.zoom()) }.accessibilityLabel("查看置顶消息")
                }

                ScrollView {
                    VStack(spacing: 14.zoom()) {
                        if store.hasMore {
                            Button { Task { let anchor = store.messages.first?.id; await store.loadMore(); if let anchor { proxy.scrollTo(anchor, anchor: .top) } } }
                            label: { Text("加载更早消息") }.disabled(store.isLoading).padding()
                        }
                        ForEach(displayedMessages) { message in messageRow(message) }
                        Color.clear.frame(height: 1).id("latest")
                            .background(GeometryReader { geometry in Color.clear.preference(key: ChatLatestPreference.self, value: geometry.frame(in: .named("chatViewport"))) })
                    }.padding(.horizontal, 16.zoom()).padding(.bottom, 14.zoom())
                }
                .simultaneousGesture(DragGesture(minimumDistance: 10).onChanged { _ in
                    resizeFollowTask?.cancel(); resizeFollowTask = nil
                    store.isAtBottom = ChatViewportPolicy.isAtBottom(latest: latestFrame, viewport: viewport)
                })
                .simultaneousGesture(TapGesture().onEnded { composerFocused = false })
                .scrollDismissesKeyboard(.interactively)
                .coordinateSpace(name: "chatViewport")
                .background(GeometryReader { geometry in Color.clear.onAppear { updateViewport(geometry.size, proxy: proxy) }.onChange(of: geometry.size) { updateViewport($0, proxy: proxy) } })
                .onPreferenceChange(ChatVisibilityPreference.self) { frames in
                    messageFrames = frames; updateVisibleMessages()
                }
                .onPreferenceChange(ChatLatestPreference.self) { frame in
                    latestFrame = frame
                    if resizeFollowTask == nil { store.isAtBottom = ChatViewportPolicy.isAtBottom(latest: frame, viewport: viewport) }
                }
                if store.unreadArrivals > 0 { Button("\(store.unreadArrivals)条新消息") { store.returnToLatest(); if let id = store.messages.last?.id { proxy.scrollTo(id, anchor: .bottom) } }.padding(8.zoom()) }
            }
            .background(MessagingTheme.background)
            .safeAreaInset(edge: .bottom, spacing: 0.zoom()) { composer }
            .onChange(of: store.messages.last?.id) { id in
                if id != nil && route.targetMessageID == nil && (!didInitialScroll || store.isAtBottom) {
                    let initiallyOpening = !didInitialScroll
                    didInitialScroll = true
                    followAfterResize(proxy, force: initiallyOpening)
                }
            }
            .onChange(of: composerFocused) { _ in followAfterResize(proxy) }
            .onChange(of: store.locatedMessageID) { id in if let id { proxy.scrollTo(id, anchor: .center) } }
        }
    }

    /// 导航配置与正文分开，控制大型聊天视图的泛型推断范围。
    private var chatNavigation: some View {
        chatViewport
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
        .tint(MessagingTheme.accent)
        .toolbarBackground(MessagingTheme.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button { showFullHistorySearch = true } label: { Image(systemName: "magnifyingglass").font(.system(size: 20.zoom())).frame(width: max(44, 44.zoom()), height: max(44, 44.zoom())) }.accessibilityLabel("搜索聊天记录")
                Button { showSettings = true } label: { Image(systemName: "ellipsis").font(.system(size: 20.zoom())).frame(width: max(44, 44.zoom()), height: max(44, 44.zoom())) }.accessibilityLabel("聊天设置")
            }
        }
        .navigationDestination(isPresented: Binding(get: { selectedProfile != nil }, set: { if !$0 { selectedProfile = nil } })) {
            if let profile = selectedProfile {
                ContactRecordDetailView(store: LoginSessionService.shared.contacts, businessStore: LoginSessionService.shared.contactBusiness,
                    contactID: profile.contactID, fileHost: OSSConnectionBootstrap.shared.current?.getFileHost,
                    sourceGroupID: profile.sourceGroupID)
            }
        }
        .navigationDestination(isPresented: $showSettings) { ChatSettingsView(route: route) }
        .task(id: runtime.revision) { if let context = runtime.context(for: route) { await store.open(context) } else { store.close() } }
        .onDisappear { resizeFollowTask?.cancel(); resizeFollowTask = nil; store.isVisible = false; if selectedProfile == nil && !showSettings && !showStickers && mediaMessage == nil && editingMessage == nil && !showForward && forwardRecord == nil && locationMessage == nil && !showFullHistorySearch && pinningMessage == nil && !showPinnedMessages && !showNotices { store.close() } }
        .onAppear { store.isForeground = scenePhase == .active; store.isVisible = true }
    }

    /// 弹层仍使用原状态和上下文，不重新创建聊天Store。
    private var chatPresentations: some View {
        chatNavigation
        .sheet(isPresented: $showStickers) { NavigationStack { ChatStickersView(chat: store) } }
        .sheet(isPresented: $showNotices) { NavigationStack { ChatGroupNoticesView(route: route) } }
        .sheet(isPresented: $showPinnedMessages) { NavigationStack { ChatPinnedMessagesView(messages: pinnedMessages) { id in Task { await store.locate(id) } } } }
        .sheet(item: $pinningMessage) { message in if let context = store.context { NavigationStack { ChatPinActionView(message: message, context: context, permission: store.permission, onChange: { Task { await reloadPins() } }) } } }
        .sheet(isPresented: $showFullHistorySearch) {
            if let context = store.context { NavigationStack { ChatHistorySearchView(context: context) { id in Task { await store.locate(id) } } } }
        }
        .sheet(isPresented: $showMentionPicker) {
            NavigationStack { List(mentionMembers) { member in Button(member.name) { store.insertMention(member); showMentionPicker = false } }.navigationTitle("选择@成员") }
        }
        .sheet(item: $forwardRecord) { message in if let context = store.context { NavigationStack { ChatForwardRecordView(message: message, context: context) } } }
        .sheet(item: $locationMessage) { message in NavigationStack { ChatLocationDetailView(message: message) } }
        .sheet(item: $editingMessage) { message in if let context = store.context { NavigationStack { ChatMessageEditorView(message: message, context: context, store: store) } } }
        .sheet(isPresented: $showForward) { if let context = store.context { NavigationStack { ChatForwardRecipientView(messages: forwardingMessages, context: context, chat: store) } } }
        .sheet(item: $mediaMessage) { message in
            if let context = store.context { NavigationStack { ChatMediaDetailView(message: message, context: context, onVoicePlayed: { Task { await store.markVisible(message.id, voicePlayed: true) } }) } }
        }
    }

    /// 业务观察和确认操作独立于展示组件，继续保留原回调边界。
    var body: some View {
        chatPresentations
        .messagingLoadingToast(store.isLoading, title: "正在加载聊天记录")
        .messagingFeedbackToast(store.errorMessage, isEnabled: !showSettings && !showStickers && !showForward && mediaMessage == nil && editingMessage == nil && pinningMessage == nil)
        .onChange(of: store.messages) { _ in
            pinRefreshTask?.cancel(); pinRefreshTask = Task { do { try await Task.sleep(nanoseconds: 300_000_000); await reloadPins() } catch {} }
        }
        .onChange(of: store.input) { _ in store.reconcileMentions(); store.persistDraft() }
        .onChange(of: scenePhase) { store.isForeground = $0 == .active }
        .confirmationDialog("删除所选消息", isPresented: $showDeleteSelection, titleVisibility: .visible) {
            Button("仅为我删除", role: .destructive) { Task { await store.deleteSelected(both: false) } }
            if selectedCanDeleteBoth { Button("从双方或群成员设备删除", role: .destructive) { Task { await store.deleteSelected(both: true) } } }
        } message: { Text("只删除服务器或本机已确认成功的记录，失败项会保留选择并显示明细。") }
        .confirmationDialog("确认消息操作", isPresented: Binding(get: { confirmAction != nil }, set: { if !$0 { confirmAction = nil } }), titleVisibility: .visible) {
            if let action = confirmAction, let id = actionMessageID {
                Button(actionTitle(action), role: .destructive) { Task { await store.perform(action, id: id) }; confirmAction = nil }
                Button("取消", role: .cancel) { confirmAction = nil }
            }
        } message: { Text(confirmAction == .delete ? "仅删除你自己的这条聊天记录。" : confirmAction == .deleteBoth ? "将申请从双方聊天记录删除这条消息。" : "将申请撤回这条消息。") }
    }

    private var displayedMessages: [ChatMessageRecord] { store.messages }

    /// 输入焦点独立于草稿，收起键盘后保留正文、引用和成员UID片段。
    private var composer: some View {
        VStack(spacing: 8.zoom()) {
            if let reference = store.reference { HStack { Text("回复：" + reference.displayText).font(.caption).lineLimit(2); Spacer(); Button("取消引用") { store.reference = nil } } }
            if !store.selectedIDs.isEmpty { HStack { Text("已选择\(store.selectedIDs.count)/100"); Spacer(); Button("删除", role: .destructive) { showDeleteSelection = true }; Button("转发") { forwardingMessages = store.messages.filter { store.selectedIDs.contains($0.id) }; showForward = true }; Button("取消多选") { store.cancelSelection() } } }
            if showAttachments && !composerFocused && route.kind == .group && !(store.permission.role == 0 && store.permission.isPrivateChat) {
                Button("@成员") { Task { await loadMentionMembers() } }.disabled(!store.permission.canSend)
            }
            HStack(alignment: .bottom, spacing: 10.zoom()) {
                if !dynamicTypeSize.isAccessibilitySize { attachmentToggle }
                TextField("发送消息", text: $store.input, axis: .vertical).lineLimit(1...(composerFocused && dynamicTypeSize.isAccessibilitySize ? 2 : 5)).padding(10.zoom()).background(MessagingTheme.surface).clipShape(RoundedRectangle(cornerRadius: 8.zoom()))
                    .focused($composerFocused).accessibilityLabel("消息正文").disabled(!store.permission.canSend)
                if !dynamicTypeSize.isAccessibilitySize {
                    stickerButton
                    if composerFocused { keyboardDismissButton }
                }
                Button { store.sendText() } label: { Text("发送").font(.subheadline.weight(.semibold)).frame(minWidth: max(44, 44.zoom())) }.buttonStyle(MessagingActionButtonStyle()).disabled(!store.permission.canSend || store.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: 12.zoom()) {
                    attachmentToggle
                    stickerButton
                    Spacer(minLength: 8)
                    if composerFocused { keyboardDismissButton }
                }
            }
            ChatMediaComposer(chat: store, compact: composerFocused || !showAttachments)
        }.padding(.horizontal, 16.zoom()).padding(.vertical, 10.zoom()).background(MessagingTheme.background)
            .overlay(alignment: .top) { MessagingTheme.divider.frame(height: 0.5) }
    }

    /// 展开收起只改变工具栏，不重建上传和录音所有者。
    private var attachmentToggle: some View {
        Button { showAttachments.toggle(); composerFocused = false } label: {
            Image(systemName: showAttachments ? "xmark.circle" : "plus.circle").font(.system(size: 24.zoom()))
                .frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
        }.accessibilityLabel(showAttachments ? "收起附件工具" : "展开附件工具")
    }

    /// 表情入口沿用旧输入区位置，打开前收起键盘并保留正文。
    private var stickerButton: some View {
        Button { showStickers = true; composerFocused = false } label: {
            Image(systemName: "face.smiling").font(.system(size: 22.zoom()))
                .frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
        }.accessibilityLabel("选择表情与贴纸").disabled(!store.permission.canSend)
    }

    /// 独立收起操作给大字号和硬件键盘用户提供明确出口。
    private var keyboardDismissButton: some View {
        Button { composerFocused = false } label: {
            Image(systemName: "keyboard.chevron.compact.down").font(.system(size: 20.zoom()))
                .frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
        }.accessibilityLabel("收起键盘").accessibilityIdentifier("chatDismissKeyboard")
    }

    /// 视口收缩前保留末尾跟随意图，历史浏览与搜索定位不强制滚动。
    private func updateViewport(_ size: CGSize, proxy: ScrollViewProxy) {
        let followsLatest = store.isAtBottom
        viewport = CGRect(origin: .zero, size: size)
        updateVisibleMessages()
        if followsLatest { followAfterResize(proxy) }
        else if resizeFollowTask == nil { store.isAtBottom = ChatViewportPolicy.isAtBottom(latest: latestFrame, viewport: viewport) }
    }

    /// 首屏等到布局完成再落到最新，其余变化只跟随原末尾；用户拖动仍取消，不改草稿或消息状态。
    private func followAfterResize(_ proxy: ScrollViewProxy, force: Bool = false) {
        guard force || store.isAtBottom, route.targetMessageID == nil else { return }
        if force { store.isAtBottom = true }
        resizeFollowTask?.cancel()
        resizeFollowTask = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
            guard !Task.isCancelled, store.isVisible else { return }
            proxy.scrollTo("latest", anchor: .bottom)
            resizeFollowTask = nil
            store.isAtBottom = ChatViewportPolicy.isAtBottom(latest: latestFrame, viewport: viewport)
        }
    }

    /// 消息或视口变化均重算可见正文，屏外记录不会因键盘变化误报已读。
    private func updateVisibleMessages() {
        let visible = Set(messageFrames.filter { $0.value.intersects(viewport) }.keys)
        store.setVisibleMessageIDs(visible)
        for id in visible { Task { await store.markVisible(id) } }
    }

    /// 双向批量入口必须每条均符合当前作者、会话和群角色矩阵。
    private var selectedCanDeleteBoth: Bool {
        let values = store.messages.filter { store.selectedIDs.contains($0.id) }
        return !values.isEmpty && values.allSatisfy { ChatActionPolicy.allowed(for: $0, userUID: store.context?.userUID ?? "", permission: store.permission).contains(.deleteBoth) }
    }

    /// 当前成员选择来自真实群详情，禁止私聊策略同时限制普通成员@入口。
    private func loadMentionMembers() async {
        guard let context = store.context else { return }
        let client = SDKChatSettingsClient(); defer { client.close() }
        do {
            guard let group = try await client.load(context: context).group, group.isActive,
                  group.role > 0 || !group.isPrivateChat else { return }
            mentionMembers = [ChatGroupMember(id: "-1", name: "所有人", avatar: "", role: 0, isDeleted: false)] + group.members.filter { !$0.isDeleted }
            showMentionPicker = true
        } catch { store.errorMessage = error.localizedDescription }
    }

    /// 独立消息行降低SwiftUI类型推断成本，复用稳定气泡ID与实际可见区域。
    private func messageRow(_ message: ChatMessageRecord) -> some View {
        VStack(spacing: 8.zoom()) {
            if showsDate(for: message) { Text(Date(timeIntervalSince1970: Double(message.timestamp) / 1000), style: .date).font(.caption).foregroundStyle(.secondary) }
            ChatMessageBubble(message: message, own: message.senderID == store.context?.userUID,
                isSelected: store.selectedIDs.contains(message.id), isHighlighted: store.locatedMessageID == message.id,
                onRetry: { store.retry(message.id) }, onReference: { Task { await store.locate(message.referenceID) } }, onAvatar: { openSenderProfile(message) }, onMention: mentionAction(for: message), referenceSummary: store.referenceSummary(message.referenceID))
                .onTapGesture { activateMessage(message) }
                .accessibilityAction(named: openActionTitle(message)) { activateMessage(message) }
                .contextMenu { messageMenu(message) }
                .accessibilityAction(named: "选择消息") { store.toggleSelection(message.id) }
        }
        .id(message.id)
        .background(GeometryReader { geometry in Color.clear.preference(key: ChatVisibilityPreference.self, value: [message.id: geometry.frame(in: .named("chatViewport"))]) })
    }

    /// 群内头像资料携带来源群，沿用真实私聊限制；返回后保留聊天和草稿。
    private func openSenderProfile(_ message: ChatMessageRecord) {
        guard !message.senderID.isEmpty else { return }
        selectedProfile = ContactsRoute(contactID: message.senderID,
            sourceGroupID: route.kind == .group ? route.id : route.sourceGroupID)
    }

    /// 群头像长按与辅助功能都能提及作者，执行时再次检查当前禁言和私聊策略。
    private func mentionAction(for message: ChatMessageRecord) -> (() -> Void)? {
        guard route.kind == .group, message.senderID != store.context?.userUID,
              !message.senderID.isEmpty, !message.senderName.isEmpty, store.permission.canSend,
              !(store.permission.role == 0 && store.permission.isPrivateChat) else { return nil }
        return {
            guard store.permission.canSend, !(store.permission.role == 0 && store.permission.isPrivateChat) else { return }
            store.insertMention(ChatGroupMember(id: message.senderID, name: message.senderName, avatar: message.avatarURL, role: 0, isDeleted: false))
            composerFocused = true
        }
    }

    /// 点击和辅助功能共用操作，避免可访问用户无法打开媒体正文。
    private func activateMessage(_ message: ChatMessageRecord) {
        if !store.selectedIDs.isEmpty { store.toggleSelection(message.id) }
        else if message.status == .normal {
            if message.type == 18 { forwardRecord = message }
            else if [3, 7].contains(message.type) { locationMessage = message }
            else if [1, 2, 4, 5, 12].contains(message.type) { mediaMessage = message }
        }
    }

    /// 媒体操作名称与真实点击目标相同，普通正文使用选择动作。
    private func openActionTitle(_ message: ChatMessageRecord) -> String {
        switch message.type { case 1, 12: return "查看图片"; case 2: return "查看视频"; case 4: return "播放语音"; case 5: return "查看文件"; case 18: return "查看聊天记录"; case 3, 7: return "查看位置"; default: return "选择消息" }
    }

    /// 同日不插五分钟日期，只在第一条和跨日处展示。
    private func showsDate(for message: ChatMessageRecord) -> Bool {
        guard let index = displayedMessages.firstIndex(where: { $0.id == message.id }), index > 0 else { return true }
        return !Calendar.current.isDate(Date(timeIntervalSince1970: Double(message.timestamp) / 1000), inSameDayAs: Date(timeIntervalSince1970: Double(displayedMessages[index - 1].timestamp) / 1000))
    }

    /// 菜单由实时权限矩阵产生，破坏动作使用确认并在提交再次校验。
    @ViewBuilder private func messageMenu(_ message: ChatMessageRecord) -> some View {
        let allowed = ChatActionPolicy.allowed(for: message, userUID: store.context?.userUID ?? "", permission: store.permission)
        if message.type == 6 && !message.cardUID.isEmpty { NavigationLink("查看名片", value: ContactsRoute(contactID: message.cardUID, sourceGroupID: route.kind == .group ? route.id : route.sourceGroupID)) }
        if allowed.contains(.copy) { Button("复制") { UIPasteboard.general.string = message.text } }
        if allowed.contains(.reply) { Button("引用回复") { store.reference = message } }
        if allowed.contains(.edit) { Button("编辑") { editingMessage = message } }
        if allowed.contains(.forward) { Button("转发") { forwardingMessages = [message]; showForward = true } }
        if allowed.contains(.pin) { Button("置顶范围…") { pinningMessage = message } }
        if allowed.contains(.select) { Button("多选") { store.toggleSelection(message.id) } }
        if allowed.contains(.delete) { Button("仅为我删除", role: .destructive) { actionMessageID = message.id; confirmAction = .delete } }
        if allowed.contains(.deleteBoth) { Button("双向删除", role: .destructive) { actionMessageID = message.id; confirmAction = .deleteBoth } }
        if allowed.contains(.recall) { Button("撤回", role: .destructive) { actionMessageID = message.id; confirmAction = .recall } }
    }

    /// 真实置顶查询刷新顶部条，删除撤回和SDK事件后不保留失效正文。
    private func reloadPins() async {
        guard let context = store.context else { pinnedMessages = []; pinnedNotice = nil; return }
        if context.route.kind == .group {
            let notices = SDKChatNoticesClient(); notices.open(context); defer { notices.close() }
            if let records = try? await notices.load(page: 1), store.context == context, !Task.isCancelled { pinnedNotice = records.first(where: \.pinned) }
        }
        guard store.permission.canPin else { pinnedMessages = []; return }
        do { let records = try await SDKChatActionsClient().pinned(context: context); guard store.context == context, !Task.isCancelled else { return }; pinnedMessages = records }
        catch { if store.context == context { /* 离线保留已知置顶条，不用网络错误覆盖正文输入。 */ } }
    }

    /// 确认按钮明确区分本地范围、双方范围和撤回。
    private func actionTitle(_ action: ChatMessageAction) -> String {
        action == .delete ? "仅为我删除" : action == .deleteBoth ? "双向删除" : "撤回"
    }
}

private struct ChatVisibilityPreference: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    /// 合并当前已布局的消息区域，用实际视口交集判断正文可见。
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) { value.merge(nextValue(), uniquingKeysWith: { _, new in new }) }
}
