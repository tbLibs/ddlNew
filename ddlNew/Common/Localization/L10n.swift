import Foundation

/// 语言是安装级偏好，和账号、SDK认证及连接状态无关。
nonisolated enum AppLanguage: String, CaseIterable, Sendable {
    case system
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"

    static let preferenceKey = "app.language.selection"
    static func saved(in defaults: UserDefaults = .standard) -> Self {
        defaults.string(forKey: preferenceKey).flatMap(Self.init(rawValue:)) ?? .system
    }
    func save(in defaults: UserDefaults = .standard) { defaults.set(rawValue, forKey: Self.preferenceKey) }
    func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        guard self == .system else { return rawValue }
        let parts = (preferredLanguages.first ?? "en").replacingOccurrences(of: "_", with: "-").lowercased().split(separator: "-")
        guard parts.first == "zh" else { return "en" }
        if parts.contains("hant") { return "zh-Hant" }
        if parts.contains("hans") { return "zh-Hans" }
        return parts.contains(where: { ["tw", "hk", "mo"].contains(String($0)) }) ? "zh-Hant" : "zh-Hans"
    }
}

/// 保留模板和参数边界，翻译可调整参数顺序；用户输入不作为翻译键。
nonisolated struct L10nKey: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    let key: String
    let arguments: [String]
    init(stringLiteral value: String) { key = value; arguments = [] }
    init(stringInterpolation: StringInterpolation) { key = stringInterpolation.key; arguments = stringInterpolation.arguments }
    struct StringInterpolation: StringInterpolationProtocol {
        var key = ""
        var arguments: [String] = []
        init(literalCapacity: Int, interpolationCount: Int) { arguments.reserveCapacity(interpolationCount) }
        mutating func appendLiteral(_ literal: String) { key += literal.replacingOccurrences(of: "%", with: "%%") }
        mutating func appendInterpolation<T>(_ value: T) { key += "%@"; arguments.append(String(describing: value)) }
    }
}

nonisolated enum L10n {
    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var code = AppLanguage.saved().resolved()
        var bundles: [String: Bundle] = [:]
    }
    private static let state = State()
    static var languageCode: String {
        state.lock.lock(); defer { state.lock.unlock() }; return state.code
    }
    static var locale: Locale { Locale(identifier: languageCode) }
    static func use(_ language: AppLanguage, preferredLanguages: [String] = Locale.preferredLanguages) {
        state.lock.lock(); defer { state.lock.unlock() }
        state.code = language.resolved(preferredLanguages: preferredLanguages)
    }
    static func tr(_ key: L10nKey) -> String {
        let language = languageCode
        return render(key, language: language, translation: lookup(key.key, language: language))
    }
    /// 仅用于应用自有文案（例如保留稳定rawValue的显示名），不能用于聊天正文和昵称。
    static func lookup(_ key: String) -> String { lookup(key, language: languageCode) }
    private static func lookup(_ key: String, language: String) -> String {
        state.lock.lock()
        let bundle: Bundle?
        if let cached = state.bundles[language] { bundle = cached }
        else {
            bundle = Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:))
            state.bundles[language] = bundle
        }
        state.lock.unlock()
        return bundle?.localizedString(forKey: key, value: key, table: "Localizable") ?? key
    }
    static func render(_ key: L10nKey, language: String, translation: String) -> String {
        guard !key.arguments.isEmpty else { return translation }
        return String(format: translation, locale: Locale(identifier: language), arguments: key.arguments.map { $0 as NSString })
    }
}
