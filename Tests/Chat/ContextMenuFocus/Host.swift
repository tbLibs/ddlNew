import SwiftUI

@main struct FocusHost: App {
    var body: some Scene { WindowGroup { FocusPage() } }
}
struct FocusPage: View {
    @State private var composerFocused = false
    @State private var composerMode = ChatComposerMode()
    @State private var text = "保留草稿"
    @State private var selection = NSRange(location: 4, length: 0)
    @State private var nativeFocused = false
    private let clock = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private let message = "message"
    var body: some View {
        VStack {
            Text(composerFocused ? "focused" : "unfocused").accessibilityIdentifier("focusState")
            Text(nativeFocused ? "native-focused" : "native-unfocused").accessibilityIdentifier("nativeFocus")
            HStack {
                Text("长按这条消息").textSelection(.enabled)
                    .padding(30).background(Color.gray.opacity(0.2))
            }
            .accessibilityIdentifier("message")
            // PRODUCTION_CONTEXT_MENU
            Spacer()
            ChatComposerTextInput(text: $text, selection: $selection, focused: $composerFocused, maximumLines: 5)
                .frame(height: 70).background(Color.gray.opacity(0.1))
        }.padding().navigationTitle("Focus checks")
        // PRODUCTION_KEYBOARD_DISMISSAL
        .onReceive(clock) { _ in
            func input(in view: UIView) -> UITextView? {
                if let view = view as? UITextView, view.accessibilityIdentifier == "chatMessageInput" { return view }
                return view.subviews.lazy.compactMap { input(in: $0) }.first
            }
            nativeFocused = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows).compactMap { input(in: $0) }.contains { $0.isFirstResponder }
        }
    }
    private func messageMenu(_ message: String) -> some View {
        Group {
            Button("复制") {}
            Button("引用回复") { composerMode.beginTyping(); composerFocused = true }
        }
    }
}
