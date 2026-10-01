import Foundation

public struct NarratorRow: Codable, Sendable, Equatable {
    public var bin: String
    public var level: String
    public var attacksWith: Int
    public var baselinesWith: Int
    public var attackRate: Double
    public var baselineRate: Double
    /// Infinite lift is sent as 99.
    public var lift: Double
    public var gated: Bool
    public var id: String { "\(bin):\(level)" }
}

/// Everything the language model is allowed to see: the table, never the diary or coordinates.
public struct NarratorInput: Codable, Sendable, Equatable {
    public var nAttacks: Int
    public var nBaselines: Int
    public var season: String?
    public var rows: [NarratorRow]
    public var rules: [String]
    public var styleScore: Int

    public init(report: LiftReport, styleScore: Int = NarratorStyle.defaultScore) {
        let source = report.gatedRows.isEmpty ? Array(report.rows.prefix(5)) : report.gatedRows
        nAttacks = report.nAttacks
        nBaselines = report.nBaselines
        season = report.seasonHint
        rows = source.map {
            NarratorRow(bin: $0.bin, level: $0.level, attacksWith: $0.attacksWith, baselinesWith: $0.baselinesWith,
                        attackRate: $0.attackRate, baselineRate: $0.baselineRate,
                        lift: $0.lift.isFinite ? $0.lift : 99, gated: $0.gated)
        }
        rules = Narrator.rules
        self.styleScore = max(0, min(100, styleScore))
    }
}

public struct NarratorOutput: Sendable, Equatable {
    public enum Source: String, Sendable {
        case template
        case onDevice
    }

    public var headline: String
    public var caveat: String
    public var drivers: [String]
    public var source: Source
    public var note: String?

    public init(headline: String, caveat: String, drivers: [String], source: Source, note: String? = nil) {
        self.headline = headline
        self.caveat = caveat
        self.drivers = drivers
        self.source = source
        self.note = note
    }
}

public enum Narrator {
    public static let rules = [
        "Do not claim causation or predict an attack.",
        "Always mention the counts for the top driver when gated rows exist.",
        "If no gated rows, say we need more usual days or more inhaler logs.",
        "Outdoor air only — not indoor, not a diagnosis.",
    ]

    public static let caveat =
        "Outdoor air only — not a medical diagnosis. Comparison to your usual logged days, not a prediction."

    /// Fixed factual sentence; always available. Ignores style.
    public static func template(_ input: NarratorInput) -> NarratorOutput {
        let gated = input.rows.filter(\.gated)
        guard let top = gated.first else {
            let headline = input.nBaselines < 12
                ? "You have \(input.nAttacks) attack logs and \(input.nBaselines) usual-day samples. Keep logging quiet days so we can compare."
                : "Nothing clears the sample gate yet (\(input.nAttacks) attacks, \(input.nBaselines) usual days). Patterns need more repeats."
            return NarratorOutput(headline: headline, caveat: caveat, drivers: [], source: .template)
        }
        var headline = "\(Bins.label(top.bin)) (\(top.level)) showed up on \(top.attacksWith) of \(input.nAttacks) attacks vs \(top.baselinesWith) of \(input.nBaselines) usual days (~\(Lift.format(top.lift))×)."
        if gated.count > 1 {
            let second = gated[1]
            headline += " Next: \(Bins.label(second.bin)) (\(second.level))."
        }
        if let season = input.season {
            headline += " Season context: \(season)."
        }
        return NarratorOutput(headline: headline, caveat: caveat, drivers: gated.prefix(3).map(\.id), source: .template)
    }

