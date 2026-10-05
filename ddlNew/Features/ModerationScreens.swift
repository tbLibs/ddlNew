import SwiftUI

struct ReportMessageSheet: View {
    @EnvironmentObject private var store: ClubStore
    @Environment(\.dismiss) private var dismiss
    let conversation: ClubMessage
    let entry: ChatEntry
    @State private var reason: ReportReason?
    @State private var details = ""
    @State private var saving = false
    @State private var errorMessage: String?

    private var alreadyReported: Bool {
        store.hasReported(conversationID: conversation.id, messageID: entry.id)
    }

    var body: some View {
        NavigationView {
            ClubScroll {
                VStack(alignment: .leading, spacing: 18) {
                    Text("举报消息").font(.title2.bold())
                    ClubCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("来自 \(conversation.title)").font(.subheadline.weight(.semibold))
                            Text(entry.text).font(.subheadline).foregroundColor(ClubTheme.secondary)
                                .lineLimit(4)
                        }
                    }
                    if alreadyReported {
                        Text("这条消息已记录过举报。")
                            .font(.subheadline).foregroundColor(ClubTheme.secondary)
                            .accessibilityIdentifier("alreadyReportedMessage")
                    } else {
                        Text("选择原因").font(.headline)
                        ClubCard(padding: 0) {
                            VStack(spacing: 0) {
                                ForEach(ReportReason.allCases) { option in
                                    Button {
                                        reason = option
                                        errorMessage = nil
                                    } label: {
                                        HStack {
                                            Text(option.rawValue)
                                            Spacer()
                                            if reason == option {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(ClubTheme.darkTeal)
                                            }
                                        }
                                        .foregroundColor(ClubTheme.ink)
                                        .frame(minHeight: 50).padding(.horizontal, 16)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("reportReason.\(option.rawValue)")
                                    .accessibilityAddTraits(reason == option ? .isSelected : [])
                                    if option != ReportReason.allCases.last { Divider().padding(.leading, 16) }
                                }
                            }
                        }
                        Text("补充说明（选填，最多 300 字）").font(.headline)
                        TextEditor(text: $details)
                            .frame(minHeight: 110)
                            .padding(8)
                            .background(ClubTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(ClubTheme.border))
                            .accessibilityLabel("补充说明")
                            .accessibilityIdentifier("reportDetails")
                            .onChange(of: details) { value in
                                if value.count > 300 { details = String(value.prefix(300)) }
                            }
                        if let errorMessage {
                            Text(errorMessage).font(.subheadline).foregroundColor(ClubTheme.error)
                        }
                        Button(saving ? "正在提交…" : "提交举报") {
                            guard let reason else { return }
                            saving = true
                            errorMessage = nil
                            Task {
                                do {
                                    if try await store.reportMessage(conversation: conversation, entry: entry,
                                                                     reason: reason, details: details) {
                                        dismiss()
                                    } else {
                                        errorMessage = "这条消息已记录过举报。"
                                    }
                                } catch {
                                    errorMessage = "保存失败，请重试。"
                                }
                                saving = false
                            }
                        }
                        .buttonStyle(ClubButtonStyle())
                        .disabled(reason == nil || saving)
                        .accessibilityIdentifier("submitMessageReport")
                    }
                }.padding(20)
            }
            .navigationTitle("举报")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
        .navigationViewStyle(.stack)
        .interactiveDismissDisabled(saving)
    }
}

struct ReportHistoryScreen: View {
    @EnvironmentObject private var store: ClubStore

    var body: some View {
        ClubScroll {
            VStack(alignment: .leading, spacing: 16) {
                if store.reportRecords.isEmpty {
                    EmptyClubState(title: "暂无举报记录", message: "在聊天中打开消息操作，即可举报具体消息。")
                } else {
                    ForEach(store.reportRecords) { report in
                        ClubCard {
                            VStack(alignment: .leading, spacing: 9) {
                                HStack {
                                    Text(report.reason.rawValue).font(.headline)
                                    Spacer()
                                    Text(report.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption).foregroundColor(ClubTheme.secondary)
                                }
                                Text(report.sourceTitle).font(.subheadline.weight(.medium))
                                Text(report.messageText).font(.subheadline).foregroundColor(ClubTheme.secondary)
                                    .lineLimit(3)
                                if !report.details.isEmpty {
                                    Divider()
                                    Text(report.details).font(.subheadline).foregroundColor(ClubTheme.secondary)
                                }
                            }
                        }
                        .accessibilityIdentifier("reportRecord.\(report.id.uuidString)")
                    }
                }
            }.padding(20)
        }
        .navigationTitle("举报记录").navigationBarTitleDisplayMode(.inline)
        .modifier(ClubDetailChrome())
    }
}
