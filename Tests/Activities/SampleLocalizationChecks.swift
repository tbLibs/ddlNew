import Foundation

// Model boundary test: observable translation output without a bundle or account.
enum L10n {
    static var language = "en"
    static func lookup(_ key: String) -> String { language + ":" + key }
}

@main struct SampleLocalizationChecks {
    static func main() {
        let sample = ClubActivity.samples[0]
        let snapshot = sample
        let getters: [KeyPath<ClubActivity, String>] = [\.displayTitle, \.displayCategory, \.displayDate, \.displayPlace, \.displayMeetingPoint, \.displayRequirement, \.displayNotice]
        for path in getters { precondition(sample[keyPath: path].hasPrefix("en:")) }
        L10n.language = "zh-Hant"
        for path in getters { precondition(sample[keyPath: path].hasPrefix("zh-Hant:")) }
        precondition(sample == snapshot, "Changing language must not mutate the saved activity or its identity")
        let external = ClubActivity(id: sample.id, title: sample.title, category: sample.category, date: sample.date,
                                    place: sample.place, meetingPoint: sample.meetingPoint, capacity: sample.capacity,
                                    requirement: sample.requirement, notice: sample.notice, checkInCode: sample.checkInCode,
                                    checkInTime: sample.checkInTime)
        let originals: [KeyPath<ClubActivity, String>] = [\.title, \.category, \.date, \.place, \.meetingPoint, \.requirement, \.notice]
        for (display, original) in zip(getters, originals) {
            precondition(external[keyPath: display] == external[keyPath: original], "Matching a sample ID or text must not translate external content")
        }
        precondition(sample.capacity == 4 && sample.checkInCode == "6812" && sample.checkInTime == "16:00–16:45")
        print("Bundled activity display localization: 23 checks passed")
    }
}
