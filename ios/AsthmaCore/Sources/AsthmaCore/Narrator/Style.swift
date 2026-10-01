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
        public var attacksWith: Int
        public var nAttacks: Int
        public var baselinesWith: Int
        public var nBaselines: Int
        public var liftLabel: String
    }

    /// Few-shot using THIS diary's top row so the model copies register, not invented stats.
    public func fewShot(_ f: ExampleFacts) -> String {
        let counts = "\(f.attacksWith) of \(f.nAttacks) vs \(f.baselinesWith) of \(f.nBaselines)"
        switch self {
        case .clinical:
            return """
            Example headline in THIS register (same facts, your voice must match this density):
            "Association signal: \(f.binLabel)=\(f.level). Inhaler-day prevalence \(f.attacksWith)/\(f.nAttacks); usual-day prevalence \(f.baselinesWith)/\(f.nBaselines); crude lift \(f.liftLabel)×. Not causal."
            """
        case .plain:
            return """
            Example headline in THIS register (same facts, your voice must match this warmth):
            "Quick read: \(f.binLabel.lowercased()) was \(f.level) a lot more often when you used your inhaler (\(counts) usual days, about \(f.liftLabel)×). Outdoor air only — not a diagnosis."
            """
        case .poetic:
            return """
            Example headline in THIS register (same facts, your voice must match this lyric shape):
            "There is a weather that keeps finding the hard days — \(f.level) \(f.binLabel.lowercased()) in the outdoor air — and your log keeps answering (\(counts); ~\(f.liftLabel)×). Not fate. Just a rhyme the diary keeps humming."
            """
        }
    }

    public func promptBlock(example: ExampleFacts?) -> String {
        let shared = [
            "CRITICAL: The three registers must sound OBVIOUSLY different. Do not write a bland middle sentence for every style.",
            "Voice only — the lift table is ground truth.",
            "You MUST include the exact inhaler/usual counts for the top gated driver (e.g. 8 of 14 vs 3 of 40).",
            "Never invent drivers, counts, diagnoses, or predictions of an attack.",
            "Never say weather caused the attack. Never say lungs know / remember / warn / whisper.",
            "Outdoor air context only.",
        ]
        let voice: String
        switch self {
        case .clinical:
            voice = "Register: CLINICAL (sound like a methods note). Use technical diction: prevalence, co-occurrence, lift, conditioned on inhaler days, usual-day sample. Lead with the exposure name and level. Prefer fractions (8/14) and '×' lift. No metaphors. No second-person coaching. One dense sentence preferred; max two. Forbidden words: 'weather leans', 'echo', 'humming', 'hard days', 'quick read'."
        case .plain:
            voice = "Register: PLAIN (sound like a friend summarizing your diary). Start with 'Quick read:' or 'Here's the pattern:'. Use you/your. Everyday words only — no 'prevalence', 'co-occurrence', 'stratum', 'crude lift'. Say the pattern in one plain sentence, then the counts in the same breath. No metaphor, no research jargon."
        case .poetic:
            voice = "Register: POETIC (sound like a short lyric essay, still honest). Open with imagery about outdoor air, season, heat, haze, pollen, afternoon light — then land the exact counts. Vary sentence rhythm. Allow one metaphor. Prefer sensory language over clinical nouns. Do NOT open with the pollutant name as a chart label. Do NOT use 'Quick read', 'prevalence', or 'co-occurrence'. Still include exact counts before the end. Max three sentences. No destiny / prophecy / body-as-fate."
        }
        var parts = ["Style:", voice] + shared.map { "- \($0)" }
        if let example { parts += ["", fewShot(example)] }
        return parts.joined(separator: "\n")
    }
}
