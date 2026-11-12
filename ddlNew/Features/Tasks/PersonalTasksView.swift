import SwiftUI

private enum TaskListFilter: String, CaseIterable {
    case all = "全部", open = "待办", overdue = "已逾期", completed = "已完成"
}

/// 使用主Tab的导航栈；所有列表和详情共享同一账号的持久化状态。
struct PersonalTasksView: View {
    @ObservedObject private var store = PersonalTaskStore.shared
    var groupID: String? = nil
    var groupName: String? = nil
    @State private var query = ""
    @State private var filter: TaskListFilter = .open
    @State private var creating = false
    @State private var showInformation = false
    @State private var feedback: String?
    @State private var feedbackRevision = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            content(now: timeline.date)
        }
        .navigationTitle(L10n.tr("事项"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: L10n.tr("搜索事项、负责人或聊天"))
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { showInformation = true } label: { Image(systemName: "info.circle") }
                    .accessibilityLabel(L10n.tr("事项数据说明"))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { creating = true } label: { Image(systemName: "plus") }
                    .disabled(!store.ready || store.busy)
                    .accessibilityLabel(L10n.tr("新建事项")).accessibilityIdentifier("tasks.create")
            }
        }
        .navigationDestination(isPresented: $creating) {
            PersonalTaskEditor(record: newRecord, creating: true, epoch: store.epoch) {
                feedback = L10n.tr("保存成功"); feedbackRevision += 1
            }
        }
        .messagingFeedbackToast(feedback, trigger: feedbackRevision)
        .alert(L10n.tr("事项数据说明"), isPresented: $showInformation) {
            Button(L10n.tr("知道了"), role: .cancel) { }
        } message: {
            Text(L10n.tr("事项保存在当前设备，按账号隔离。负责人和进度由你记录，不会通知其他成员。卸载应用会移除这些记录，当前不支持云端恢复。"))
        }
    }

    private var newRecord: TaskRecord {
        var record = TaskRecord()
        if let groupID { record.source = TaskSource(conversationID: groupID, conversationName: groupName ?? "", messageID: "", isGroup: true) }
        return record
    }

    private func content(now: Date) -> some View {
        let scoped = store.records.filter { record in
            guard let groupID else { return true }
            return record.source?.belongsToGroup(groupID) == true
        }
        let records = scoped.filter { item in
            let matches: Bool
            switch filter {
            case .all: matches = true
            case .open: matches = !item.progress.isFinished
            case .overdue: matches = item.isOverdue(at: now)
            case .completed: matches = item.progress == .completed
            }
            let words = [item.title, item.notes, item.responsible, item.source?.conversationName ?? ""].joined(separator: " ")
            return matches && (query.isEmpty || words.localizedStandardContains(query))
        }.sorted {
            if $0.isOverdue(at: now) != $1.isOverdue(at: now) { return $0.isOverdue(at: now) }
            if $0.dueDate != $1.dueDate { return ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            return $0.createdAt > $1.createdAt
        }
        return List {
            Section {
                HStack(spacing: 0) {
                    metric("待办", value: scoped.filter { !$0.progress.isFinished }.count)
                    metric("已逾期", value: scoped.filter { $0.isOverdue(at: now) }.count)
                    metric("已完成", value: scoped.filter { $0.progress == .completed }.count)
                }.padding(.vertical, 8)
                Picker(L10n.tr("事项筛选"), selection: $filter) {
                    ForEach(TaskListFilter.allCases, id: \.self) { Text(L10n.lookup($0.rawValue)).tag($0) }
                }.pickerStyle(.segmented)
            }
            if let error = store.errorMessage, !store.ready {
                Section {
                    Text(error).foregroundStyle(MessagingTheme.error)
                    Button(L10n.tr("重试")) { Task { await store.reload() } }.disabled(store.busy)
                }
            } else if !store.ready {
                if store.owner == nil { Text(L10n.tr("登录后查看事项")) }
                else { ProgressView() }
            } else if records.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "checklist").font(.system(size: 36)).foregroundStyle(MessagingTheme.accent)
                        Text(L10n.tr("暂无符合条件的事项")).font(.headline)
                        Text(L10n.tr("添加一个事项，或在聊天中长按文字消息创建。")).font(.subheadline).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 28)
                }
            } else {
                Section {
                    ForEach(records) { record in
                        NavigationLink {
                            PersonalTaskDetail(id: record.id, epoch: store.epoch)
                        } label: { TaskRecordRow(record: record, now: now) }
                        .accessibilityIdentifier("tasks.row.\(record.id)")
                    }
                }
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden)
        .background(MessagingTheme.background).tint(MessagingTheme.accent)
    }
    private func metric(_ title: String, value: Int) -> some View {
        VStack(spacing: 6) {
            Text(value.formatted()).font(.title2.weight(.semibold)).monospacedDigit()
            Text(L10n.lookup(title)).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }
}