    /// Instructions + prompt for an on-device model using guided generation (no JSON parsing needed).
    public static func prompt(_ input: NarratorInput) -> (instructions: String, prompt: String) {
        let style = NarratorStyle(score: input.styleScore)
        let example = (input.rows.first(where: \.gated) ?? input.rows.first).map {
            NarratorStyle.ExampleFacts(binLabel: Bins.label($0.bin), level: $0.level, attacksWith: $0.attacksWith,
                                       nAttacks: input.nAttacks, baselinesWith: $0.baselinesWith,
                                       nBaselines: input.nBaselines, liftLabel: Lift.format($0.lift))
        }
        let instructions = ([
            "You write one honest insight for an asthma inhaler diary.",
            "You are given a precomputed table comparing inhaler days to usual days. Do not invent counts or new drivers.",
            "Fill headline (the insight), caveat (one short honest limit), drivers (ids like \"ozone:high\" copied from the table).",
            "",
            style.promptBlock(example: example),
            "",
            "Rules:",
        ] + input.rules.map { "- \($0)" }).joined(separator: "\n")

        struct Table: Encodable {
            let nAttacks: Int, nBaselines: Int, season: String?, rows: [NarratorRow]
        }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let json = (try? enc.encode(Table(nAttacks: input.nAttacks, nBaselines: input.nBaselines,
                                          season: input.season, rows: input.rows)))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return (instructions, "styleBand=\(style.rawValue)\n\nTable JSON:\n\(json)")
    }
}

/// Checks model output before it reaches the screen. Failure → template.
public enum NarrationGuard {
    public enum Problem: Equatable, Sendable {
        case empty
        case bannedPhrase(String)
        case unknownNumber(String)
    }

    static let banned: [String] = [
        #"\bwill (have|get|trigger)\b"#,
        #"\byou'?ll have\b"#,
        #"\bgoing to have\b"#,
        #"%"#,
        #"\bpercent\b"#,
        #"\bcaus(e|es|ed|ing)\b"#,
        #"\bdiagnos(is|e|ed)\b(?! *—)"#,
        #"\blungs? (know|remember|warn|whisper)"#,
    ]

    /// Numbers that may appear: counts, totals, formatted lifts.
    static func allowedNumbers(_ input: NarratorInput) -> Set<String> {
        var s: Set<String> = [String(input.nAttacks), String(input.nBaselines)]
        for r in input.rows {
            s.insert(String(r.attacksWith))
            s.insert(String(r.baselinesWith))
            let f = Lift.format(r.lift)
            s.insert(f)
            s.insert(String(Int(r.lift.rounded())))
            if f.hasSuffix(".0") { s.insert(String(f.dropLast(2))) }
        }
        return s
    }

    public static func problems(headline: String, input: NarratorInput) -> [Problem] {
        let text = headline.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [.empty] }
        var out: [Problem] = []
        for pattern in banned where text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
            out.append(.bannedPhrase(pattern))
        }
        let scrubbed = text.replacingOccurrences(of: "PM2.5", with: "PM", options: .caseInsensitive)
        let allowed = allowedNumbers(input)
        let regex = try! NSRegularExpression(pattern: #"\d+(\.\d+)?"#)
        let ns = scrubbed as NSString
        for m in regex.matches(in: scrubbed, range: NSRange(location: 0, length: ns.length)) {
            let n = ns.substring(with: m.range)
            if !allowed.contains(n) { out.append(.unknownNumber(n)) }
        }
        return out
    }

    /// Validated model output, or the template with a note on why.
    public static func accept(headline: String, caveat: String, drivers: [String], input: NarratorInput) -> NarratorOutput {
        let issues = problems(headline: headline, input: input)
        guard issues.isEmpty else {
            var t = Narrator.template(input)
            t.note = "Model output rejected: \(issues)"
            return t
        }
        let known = Set(input.rows.map(\.id))
        let cleanCaveat = problems(headline: caveat, input: input).isEmpty && !caveat.isEmpty ? caveat : Narrator.caveat
        return NarratorOutput(headline: headline.trimmingCharacters(in: .whitespacesAndNewlines), caveat: cleanCaveat,
                              drivers: drivers.filter(known.contains), source: .onDevice)
    }
}
