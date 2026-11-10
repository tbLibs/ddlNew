import Combine
import Foundation

@MainActor final class AppLanguageStore: ObservableObject {
    static let shared = AppLanguageStore()
    @Published private(set) var selection: AppLanguage
    @Published private(set) var locale: Locale

    init() {
        let saved = AppLanguage.saved()
        selection = saved
        locale = Locale(identifier: saved.resolved())
        L10n.use(saved)
    }
    func select(_ language: AppLanguage) {
        language.save()
        L10n.use(language)
        selection = language
        locale = L10n.locale
    }
    /// 跟随系统时回到前台重新读取；不修改认证、路由、页面身份或输入状态。
    func refreshSystemLanguage() {
        guard selection == .system else { return }
        L10n.use(.system)
        locale = L10n.locale
    }
}
