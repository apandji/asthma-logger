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

    /// "Shows up on your flare days", as a mark instead of words (owner, Oct 17): the sentence states the fact
    /// and ends with felt air's sparkle, two for often, one for sometimes. The view draws the mark; `spoken(_:)`
    /// turns it back into words for VoiceOver and notifications. Private-use characters, so they never clash.
    public enum Mark: String, CaseIterable, Sendable {
        case often = "\u{E000}"
        case sometimes = "\u{E001}"

        public static func of(_ r: LiftRow) -> Mark { AirProfile.Strength.of(r) == .strong ? .often : .sometimes }

        /// The words the mark stands for.
        public var words: String {
            switch self {
            case .often: "It often shows up on your flare days."
            case .sometimes: "It sometimes shows up on your flare days."
            }
        }
    }

    /// A pattern as a plain fact in the time's tense, then the mark: "Weed pollen was high." Words, never
    /// counts (owner, Oct 17). Each factor has its own natural sentence (copy pass, Oct 18): the old
    /// "<Thing> was there." made "Heat was there." and "High ozone was there."
    public static func pattern(_ r: LiftRow, past: Bool = false) -> String {
        marked(bin: r.bin, level: r.level, time: past ? .back : .now, mark: .of(r))
    }

    public static func marked(bin: String, level: String, time: Time, mark: Mark) -> String {
        fact(bin, level, time: time) + "\u{00A0}" + mark.rawValue   // non-breaking: the mark never wraps alone
    }

    /// "Weed pollen was high." / "Weed pollen is high." / ahead, the clause after "Thursday afternoon: ",
    /// "weed pollen looks high." Ahead is a forecast, so it "looks": never "will".
    public static func fact(_ bin: String, _ level: String, time: Time) -> String {
        let p = phrasing(bin, level)
        switch time {
        case .back: return p.back
        case .now: return p.now
        case .ahead: return p.ahead + "."
        }
    }

    private static func phrasing(_ bin: String, _ level: String) -> (back: String, now: String, ahead: String) {
        // Things measured in amounts: "X was high", "X was up a little".
        func amount(_ name: String, plural: Bool = false) -> (String, String, String)? {
            let (was, iz, look) = plural ? ("were", "are", "look") : ("was", "is", "looks")
            let cap = name.prefix(1).uppercased() + name.dropFirst()
            switch level {
            case "high": return ("\(cap) \(was) high.", "\(cap) \(iz) high.", "\(name) \(look) high")
            case "moderate": return ("\(cap) \(was) up a little.", "\(cap) \(iz) up a little.", "\(name) \(look) a little high")
            default: return nil
            }
        }
        if bin == "pm25", let a = amount("fine particles", plural: true) { return a }
        if bin == "ozone", let a = amount("ozone") { return a }
        if bin.hasPrefix("pollen_"), let a = amount("\(bin.dropFirst("pollen_".count)) pollen") { return a }
        switch (bin, level) {
        case ("temp", let t) where ["hot", "cold", "mild"].contains(t): return ("It was \(t).", "It's \(t).", "it looks \(t)")
        case ("humidity", "humid"): return ("It was humid.", "It's humid.", "it looks humid")
        case ("humidity", "dry"): return ("The air was dry.", "The air is dry.", "the air looks dry")
        case ("smoke_at_point", "yes"): return ("The air was smoky.", "The air is smoky.", "the air looks smoky")
        case ("heat_alert", "yes"): return ("A heat alert was on.", "A heat alert is on.", "a heat alert is out")
        case ("temp_drop", "yes"):
            return ("The temperature had dropped fast.", "The temperature is dropping fast.", "a sharp temperature drop is on the way")
        case (let b, _) where b.hasPrefix("tag_"):
            let l = Bins.label(b).lowercased()
            return ("You mentioned \(l).", "You mentioned \(l).", l)
        default:
            let l = Bins.label(bin)
            return ("\(l) was \(level).", "\(l) is \(level).", "\(l.lowercased()) looks \(level)")
        }
    }

    /// Every (bin, level) the read can mark, for reading a factor back out of a sentence.
    private static var markable: [(String, String)] {
        var out: [(String, String)] = []
        for b in ["pm25", "ozone", "pollen_weed", "pollen_tree", "pollen_grass"] { out += [(b, "high"), (b, "moderate")] }
        out += [("temp", "hot"), ("temp", "cold"), ("temp", "mild"), ("humidity", "humid"), ("humidity", "dry"),
                ("smoke_at_point", "yes"), ("heat_alert", "yes"), ("temp_drop", "yes")]
        out += JournalTag.allCases.map { ("tag_\($0.rawValue)", "yes") }
        return out
    }

    /// The thing the mark is about, read back out of a marked sentence ("Weed pollen was high. ✦" →
    /// "High weed pollen"), so the key can say "High weed pollen shows up often on your flare days", the
    /// same words as Insights. Nil when the sentence isn't one of ours.
    public static func factor(in sentence: String) -> String? {
        let marks = Mark.allCases.map(\.rawValue)
        guard let range = marks.lazy.compactMap({ sentence.range(of: $0) }).min(by: { $0.lowerBound < $1.lowerBound }) else { return nil }
        let s = String(sentence[..<range.lowerBound]).replacingOccurrences(of: "\u{00A0}", with: "").trimmingCharacters(in: .whitespaces)
        if s.contains("temperature had fallen") || s.contains("temperature has fallen") { return noun("temp_drop", "yes") }
        for (b, l) in markable {
            let p = phrasing(b, l)
            if s.hasSuffix(p.back) || s.hasSuffix(p.now) || s.hasSuffix(p.ahead + ".") { return noun(b, l) }
        }
        return nil
    }

    /// The sentence with each mark said in words: for VoiceOver, notifications and anything without the sparkle.
    public static func spoken(_ s: String) -> String {
        Mark.allCases.reduce(s) { $0.replacingOccurrences(of: "\u{00A0}" + $1.rawValue, with: " " + $1.words) }
    }

    /// The event as a fact, in the time's tense, without the temperature lead.
    /// `fires`: active wildfires nearby (Ambee), for the smoke line from the board: "There are two active
    /// wildfires 50 miles north. Heavy smoke is drifting into your area."
    public static func eventFact(_ e: AirAdvice.Event, time: Time, fallF: Double?, fires: WildfiresNearby? = nil) -> String {
        let drop = fallF.map { "\(Int($0.rounded()))°" }
        switch (e, time) {
        case (.tempDrop, .ahead(let when)): return "\(when): a sharp temperature drop on the way."
        case (.tempDrop, .back): return drop.map { "The temperature had fallen \($0) in three hours." } ?? "The temperature had dropped fast."
        case (.tempDrop, _): return drop.map { "The temperature has fallen \($0) in three hours." } ?? "The temperature is dropping fast."
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
    /// - `looksLikeFlare`: unused since the verdict moved to the pill alone (kept so callers needn't change).
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
                // The verdict pill says how it compares; the sentence never repeats it (owner, Oct 17).
                parts.append("Nothing in the air stands out right now.")
            }
        case .ahead(let when):
            // What's in the forecast, never the verdict: the pill alone says how it compares (owner, Oct 17), so
            // the two can't disagree. A factor that shows up on your flare days carries the sparkle.
            if learned, let top = shared.first {
                let clause = fact(top.bin, top.level, time: time)
                parts.append(event == nil ? "\(when): \(clause)\u{00A0}\(Mark.of(top).rawValue)"
                                          : (clause.prefix(1).uppercased() + clause.dropFirst()) + "\u{00A0}" + Mark.of(top).rawValue)
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
