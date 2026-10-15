//
//  ChatEmojiPanel.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import SwiftUI
import UIAdapter

/// 基础表情插入旧端文本标记；SDK贴纸仍使用独立的真实资源发送链路。
struct ChatEmojiPanel: View {
    @ObservedObject var chat: ChatStore
    @Binding var selection: NSRange
    @State private var tab = 0
    @State private var recent: [ChatEmojiItem] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("表情类型", selection: $tab) { Text("表情").tag(0); Text("贴纸").tag(1) }.pickerStyle(.segmented)
                if tab == 0 {
                    Button { edit(ChatEmojiCatalog.deletingBackward(chat.input, selection: selection)) } label: {
                        Image(systemName: "delete.left").frame(width: 44, height: 44)
                    }.accessibilityLabel("删除前一个表情或文字").disabled(chat.input.isEmpty)
                }
            }.padding(.horizontal, 12.zoom())
            if tab == 0 {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8.zoom()) {
                        Text("互动表情").font(.caption).foregroundStyle(MessagingTheme.secondaryText)
                        HStack(spacing: 12.zoom()) {
                            ForEach(ChatGameSticker.allCases) { game in
                                Button { chat.sendGame(game) } label: {
                                    VStack(spacing: 4.zoom()) {
                                        Image(game.icon).resizable().scaledToFit().frame(width: 44.zoom(), height: 44.zoom())
                                        Text(game.title).font(.caption).foregroundStyle(MessagingTheme.text)
                                    }.frame(maxWidth: .infinity, minHeight: 64).contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityLabel("发送" + game.title)
                            }
                        }
                        Text("最近使用").font(.caption).foregroundStyle(MessagingTheme.secondaryText)
                        grid(recent.isEmpty ? Array(ChatEmojiCatalog.items.prefix(7)) : recent)
                        Text("全部表情").font(.caption).foregroundStyle(MessagingTheme.secondaryText)
                        grid(ChatEmojiCatalog.items)
                    }.padding(.horizontal, 12.zoom()).padding(.bottom, 12.zoom())
                }
            } else { ChatStickersView(chat: chat, embedded: true) }
        }.disabled(!chat.permission.canSend)
    }

    /// 自适应列宽保留至少44pt的操作区，窄屏与辅助字号不会挤掉表情。
    private func grid(_ items: [ChatEmojiItem]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 4)], spacing: 4) {
            ForEach(items) { item in
                Button {
                    edit(ChatEmojiCatalog.replacing(chat.input, range: selection, with: item.token))
                    recent.removeAll { $0.id == item.id }; recent.insert(item, at: 0); recent = Array(recent.prefix(7))
                } label: {
                    Image(item.image).resizable().scaledToFit().frame(width: 30.zoom(), height: 30.zoom())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(.plain).accessibilityLabel("插入表情" + item.token)
            }
        }
    }

    /// 外部编辑与键盘走同一个草稿/提及核对入口，不创建或直接发送消息。
    private func edit(_ result: (text: String, selection: NSRange)) {
        chat.input = result.text; chat.reconcileMentions(); selection = result.selection; chat.persistDraft()
    }
}
