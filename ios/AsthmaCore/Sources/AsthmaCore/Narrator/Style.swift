import Foundation

/// 0 = clinical, 100 = poetic. Voice only — never changes the numbers. Set in Settings.
public enum NarratorStyle: String, Sendable, CaseIterable {
    case clinical, plain, poetic

    public static let defaultScore = 35

    public static func clamp(_ score: Double) -> Int {
        guard score.isFinite else { return defaultScore }
        return Int(max(0, min(100, score.rounded())))
    }

    public init(score: Int) {
        let s = max(0, min(100, score))
        self = s <= 33 ? .clinical : (s <= 66 ? .plain : .poetic)
    }

    public var label: String {
        switch self {
        case .clinical: "Clinical"
        case .plain: "Plain"
        case .poetic: "Poetic"
        }
    }

    /// Creativity by band — clinical stays tight; poetic can wander in diction.
    public var temperature: Double {
        switch self {
        case .clinical: 0.05
        case .plain: 0.25
        case .poetic: 0.7
        }
    }

    public struct ExampleFacts: Sendable {
        public var binLabel: String
        public var level: String
        /// The template's plain clause, e.g. "ozone was high".
        public var clause: String
        public var attacksWith: Int
        public var nAttacks: Int
        public var baselinesWith: Int
        public var nBaselines: Int
    }

    /// Few-shot using THIS diary's top row so the model copies register, not invented stats.
    /// Mirrored in web/src/lib/insights/style.ts.
    public func fewShot(_ f: ExampleFacts) -> String {
        switch self {
        case .clinical:
            return """
            Example headline in THIS register (same facts, your voice must match this density):
            "\(f.binLabel) \(f.level): present on \(f.attacksWith) of \(f.nAttacks) inhaler uses and \(f.baselinesWith) of \(f.nBaselines) usual days. An association in your log, not a cause."
            """
        case .plain:
            return """
            Example headline in THIS register (same facts, your voice must match this warmth):
            "Here's what stands out: \(f.clause) on \(f.attacksWith) of the \(f.nAttacks) times you used your inhaler, and on only \(f.baselinesWith) of \(f.nBaselines) usual days."
            """
        case .poetic:
            return """
            Example headline in THIS register (same facts, your voice must match this lyric shape):
            "Some days the outdoor air feels heavier. \(f.clause.prefix(1).uppercased() + f.clause.dropFirst()) on \(f.attacksWith) of the \(f.nAttacks) times you reached for your inhaler, and on just \(f.baselinesWith) of \(f.nBaselines) ordinary days. Not a cause, just something your log keeps noticing."
            """
        }
    }

    public func promptBlock(example: ExampleFacts?) -> String {
        let shared = [
            "CRITICAL: The three registers must sound OBVIOUSLY different. Do not write a bland middle sentence for every style.",
            "Voice only — the lift table is ground truth.",
            "You MUST include the exact counts for the top gated driver: how many of the times they used their inhaler, and how many usual days (e.g. 8 of 10 vs 3 of 24).",
            "Count inhaler uses as 'times you used your inhaler'. Never use the word 'attack'.",
            "Never state a ratio or multiplier like '3×' or 'twice as often'. Give the two counts instead.",
            "Never invent drivers, counts, diagnoses, or predictions.",
            "Never say the weather caused anything. Never say lungs know / remember / warn / whisper.",
            "Outdoor air context only.",
        ]
        let voice: String
        switch self {
        case .clinical:
            voice = "Register: CLINICAL (sound like a short methods note). Precise and neutral: name the condition and level, then the two counts. Words like 'present on', 'inhaler uses', 'usual days', 'association'. No metaphors. No second-person coaching. One or two short sentences."
        case .plain:
            voice = "Register: PLAIN (sound like a friend reading your log back to you). Use you/your. Short sentences, everyday words. No jargon (no 'prevalence', 'co-occurrence', 'lift'). No stock openers like 'Quick read'. Say what stands out, with the two counts in the same sentence."
        case .poetic:
            voice = "Register: POETIC (a short lyric note, still honest). Open with one image of outdoor air, season, heat, haze, pollen or light, then land the exact counts. Vary rhythm. Allow one metaphor. Do NOT open with the pollutant name as a chart label. Max three sentences. No destiny / prophecy / body-as-fate."
        }
        var parts = ["Style:", voice] + shared.map { "- \($0)" }
        if let example { parts += ["", fewShot(example)] }
        return parts.joined(separator: "\n")
    }
}
