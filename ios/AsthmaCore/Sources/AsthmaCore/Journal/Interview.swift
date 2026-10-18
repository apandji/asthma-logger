import Foundation

/// The questions a note asks, and in what order. A short structured interview, not a conversation: the
/// questions are a fixed set, picked by what hasn't been answered yet, and it ends after a few. Grounded in
/// docs/design/journaling-clinical.md:
/// - the control domains a US provider asks about (NAEPP EPR-3 Fig 3-5c; GINA 2024 Box 2-2): symptoms, night
///   waking, activity limitation, reliever use;
/// - NICE NG245 evidence review L: focused questions beat "how have you been?";
/// - ecological momentary assessment (Shiffman 2008): ask about this moment, not the past month.
/// Past tense throughout: a note is often added hours later.
/// Both capture styles use it: chat asks one at a time; the classic journal shows them as sections.
public enum Interview {
    public enum Question: String, Sendable, CaseIterable, Identifiable {
        case doing, place, symptoms, exposure, activity, night, reliever, around, anythingElse
        public var id: String { rawValue }

        public var text: String {
            switch self {
            case .doing: "What were you doing?"
            case .place: "Where were you?"
            case .symptoms: "Did you experience any of the following symptoms?"
            case .exposure: "Were you outside?"
            case .activity: "Did it keep you from doing something?"
            case .night: "Did it wake you up?"
            // How many puffs is counted where it was logged (the panel); this asks how the reliever worked.
            case .reliever: "Did the puff help?"
            case .around: "What was around you?"
            case .anythingElse: "Anything else?"
            }
        }

        /// The question as asked about this moment. We know where you were, so "Where were you?" would sound
        /// like we don't: it names the place and time instead ("What can you tell me about University City at
        /// 4:52 PM?"). Without a place it falls back to the plain question.
        /// The exposure question states what was elevated first ("Tree pollen was high around then. …").
        public func text(place: String?, time: String?, elevated: Elevated? = nil) -> String {
            if self == .exposure, let elevated { return elevated.question }
            guard self == .place, let place, !place.isEmpty else { return text }
            return "What can you tell me about \(place)" + (time.map { " at \($0)" } ?? "") + "?"
        }

        /// The tag a plain "yes" means, for the yes/no questions.
        public var yesTag: JournalTag? {
            switch self {
            case .activity: .activityLimited
            case .night: .wokeAtNight
            case .reliever: .betterAfter
            default: nil
            }
        }

        public var isYesNo: Bool { yesTag != nil }
    }

    /// A tappable answer: a tag, a plain yes / no, or "none of these".
    public enum Reply: Hashable, Sendable {
        case tag(JournalTag)
        case yes
        case no
        case none

        public var label: String {
            switch self {
            case .tag(let t): t.label
            case .yes: "Yes"
            case .no: "No"
            case .none: "None of these"
            }
        }
    }

    /// Where the moment stands, for picking the next question.
    public struct Context: Sendable, Equatable {
        public var asked: [Question]
        /// Confirmed or heard so far (symptoms, outcomes and triggers).
        public var tags: Set<JournalTag>
        /// Everything said so far, for the domains tags don't cover (doing, place).
        public var words: String
        /// The moment's hour (0–23), for the night question.
        public var hour: Int
        /// Puffs on the moment, for the reliever question.
        public var puffs: Int
        /// A rescue moment (symptom questions only make sense there).
        public var isRescue: Bool

        /// What was elevated in the outdoor air at the moment, most notable first (`Elevated`).
        public var elevated: [Elevated]

        public init(asked: [Question] = [], tags: Set<JournalTag> = [], words: String = "", hour: Int, puffs: Int, isRescue: Bool,
                    elevated: [Elevated] = []) {
            self.asked = asked; self.tags = tags; self.words = words; self.hour = hour; self.puffs = puffs; self.isRescue = isRescue
            self.elevated = elevated
        }
    }

    /// Something in the outdoor air at the moment that clinical guidance says to ask about. Thresholds are the
    /// guidance's own, not ours: pollutants at the EPA's "Unhealthy for Sensitive Groups" (AQI 101+, PM2.5 over
    /// 35.4 µg/m³, ozone over 70 ppb: people with asthma should cut back on outdoor exertion), pollen at
    /// "high" (Ambee's risk bands), cold air (a common bronchoconstriction trigger, NAEPP EPR-3, below 40 °F),
    /// heat (the National Weather Service's heat advisory range, 90 °F and up).
    /// The question states the fact, then asks about exposure. Never a cause: "Tree pollen was high around
    /// then. Were you outside?", not "Tree pollen set this off".
    public enum Elevated: String, Sendable, CaseIterable {
        case particles, ozone, treePollen, grassPollen, weedPollen, cold, heat

        /// The fact, then the exposure question.
        public var question: String {
            switch self {
            case .particles: "Fine particles were high around then. Were you outside?"
            case .ozone: "Ozone was high around then. Were you active outdoors?"
            case .treePollen: "Tree pollen was high around then. Were you outside?"
            case .grassPollen: "Grass pollen was high around then. Were you outside?"
            case .weedPollen: "Weed pollen was high around then. Were you outside?"
            case .cold: "It was cold out. Were you breathing cold air?"
            case .heat: "It was hot out. Were you active outdoors?"
            }
        }

