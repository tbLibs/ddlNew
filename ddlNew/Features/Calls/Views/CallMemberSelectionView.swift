import SwiftUI
import UIAdapter

struct CallMemberSelectionView: View {
    let request: CallSelectionRequest
    @ObservedObject var coordinator: CallCoordinator
    @State private var selected: Set<String> = []
    @State private var query = ""

    private var members: [CallParticipant] {
        request.members.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List(members) { member in
                let alreadyInCall = request.selectedIDs.contains(member.id)
                Button {
                    if !selected.insert(member.id).inserted { selected.remove(member.id) }
                } label: {
                    HStack(spacing: 12.zoom()) {
                        Image(systemName: selected.contains(member.id) || alreadyInCall ? "checkmark.circle.fill" : "circle")
                            .font(.title3).foregroundStyle(alreadyInCall ? MessagingTheme.secondaryText : MessagingTheme.accent).accessibilityHidden(true)
                        CallAvatar(name: member.name, resource: member.avatar, size: 44.zoom())
                        VStack(alignment: .leading, spacing: 8.zoom()) {
                            Text(member.name).font(.body.weight(.semibold)).foregroundStyle(MessagingTheme.text)
                            if alreadyInCall { Text("已在通话").font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
                        }
                        Spacer()
                    }.padding(.vertical, 8.zoom()).frame(minHeight: max(44, 64.zoom()))
                }
                .listRowBackground(MessagingTheme.surface)
                .disabled(alreadyInCall || coordinator.busy)
                .accessibilityLabel(member.name + (alreadyInCall ? "，已在通话" : selected.contains(member.id) ? "，已选择" : "，未选择"))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(MessagingTheme.surface)
            .searchable(text: $query, prompt: "搜索群成员")
            .navigationTitle(request.isAdditionalInvite ? "邀请成员" : (request.kind == .audio ? "发起语音通话" : "发起视频通话"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { coordinator.cancelSelection() }.disabled(coordinator.busy)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("确定（\(selected.count)）") {
                        Task { await coordinator.submitSelection(selected, requestID: request.id) }
                    }.buttonStyle(.plain).foregroundStyle(MessagingTheme.accent).frame(minHeight: 44).disabled(selected.isEmpty || coordinator.busy)
                }
            }
            .overlay { if coordinator.busy { ProgressView().padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
        }.tint(MessagingTheme.accent)
            .interactiveDismissDisabled(coordinator.busy)
    }
}
