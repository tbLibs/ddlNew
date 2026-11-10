import SwiftUI
import UIKit

enum MineSupportRoute: Hashable { case network, about }

struct NetworkDiagnosticScreen: View {
    @Environment(\.locale) private var localizationLocale
    @StateObject private var store = NetworkDiagnosticStore()
    @ObservedObject private var runtime = ChatRuntime.shared
    var body: some View {
        NetworkDiagnosticPageContent(results: store.results, running: store.running,
            completed: store.completed, activeSection: store.activeSection,
            status: store.status, license: currentLicense, activeTargets: store.activeTargets, sources: store.sources) {
                if store.running { store.reset() } else { store.start() }
            }
            .navigationTitle(L10n.tr("网络检测")).navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HomeTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onDisappear { store.cancel() }
            .onChange(of: runtime.revision) { _ in store.reset() }
    }

    private var currentLicense: String {
        guard let uid = runtime.userUID else { return "" }
        return runtime.context(for: ChatRoute(id: uid, kind: .single, title: "", avatarURL: ""))?.tenantID ?? ""
    }
}

struct AboutUsScreen: View {
    @Environment(\.locale) private var localizationLocale
    @State private var document: LegalDocument?
    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return L10n.tr("当前版本 v\(info["CFBundleShortVersionString"] as? String ?? "—") (\(info["CFBundleVersion"] as? String ?? "—"))")
    }
    private var appIcon: UIImage? {
        let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
        let primary = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        let names = primary?["CFBundleIconFiles"] as? [String]
        return names?.last.flatMap { UIImage(named: $0) }
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Group {
                    if let appIcon { Image(uiImage: appIcon).resizable().scaledToFit() }
                    else { Image(systemName: "app.fill").resizable().scaledToFit().foregroundStyle(HomeTheme.forest) }
                }
                .frame(width: 82, height: 82).clipShape(RoundedRectangle(cornerRadius: 20))
                .accessibilityHidden(true)
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? L10n.tr("响铃"))
                    .font(.title2.weight(.semibold))
                Text(version).font(.subheadline).foregroundStyle(HomeTheme.secondaryText)
                VStack(spacing: 0) {
                    legalRow(.support)
                    Divider()
                    legalRow(.privacy)
                }.padding(.horizontal, 16)
                    .background(HomeTheme.surface, in: RoundedRectangle(cornerRadius: 20))
            }
            .padding(24).frame(maxWidth: HomeTheme.contentWidth).frame(maxWidth: .infinity)
        }
        .background(HomeTheme.background.ignoresSafeArea()).foregroundStyle(HomeTheme.text).tint(HomeTheme.forest)
        .navigationTitle(L10n.tr("关于我们")).navigationBarTitleDisplayMode(.inline)
        .sheet(item: $document) { LegalDocumentScreen(document: $0) }
    }
    private func legalRow(_ value: LegalDocument) -> some View {
        Button { document = value } label: {
            HStack {
                Text(value.title).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Image(systemName: "chevron.right").font(.caption).accessibilityHidden(true)
            }.frame(minHeight: 56).contentShape(Rectangle())
        }.buttonStyle(HomePressStyle())
    }
}
