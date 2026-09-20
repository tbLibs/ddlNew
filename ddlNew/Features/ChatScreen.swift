import SwiftUI
import UIKit
import SwiftUIIntrospect

struct ChatScreen: View {
    @EnvironmentObject private var community: ClubCommunity
    @FocusState private var composerFocused: Bool
    @State private var showingContact = false
    let conversation: ClubMessage

    private var entries: [ChatEntry] { community.conversations[conversation.id] ?? [] }
    private var contact: ClubContact? { community.contacts.first { $0.id == conversation.contactID } }
    private var draft: Binding<String> {
        Binding(get: { community.drafts[conversation.id] ?? "" }, set: { community.drafts[conversation.id] = $0 })
    }
    private var canSend: Bool { !draft.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 22) {
                        if entries.isEmpty {
                            VStack(spacing: 14) {
                                avatar(outgoing: false)
                                Text("和\(conversation.title)开始聊天").font(.headline).foregroundColor(ClubTheme.ink)
                                Text("发一句问候，认识同行的伙伴。")
                                    .font(.subheadline).foregroundColor(ClubTheme.secondary)
                            }.frame(maxWidth: .infinity).padding(.vertical, 36)
                        }
                        ForEach(entries) { entry in
                            messageBubble(entry).id(entry.id)
                        }
                    }.padding(20)
                }
                .contentShape(Rectangle())
                .onTapGesture { composerFocused = false }
                .introspect(.scrollView, on: .iOS(.v15, .v16, .v17, .v18, .v26, .v27)) { $0.keyboardDismissMode = .interactive }
                .onAppear { scrollToLatest(proxy) }
                .onChange(of: entries.count) { _ in scrollToLatest(proxy) }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in scrollToLatest(proxy) }
            }
            composer
        }
        .background(ClubTheme.background)
        .navigationBarHidden(false)
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .modifier(ClubDetailChrome())
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if contact != nil {
                    Button {
                        composerFocused = false
                        showingContact = true
                    } label: { Image(systemName: "person.crop.circle") }
                    .accessibilityLabel("成员资料").accessibilityIdentifier("chatContactDetails")
                }
                if composerFocused {
                    Button { composerFocused = false } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                    }
                    .accessibilityLabel("收起键盘")
                    .accessibilityIdentifier("keyboardDone")
                }
            }
        }
        .sheet(isPresented: $showingContact) {
            if let contact { ContactDetailSheet(contact: contact).environmentObject(community) }
        }
        .onDisappear { composerFocused = false }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 12) {
            composerField
                .font(.body).foregroundColor(ClubTheme.ink)
                .focused($composerFocused).submitLabel(.send)
                .onSubmit(send)
                .accessibilityLabel("输入消息").accessibilityIdentifier("chatInput")
                .padding(.horizontal, 14).padding(.vertical, 12)
                .frame(minHeight: 48)
                .background(ClubTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(ClubTheme.border, lineWidth: 1))
            Button(action: send) {
                Image(systemName: "arrow.up").font(.system(size: 20, weight: .semibold))
                    .foregroundColor(canSend ? .white : ClubTheme.secondary)
                    .frame(width: 48, height: 48)
                    .background(canSend ? ClubTheme.darkTeal : ClubTheme.border.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 17))
            }
            .disabled(!canSend).accessibilityLabel("发送消息").accessibilityIdentifier("sendChatMessage")
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(ClubTheme.card.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(ClubTheme.border.opacity(0.5)).frame(height: 0.5) }
    }

    @ViewBuilder private var composerField: some View {
        if #available(iOS 16, *) {
            TextField("输入消息…", text: draft, axis: .vertical).lineLimit(1...4)
        } else {
            TextField("输入消息…", text: draft)
        }
    }

    private func messageBubble(_ entry: ChatEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if entry.isOutgoing { Spacer(minLength: 38) }
            if !entry.isOutgoing { avatar(outgoing: false) }
            VStack(alignment: entry.isOutgoing ? .trailing : .leading, spacing: 7) {
                Text(entry.isOutgoing ? "我" : conversation.title)
                    .font(.caption).foregroundColor(ClubTheme.secondary)
                Text(entry.text).font(.body).foregroundColor(ClubTheme.ink)
                    .lineSpacing(5).padding(16)
                    .background(entry.isOutgoing ? ClubTheme.pale : ClubTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(entry.isOutgoing ? ClubTheme.darkTeal.opacity(0.16) : ClubTheme.border, lineWidth: 1))
                    .accessibilityIdentifier(entry.isOutgoing ? "outgoingMessage" : "incomingMessage")
                Text(entry.time).font(.caption2).foregroundColor(ClubTheme.secondary)
            }
            if entry.isOutgoing { avatar(outgoing: true) }
            if !entry.isOutgoing { Spacer(minLength: 38) }
        }.frame(maxWidth: .infinity, alignment: entry.isOutgoing ? .trailing : .leading)
    }

    private func avatar(outgoing: Bool) -> some View {
        ClubIcon(name: outgoing ? "person" : conversation.icon, size: 20)
            .foregroundColor(ClubTheme.darkTeal).frame(width: 38, height: 38)
            .background(ClubTheme.pale.opacity(outgoing ? 1 : 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 13))
    }

    private func send() {
        guard canSend else { return }
        community.sendMessage(in: conversation.id)
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        if let last = entries.last { proxy.scrollTo(last.id, anchor: .bottom) }
    }
}
