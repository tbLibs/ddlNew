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
                        CallAvatar(name: member.name, resource: member.avatar, size: 44.zoom())
                        Text(member.name).foregroundStyle(MessagingTheme.text)
                        Spacer()
                        if alreadyInCall { Text("已在通话").font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
                        Image(systemName: selected.contains(member.id) || alreadyInCall ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(alreadyInCall ? MessagingTheme.secondaryText : MessagingTheme.accent)
                    }.frame(minHeight: 48)
                }
                .disabled(alreadyInCall || coordinator.busy)
                .accessibilityLabel(member.name + (alreadyInCall ? "，已在通话" : selected.contains(member.id) ? "，已选择" : "，未选择"))
            }
            .searchable(text: $query, prompt: "搜索群成员")
            .navigationTitle(request.isAdditionalInvite ? "邀请成员" : (request.kind == .audio ? "发起语音通话" : "发起视频通话"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { coordinator.cancelSelection() }.disabled(coordinator.busy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定（\(selected.count)）") {
                        Task { await coordinator.submitSelection(selected, requestID: request.id) }
                    }.disabled(selected.isEmpty || coordinator.busy)
                }
            }
            .overlay { if coordinator.busy { ProgressView().padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
        }.tint(MessagingTheme.accent)
            .interactiveDismissDisabled(coordinator.busy)
    }
}
