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
    @ObservedObject private var calls = CallCoordinator.shared
    @ObservedObject private var callConfiguration = CallConfigurationStore.shared
    @ObservedObject private var contacts = LoginSessionService.shared.contacts
    private let conversations = LoginSessionService.shared.conversations
    @State private var liveGroupTitle: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var voicePlayback = ChatVoicePlayback()
    @State private var openedContext: ChatContext?
    @State private var conversationClosed = false
    @State private var confirmAction: ChatMessageAction?
    @State private var actionMessageID: String?
    @State private var pinnedNotice: ChatGroupNotice?
    @State private var showNotices = false
    @State private var pinnedMessages: [ChatMessageRecord] = []
    @State private var pinningMessage: ChatMessageRecord?
    @State private var showPinnedMessages = false
    @State private var pendingSheetLocation: (id: String, context: ChatContext)?
    @State private var pendingLocatedMessageID: String?
    @State private var pendingSendSuccessScroll = false
    @State private var pinRefreshTask: Task<Void, Never>?
    @State private var showMentionPicker = false
    @State private var mentionMembers: [ChatGroupMember] = []
    @State private var inputSelection = NSRange(location: NSNotFound, length: 0)
    @State private var mentionRequest: ChatMentionRequest?
    @State private var mentionTask: Task<Void, Never>?
    @State private var detailDestination: ChatDetailDestination?
    @State private var composerMode = ChatComposerMode()
    @State private var forwardingMerged = false
    @State private var showDeleteSelection = false
    @State private var forwardRecord: ChatMessageRecord?
    @State private var locationMessage: ChatMessageRecord?
    @State private var editingMessage: ChatMessageRecord?
    @State private var forwardingMessages: [ChatMessageRecord] = []
    @State private var showForward = false
    @State private var showCamera = false
    @State private var mediaMessage: ChatMessageRecord?
    @State private var mediaGallery: ChatPhotoBrowserRequest?
    @State private var viewport = CGRect.zero
    @State private var scrollGeometry = ChatScrollGeometry()
    @State private var resizeFollowTask: Task<Void, Never>?
    @State private var didInitialScroll = false
    @State private var alignedInitialHistoryRevision = 0
    @State private var followsInitialLatest = true
    @State private var showFullHistorySearch = false
    // UIKit输入器自己管理first responder，普通状态不会因缺少.focused目标而被系统复位。
    @State private var composerFocused = false

    /// 创建页面独立Store，根runtime统一管理退出和认证轮次。
    init(route: ChatRoute) { self.route = route; _store = StateObject(wrappedValue: ChatRuntime.shared.makeStore()) }

    /// 聊天正文与输入共用原状态，键盘交互只切焦点不修改文字或引用。
    private var chatViewport: some View {
        let messages = displayedMessages
        let initialHistoryRevision = store.initialHistoryRevision
        return ScrollViewReader { proxy in
            VStack(spacing: 0.zoom()) {
                if route.kind == .group && composerMode.panel != .selection { groupNavigation }
                if let room = calls.groupRooms[route.id], route.kind == .group,
                   !room.participants.isEmpty, calls.session?.context.route.id != route.id,
                   let context = store.context, calls.canOfferCall(context: context),
                   !room.participants.contains(where: { $0.id == context.userUID }) {
                    CallGroupBanner(room: room) {
                        guard let context = store.context else { return }
                        composerFocused = false; voicePlayback.stop()
                        Task { await calls.joinGroupRoom(context: context) }
                    }
                }
                if let notice = pinnedNotice { Button { showNotices = true } label: { Label("群公告：" + notice.content, systemImage: "megaphone").lineLimit(2).padding(10.zoom()) }.accessibilityLabel("查看置顶群公告 " + notice.content) }
                if let pinned = pinnedMessages.first {
                    HStack(spacing: 0) {
                        Button { locateMessage(pinned.serverID.isEmpty ? pinned.localID : pinned.serverID) } label: {
                            HStack { Image(systemName: "pin.fill"); Text(pinned.displayText).lineLimit(1); Spacer(minLength: 0) }.padding(10.zoom()).frame(maxWidth: .infinity)
                        }.accessibilityLabel("定位置顶消息 " + pinned.displayText)
                        Button { composerFocused = false; showPinnedMessages = true } label: {
                            HStack { Text("\(pinnedMessages.count)条"); Image(systemName: "list.bullet") }.padding(10.zoom()).frame(minHeight: 44)
                        }.accessibilityLabel("查看全部置顶消息")
                    }.buttonStyle(.plain)
                }

                ScrollView {
                    VStack(spacing: 0) {
                        // 历史较长时只构建视口附近的气泡，避免每次滑动布局整份历史。
                        LazyVStack(spacing: 14.zoom()) {
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                messageRow(message, previous: index > 0 ? messages[index - 1] : nil)
                            }
                        }
                        // 末尾标记独立于懒加载行，首屏和发送后定位仍能取得内容底部坐标。
                        Color.clear.frame(height: 1).id("latest")
                            .background(GeometryReader { geometry in Color.clear.preference(key: ChatLatestPreference.self, value: ChatLatestPreference.Value(frame: geometry.frame(in: .named("chatViewport")), lastMessageID: messages.last?.id, initialHistoryRevision: initialHistoryRevision)) })
                            .padding(.top, messages.isEmpty ? 0 : 14.zoom())
                    }.padding(.horizontal, 16.zoom()).padding(.bottom, 14.zoom())
                }
                .refreshable {
                    guard !store.isLoading, let context = store.context else { return }
                    followsInitialLatest = false
                    resizeFollowTask?.cancel(); resizeFollowTask = nil
                    store.isAtBottom = false
                    let anchor = displayedMessages.first?.id
                    await store.refreshHistory()
                    // 补页仅恢复本次会话原来的首条，失败、无新增或离开聊天时不强制滚动。
                    guard store.isVisible, store.context == context,
                          let anchor, displayedMessages.first?.id != anchor,
                          displayedMessages.contains(where: { $0.id == anchor }) else { return }
                    proxy.scrollTo(anchor, anchor: .top)
                }
                .simultaneousGesture(DragGesture(minimumDistance: 10).onChanged { _ in
                    if followsInitialLatest { followsInitialLatest = false }
                    if let task = resizeFollowTask { task.cancel(); resizeFollowTask = nil }
                    store.isAtBottom = ChatViewportPolicy.isAtBottom(latest: latestFrame, viewport: viewport)
                }.onEnded { _ in
                    // 已读失败后，小幅滑动即使未跨消息边界也能重试；每个手势只补查一次。
                    updateVisibleMessages(recheck: true)
                })
                .simultaneousGesture(TapGesture().onEnded { composerFocused = false; composerMode.beginTyping() })
                .scrollDismissesKeyboard(.interactively)
                .coordinateSpace(name: "chatViewport")
                .background(GeometryReader { geometry in Color.clear.onAppear { updateViewport(geometry.size, proxy: proxy) }.onChange(of: geometry.size) { updateViewport($0, proxy: proxy) } })
                .onPreferenceChange(ChatVisibilityPreference.self) { frames in
                    messageFrames = frames; updateVisibleMessages()
                    positionLocatedMessage(proxy)
                }
                .onPreferenceChange(ChatLatestPreference.self) { layout in
                    latestLayout = layout
                    positionSendSuccess(proxy)
                    if followsInitialLatest { positionInitialMessages(proxy) }
                    else if resizeFollowTask == nil { store.isAtBottom = ChatViewportPolicy.isAtBottom(latest: latestFrame, viewport: viewport) }
                }
                .opacity(initialMessagesReady ? 1 : 0)
                .allowsHitTesting(initialMessagesReady)
                .accessibilityHidden(!initialMessagesReady)
                if store.unreadArrivals > 0 { Button("\(store.unreadArrivals)条新消息") { store.returnToLatest(); if let id = store.messages.last?.id { proxy.scrollTo(id, anchor: .bottom) } }.padding(8.zoom()) }
            }
            .background(MessagingTheme.background)
            .safeAreaInset(edge: .bottom, spacing: 0.zoom()) { composer }
            .onAppear { resumeChat(proxy) }
            .onChange(of: store.messages.last?.id) { id in
                guard id != nil else { return }
                if followsInitialLatest { positionInitialMessages(proxy) }
                else if store.isAtBottom { followAfterResize(proxy) }
            }
            .onChange(of: composerFocused) { _ in followAfterResize(proxy) }
            .onChange(of: store.locationRevision) { _ in receiveLocatedMessage(proxy) }
            .onChange(of: store.sendSuccessRevision) { _ in receiveSendSuccess(proxy) }
        }
    }

    /// 标题跟随当前资料：单聊读取通讯录，群聊读取改名后由 SDK 发布的会话数据。
    private var chatTitle: String {
        if route.kind == .single, let contact = contacts.contacts.first(where: { $0.id == route.id }) { return contact.displayName }
        if let liveGroupTitle { return liveGroupTitle }
        return route.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? route.id : route.title
    }

    /// 会话预览和未读频繁变化，仅当前群名改变才更新聊天页的展示状态。
    private func updateGroupTitle(_ values: [ConversationRecord]) {
        let title = route.kind == .group ? values.first(where: { $0.id == route.id && $0.kind == .group })?.title : nil
        let name = title.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        if liveGroupTitle != name { liveGroupTitle = name }
    }

    /// 导航配置与正文分开，控制大型聊天视图的泛型推断范围。
    private var chatNavigation: some View {
        chatViewport
        .onReceive(conversations.$conversations) { updateGroupTitle($0) }
        .navigationTitle(composerMode.panel == .selection ? "选择消息（\(store.selectedIDs.count)）" : chatTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        // 目标页在push准备时就声明隐藏底栏，避免先按Tab栏安全区布局、随后输入区下移。
        .toolbar(.hidden, for: .tabBar)
        .tint(MessagingTheme.accent)
        .toolbarBackground(MessagingTheme.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(composerMode.panel == .selection ? "选择消息（\(store.selectedIDs.count)）" : chatTitle)
                    .font(.headline).lineLimit(1).foregroundStyle(MessagingTheme.text)
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if composerMode.panel == .selection {
                    Button("取消") { store.cancelSelection(); composerMode.endSelection() }.frame(minHeight: 44).accessibilityLabel("取消多选")
                } else {
                    Button { composerFocused = false; showSettings = true } label: { Image(systemName: "ellipsis").font(.system(size: 20.zoom())).frame(width: max(44, 44.zoom()), height: max(44, 44.zoom())) }.accessibilityLabel("聊天设置")
                }
            }
        }
        .navigationDestination(isPresented: Binding(get: { detailDestination != nil }, set: { if !$0 { detailDestination = nil } })) {
            switch detailDestination {
            case .settings:
                ChatSettingsView(route: route)
            case .profile(let profile):
                ContactRecordDetailView(store: LoginSessionService.shared.contacts, businessStore: LoginSessionService.shared.contactBusiness,
                    contactID: profile.contactID, fileHost: OSSConnectionBootstrap.shared.current?.getFileHost,
                    sourceGroupID: profile.sourceGroupID)
            case .chat(let target):
                ChatRoomView(route: target)
            case nil:
                EmptyView()
            }
        }
        .environment(\.contactChatNavigation, ContactChatNavigationAction(open: openChatFromProfile))
        .task(id: runtime.revision) {
            mentionTask?.cancel(); mentionRequest = nil; showMentionPicker = false
            guard !conversationClosed else { return }
            if let context = runtime.context(for: route) {
                if store.context != context {
                    didInitialScroll = false; alignedInitialHistoryRevision = 0; followsInitialLatest = true
                    pendingSheetLocation = nil; pendingLocatedMessageID = nil; pendingSendSuccessScroll = false
                    latestLayout = ChatLatestPreference.Value(); messageFrames.removeAll(); visibleMessageIDs.removeAll()
                }
                openedContext = context; await store.open(context)
                if route.kind == .group { await calls.refreshGroupRoom(context: context) }
            }
            else { store.close() }
        }
        .onChange(of: runtime.closedConversationContext) { closed in
            guard let closed, closed == openedContext else { return }
            // 离群后先撤销设置页，再退出聊天；阻止返回动画期间重新打开已关闭的Store。
            conversationClosed = true; detailDestination = nil; showCamera = false; mediaGallery = nil; mentionTask?.cancel(); mentionRequest = nil; showMentionPicker = false; store.close()
            DispatchQueue.main.async { dismiss() }
        }
        .onChange(of: calls.session?.id) { id in
            if id != nil { composerFocused = false; voicePlayback.stop() }
        }
        .onDisappear { voicePlayback.stop(); resizeFollowTask?.cancel(); resizeFollowTask = nil; store.isVisible = false; mentionTask?.cancel(); mentionTask = nil; if !showMentionPicker { mentionRequest = nil }; if detailDestination == nil && mediaMessage == nil && mediaGallery == nil && editingMessage == nil && !showForward && !showCamera && forwardRecord == nil && locationMessage == nil && !showFullHistorySearch && pinningMessage == nil && !showPinnedMessages && !showNotices && !showMentionPicker && !calls.isPresented && calls.selection == nil { mentionTask?.cancel(); mentionRequest = nil; store.close() } }
    }

    /// 弹层仍使用原状态和上下文，不重新创建聊天Store。
    private var chatPresentations: some View {
        chatNavigation
        .sheet(isPresented: $showNotices, onDismiss: {
            pinRefreshTask?.cancel(); pinRefreshTask = Task { await reloadPins() }
        }) { NavigationStack { ChatGroupNoticesView(route: route) } }
        .sheet(isPresented: $showPinnedMessages, onDismiss: locateAfterSheetDismissal) { NavigationStack { ChatPinnedMessagesView(messages: pinnedMessages, onLocate: queueSheetLocation).toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { showPinnedMessages = false } } } } }
        .sheet(item: $pinningMessage) { message in if let context = store.context { NavigationStack { ChatPinActionView(message: message, context: context, permission: store.permission, onChange: { Task { await reloadPins() } }) } } }
        .sheet(isPresented: $showFullHistorySearch, onDismiss: locateAfterSheetDismissal) {
            if let context = store.context { NavigationStack { ChatHistorySearchView(context: context, onLocate: queueSheetLocation).toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { showFullHistorySearch = false } } } } }
        }
        .sheet(isPresented: $showMentionPicker, onDismiss: {
            let context = mentionRequest?.context
            mentionRequest = nil
            if let context, store.context == context, runtime.isCurrent(context), !conversationClosed { composerFocused = true }
        }) {
            ChatMentionPickerView(members: mentionMembers, onSelect: { member in
                if let request = mentionRequest, store.context == request.context,
                   runtime.isCurrent(request.context), store.input == request.text,
                   let selection = store.insertMention(member, replacingAt: request.range) { inputSelection = selection }
                showMentionPicker = false
            }, onCancel: { showMentionPicker = false })
        }
        // 只读弹层提供明确关闭入口，Mac运行iPhone App时不能依赖手势下拉退出。
        .sheet(item: $forwardRecord) { message in if let context = store.context { NavigationStack { ChatForwardRecordView(message: message, context: context).toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { forwardRecord = nil } } } } } }
        .sheet(item: $locationMessage) { message in NavigationStack { ChatLocationDetailView(message: message).toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { locationMessage = nil } } } } }
        .sheet(item: $editingMessage) { message in if let context = store.context { NavigationStack { ChatMessageEditorView(message: message, context: context, store: store) } } }
        .sheet(isPresented: $showForward, onDismiss: { if store.selectedIDs.isEmpty { composerMode.endSelection() } }) { if let context = store.context { NavigationStack { ChatForwardRecipientView(messages: forwardingMessages, context: context, chat: store, initialMerged: forwardingMerged) } } }
        .sheet(item: $mediaMessage) { message in
            if let context = store.context { NavigationStack { ChatMediaDetailView(message: message, context: context, onVoicePlayed: { Task { await store.markVisible(message.id, voicePlayed: true) } }).toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { mediaMessage = nil } } } } }
        }
        .chatPhotoBrowser(item: $mediaGallery, context: store.context)
    }

    /// 业务观察和确认操作独立于展示组件，继续保留原回调边界。
    var body: some View {
        chatPresentations
        .messagingFeedbackToast(chatFeedbackMessage, isEnabled: !showSettings && !showForward && mediaMessage == nil && mediaGallery == nil && editingMessage == nil && pinningMessage == nil)
        .onChange(of: store.messages) { _ in
            // 同一可见ID的服务端身份/已读资格可能补齐，消息变化时主动重查一次。
            updateVisibleMessages(recheck: true)
            pinRefreshTask?.cancel(); pinRefreshTask = Task { do { try await Task.sleep(nanoseconds: 300_000_000); await reloadPins() } catch {} }
        }
        .onChange(of: store.pinRevision) { _ in
            pinRefreshTask?.cancel(); pinRefreshTask = Task { await reloadPins() }
        }
        .onChange(of: store.input) { _ in store.reconcileMentions(); store.persistDraft() }
        // 设置页修改公告后返回，主动核对真实置顶状态，不等下一条聊天消息触发刷新。
        .onChange(of: showSettings) { showing in
            if !showing { pinRefreshTask?.cancel(); pinRefreshTask = Task { await reloadPins() } }
        }
        .onChange(of: scenePhase) { phase in store.isForeground = phase == .active; if phase != .active { voicePlayback.stop() } }
        .onChange(of: composerMode.panel) { panel in if panel == .selection { voicePlayback.stop() } }
        .confirmationDialog("删除所选消息", isPresented: $showDeleteSelection, titleVisibility: .visible) {
            if selectedCanDelete { Button("仅为我删除", role: .destructive) { Task { await deleteSelection(both: false) } } }
            if selectedCanDeleteBoth { Button("从双方或群成员设备删除", role: .destructive) { Task { await deleteSelection(both: true) } } }
        } message: { Text("只删除服务器或本机已确认成功的记录，失败项会保留选择并显示明细。") }
        .confirmationDialog("确认消息操作", isPresented: Binding(get: { confirmAction != nil }, set: { if !$0 { confirmAction = nil } }), titleVisibility: .visible) {
            if let action = confirmAction, let id = actionMessageID {
                Button(actionTitle(action), role: .destructive) { Task { await store.perform(action, id: id) }; confirmAction = nil }
                Button("取消", role: .cancel) { confirmAction = nil }
            }
        } message: { Text(confirmAction == .delete ? "仅删除你自己的这条聊天记录。" : confirmAction == .deleteBoth ? "将申请从双方聊天记录删除这条消息。" : "将申请撤回这条消息。") }
    }

    private var displayedMessages: [ChatMessageRecord] { store.messages.filter(\.isVisible) }
    /// 工具栏和资料入口只修改各自目标，系统返回时由统一导航绑定清理。
    private var showSettings: Bool {
        get { detailDestination == .settings }
        nonmutating set {
            if newValue { detailDestination = .settings }
            else if detailDestination == .settings { detailDestination = nil }
        }
    }
    private var selectedProfile: ContactsRoute? {
        get { if case .profile(let profile) = detailDestination { return profile }; return nil }
        nonmutating set {
            if let newValue { detailDestination = .profile(newValue) }
            else if case .profile = detailDestination { detailDestination = nil }
        }
    }

    /// 同会话按业务身份返回原页；其他好友替换直属子树，保留群来源与原聊天Store。
    private func openChatFromProfile(_ target: ChatRoute) {
        guard !conversationClosed else { return }
        if target.id == route.id && target.kind == route.kind { detailDestination = nil }
        else { detailDestination = .chat(target) }
    }

    private var messageFrames: [String: CGRect] {
        get { scrollGeometry.messageFrames }
        nonmutating set { scrollGeometry.messageFrames = newValue }
    }
    private var latestLayout: ChatLatestPreference.Value {
        get { scrollGeometry.latestLayout }
        nonmutating set { scrollGeometry.latestLayout = newValue }
    }
    private var latestFrame: CGRect { latestLayout.frame }
    private var visibleMessageIDs: Set<String> {
        get { scrollGeometry.visibleMessageIDs }
        nonmutating set { scrollGeometry.visibleMessageIDs = newValue }
    }
    // 只在首次展示前等待定位；沿旧端增量补齐，已显示的正文不重新隐藏。
    private var initialMessagesReady: Bool {
        store.initialHistoryRevision > 0 && (route.targetMessageID != nil || !followsInitialLatest || displayedMessages.isEmpty
            || didInitialScroll)
    }

    /// 请求未结束时不提示临时禁发，确认后的限制与业务错误共用浮层，不挤占消息视口。
    private var chatFeedbackMessage: String? {
        if let error = store.errorMessage, !error.isEmpty { return error }
        guard store.context != nil, !store.isLoading, !store.permission.isChecking,
              !store.permission.isActive || !store.permission.canSend else { return nil }
        return store.permission.reason.isEmpty ? "当前会话暂不能发送消息" : store.permission.reason
    }

    /// 引用和多选独立占位，媒体组件保持同一身份，切换面板不销毁上传或草稿。
    private var composer: some View {
        VStack(spacing: 0) {
            if composerMode.panel == .selection { selectionBar }
            else if let reference = store.reference {
                HStack(spacing: 8.zoom()) {
                    Rectangle().fill(MessagingTheme.accent).frame(width: 3)
                    VStack(alignment: .leading, spacing: 3.zoom()) {
                        Text("回复 " + reference.senderName).font(.caption.weight(.semibold))
                        Text(reference.displayText).font(.caption).foregroundStyle(MessagingTheme.secondaryText).lineLimit(2)
                    }
                    Spacer(minLength: 4)
                    Button { store.reference = nil } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("取消引用")
                }
                .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 16.zoom()).padding(.vertical, 6.zoom())
            }
            ChatMediaComposer(chat: store, mode: $composerMode, focused: $composerFocused, inputSelection: $inputSelection, showCamera: $showCamera,
                onBeginRecording: { voicePlayback.stop() },
                onAtSign: atSignAction)
        }.background(MessagingTheme.surface)
            .overlay(alignment: .top) { MessagingTheme.divider.frame(height: 0.5) }
    }

    private var atSignAction: ((NSRange) -> Void)? {
        guard route.kind == .group else { return nil }
        return { range in beginMention(at: range) }
    }

    /// 群顶部保留旧版消息/群公告入口；未批准的收藏链接标签不展示。
    private var groupNavigation: some View {
        HStack(spacing: 24.zoom()) {
            Label("消息", systemImage: "message").font(.subheadline.weight(.semibold)).foregroundStyle(MessagingTheme.accent)
            Button { composerFocused = false; showNotices = true } label: { Label("群公告", systemImage: "megaphone").font(.subheadline) }.frame(minHeight: 44)
            Spacer(minLength: 0)
            Button { composerFocused = false; showFullHistorySearch = true } label: { Image(systemName: "magnifyingglass").frame(width: 44, height: 44) }.accessibilityLabel("搜索聊天记录")
        }.padding(.horizontal, 16.zoom()).background(MessagingTheme.surface)
    }

    /// 多选使用独立底栏，零选中仍保留取消出口，不显示普通输入或录音面板。
    private var selectionBar: some View {
        HStack(spacing: 0) {
            Button { beginForward(merged: true) } label: { Label("合并转发", systemImage: "square.stack").frame(maxWidth: .infinity) }
            Divider().frame(height: 24)
            Button { beginForward(merged: false) } label: { Label("逐条转发", systemImage: "arrowshape.turn.up.right").frame(maxWidth: .infinity) }
            if store.permission.canDelete || store.permission.canDeleteBoth {
                Divider().frame(height: 24)
                Button(role: .destructive) { showDeleteSelection = true } label: { Label("删除", systemImage: "trash").frame(maxWidth: .infinity) }
                    .disabled(!selectedCanDelete && !selectedCanDeleteBoth)
            }
        }.labelStyle(ChatComposerToolLabelStyle()).buttonStyle(.plain).padding(.vertical, 8.zoom()).padding(.horizontal, 16.zoom())
            .disabled(store.selectedIDs.isEmpty)
    }

    /// 转发入口固定本次模式，接收人确认页仍允许复核和更换模式。
    private func beginForward(merged: Bool) {
        forwardingMerged = merged
        forwardingMessages = store.messages.filter { store.selectedIDs.contains($0.id) }
        showForward = true
    }

    /// 仅已确认删除的选择被清理，失败项留在多选界面供重试。
    private func deleteSelection(both: Bool) async {
        await store.deleteSelected(both: both)
        if store.selectedIDs.isEmpty { composerMode.endSelection() }
    }

    /// 视口收缩前保留末尾跟随意图，历史浏览与搜索定位不强制滚动。
    private func updateViewport(_ size: CGSize, proxy: ScrollViewProxy) {
        let followsLatest = store.isAtBottom
        viewport = CGRect(origin: .zero, size: size)
        updateVisibleMessages()
        positionSendSuccess(proxy)
        if followsInitialLatest { positionInitialMessages(proxy) }
        else if followsLatest { followAfterResize(proxy) }
        else if resizeFollowTask == nil { store.isAtBottom = ChatViewportPolicy.isAtBottom(latest: latestFrame, viewport: viewport) }
    }

    /// 子页期间可能已完成布局，返回时主动重试，不能只等待不一定再变化的几何事件。
    private func resumeChat(_ proxy: ScrollViewProxy) {
        store.isForeground = scenePhase == .active
        store.isVisible = true
        positionSendSuccess(proxy)
        positionLocatedMessage(proxy)
        if followsInitialLatest { positionInitialMessages(proxy) }
    }

    /// 沿旧端停止首屏和键盘末尾跟随，再按真实消息身份补齐历史。
    private func locateMessage(_ id: String) {
        guard !id.isEmpty, let context = store.context else { return }
        followsInitialLatest = false; didInitialScroll = true; pendingLocatedMessageID = nil
        resizeFollowTask?.cancel(); resizeFollowTask = nil
        store.isAtBottom = false; composerFocused = false
        Task {
            guard store.context == context, runtime.isCurrent(context), !conversationClosed else { return }
            await store.locate(id)
        }
    }

    /// 列表先返回聊天再定位；记录会话归属，弹层期间切账号不得操作新会话。
    private func queueSheetLocation(_ id: String) {
        guard let context = store.context else { return }
        pendingSheetLocation = (id, context)
    }

    /// 使用实际弹层关闭回调替代旧端固定延迟，取消关闭不产生定位。
    private func locateAfterSheetDismissal() {
        guard let selection = pendingSheetLocation else { return }
        pendingSheetLocation = nil
        guard selection.context == store.context, runtime.isCurrent(selection.context), !conversationClosed else { return }
        locateMessage(selection.id)
    }

    /// 定位结果可能先于新历史布局到达，保留请求供几何或页面恢复回调消费。
    private func receiveLocatedMessage(_ proxy: ScrollViewProxy) {
        guard let id = store.locatedMessageID else { return }
        followsInitialLatest = false; didInitialScroll = true
        resizeFollowTask?.cancel(); resizeFollowTask = nil
        store.isAtBottom = false; pendingLocatedMessageID = id
        positionLocatedMessage(proxy)
    }

    /// 先按稳定ID使懒加载目标进入布局，再以实际行坐标完成居中；隐藏页面不消费请求。
    private func positionLocatedMessage(_ proxy: ScrollViewProxy) {
        guard let id = pendingLocatedMessageID, store.isVisible,
              !showPinnedMessages, !showFullHistorySearch,
              viewport.width > 0, viewport.height > 0 else { return }
        resizeFollowTask?.cancel(); resizeFollowTask = nil
        store.isAtBottom = false
        proxy.scrollTo(id, anchor: .center)
        if messageFrames[id] != nil { pendingLocatedMessageID = nil }
    }

    /// SDK成功回执强制回到最新消息，即使用户之前正在浏览旧记录。
    private func receiveSendSuccess(_ proxy: ScrollViewProxy) {
        followsInitialLatest = false; didInitialScroll = true
        pendingLocatedMessageID = nil
        resizeFollowTask?.cancel(); resizeFollowTask = nil
        pendingSendSuccessScroll = true
        store.returnToLatest()
        positionSendSuccess(proxy)
    }

    /// 等末条消息对应的布局完成后消费回执，避免ACK早于列表更新时滚动到旧位置。
    private func positionSendSuccess(_ proxy: ScrollViewProxy) {
        guard pendingSendSuccessScroll, store.isVisible,
              let lastID = displayedMessages.last?.id,
              latestLayout.lastMessageID == lastID,
              latestFrame.width > 0, viewport.width > 0, viewport.height > 0 else { return }
        proxy.scrollTo("latest", anchor: .bottom)
        // 懒加载先使用估算高度跳转，末条实际进入视口后才消费本次请求。
        guard ChatViewportPolicy.isAtBottom(latest: latestFrame, viewport: viewport) else { return }
        store.returnToLatest()
        pendingSendSuccessScroll = false
    }

    /// 沿旧端在真实布局回调无动画对齐首屏，用户翻历史或显式定位后停止首次跟随。
    private func positionInitialMessages(_ proxy: ScrollViewProxy) {
        guard followsInitialLatest, store.isVisible, route.targetMessageID == nil,
              store.initialHistoryRevision > 0, latestLayout.initialHistoryRevision == store.initialHistoryRevision,
              let lastID = displayedMessages.last?.id, latestLayout.lastMessageID == lastID,
              viewport.width > 0, viewport.height > 0, latestFrame.width > 0 else { return }
        resizeFollowTask?.cancel(); resizeFollowTask = nil
        var transaction = Transaction(animation: nil); transaction.disablesAnimations = true
        withTransaction(transaction) {
            if ChatViewportPolicy.isAtBottom(latest: latestFrame, viewport: viewport) {
                didInitialScroll = true; alignedInitialHistoryRevision = store.initialHistoryRevision; store.isAtBottom = true
            } else { proxy.scrollTo("latest", anchor: .bottom) }
        }
        if didInitialScroll { updateVisibleMessages() }
    }

    /// 键盘和后续尺寸变化继续合并处理，首次定位不等待这条延迟任务。
    private func followAfterResize(_ proxy: ScrollViewProxy) {
        guard !followsInitialLatest, store.isAtBottom, route.targetMessageID == nil else { return }
        resizeFollowTask?.cancel()
        resizeFollowTask = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
            guard !Task.isCancelled, store.isVisible else { return }
            proxy.scrollTo("latest", anchor: .bottom)
            resizeFollowTask = nil
            store.isAtBottom = ChatViewportPolicy.isAtBottom(latest: latestFrame, viewport: viewport)
        }
    }

    /// 可见集合供已读和游戏行局部消费，跨消息边界也不使聊天根视图重建。
    private func updateVisibleMessages(recheck: Bool = false) {
        let visible = initialMessagesReady ? Set(messageFrames.filter { $0.value.intersects(viewport) }.keys) : []
        guard visible != visibleMessageIDs || recheck else { return }
        if visible != visibleMessageIDs { visibleMessageIDs = visible }
        store.setVisibleMessageIDs(visible)
        guard !visible.isEmpty, let context = store.context else { return }
        Task { @MainActor in
            for id in visible {
                guard store.context == context else { return }
                await store.markVisible(id)
            }
        }
    }

    /// 双向批量入口必须每条均符合当前作者、会话和群角色矩阵。
    private var selectedCanDelete: Bool {
        let values = store.messages.filter { store.selectedIDs.contains($0.id) }
        return !values.isEmpty && values.allSatisfy { ChatActionPolicy.allowed(for: $0, userUID: store.context?.userUID ?? "", permission: store.permission).contains(.delete) }
    }

    /// 双向删除沿原权限矩阵，只在全部选择均被允许时提供。
    private var selectedCanDeleteBoth: Bool {
        let values = store.messages.filter { store.selectedIDs.contains($0.id) }
        return !values.isEmpty && values.allSatisfy { ChatActionPolicy.allowed(for: $0, userUID: store.context?.userUID ?? "", permission: store.permission).contains(.deleteBoth) }
    }

    /// 与旧端一致：只有实际键入@才打开成员页；取消或受限时保留普通@正文。
    private func beginMention(at range: NSRange) {
        guard let context = store.context, runtime.isCurrent(context), store.permission.canSend,
              !(store.permission.role == 0 && store.permission.isPrivateChat), !showMentionPicker else { return }
        let request = ChatMentionRequest(context: context, text: store.input, range: range)
        mentionTask?.cancel(); mentionRequest = request; composerFocused = false
        mentionTask = Task { await loadMentionMembers(request) }
    }

    /// SDK完整成员同步后再展示，迟到结果不能切换身份或覆盖已变化的草稿。
    private func loadMentionMembers(_ request: ChatMentionRequest) async {
        let client = SDKChatSettingsClient(); defer { client.close() }
        defer {
            if mentionRequest?.id == request.id && !showMentionPicker {
                let restoreFocus = !Task.isCancelled && isCurrentMentionRequest(request)
                mentionRequest = nil
                if restoreFocus { composerFocused = true }
            }
        }
        do {
            let result = try await client.load(context: request.context)
            guard !Task.isCancelled, isCurrentMentionRequest(request),
                  let group = result.group, group.isActive, group.role > 0 || !group.isPrivateChat else { return }
            let members = group.members.filter { !$0.isDeleted }
            mentionMembers = members.isEmpty ? [] : [ChatGroupMember(id: "-1", name: "所有人", avatar: "", role: 0, isDeleted: false)] + members
            showMentionPicker = true
        } catch {
            if !Task.isCancelled, isCurrentMentionRequest(request) { store.errorMessage = error.localizedDescription }
        }
    }

    /// 请求期间进入子页、继续编辑或切换面板，旧结果连焦点也不能恢复。
    private func isCurrentMentionRequest(_ request: ChatMentionRequest) -> Bool {
        mentionRequest?.id == request.id && store.context == request.context && runtime.isCurrent(request.context)
            && store.input == request.text && store.isVisible && !showSettings && selectedProfile == nil
            && composerMode.panel == .text && !composerFocused
    }

    /// 独立消息行降低SwiftUI类型推断成本，复用稳定气泡ID与实际可见区域。
    private func messageRow(_ message: ChatMessageRecord, previous: ChatMessageRecord?) -> some View {
        VStack(spacing: 8.zoom()) {
            if showsDate(for: message, after: previous) { Text(Date(timeIntervalSince1970: Double(message.timestamp) / 1000), style: .date).font(.caption).foregroundStyle(.secondary) }
            if message.type == 1000 || message.status == .recalled {
                Text(message.displayText).font(.caption).foregroundStyle(MessagingTheme.secondaryText)
                    .frame(maxWidth: .infinity).multilineTextAlignment(.center).padding(.vertical, 4.zoom())
            } else {
                HStack(alignment: .center, spacing: 6.zoom()) {
                    if composerMode.panel == .selection {
                        Button { store.toggleSelection(message.id) } label: {
                            Image(systemName: store.selectedIDs.contains(message.id) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 23.zoom())).frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
                        }.accessibilityLabel("选择消息 " + message.displayText).accessibilityValue(store.selectedIDs.contains(message.id) ? "已选中" : "未选中")
                            .disabled(!ChatActionPolicy.allowed(for: message, userUID: store.context?.userUID ?? "", permission: store.permission).contains(.select) && !store.selectedIDs.contains(message.id))
                    }
                    ChatMessageBubble(message: message, own: message.senderID == store.context?.userUID,
                    isSelected: store.selectedIDs.contains(message.id), isHighlighted: store.locatedMessageID == message.id,
                    onRetry: { store.retry(message.id) }, onReference: { locateMessage(message.referenceID) }, onAvatar: { openSenderProfile(message) }, onMention: mentionAction(for: message), onOpenCard: { activateMessage(message) }, referenceSummary: store.referenceSummary(message.referenceID), showsSenderName: route.kind == .group, scrollVisibility: scrollGeometry, onGameAnimationComplete: { store.completeGameAnimation($0) }, voicePlayback: voicePlayback)
                    .allowsHitTesting(composerMode.panel != .selection)
                    .accessibilityHidden(composerMode.panel == .selection)
                    .overlay {
                        if composerMode.panel == .selection { Color.clear.contentShape(Rectangle()).onTapGesture { store.toggleSelection(message.id) } }
                    }
                    .onTapGesture { if composerMode.panel != .selection { activateMessage(message) } }
                    .accessibilityAction(named: openActionTitle(message)) { activateMessage(message) }
                    .contextMenu { if composerMode.panel != .selection { messageMenu(message) } }
                    .accessibilityAction(named: "选择消息") { composerMode.selectMessages(); composerFocused = false; store.toggleSelection(message.id) }
                }
            }
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
        guard !message.isMediaUploading else { return }
        if calls.session != nil && [2, 4].contains(message.type) {
            store.errorMessage = "通话中暂不能播放语音或视频"; return
        }
        if message.type != 4 { voicePlayback.stop() }
        if composerMode.panel == .selection { store.toggleSelection(message.id) }
        else if message.status == .normal {
            if let cardID = message.cardProfileID { selectedProfile = ContactsRoute(contactID: cardID) }
            else if message.type == 18 { forwardRecord = message }
            else if [3, 7].contains(message.type) { locationMessage = message }
            else if [1, 2, 12].contains(message.type) {
                let gallery = ChatPhotoBrowserRequest(selected: message, messages: store.messages)
                if !gallery.items.isEmpty { mediaGallery = gallery }
            }
            else if message.type == 4, let context = store.context {
                voicePlayback.toggle(message, context: context,
                    onPlayed: { [store] in Task { await store.markVisible(message.id, voicePlayed: true) } },
                    onError: { [store] in store.errorMessage = $0 })
            }
            else if message.type == 5 { mediaMessage = message }
        }
    }

    /// 媒体操作名称与真实点击目标相同，普通正文使用选择动作。
    private func openActionTitle(_ message: ChatMessageRecord) -> String {
        switch message.type { case 6: return "查看名片"; case 1, 12: return "查看图片"; case 2: return "查看视频"; case 4: return "播放语音"; case 5: return "查看文件"; case 18: return "查看聊天记录"; case 3, 7: return "查看位置"; default: return "选择消息" }
    }

    /// 直接比较渲染快照里的相邻记录，避免每行重复过滤并线性查找整段历史。
    private func showsDate(for message: ChatMessageRecord, after previous: ChatMessageRecord?) -> Bool {
        guard let previous else { return true }
        return !Calendar.current.isDate(Date(timeIntervalSince1970: Double(message.timestamp) / 1000), inSameDayAs: Date(timeIntervalSince1970: Double(previous.timestamp) / 1000))
    }

    /// 菜单由实时权限矩阵产生，破坏动作使用确认并在提交再次校验。
    @ViewBuilder private func messageMenu(_ message: ChatMessageRecord) -> some View {
        let allowed = ChatActionPolicy.allowed(for: message, userUID: store.context?.userUID ?? "", permission: store.permission)
        if let cardID = message.cardProfileID { Button("查看名片") { selectedProfile = ContactsRoute(contactID: cardID) } }
        if allowed.contains(.copy) { Button("复制") { UIPasteboard.general.string = message.text } }
        if allowed.contains(.reply) { Button("引用回复") { store.reference = message; composerMode.beginTyping(); composerFocused = true } }
        if allowed.contains(.edit) { Button("编辑") { editingMessage = message } }
        if allowed.contains(.forward) { Button("转发") { forwardingMerged = false; forwardingMessages = [message]; showForward = true } }
        if allowed.contains(.pin) { Button("置顶范围…") { pinningMessage = message } }
        if allowed.contains(.select) { Button("多选") { composerMode.selectMessages(); composerFocused = false; store.toggleSelection(message.id) } }
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

/// 记录本次@的正文与登录上下文，成员页返回时只消费同一次输入。
private struct ChatMentionRequest {
    let id = UUID()
    let context: ChatContext
    let text: String
    let range: NSRange
}