        /// What a "yes" says: a trigger to tick, and whether you were outdoors (it corrects the indoor guess).
        public var yes: (tag: JournalTag?, outdoors: Bool) {
            switch self {
            case .cold: (.coldAir, true)
            case .ozone, .heat: (.exercise, true)
            case .particles, .treePollen, .grassPollen, .weedPollen: (nil, true)
            }
        }

        /// A "no" to "were you outside?" says indoors; to the cold or activity questions it says nothing more.
        public var noMeansIndoors: Bool {
            switch self {
            case .particles, .treePollen, .grassPollen, .weedPollen: true
            case .ozone, .heat, .cold: false
            }
        }
    }

    /// At most this many questions before "Anything else?".
    public static let limit = 4

    /// The opening question. Rotates per moment so the same person doesn't always start the same way; a
    /// rescue opens on what was going on or how it felt, a note on what was going on or where.
    public static func first(seed: Int, isRescue: Bool) -> Question {
        let pool: [Question] = isRescue ? [.doing, .symptoms, .around] : [.doing, .place, .around]
        return pool[abs(seed) % pool.count]
    }

    /// The next question, or nil when the interview is done. Follow-ups go in the providers' order
    /// (symptoms, activity, night, reliever), then context (doing, place, around), skipping anything the
    /// answers already covered and anything that doesn't apply to this moment.
    public static func next(_ c: Context) -> Question? {
        if c.asked.contains(.anythingElse) { return nil }
        if c.asked.filter({ $0 != .anythingElse }).count >= limit { return .anythingElse }
        let order: [Question] = c.isRescue
            ? [.symptoms, .exposure, .activity, .night, .reliever, .doing, .place, .around]
            : [.doing, .place, .around, .symptoms]
        for q in order where !c.asked.contains(q) && applies(q, c) && !covered(q, c) {
            return q
        }
        return .anythingElse
    }

    /// The replies offered for a question, the big tappable chips.
    public static func replies(_ q: Question) -> [Reply] {
        switch q {
        case .symptoms: [.tag(.wheezing), .tag(.coughing), .tag(.chestTightness), .tag(.shortOfBreath), .none]
        case .activity, .night, .exposure: [.yes, .no]
        case .reliever: [.yes, .no]
        case .doing: [.tag(.exercise), .tag(.cooking), .tag(.cleaningProducts), .tag(.stress), .tag(.laughingOrCrying)]
        case .place: []
        case .around: [.tag(.pets), .tag(.smoke), .tag(.dust), .tag(.mold), .tag(.coldAir), .tag(.strongScents)]
        case .anythingElse: [.tag(.coldOrFlu), .tag(.urgentVisit), .tag(.oralSteroids), .none]
        }
    }

    /// Reads a spoken or typed answer to a yes/no question. Nil when it's neither ("it was fine, I think").
    public static func yesNo(_ text: String) -> Bool? {
        let w = text.lowercased().split { !$0.isLetter && $0 != "'" }.map(String.init)
        guard let first = w.first else { return nil }
        let yes: Set<String> = ["yes", "yeah", "yep", "yup", "it", "definitely", "sure", "kind", "sort", "a"]
        let no: Set<String> = ["no", "nope", "nah", "not", "didn't", "didnt", "never"]
        if no.contains(first) { return false }
        if ["yes", "yeah", "yep", "yup", "definitely", "sure"].contains(first) { return true }
        if yes.contains(first), w.contains(where: { ["did", "yes", "yeah", "lot", "bit", "little"].contains($0) }) { return true }
        return nil
    }

    // MARK: -

    static func applies(_ q: Question, _ c: Context) -> Bool {
        switch q {
        case .night: c.isRescue && (c.hour >= 22 || c.hour < 7)
        case .exposure: c.isRescue && !c.elevated.isEmpty
        case .reliever: c.isRescue
        case .symptoms, .activity: c.isRescue
        default: true
        }
    }

    static func covered(_ q: Question, _ c: Context) -> Bool {
        let w = " " + c.words.lowercased() + " "
        switch q {
        case .symptoms: return c.tags.contains { $0.kind == .symptom && $0 != .wokeAtNight && $0 != .activityLimited }
        case .activity: return c.tags.contains(.activityLimited)
        case .night: return c.tags.contains(.wokeAtNight)
        case .reliever: return c.tags.contains(.betterAfter)
        case .doing:
            return c.tags.contains { [.exercise, .cooking, .cleaningProducts, .laughingOrCrying].contains($0) }
                || doingWords.contains { w.contains($0) }
        case .place: return placeWords.contains { w.contains($0) }
        case .exposure:
            if c.elevated.first == .cold, c.tags.contains(.coldAir) { return true }
            return [" outside", " outdoors", " inside", " indoors"].contains { w.contains($0) }
        case .around: return c.tags.contains { $0.kind == .trigger && ![.exercise, .stress, .laughingOrCrying].contains($0) }
        case .anythingElse: return false
        }
    }

    static let doingWords = [" walk", " ran ", " running", " work", " sleep", " slept", " play", " drive", " driving",
                             " class", " school", " shopping", " eating", " sitting", " lying", " watching"]
    static let placeWords = [" at home", " at work", " outside", " inside", " indoors", " outdoors", " park",
                             " in the car", " office", " school", " kitchen", " bedroom", " in bed", " gym", " store"]
}