private struct TaskRecordRow: View {
    let record: TaskRecord
    let now: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top) {
                Text(record.title).font(.headline).lineLimit(2)
                Spacer(minLength: 8)
                Text(L10n.lookup(record.progress.title)).font(.caption).foregroundStyle(MessagingTheme.accent)
            }
            if !record.responsible.isEmpty { Label(record.responsible, systemImage: "person").font(.subheadline).foregroundStyle(.secondary).lineLimit(1) }
            if let source = record.source { Label(source.conversationName, systemImage: source.isGroupConversation ? "person.3" : "person").font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            if let due = record.dueDate {
                HStack {
                    Image(systemName: "calendar")
                    Text(due, format: .dateTime.month().day().hour().minute())
                    if record.isOverdue(at: now) { Text(L10n.tr("已逾期")) }
                }.font(.caption).foregroundStyle(record.isOverdue(at: now) ? MessagingTheme.error : MessagingTheme.secondaryText)
            }
        }.padding(.vertical, 6)
    }
}

struct PersonalTaskEditor: View {
    @ObservedObject private var store = PersonalTaskStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TaskRecord
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var feedback: String?
    @State private var feedbackRevision = 0
    @State private var discard = false
    private let original: TaskRecord
    let creating: Bool
    let epoch: UUID

    private let onSaved: () -> Void

    init(record: TaskRecord, creating: Bool, epoch: UUID, onSaved: @escaping () -> Void = {}) {
        self.onSaved = onSaved
        original = record; self.creating = creating; self.epoch = epoch
        _draft = State(initialValue: record)
        _hasDueDate = State(initialValue: record.dueDate != nil)
        _dueDate = State(initialValue: record.dueDate ?? Date().addingTimeInterval(86400))
    }
    private var edited: TaskRecord { var item = draft; item.dueDate = hasDueDate ? dueDate : nil; return item }
    var body: some View {
        Form {
            Section(L10n.tr("事项内容")) {
                TextField(L10n.tr("事项标题"), text: limited($draft.title, count: 80))
                    .accessibilityIdentifier("tasks.title")
                TextField(L10n.tr("说明"), text: limited($draft.notes, count: 1000), axis: .vertical).lineLimit(4...8)
                TextField(L10n.tr("负责人备注"), text: limited($draft.responsible, count: 80))
            }
            Section(L10n.tr("安排")) {
                Toggle(L10n.tr("设置截止时间"), isOn: $hasDueDate)
                if hasDueDate { DatePicker(L10n.tr("截止时间"), selection: $dueDate) }
                Picker(L10n.tr("进度"), selection: $draft.progress) {
                    ForEach(TaskProgress.allCases, id: \.self) { Text(L10n.lookup($0.title)).tag($0) }
                }
            }
            Section(L10n.tr("处理结果")) {
                TextField(L10n.tr("记录处理结果或需要补充的内容"), text: limited($draft.result, count: 1000), axis: .vertical).lineLimit(4...8)
            }
            if let source = draft.source {
                Section(L10n.lookup(source.title)) {
                    Text(source.conversationName)
                    Button(L10n.tr("移除来源关联"), role: .destructive) { draft.source = nil }
                }
            }
        }
        .navigationTitle(creating ? L10n.tr("新建事项") : L10n.tr("编辑事项"))
        .navigationBarTitleDisplayMode(.inline).toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(L10n.tr("取消")) { if edited != original { discard = true } else { dismiss() } }.disabled(store.busy)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(L10n.tr("保存")) {
                    Task {
                        if await store.save(edited, expectedEpoch: epoch, creating: creating) { dismiss(); onSaved() }
                        else { feedback = store.errorMessage ?? L10n.tr("事项暂不可用，请重新打开页面"); feedbackRevision += 1 }
                    }
                }.disabled(!store.ready || store.busy || epoch != store.epoch || draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("tasks.save")
            }
        }
        .confirmationDialog(L10n.tr("放弃事项修改？"), isPresented: $discard, titleVisibility: .visible) {
            Button(L10n.tr("放弃修改"), role: .destructive) { dismiss() }
        }
        .messagingFeedbackToast(feedback, trigger: feedbackRevision)
        .onChange(of: store.epoch) { _ in dismiss() }
    }
    private func limited(_ value: Binding<String>, count: Int) -> Binding<String> {
        Binding(get: { value.wrappedValue }, set: { text in
            value.wrappedValue = String(text.prefix(count))
            if text.count > count { feedback = L10n.tr("最多输入\(count)个字符"); feedbackRevision += 1 }
        })
    }
}

