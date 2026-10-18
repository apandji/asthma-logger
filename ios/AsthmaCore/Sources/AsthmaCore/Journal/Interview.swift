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
        case doing, place, symptoms, activity, night, reliever, around, anythingElse
        public var id: String { rawValue }

        public var text: String {
            switch self {
            case .doing: "What were you doing?"
            case .place: "Where were you?"
            case .symptoms: "How did your breathing feel?"
            case .activity: "Did it keep you from doing something?"
            case .night: "Did it wake you up?"
            // How many puffs is counted where it was logged (the panel); this asks how the reliever worked.
            case .reliever: "Did the puff help?"
            case .around: "What was around you?"
            case .anythingElse: "Anything else?"
            }
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

        public init(asked: [Question] = [], tags: Set<JournalTag> = [], words: String = "", hour: Int, puffs: Int, isRescue: Bool) {
            self.asked = asked; self.tags = tags; self.words = words; self.hour = hour; self.puffs = puffs; self.isRescue = isRescue
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
            ? [.symptoms, .activity, .night, .reliever, .doing, .place, .around]
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
        case .activity, .night: [.yes, .no]
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
        case .around: return c.tags.contains { $0.kind == .trigger && ![.exercise, .stress, .laughingOrCrying].contains($0) }
        case .anythingElse: return false
        }
    }

    static let doingWords = [" walk", " ran ", " running", " work", " sleep", " slept", " play", " drive", " driving",
                             " class", " school", " shopping", " eating", " sitting", " lying", " watching"]
    static let placeWords = [" at home", " at work", " outside", " inside", " indoors", " outdoors", " park",
                             " in the car", " office", " school", " kitchen", " bedroom", " in bed", " gym", " store"]
}
