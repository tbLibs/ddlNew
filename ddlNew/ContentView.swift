import SwiftUI
import AlertToast

struct ContentView: View {
    @StateObject private var store = ClubStore()
    var body: some View {
        Group {
            switch store.stage {
            case .splash: SplashScreen().ignoresSafeArea()
            case .restoreFailed:
                VStack(spacing: 24) {
                    EmptyClubState(title: "暂时无法读取本机记录", message: "现有记录未被覆盖。请解锁设备并检查存储空间后重试。")
                    Button("重新读取") { Task { await store.restore() } }
                        .buttonStyle(ClubButtonStyle())
                }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).background(ClubBackground())
            case .invite: InviteScreen()
            case .login: LoginScreen()
            case .member: MemberTabs()
            }
        }
        .environmentObject(store)
        .tint(ClubTheme.teal)
        .foregroundColor(ClubTheme.ink)
        .preferredColorScheme(.light)
        .toast(isPresenting: $store.showToast, duration: 2.5) {
            AlertToast(displayMode: .hud, type: .regular, title: store.toastMessage,
                       style: .style(backgroundColor: ClubTheme.card, titleColor: ClubTheme.ink))
        }
        .task { await store.restore() }
    }
}
