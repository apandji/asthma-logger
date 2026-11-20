import AsthmaCore
import Foundation

/// A moment's journal read back as a few plain sentences (April, Nov 20: "like a real diary, but not weird,
/// more like a madlib"), built from what was picked and said, not a list of chips:
/// "You were studying and feeling stressed, inside. There was dust and mold around."
/// Anything said or typed that the sentences don't already cover is kept as the person's own words.
enum JournalSummary {
    struct Read: Equatable {
        var sentences: [String]
        /// Your own words, quoted as said.
        var quotes: [String]
        var isEmpty: Bool { sentences.isEmpty && quotes.isEmpty }
    }

    static func read(_ e: LogEvent) -> Read {
        let tags = e.tags
        var sentences: [String] = []

        // What you were doing: your own words for it first, then what you picked.
        let doingQuestion = Interview.Question.doing.text
        let ownDoing = e.notes.filter { $0.question == doingQuestion }.map(\.transcript).filter { !isChipAnswer($0) }
            .map { lowerFirst($0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "."))) }
            .filter { !$0.isEmpty }
        let picked: [(JournalTag, String)] = [(.exercise, "exercising"), (.cooking, "cooking"), (.cleaningProducts, "cleaning"),
                                              (.laughingOrCrying, "laughing or crying"), (.stress, "feeling stressed")]
        let doing = ownDoing + picked.filter { tags.contains($0.0) }.map(\.1)
        let whereWord: String? = switch e.indoorConfirmedRaw.flatMap(IndoorOutdoor.init(rawValue:)) {
            case .indoor?: "inside"
            case .outdoor?: "outside"
            default: nil
        }
        if !doing.isEmpty {
            sentences.append("You were " + list(doing) + (whereWord.map { ", \($0)" } ?? "") + ".")
        } else if let whereWord {
            sentences.append("You were \(whereWord).")
        }

        // What was around.
        let around: [(JournalTag, String)] = [(.pets, "pets"), (.smoke, "smoke"), (.dust, "dust"), (.mold, "mold or damp"),
                                              (.coldAir, "cold air"), (.strongScents, "strong scents")]
        let near = around.filter { tags.contains($0.0) }.map(\.1)
        if !near.isEmpty { sentences.append("There was " + list(near) + " around.") }
        if tags.contains(.coldOrFlu) { sentences.append("You had a cold or flu.") }

        // How it felt, and what happened.
        let symptoms: [(JournalTag, String)] = [(.wheezing, "wheezing"), (.coughing, "coughing"),
                                                (.chestTightness, "a tight chest"), (.shortOfBreath, "shortness of breath")]
        let felt = symptoms.filter { tags.contains($0.0) }.map(\.1)
        if !felt.isEmpty { sentences.append("You noticed " + list(felt) + ".") }
        let outcomes: [(JournalTag, String)] = [(.wokeAtNight, "It woke you up."), (.activityLimited, "It kept you from doing something."),
                                                (.secondPuff, "You needed a second puff."), (.betterAfter, "The puff helped."),
                                                (.urgentVisit, "You went to urgent care or the ER."), (.oralSteroids, "You took oral steroids.")]
        sentences += outcomes.filter { tags.contains($0.0) }.map(\.1)

        // Everything else you said or typed, in your words.
        var quotes = e.notes.sorted { $0.recordedAt < $1.recordedAt }
            .filter { $0.question != doingQuestion }
            .map { $0.transcript.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !isChipAnswer($0) }
        if e.notes.isEmpty, let words = e.voiceTranscript?.trimmingCharacters(in: .whitespacesAndNewlines), !words.isEmpty {
            quotes = [words]
        }
        return Read(sentences: sentences, quotes: quotes)
    }

    /// An answer that is only chips or a quick reply ("Dust, Mold / damp", "Inside", "None of these"): the
    /// sentences already say it.
    static func isChipAnswer(_ text: String) -> Bool {
        let quick: Set<String> = ["None of these", "Inside", "Outside", "Yes", "No", "…", "Somewhere else"]
        let labels = Set(JournalTag.allCases.map(\.label))
        let parts = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return !parts.isEmpty && parts.allSatisfy { quick.contains($0) || labels.contains($0) }
    }

    /// "a, b and c".
    static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: ""
        case 1: items[0]
        default: items.dropLast().joined(separator: ", ") + " and " + items.last!
        }
    }

    private static func lowerFirst(_ s: String) -> String {
        // Keep "I" and names as they are; only a capital that starts an ordinary word comes down.
        guard let f = s.first, f.isUppercase, s.count > 1, !s.hasPrefix("I ") else { return s }
        let second = s[s.index(after: s.startIndex)]
        return second.isUppercase ? s : f.lowercased() + s.dropFirst()
    }
}
