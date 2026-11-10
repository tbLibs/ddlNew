import SwiftUI

struct LegalConsentRow: View {
    @Environment(\.locale) private var localizationLocale
    @Binding var isAccepted: Bool
    let onOpenDocument: () -> Void
    @State private var webLink: WebLink?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button { isAccepted.toggle() } label: {
                Image(systemName: isAccepted ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.tr("同意隐私政策和使用支持"))
            .accessibilityValue(isAccepted ? L10n.tr("已勾选") : L10n.tr("未勾选"))
            .accessibilityAddTraits(isAccepted ? .isSelected : [])
            .accessibilityIdentifier("acceptLegalDocuments")

            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.tr("我已阅读并同意以下内容"))
                    .foregroundColor(LoginPalette.secondary)
                HStack(spacing: 24) {
                    Button(L10n.tr("隐私政策")) { openWebPage(privacyPolicyURLString) }
                        .accessibilityIdentifier("openPrivacyPolicy")
                    Button(L10n.tr("使用支持")) { openWebPage(usageSupportURLString) }
                        .accessibilityIdentifier("openSupport")
                }
                .buttonStyle(AuthenticationTextButtonStyle())
                .frame(minHeight: 44)
            }
        }
        .font(.footnote)
        .foregroundColor(LoginPalette.darkTeal)
        .frame(minHeight: 44)
        .sheet(item: $webLink) { link in
            SafariView(url: link.url)
                .ignoresSafeArea()
        }
    }

    private func openWebPage(_ address: String) {
        onOpenDocument()
        // Safari 只接受 HTTP/HTTPS；配置中统一使用 HTTPS，不加载本地旧版文档。
        guard let url = URL(string: address), url.scheme == "https",
              let host = url.host, !host.isEmpty else { return }
        webLink = WebLink(url: url)
    }
}
