import Foundation

@main struct LocalizationChecks {
    static func main() throws {
        precondition(AppLanguage.system.resolved(preferredLanguages: ["zh-Hans-CN"]) == "zh-Hans")
        precondition(AppLanguage.system.resolved(preferredLanguages: ["zh-Hant-TW"]) == "zh-Hant")
        precondition(AppLanguage.system.resolved(preferredLanguages: ["zh-HK"]) == "zh-Hant")
        precondition(AppLanguage.system.resolved(preferredLanguages: ["en-GB"]) == "en")
        precondition(AppLanguage.system.resolved(preferredLanguages: ["fr-FR"]) == "en")
        precondition(AppLanguage.simplifiedChinese.resolved(preferredLanguages: ["en"]) == "zh-Hans")
        let key: L10nKey = "共\(3)人，完成\(50)%"
        precondition(key.key == "共%@人，完成%@%%")
        precondition(key.arguments == ["3", "50"])
        precondition(L10n.render(key, language: "en", translation: "Completed %2$@%% for %1$@ people") == "Completed 50% for 3 people")
        let supplied: L10nKey = "成员\("Alice %@")"
        precondition(L10n.render(supplied, language: "en", translation: "Member %@") == "Member Alice %@")
        let suite = "ddlNew.localize.checks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        precondition(AppLanguage.saved(in: defaults) == .system)
        AppLanguage.traditionalChinese.save(in: defaults)
        precondition(AppLanguage.saved(in: defaults) == .traditionalChinese)
        defaults.set("removed-language", forKey: AppLanguage.preferenceKey)
        precondition(AppLanguage.saved(in: defaults) == .system)
        print("Localization language mapping, interpolation and preference checks passed")
    }
}
