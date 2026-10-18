import Foundation

/// The read: the one sentence under the context line, at every time on the timeline (docs/design/header-ia.md).
/// It says why this moment matters to *you*, never a weather readout (the sky and the Weather details have the
/// numbers). Facts and raw counts only: no causes, no odds.
public enum TheRead {
    public enum Time: Sendable, Equatable {
        case now
        /// "Thursday afternoon".
        case ahead(String)
        case back
    }

    /// About you, not the air: when and where you used your inhaler. These belong in Insights ("You used your
    /// inhaler most in the evening"), never in the read on Now or Ahead.
    public static let personalBins: Set<String> = ["hour", "season", "place", "indoor_outdoor"]

    /// Gated rows about the air whose level this frame has, biggest flare-vs-baseline gap first.
    public static func shared(_ frame: FeatureFrame, rows: [LiftRow]) -> [LiftRow] {
        Bins.all.compactMap { def -> LiftRow? in
            guard !personalBins.contains(def.bin), let level = def.levelOf(frame) else { return nil }
            return rows.first { $0.bin == def.bin && $0.level == level && $0.gated && $0.attackRate > $0.baselineRate }
        }
        .sorted { ($0.attackRate - $0.baselineRate) > ($1.attackRate - $1.baselineRate) }
    }

    /// "High weed pollen", "A sharp temperature drop", "Exercise".
    public static func noun(_ bin: String, _ level: String) -> String {
        switch (bin, level) {
        case ("pm25", "high"): "High fine particles"
        case ("pm25", "moderate"): "Raised fine particles"
        case ("ozone", "high"): "High ozone"
        case ("ozone", "moderate"): "Raised ozone"
        case ("pollen_weed", "high"): "High weed pollen"
        case ("pollen_weed", "moderate"): "Raised weed pollen"
        case ("temp", "hot"): "Heat"
        case ("temp", "cold"): "Cold"
        case ("temp", "mild"): "Mild weather"
        case ("humidity", "humid"): "Humid air"
        case ("humidity", "dry"): "Dry air"
        case ("smoke_at_point", "yes"): "Smoke-like air"
        case ("heat_alert", "yes"): "A heat alert"
        case ("temp_drop", "yes"): "A sharp temperature drop"
        case ("hour", let part): "The \(part)"
        case ("indoor_outdoor", let io): io == "indoor" ? "Being indoors" : "Being outdoors"
        case (let b, _) where b.hasPrefix("tag_"): Bins.label(b)
        case (let b, let l): "\(Bins.label(b)) \(l)"
        }
    }

    /// "High weed pollen often shows up on your flare days." In words, never counts: you're not a number
    /// (owner, Oct 17). The only numbers on screen are readings, when you hold the sky.
    /// `past`, for a logged moment: "High weed pollen was there. It often shows up on your flare days."
    public static func pattern(_ r: LiftRow, past: Bool = false) -> String {
        let often = AirProfile.Strength.of(r) == .strong ? "often" : "sometimes"
        let thing = noun(r.bin, r.level)
        return past ? "\(thing) was there. It \(often) shows up on your flare days."
                    : "\(thing) \(often) shows up on your flare days."
    }

    /// The event as a fact, in the time's tense, without the temperature lead.
    /// `fires`: active wildfires nearby (Ambee), for the smoke line from the board: "There are two active
    /// wildfires 50 miles north. Heavy smoke is drifting into your area."
    public static func eventFact(_ e: AirAdvice.Event, time: Time, fallF: Double?, fires: WildfiresNearby? = nil) -> String {
        let drop = fallF.map { "\(Int($0.rounded()))°" }
        switch (e, time) {
        case (.tempDrop, .ahead(let when)): return "\(when): a sharp temperature drop on the way."
        case (.tempDrop, _): return drop.map { "A sharp cold drop: \($0) in three hours." } ?? "A sharp cold drop."
        case (.smoke, .ahead(let when)): return "\(when): wildfire smoke in the forecast."
        case (.smoke, .back): return "Wildfire smoke was in the air."
        case (.smoke, _): return [fires?.sentence, "Heavy smoke is drifting into your area."].compactMap { $0 }.joined(separator: " ")
        case (.stormPollen, .ahead(let when)): return "\(when): a thunderstorm while pollen is high."
        case (.stormPollen, _): return "A thunderstorm while pollen is high."
        case (.mold, .ahead(let when)): return "\(when): rainy, humid and warm."
        case (.mold, _): return "Rainy, humid and warm: the kind of day mold grows."
        }
    }

