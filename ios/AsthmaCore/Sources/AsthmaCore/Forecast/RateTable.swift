import Foundation

/// Smoothed log likelihood ratios per bin level (docs/predictive-engine.md §5).
/// Rebuilt from frames whenever a log lands; scoring a forecast hour is a lookup.
public struct RateTable: Sendable {
    public struct Entry: Sendable, Equatable {
        public var bin: String
        public var level: String
        public var attacksWith: Int
        public var baselinesWith: Int
        public var logLR: Double
        /// Enough samples to count toward a score.
        public var gated: Bool
        public var id: String { "\(bin):\(level)" }
    }

    public let entries: [String: Entry]
    public let nAttacks: Int
    public let nBaselines: Int
    public let gate: LiftGate
    let bins: [BinDef]

    /// Overall sample gate. Below it there is no personal pattern: use `GenericHazards` (cold start).
    public var isPersonal: Bool { nAttacks >= gate.minAttacks && nBaselines >= gate.minBaselines }

    public init(frames: [FeatureFrame], gate: LiftGate = .default, k: Double = 2, bins: [BinDef] = Bins.all) {
        let attacks = frames.filter { $0.kind == .attack }
        let baselines = frames.filter { $0.kind == .baseline }
        nAttacks = attacks.count
        nBaselines = baselines.count
        self.gate = gate
        self.bins = bins
        let overall = attacks.count >= gate.minAttacks && baselines.count >= gate.minBaselines

        var out: [String: Entry] = [:]
        for def in bins {
            let levels = Set(frames.compactMap(def.levelOf))
            guard !levels.isEmpty else { continue }
            let nLevels = Double(levels.count)
            for level in levels {
                let a = attacks.filter { def.levelOf($0) == level }.count
                let b = baselines.filter { def.levelOf($0) == level }.count
                let pA = (Double(a) + k) / (Double(attacks.count) + k * nLevels)
                let pB = (Double(b) + k) / (Double(baselines.count) + k * nLevels)
                let e = Entry(bin: def.bin, level: level, attacksWith: a, baselinesWith: b,
                              logLR: log(pA / pB), gated: overall && a >= gate.minAttacksInLevel)
                out[e.id] = e
            }
        }
        entries = out
    }

    /// Sum of gated log-LRs active in the frame, plus the entries that contributed.
    public func score(_ frame: FeatureFrame) -> (score: Double, contributions: [Entry]) {
        var total = 0.0
        var used: [Entry] = []
        for def in bins {
            guard let level = def.levelOf(frame), let e = entries["\(def.bin):\(level)"], e.gated else { continue }
            total += e.logLR
            used.append(e)
        }
        return (total, used)
    }
}

public enum RiskBand: String, Sendable, Codable {
    case quiet, usual, elevated
}

/// Bands scores against this person's own usual-day scores, not a made-up probability (§6).
public struct RiskBander: Sendable {
    public let p80: Double
    public let p20: Double
    public let canCallQuiet: Bool

    public init(table: RateTable, baselineFrames: [FeatureFrame]) {
        let scores = baselineFrames.filter { $0.kind == .baseline }.map { table.score($0).score }.sorted()
        p80 = Self.percentile(scores, 0.8)
        p20 = Self.percentile(scores, 0.2)
        canCallQuiet = scores.count >= table.gate.minBaselines
    }

    static func percentile(_ sorted: [Double], _ p: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let rank = Int((p * Double(sorted.count)).rounded(.up)) - 1
        return sorted[min(max(rank, 0), sorted.count - 1)]
    }

    public func band(_ score: Double) -> RiskBand {
        if score > p80 { return .elevated }
        if canCallQuiet && score < p20 { return .quiet }
        return .usual
    }
}
