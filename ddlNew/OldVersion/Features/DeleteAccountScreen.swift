import SwiftUI

struct DeleteAccountScreen: View {
    @EnvironmentObject private var store: ClubStore
    @EnvironmentObject private var community: ClubCommunity
    @State private var acknowledged = false
    @State private var confirming = false
    @State private var deleting = false
    @State private var errorMessage: String?

    var body: some View {
        ClubScroll {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "person.crop.circle.badge.minus")
                    .font(.system(size: 36)).foregroundColor(ClubTheme.error)
                    .frame(width: 76, height: 76).background(ClubTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 24)).accessibilityHidden(true)
                Text("注销前，请确认以下事项").font(.title2.bold())
                Text("注销仅清除本机账号和记录，不会向俱乐部服务器提交请求。")
                    .font(.body).foregroundColor(ClubTheme.secondary).lineSpacing(5)
                ClubCard {
                    VStack(alignment: .leading, spacing: 18) {
                        explanation("清除本机记录", "清除登录状态、俱乐部连接、报名、候补和签到记录。")
                        Divider()
                        explanation("结束聊天会话", "清除本次会话中的聊天记录、草稿和常用联系人。")
                        Divider()
                        explanation("账号无法再次登录", "注销后不可撤销，本机将保留注销标记，原本机账号无法再次登录。")
                    }
                }
                Toggle("我已了解注销后果", isOn: $acknowledged)
                    .font(.body).tint(ClubTheme.darkTeal)
                    .accessibilityIdentifier("acknowledgeAccountDeletion")
                if let errorMessage {
                    Text(errorMessage).font(.subheadline).foregroundColor(ClubTheme.error)
                        .accessibilityIdentifier("accountDeletionError")
                }
                Button { confirming = true } label: {
                    HStack {
                        if deleting { ProgressView().tint(.white) }
                        Text(deleting ? "正在注销…" : "确认注销账号")
                    }.frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent).tint(ClubTheme.error)
                .disabled(!acknowledged || deleting)
                .accessibilityIdentifier("confirmAccountDeletion")
            }.padding(24).disabled(deleting)
        }
        .navigationTitle("注销账号").navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(deleting)
        .alert("确定注销账号？", isPresented: $confirming) {
            Button("取消", role: .cancel) { }
            Button("注销账号", role: .destructive) {
                deleting = true
                errorMessage = nil
                Task {
                    do {
                        try await store.deleteAccount()
                        community.eraseSession()
                    } catch {
                        errorMessage = "注销未完成，本机数据未清除，请重试。"
                        deleting = false
                    }
                }
            }.accessibilityIdentifier("executeAccountDeletion")
        } message: {
            Text("将清除本机记录并退出会员空间，原本机账号将无法再次登录。此操作不可撤销。")
        }
    }

    private func explanation(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundColor(ClubTheme.secondary).lineSpacing(4)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
