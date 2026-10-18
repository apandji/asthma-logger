import Foundation

/// Closed list of what a note can say. The model picks from this list; the user confirms.
/// Three kinds (docs/design/journaling-clinical.md):
/// - **Triggers**, the things the outdoor APIs can't see. Only these become lift-table bins: adding one adds a
///   bin, bump `BinSpec.version`.
/// - **Symptoms**, the control domains a US provider asks about (NAEPP EPR-3 Fig 3-5c; GINA 2024 Box 2-2):
///   wheezing, coughing, chest tightness, shortness of breath, night waking, activity limitation.
/// - **Outcomes**: reliever response and escalation (a second puff, better after, urgent care, oral steroids).
/// Symptoms and outcomes are recorded, exported and shown to providers, never bins: "wheezing shows up on
/// your flare days" is true by definition and would crowd out the air.
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
    // Symptoms
    case wheezing
    case coughing
    case chestTightness
    case shortOfBreath
    case wokeAtNight
    case activityLimited
    // Outcomes
    case secondPuff
    case betterAfter
    case urgentVisit
    case oralSteroids

    public enum Kind: String, Sendable { case trigger, symptom, outcome }

    public var kind: Kind {
        switch self {
        case .wheezing, .coughing, .chestTightness, .shortOfBreath, .wokeAtNight, .activityLimited: .symptom
        case .secondPuff, .betterAfter, .urgentVisit, .oralSteroids: .outcome
        default: .trigger
        }
    }

    public static let triggers = allCases.filter { $0.kind == .trigger }
    public static let symptoms = allCases.filter { $0.kind == .symptom }
    public static let outcomes = allCases.filter { $0.kind == .outcome }

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
        case .wheezing: "Wheezing"
        case .coughing: "Coughing"
        case .chestTightness: "Chest tightness"
        case .shortOfBreath: "Shortness of breath"
        case .wokeAtNight: "Woke me up"
        case .activityLimited: "Kept me from doing something"
        case .secondPuff: "Needed a second puff"
        case .betterAfter: "Felt better after"
        case .urgentVisit: "Urgent care or ER"
        case .oralSteroids: "Oral steroids"
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
        case .wheezing: "wheezing, a whistling sound when breathing"
        case .coughing: "coughing"
        case .chestTightness: "a tight or heavy chest, chest pressure"
        case .shortOfBreath: "short of breath, breathless, couldn't breathe, couldn't catch their breath"
        case .wokeAtNight: "woke up at night because of breathing, couldn't sleep"
        case .activityLimited: "had to stop, sit down or leave; couldn't finish or keep up"
        case .secondPuff: "needed more than one puff, another puff"
        case .betterAfter: "felt better after the inhaler"
        case .urgentVisit: "urgent care, the emergency room, hospital, ambulance"
        case .oralSteroids: "oral steroids such as prednisone"
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
