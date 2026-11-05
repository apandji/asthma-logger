import Foundation

/// Your own edge for a reading (docs/design/risk-color.md): "your flare days often came when it was below about
/// 40°F", where the general edge is 32°F. Found by code, never by the model, and only when it earns it.
///
/// 1. Try cut points every `step` across the range you've been in (below 35, below 40…, or above for heat).
/// 2. Score each the way the forecast scores a level: share of flare moments past it vs share of baseline
///    moments, smoothed (add-k, k = 2).
/// 3. Keep the best one only if it passes a stricter gate than a fixed bin (we searched, so one cut can win by
///    luck): enough moments past it, raw lift above `minLift`, and the same cut (within one step) wins on most
///    random half-splits of your moments.
/// 4. Within one step of the general edge, say the general one: a personal edge appears only when you differ.
public struct PersonalEdge: Sendable, Equatable {
    public enum Side: String, Sendable { case below, above }

    public let side: Side
    /// Rounded to `step`: "about 40°F".
    public let value: Double
    /// True when it snapped to the general edge (you don't really differ).
    public let isGeneral: Bool
    public let flarePast: Int
    public let nFlare: Int
    public let baselinePast: Int
    public let nBaseline: Int
    public let lift: Double
    /// Share of half-splits that found the same cut, within one step.
    public let stability: Double

    public struct Rules: Sendable, Equatable {
        public var step: Double = 5
        public var minFlarePast = 8
        public var minBaselines = 20
        public var minLift = 1.5
        public var minStability = 0.6
        public var splits = 200
        public init() {}
    }

    /// The edge for one side, or nil when nothing passes. `general` is the human edge for that side
    /// (32°F below, 90°F above for temperature).
    public static func find(flare: [Double], baseline: [Double], side: Side, general: Double?,
                            rules: Rules = Rules(), seed: UInt64 = 7) -> PersonalEdge? {
        guard baseline.count >= rules.minBaselines, flare.count >= rules.minFlarePast else { return nil }
        guard let best = bestCut(flare: flare, baseline: baseline, side: side, rules: rules,
                                 minPast: rules.minFlarePast) else { return nil }
        let a = past(flare, best, side), b = past(baseline, best, side)
        let lift = rate(a, flare.count) / max(rate(b, baseline.count), 1e-9)
        guard lift > rules.minLift else { return nil }

        // Stability: does a random half of your moments find the same cut?
        var rng = SplitMix(seed: seed)
        var agree = 0
        for _ in 0..<rules.splits {
            let f = flare.filter { _ in rng.coin() }, g = baseline.filter { _ in rng.coin() }
            if let c = bestCut(flare: f, baseline: g, side: side, rules: rules, minPast: max(2, rules.minFlarePast / 2)),
               abs(c - best) <= rules.step { agree += 1 }
        }
        let stability = Double(agree) / Double(rules.splits)
        guard stability >= rules.minStability else { return nil }

        let snapped = general.map { abs($0 - best) <= rules.step } ?? false
        return PersonalEdge(side: side, value: snapped ? general! : best, isGeneral: snapped, flarePast: a,
                            nFlare: flare.count, baselinePast: b, nBaseline: baseline.count, lift: lift,
                            stability: stability)
    }

    /// "below about 40°F". Words for the sentence; the caller decides whether a number may show.
    public func phrase(unit: String) -> String {
        "\(side == .below ? "below" : "above") about \(Int(value))\(unit)"
    }

    // MARK: Search

    static func bestCut(flare: [Double], baseline: [Double], side: Side, rules: Rules, minPast: Int) -> Double? {
        let all = flare + baseline
        guard let lo = all.min(), let hi = all.max(), !flare.isEmpty, !baseline.isEmpty else { return nil }
        let k = 2.0
        var best: (cut: Double, score: Double)?
        var c = (lo / rules.step).rounded(.up) * rules.step
        while c <= hi {
            let a = past(flare, c, side), b = past(baseline, c, side)
            if a >= minPast {
                let score = log((Double(a) + k) / (Double(flare.count) + 2 * k))
                    - log((Double(b) + k) / (Double(baseline.count) + 2 * k))
                if score > 0, best == nil || score > best!.score { best = (c, score) }
            }
            c += rules.step
        }
        return best?.cut
    }

    static func past(_ xs: [Double], _ cut: Double, _ side: Side) -> Int {
        xs.filter { side == .below ? $0 < cut : $0 > cut }.count
    }

    static func rate(_ n: Int, _ of: Int) -> Double { of == 0 ? 0 : Double(n) / Double(of) }
}

/// Deterministic coin flips for the half-splits, so the same moments give the same edge.
struct SplitMix {
    private var s: UInt64
    init(seed: UInt64) { s = seed }
    mutating func next() -> UInt64 {
        s &+= 0x9E37_79B9_7F4A_7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func coin() -> Bool { next() & 1 == 1 }
}
