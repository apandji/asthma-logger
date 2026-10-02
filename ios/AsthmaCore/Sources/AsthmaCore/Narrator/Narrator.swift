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
                ? "You've used your inhaler \(input.nAttacks) times and logged \(input.nBaselines) usual moments. Keep logging usual days so there's something to compare."
                : "Nothing stands out yet (\(input.nAttacks) inhaler uses, \(input.nBaselines) usual days). Patterns need more repeats."
            return NarratorOutput(headline: headline, caveat: caveat, drivers: [], source: .template)
        }
        // Plain counts, no ratio: "8 of the 10 times you used your inhaler, ozone was high. …"
        var headline = "\(top.attacksWith) of the \(input.nAttacks) times you used your inhaler, \(clause(top.bin, top.level))."
        headline += top.baselinesWith == 0
            ? " On usual days, that never happened (0 of \(input.nBaselines))."
            : " On usual days, that only happened \(top.baselinesWith) of \(input.nBaselines) times."
        if gated.count > 1 {
            headline += " Also common: \(clause(gated[1].bin, gated[1].level))."
        }
        if let season = input.season {
            headline += " Most of these logs are from \(season)."
        }
        return NarratorOutput(headline: headline, caveat: caveat, drivers: gated.prefix(3).map(\.id), source: .template)
    }

    /// One bin level as a plain clause, e.g. "ozone was high", "it was evening".
    /// v1 bins mirror `conditionClause` in web/src/lib/insights/summarize.ts; v2 bins are iOS only.
    public static func clause(_ bin: String, _ level: String) -> String {
        switch bin {
        case "pm25": return "PM2.5 was \(level)"
        case "ozone": return "ozone was \(level)"
        case "pollen_weed": return level == "none" ? "there was no weed pollen" : "weed pollen was \(level)"
        case "temp": return "it was \(level) out"
        case "humidity": return level == "ok" ? "humidity was normal" : "it was \(level)"
        case "smoke_at_point": return level == "yes" ? "there were signs of smoke in the air" : "there were no signs of smoke in the air"
        case "heat_alert": return level == "yes" ? "there was a heat alert" : "there was no heat alert"
        case "hour": return "it was \(level)"
        case "place":
            switch level {
            case "home": return "you were at home"
            case "work": return "you were at work"
            case "frequent": return "you were at one of your usual places"
            default: return "you were somewhere else"
            }
        case "indoor_outdoor": return "you were likely \(level)s"  // often a guess, never stated as fact
        default:
            if bin.hasPrefix("tag_") {
                let tag = Bins.label(bin).lowercased()
                return level == "yes" ? "you noted \(tag)" : "you didn't note \(tag)"
            }
            return "\(Bins.label(bin).lowercased()) was \(level)"
        }
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
