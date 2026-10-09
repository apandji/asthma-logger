import Foundation

/// Closed list of things the outdoor APIs can't see. The model picks from this list; the user confirms.
/// Only confirmed tags become bins. Adding a case adds a bin — bump `BinSpec.version`.
public enum JournalTag: String, Codable, Sendable, CaseIterable, Identifiable, Comparable {
    case exercise
    case coldAir
    case smoke
    case pets
    case dust
    case mold
    case cleaningProducts
    case strongScents
    case cooking
    case coldOrFlu
    case stress
    case laughingOrCrying

    public var id: String { rawValue }

    public static func < (a: JournalTag, b: JournalTag) -> Bool { a.rawValue < b.rawValue }

    public var label: String {
        switch self {
        case .exercise: "Exercise"
        case .coldAir: "Cold air"
        case .smoke: "Smoke"
        case .pets: "Pets"
        case .dust: "Dust"
        case .mold: "Mold / damp"
        case .cleaningProducts: "Cleaning products"
        case .strongScents: "Strong scents"
        case .cooking: "Cooking / gas stove"
        case .coldOrFlu: "Cold or flu"
        case .stress: "Stress"
        case .laughingOrCrying: "Laughing / crying"
        }
    }

    /// Shown to the model as the meaning of each id.
    public var hint: String {
        switch self {
        case .exercise: "running, sports, climbing stairs, gym, hard physical effort"
        case .coldAir: "breathing cold or freezing air, winter wind"
        case .smoke: "cigarette, vape, campfire, fireplace, wildfire, barbecue smoke"
        case .pets: "cats, dogs, horses, animal dander"
        case .dust: "dusting, vacuuming, construction, old books, attic"
        case .mold: "mold, damp basement, mildew, musty smell"
        case .cleaningProducts: "bleach, sprays, disinfectant, chemical fumes"
        case .strongScents: "perfume, cologne, air freshener, candles, paint"
        case .cooking: "frying, gas stove, kitchen fumes"
        case .coldOrFlu: "sick, cold, flu, COVID, sore throat, congestion"
        case .stress: "stress, anxiety, panic, argument, upset"
        case .laughingOrCrying: "hard laughing or crying"
        }
    }
}

public enum TagExtraction {
    /// Keeps only known ids, de-duplicated, in list order. Unknown strings are dropped.
    public static func sanitize(_ raw: [String]) -> [JournalTag] {
        let wanted = Set(raw.map { $0.trimmingCharacters(in: .whitespaces) })
        return JournalTag.allCases.filter { wanted.contains($0.rawValue) }
    }

    /// Keyword fallback when the on-device model is unavailable. Suggestions only — the user confirms.
    /// Same rules (and negation) as `KeywordTagger`; use `VoiceNoteTagger` for the full flow.
    public static func keywordGuess(_ text: String) -> [JournalTag] {
        KeywordTagger.scan(text).tags
    }
}
