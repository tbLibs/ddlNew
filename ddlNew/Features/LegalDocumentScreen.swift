import SwiftUI
import WebKit

enum LegalDocument: String, Identifiable {
    case privacy, support, licenses
    var id: String { rawValue }
    var title: String {
        switch self {
        case .privacy: return "隐私政策"
        case .support: return "使用支持"
        case .licenses: return "开源许可"
        }
    }
    var fileURL: URL? { Bundle.main.url(forResource: rawValue, withExtension: "html") }
    var onlineURL: URL? {
        guard let file = Bundle.main.url(forResource: "LegalLinks", withExtension: "json"),
              let data = try? Data(contentsOf: file),
              let links = try? JSONDecoder().decode([String: String].self, from: data),
              let value = links[rawValue], let url = URL(string: value), url.scheme == "https" else { return nil }
        return url
    }
}

struct LegalDocumentScreen: View {
    @Environment(\.dismiss) private var dismiss
    let document: LegalDocument
    var body: some View {
        NavigationView {
            Group {
                if let url = document.fileURL {
                    LocalLegalPage(url: url)
                } else {
                    Text("暂时无法打开文档，请稍后重试。").padding()
                }
            }
            .navigationTitle(document.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
            }
        }.navigationViewStyle(.stack).tint(ClubTheme.darkTeal)
    }
}

private struct LocalLegalPage: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return view
    }
    func updateUIView(_ uiView: WKWebView, context: Context) { }
}

struct LegalEntryLinks: View {
    @State private var document: LegalDocument?
    var body: some View {
        HStack(spacing: 24) {
            Button("隐私政策") { document = .privacy }.accessibilityIdentifier("openPrivacyPolicy")
            Button("使用支持") { document = .support }.accessibilityIdentifier("openSupport")
        }
        .font(.footnote).foregroundColor(ClubTheme.darkTeal)
        .frame(minHeight: 44)
        .sheet(item: $document) { LegalDocumentScreen(document: $0) }
    }
}