    /// The sentence for Now or Ahead.
    /// - `shared`: from `shared(_:rows:)` (empty before felt air has learned).
    /// - `notable`: what's at a high level, as present-tense clauses ("weed pollen is high"), for before it has learned.
    /// - `verdict`: Ahead only, the look-ahead's call (looks like flare days, or not).
    public static func sentence(time: Time, learned: Bool, event: AirAdvice.Event?, fallF: Double?, fires: WildfiresNearby? = nil,
                                shared: [LiftRow], notable: [String], looksLikeFlare: Bool = false) -> String {
        var parts: [String] = []
        if let event { parts.append(eventFact(event, time: time, fallF: fallF, fires: fires)) }
        switch time {
        case .back:
            break
        case .now:
            if learned, let top = shared.first {
                parts.append(pattern(top))
            } else if parts.isEmpty, let n = notable.first {
                parts.append(n.prefix(1).uppercased() + n.dropFirst() + ".")
            } else if parts.isEmpty {
                parts.append(learned ? "Nothing here stands out against your flare days." : "Nothing in the air stands out right now.")
            }
        case .ahead(let when):
            if learned, looksLikeFlare, let top = shared.first {
                parts.append(event == nil ? "\(when) looks more like your flare days: \(noun(top.bin, top.level).lowercased())."
                                          : pattern(top))
            } else if learned, event == nil {
                parts.append("\(when) looks like your baseline days.")
            } else if event == nil, let n = notable.first {
                parts.append("\(when): \(n).")
            } else if event == nil {
                parts.append("\(when): nothing in the forecast stands out.")
            }
        }
        return parts.joined(separator: " ")
    }

    /// For Insights: "You tend to use your inhaler in the evening." Gated rows only, no counts.
    public static func personal(_ rows: [LiftRow]) -> [String] {
        rows.filter { $0.gated && personalBins.contains($0.bin) && $0.attackRate > $0.baselineRate }
            .sorted { ($0.attackRate - $0.baselineRate) > ($1.attackRate - $1.baselineRate) }
            .map { r in
                let when: String = switch r.bin {
                case "hour": "in the \(r.level)"
                case "season": "in \(r.level)"
                case "indoor_outdoor": r.level == "indoor" ? "indoors" : "outdoors"
                default: "at \(r.level)"
                }
                return "You tend to use your inhaler \(when)."
            }
    }

    /// When there's no air reading. Never "nothing stands out": that would imply we looked and saw clean air.
    /// `reason`: why, when known ("Logged on Apple Watch while your iPhone was away, so there's no air reading.").
    public static func noReading(_ time: Time, checking: Bool = false, reason: String? = nil) -> String {
        if checking { return time == .now ? "Checking the air near you…" : "Checking the air for this moment…" }
        switch time {
        case .now: return "Couldn't read the air here just now. Logging still works."
        case .back: return reason ?? "No air reading for this moment."
        case .ahead(let when): return "\(when): no forecast for here yet."
        }
    }

    /// A Note (something said, no inhaler): its own words lead, else its tags.
    public static func note(_ words: String?, tags: [JournalTag] = []) -> String {
        let w = (words ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !w.isEmpty else {
            return tags.isEmpty ? "A note, nothing said." : "A note: " + tags.map { $0.label.lowercased() }.joined(separator: ", ") + "."
        }
        let short = w.count > 90 ? String(w.prefix(87)) + "…" : w
        return "You noted: “\(short)”"
    }

    /// A Standard moment: it's routine, and it isn't part of the comparison.
    public static let standard = "Your daily inhaler. It doesn't count toward patterns."

    /// Just logged, on Now.
    public static func justLogged(_ kind: String) -> String { "\(kind) logged. What's going on?" }
}
