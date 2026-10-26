import SafariServices
import SwiftUI

struct WebLink: Identifiable {
    let id = UUID()
    let url: URL
}

/// 用户主动打开隐私政策、使用支持等链接。
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
