import SwiftUI

struct LanguageSettingsView: View {
    @ObservedObject private var language = AppLanguageStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var localizationLocale
    @State private var pending = AppLanguageStore.shared.selection

    var body: some View {
        NavigationStack {
            List(AppLanguage.allCases, id: \.rawValue) { option in
                Button { pending = option } label: {
                    HStack {
                        Text(verbatim: title(option)).foregroundStyle(LoginPalette.ink)
                        Spacer()
                        if pending == option { Image(systemName: "checkmark").foregroundStyle(LoginPalette.darkTeal) }
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }
                .accessibilityIdentifier("language.\(option.rawValue)")
                .accessibilityAddTraits(pending == option ? [.isSelected] : [])
            }
            .navigationTitle(L10n.tr("语言"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.tr("取消")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("确定")) { language.select(pending); dismiss() }
                        .accessibilityIdentifier("language.confirm")
                }
            }
        }
        .environment(\.locale, language.locale)
        .tint(LoginPalette.darkTeal)
    }
    private func title(_ option: AppLanguage) -> String {
        switch option {
        case .system: return L10n.tr("系统语言")
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .english: return "English"
        }
    }
}

struct LanguageSelectionButton: View {
    @Environment(\.locale) private var localizationLocale
    @State private var presented = false
    var body: some View {
        Button { presented = true } label: {
            Label(L10n.tr("语言"), systemImage: "globe")
                .frame(minHeight: 44)
        }
        .accessibilityIdentifier("openLanguageSettings")
        .sheet(isPresented: $presented) { LanguageSettingsView() }
    }
}