struct PersonalTaskDetail: View {
    @ObservedObject private var store = PersonalTaskStore.shared
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    let epoch: UUID
    @State private var deleting = false
    @State private var feedback: String?
    @State private var feedbackRevision = 0
    var body: some View {
        Group {
            if let record = store.records.first(where: { $0.id == id }), epoch == store.epoch {
                Form {
                    Section {
                        Text(record.title).font(.title3.weight(.semibold)).textSelection(.enabled)
                        Text(L10n.lookup(record.progress.title)).foregroundStyle(MessagingTheme.accent)
                        if !record.notes.isEmpty { Text(record.notes).textSelection(.enabled) }
                    }
                    if !record.responsible.isEmpty || record.dueDate != nil || record.source != nil {
                        Section(L10n.tr("安排")) {
                            if !record.responsible.isEmpty { LabeledContent(L10n.tr("负责人备注"), value: record.responsible) }
                            if let due = record.dueDate { LabeledContent(L10n.tr("截止时间")) { Text(due, format: .dateTime.year().month().day().hour().minute()) } }
                            if let source = record.source { LabeledContent(L10n.lookup(source.title), value: source.conversationName) }
                        }
                    }
                    if !record.result.isEmpty { Section(L10n.tr("处理结果")) { Text(record.result).textSelection(.enabled) } }
                    Section(L10n.tr("更新进度")) {
                        ForEach(TaskProgress.allCases.filter { $0 != record.progress }, id: \.self) { progress in
                            Button(L10n.tr("标记为\(L10n.lookup(progress.title))")) {
                                var updated = record; updated.progress = progress
                                Task {
                                    let success = await store.save(updated, expectedEpoch: epoch, creating: false)
                                    feedback = success ? L10n.tr("保存成功") : store.errorMessage
                                    feedbackRevision += 1
                                }
                            }.disabled(store.busy || !store.ready)
                        }
                    }
                    Section(L10n.tr("进度记录")) {
                        ForEach(record.changes.reversed()) { change in
                            HStack {
                                Text(L10n.lookup(change.progress.title)); Spacer()
                                Text(change.date, format: .dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Section { Button(L10n.tr("删除事项"), role: .destructive) { deleting = true }.disabled(store.busy) }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(L10n.tr("编辑")) { PersonalTaskEditor(record: record, creating: false, epoch: epoch) {
                            feedback = L10n.tr("保存成功"); feedbackRevision += 1
                        } }
                            .disabled(store.busy)
                    }
                }
            } else { Text(L10n.tr("事项已删除")) }
        }
        .navigationTitle(L10n.tr("事项详情")).navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar).tint(MessagingTheme.accent)
        .confirmationDialog(L10n.tr("删除事项？"), isPresented: $deleting, titleVisibility: .visible) {
            Button(L10n.tr("删除"), role: .destructive) {
                Task { if await store.remove(id: id, expectedEpoch: epoch) { dismiss() } else { feedback = store.errorMessage; feedbackRevision += 1 } }
            }
        } message: { Text(L10n.tr("删除后无法恢复。")) }
        .messagingFeedbackToast(feedback, trigger: feedbackRevision)
        .onChange(of: store.epoch) { _ in dismiss() }
    }
}
