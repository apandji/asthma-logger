import Foundation

public struct LiftGate: Codable, Sendable, Equatable {
    public var minAttacks: Int
    public var minBaselines: Int
    public var minAttacksInLevel: Int

    public init(minAttacks: Int, minBaselines: Int, minAttacksInLevel: Int) {
        self.minAttacks = minAttacks
        self.minBaselines = minBaselines
        self.minAttacksInLevel = minAttacksInLevel
    }

    /// Production starting point (docs/predictive-engine.md §5).
    public static let `default` = LiftGate(minAttacks: 8, minBaselines: 20, minAttacksInLevel: 4)
    /// Looser gate so demo data shows gated rows quickly.
    public static let demo = LiftGate(minAttacks: 6, minBaselines: 12, minAttacksInLevel: 3)

    /// Lift a level must beat to be called a pattern.
    public static let minLift = 1.25
}

public struct LiftRow: Codable, Sendable, Equatable, Identifiable {
    public var bin: String
    public var level: String
    public var attacksWith: Int
    public var baselinesWith: Int
    public var nAttacks: Int
    public var nBaselines: Int
    public var attackRate: Double
    public var baselineRate: Double
    /// attackRate / baselineRate; `.infinity` when the level never appeared on a usual day.
    public var lift: Double
    public var gated: Bool

    public var id: String { "\(bin):\(level)" }

    public init(bin: String, level: String, attacksWith: Int, baselinesWith: Int, nAttacks: Int, nBaselines: Int,
                attackRate: Double, baselineRate: Double, lift: Double, gated: Bool) {
        self.bin = bin
        self.level = level
        self.attacksWith = attacksWith
        self.baselinesWith = baselinesWith
        self.nAttacks = nAttacks
        self.nBaselines = nBaselines
        self.attackRate = attackRate
        self.baselineRate = baselineRate
        self.lift = lift
        self.gated = gated
    }

    private enum CodingKeys: String, CodingKey {
        case bin, level, attacksWith, baselinesWith, nAttacks, nBaselines, attackRate, baselineRate, lift, gated
    }

    // JSON has no Infinity: null means infinite lift.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bin = try c.decode(String.self, forKey: .bin)
        level = try c.decode(String.self, forKey: .level)
        attacksWith = try c.decode(Int.self, forKey: .attacksWith)
        baselinesWith = try c.decode(Int.self, forKey: .baselinesWith)
        nAttacks = try c.decode(Int.self, forKey: .nAttacks)
        nBaselines = try c.decode(Int.self, forKey: .nBaselines)
        attackRate = try c.decode(Double.self, forKey: .attackRate)
        baselineRate = try c.decode(Double.self, forKey: .baselineRate)
        lift = try c.decodeIfPresent(Double.self, forKey: .lift) ?? .infinity
        gated = try c.decode(Bool.self, forKey: .gated)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(bin, forKey: .bin)
        try c.encode(level, forKey: .level)
        try c.encode(attacksWith, forKey: .attacksWith)
        try c.encode(baselinesWith, forKey: .baselinesWith)
        try c.encode(nAttacks, forKey: .nAttacks)
        try c.encode(nBaselines, forKey: .nBaselines)
        try c.encode(attackRate, forKey: .attackRate)
        try c.encode(baselineRate, forKey: .baselineRate)
        try c.encode(lift.isFinite ? lift : nil, forKey: .lift)
        try c.encode(gated, forKey: .gated)
    }
}

public struct LiftReport: Codable, Sendable, Equatable {
    public var nAttacks: Int
    public var nBaselines: Int
    public var seasonHint: String?
    /// All rows, highest lift first.
    public var rows: [LiftRow]
    /// Rows that pass the gate — the only ones the UI may call a pattern.
    public var gatedRows: [LiftRow]
}

public enum Lift {
    /// Case-control style rates: share of inhaler frames with a level vs share of usual-day frames.
    /// Not P(attack | weather). Raw rates so the user can see the exact counts.
    public static func compute(_ frames: [FeatureFrame], gate: LiftGate = .default, bins: [BinDef] = Bins.all) -> LiftReport {
        let attacks = frames.filter { $0.kind == .attack }
        let baselines = frames.filter { $0.kind == .baseline }
        let nA = attacks.count
        let nB = baselines.count
        var rows: [LiftRow] = []

        for def in bins {
            let levels = Set(frames.compactMap(def.levelOf)).sorted()
            for level in levels {
                if def.isBoolean && level == "no" { continue }
                let aWith = attacks.filter { def.levelOf($0) == level }.count
                let bWith = baselines.filter { def.levelOf($0) == level }.count
                let aRate = rate(aWith, nA)
                let bRate = rate(bWith, nB)
                let lift: Double = bRate <= 0 ? (aWith > 0 ? .infinity : 1) : aRate / bRate
                let gated = nA >= gate.minAttacks && nB >= gate.minBaselines
                    && aWith >= gate.minAttacksInLevel && lift > LiftGate.minLift
                rows.append(LiftRow(bin: def.bin, level: level, attacksWith: aWith, baselinesWith: bWith,
                                    nAttacks: nA, nBaselines: nB, attackRate: aRate, baselineRate: bRate,
                                    lift: lift, gated: gated))
            }
        }

        // Stable sort, highest lift first; infinite lift ranks as 999 like the prototype.
        let sorted = rows.enumerated().sorted { a, b in
            let la = a.element.lift.isFinite ? a.element.lift : 999
            let lb = b.element.lift.isFinite ? b.element.lift : 999
            return la != lb ? la > lb : a.offset < b.offset
        }.map(\.element)

        return LiftReport(nAttacks: nA, nBaselines: nB, seasonHint: majoritySeason(frames),
                          rows: sorted, gatedRows: sorted.filter(\.gated))
    }

    static func rate(_ with: Int, _ total: Int) -> Double {
        total <= 0 ? 0 : Double(with) / Double(total)
    }

    static func majoritySeason(_ frames: [FeatureFrame]) -> String? {
        var order: [Season] = []
        var counts: [Season: Int] = [:]
        for f in frames {
            if counts[f.season] == nil { order.append(f.season) }
            counts[f.season, default: 0] += 1
        }
        var best: Season?
        var n = 0
        for s in order where counts[s]! > n {
            best = s
            n = counts[s]!
        }
        return best?.rawValue
    }

    /// "∞", "12", "2.4" — same as the prototype's formatLift.
    public static func format(_ lift: Double) -> String {
        guard lift.isFinite else { return "∞" }
        if lift >= 10 { return String(Int(lift.rounded(.toNearestOrAwayFromZero))) }
        let tenths = (lift * 10).rounded(.toNearestOrAwayFromZero) / 10
        return String(format: "%.1f", tenths)
    }
}
