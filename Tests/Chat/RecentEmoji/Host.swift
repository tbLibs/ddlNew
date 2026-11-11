import SwiftUI

@MainActor final class ChatStore: ObservableObject {
    @Published var input = ""
    let permission = Permission()
    var context: Context? = Context()
    struct Permission { var canSend = true }
    struct Context { let userUID = "anonymous-user"; let tenantID = "anonymous-tenant" }
    func sendGame(_ game: ChatGameSticker) {}
    func reportInputLimit() {}
    func reconcileMentions() {}
    func persistDraft() {}
}
enum MessagingTheme {
    static let secondaryText = Color.gray
    static let text = Color.primary
}
struct ChatStickersView: View {
    let chat: ChatStore
    let embedded: Bool
    var body: some View { Text("贴纸占位") }
}
@main struct RecentEmojiHost: App {
    init() {
        if ProcessInfo.processInfo.arguments.contains("--reset-recents") {
            UserDefaults.standard.removePersistentDomain(forName: "invalid.anonymous.recentemoji.host")
        }
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
struct ContentView: View {
    @StateObject private var chat = ChatStore()
    @State private var opened = true
    @State private var selection = NSRange(location: 0, length: 0)
    var body: some View {
        VStack {
            Button(opened ? "收起表情" : "打开表情") { opened.toggle() }
                .frame(height: 44)
            ZStack {
                Color.clear
                if opened { ChatEmojiPanel(chat: chat, selection: $selection) }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.locale, Locale(identifier: "zh-Hans"))
    }
}
