import Foundation

// Voice note → suggested tags → the user confirms → only confirmed tags become bins.
//
//   transcript ──► KeywordTagger (deterministic, always runs) ─┐
//              └─► TagProposer (on-device model, optional) ──► TagVocabulary.validate ─┤
//                                                                                     ▼
//                                                     VoiceNoteTagger.combine → [TagSuggestion]
//                                                                                     ▼
//                                                      TagReview (confirm / reject / add / finish)
//                                                                                     ▼
//                                     FeatureFrame.tags (confirmed only) + tagsReviewed → tag_* bins
//
// The transcript stops here. The narrator only ever sees the lift table (`NarratorInput(report:)`).

// MARK: - Suggestions

/// A tag the app thinks the note mentions. Not data: nothing reaches a bin until `TagReview` confirms it.
public struct TagSuggestion: Codable, Sendable, Equatable, Identifiable {
    public enum Source: String, Codable, Sendable {
        /// Matched a phrase rule in `KeywordTagger`.
        case keyword
        /// Proposed by the on-device model and validated against the closed list.
        case model
        /// Both agreed.
        case keywordAndModel
        /// The user picked it from the list themselves.
        case user
    }

    public var tag: JournalTag
    public var source: Source
    /// The words in the note that matched a phrase rule, e.g. "the cat" → "cat". Shown on the chip only.
    public var evidence: String?

    public var id: JournalTag { tag }

    public init(tag: JournalTag, source: Source, evidence: String? = nil) {
        self.tag = tag
        self.source = source
        self.evidence = evidence
    }
}

// MARK: - Keyword rules

/// Deterministic phrase rules with simple negation. Runs with or without the model, and its negations
/// veto the model ("no smoke today" never suggests smoke).
public enum KeywordTagger {
    public struct Mention: Sendable, Equatable {
        public var tag: JournalTag
        public var phrase: String
        public var negated: Bool
    }

    public struct Scan: Sendable, Equatable {
        public var mentions: [Mention]
        /// Tags with at least one mention that isn't negated, in list order.
        public var tags: [JournalTag]
        /// Tags mentioned only in negated form ("no smoke", "didn't go to the gym", "pet-free").
        public var ruledOut: [JournalTag]
    }

    /// Lower-case phrases per tag, matched on whole words. Bare "cold" is left out on purpose: it is
    /// either the weather or an illness, and a wrong chip costs more than a missed one.
    public static let phrases: [JournalTag: [String]] = [
        .exercise: ["run", "running", "jog", "jogging", "jogged", "gym", "workout", "worked out",
                    "working out", "exercise", "exercised", "exercising", "soccer", "basketball", "football",
                    "tennis", "stairs", "hike", "hiking", "hiked", "bike ride", "biking", "cycling", "sprint",
                    "sprinted", "sprinting", "climbing", "lifting weights"],
        .coldAir: ["cold air", "cold wind", "cold outside", "cold out", "cold morning", "cold night",
                   "freezing", "frigid", "icy", "chilly", "frosty", "below zero", "winter air"],
        .smoke: ["smoke", "smoky", "smokey", "smoking", "smoker", "cigarette", "cigarettes", "cigar", "vape",
                 "vaping", "campfire", "bonfire", "fireplace", "fire pit", "wood stove", "wildfire",
                 "wildfires", "barbecue", "bbq"],
        .pets: ["cat", "cats", "kitten", "kittens", "dog", "dogs", "puppy", "puppies", "pet", "pets",
                "horse", "horses", "dander", "hamster", "rabbit", "guinea pig"],
        .dust: ["dust", "dusty", "dusting", "sawdust", "vacuum", "vacuumed", "vacuuming", "construction",
                "attic", "drywall"],
        .mold: ["mold", "moldy", "mould", "mouldy", "mildew", "musty", "damp"],
        .cleaningProducts: ["bleach", "cleaning", "cleaner", "cleaners", "cleaning spray", "disinfectant",
                            "ammonia", "chemical fumes", "chemicals"],
        .strongScents: ["perfume", "cologne", "candle", "candles", "scented", "air freshener", "incense",
                        "hairspray", "paint", "paint fumes", "strong smell", "strong scent"],
        .cooking: ["cooking", "cooked", "frying", "fried", "gas stove", "stove", "oven", "burnt toast",
                   "kitchen fumes"],
        .coldOrFlu: ["sick", "flu", "covid", "fever", "sore throat", "congested", "congestion", "runny nose",
                     "stuffy nose", "head cold", "chest cold", "chest infection", "virus",
                     // "a cold" alone would catch "a cold morning".
                     "caught a cold", "catching a cold", "got a cold", "getting a cold", "have a cold",
                     "has a cold", "had a cold", "down with a cold"],
        .stress: ["stress", "stressed", "stressful", "anxious", "anxiety", "panic", "panicked", "upset",
                  "argument", "worried", "nervous", "overwhelmed"],
        .laughingOrCrying: ["laughing", "laughed", "laugh", "crying", "cried", "cry", "sobbing"],
    ]

    /// A negator turns off the next matches within this many words.
    static let negationWindow = 4

    static let negators: Set<String> = [
        "no", "not", "never", "without", "nothing", "none", "zero", "neither", "nor",
        "wasn't", "weren't", "isn't", "aren't", "didn't", "don't", "doesn't", "haven't", "hasn't", "hadn't",
        "won't", "wouldn't", "couldn't", "can't", "cannot",
        "wasnt", "werent", "isnt", "arent", "didnt", "dont", "doesnt", "havent", "hasnt", "hadnt",
        "wont", "wouldnt", "couldnt", "cant",
    ]

    /// Words that end a clause, so "no smoke but the cat was there" still suggests pets.
    static let clauseBreaks: Set<String> = ["but", "though", "although", "except", "however"]

    /// Phrases as word lists, longest first so "cold air" wins over anything shorter at the same spot.
    static let rules: [(tag: JournalTag, words: [String], phrase: String)] = JournalTag.allCases
        .flatMap { tag in (phrases[tag] ?? []).map { (tag: tag, words: $0.split(separator: " ").map(String.init), phrase: $0) } }
        .sorted { $0.words.count > $1.words.count }

    public static func scan(_ text: String) -> Scan {
        var mentions: [Mention] = []
        for clause in clauses(text) {
            var i = 0
            var budget = 0  // words left in which a negator still applies
            while i < clause.count {
                let word = clause[i]
                if negators.contains(word) {
                    budget = negationWindow
                    i += 1
                    continue
                }
                if let rule = match(clause, at: i) {
                    let end = i + rule.words.count
                    let postfixFree = end < clause.count && clause[end] == "free"  // "smoke free", "pet-free"
                    let negated = budget > 0 || postfixFree
                    mentions.append(Mention(tag: rule.tag, phrase: rule.phrase, negated: negated))
                    i = end
                    // "no cats or dogs": the negation carries across "or" / "nor"; otherwise it ends here.
                    budget = negated && i < clause.count && (clause[i] == "or" || clause[i] == "nor") ? negationWindow : 0
                    continue
                }
                budget = max(0, budget - 1)
                i += 1
            }
        }
        let positive = Set(mentions.filter { !$0.negated }.map(\.tag))
        let mentioned = Set(mentions.map(\.tag))
        return Scan(
            mentions: mentions,
            tags: JournalTag.allCases.filter { positive.contains($0) },
            ruledOut: JournalTag.allCases.filter { mentioned.contains($0) && !positive.contains($0) }
        )
    }

    /// Suggestions from the phrase rules alone, with the first matching phrase as evidence.
    public static func suggest(_ text: String) -> [TagSuggestion] {
        let s = scan(text)
        return s.tags.map { tag in
            TagSuggestion(tag: tag, source: .keyword,
                          evidence: s.mentions.first { $0.tag == tag && !$0.negated }?.phrase)
        }
    }

    static func match(_ words: [String], at i: Int) -> (tag: JournalTag, words: [String], phrase: String)? {
        rules.first { rule in
            i + rule.words.count <= words.count && Array(words[i..<(i + rule.words.count)]) == rule.words
        }
    }

    /// Lower-cased words split into clauses at punctuation and at "but"-like words. Hyphens split words
    /// ("pet-free" → "pet", "free"); a trailing "'s" is dropped ("cat's" → "cat").
    static func clauses(_ text: String) -> [[String]] {
        let lowered = text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
        var out: [[String]] = [[]]
        var word = ""
        func flush() {
            var w = word.trimmingCharacters(in: CharacterSet(charactersIn: "'"))
            word = ""
            if w.hasSuffix("'s") { w.removeLast(2) }
            guard !w.isEmpty else { return }
            if clauseBreaks.contains(w) { out.append([]) } else { out[out.count - 1].append(w) }
        }
        for ch in lowered {
            if ch.isLetter || ch.isNumber || ch == "'" {
                word.append(ch)
            } else {
                flush()
                if ".,;:!?()\n".contains(ch) { out.append([]) }
            }
        }
        flush()
        return out.filter { !$0.isEmpty }
    }
}

// MARK: - Vocabulary validation

/// The closed list as the model sees it, and the check every model answer goes through.
public enum TagVocabulary {
    public struct Entry: Codable, Sendable, Equatable {
        public var id: String
        public var label: String
        public var hint: String
    }

    public struct Validation: Sendable, Equatable {
        /// Known tags, de-duplicated, in list order.
        public var accepted: [JournalTag]
        /// Strings that matched nothing on the list. Logged for debugging; never become tags.
        public var rejected: [String]
    }

    public static var entries: [Entry] {
        JournalTag.allCases.map { Entry(id: $0.rawValue, label: $0.label, hint: $0.hint) }
    }

    /// The tag a raw model string names, or nil. Exact match on the id or the label after ignoring case,
    /// spaces and punctuation ("coldAir", "cold_air", "Cold air" → .coldAir). No fuzzy or partial matches.
    public static func tag(for raw: String) -> JournalTag? {
        let key = normalize(raw)
        guard !key.isEmpty, key.count <= 40 else { return nil }
        if let t = lookup[key] { return t }
        // The bin name ("tag_coldAir") names the tag too.
        if key.hasPrefix("tag") { return lookup[String(key.dropFirst(3))] }
        return nil
    }

    public static func validate(_ raw: [String]) -> Validation {
        var found = Set<JournalTag>()
        var rejected: [String] = []
        for r in raw {
            if let t = tag(for: r) { found.insert(t) } else { rejected.append(r) }
        }
        return Validation(accepted: JournalTag.allCases.filter { found.contains($0) }, rejected: rejected)
    }

    static func normalize(_ s: String) -> String {
        String(s.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(Character.init))
    }

    static let lookup: [String: JournalTag] = {
        var m: [String: JournalTag] = [:]
        for t in JournalTag.allCases {
            m[normalize(t.rawValue)] = t
            m[normalize(t.label)] = t
        }
        return m
    }()
}

// MARK: - On-device model

/// Instructions for a model that proposes tags. The app passes them with the transcript to Apple
/// Foundation Models (guided generation); the transcript is the only diary text it sees.
public enum TagPrompt {
    public static var instructions: String {
        let list = TagVocabulary.entries.map { "- \($0.id): \($0.hint)" }.joined(separator: "\n")
        return """
            You tag short asthma diary notes. Pick ids only from this list, and only when the note clearly \
            says the thing happened. Skip anything the note says did not happen ("no smoke"). Empty if none.
            \(list)
            """
    }

    public static var allowedIDs: [String] { JournalTag.allCases.map(\.rawValue) }
}

/// Something that proposes tags for a transcript: Apple Foundation Models in the app, a stub in tests.
/// Whatever it returns is raw text. `VoiceNoteTagger` validates it against the closed list, so a model
/// can never put a free-form tag into a bin.
public protocol TagProposer: Sendable {
    /// Raw tag ids for `transcript`. Throw when the model is unavailable or fails; keyword rules still run.
    func proposeTags(for transcript: String, instructions: String) async throws -> [String]
}

// MARK: - Combining

public struct TagSuggestionResult: Sendable, Equatable {
    /// Chips to show, in list order. Still only suggestions.
    public var suggestions: [TagSuggestion]
    /// Model output that isn't on the closed list. Dropped.
    public var discarded: [String]
    /// Model proposals the note itself negates ("no smoke"). Dropped.
    public var vetoed: [JournalTag]
    /// The model answered (it may have answered with nothing).
    public var modelAnswered: Bool

    public static let empty = TagSuggestionResult(suggestions: [], discarded: [], vetoed: [], modelAnswered: false)
}

public enum VoiceNoteTagger {
    /// Pure merge of keyword rules and (optional) raw model output. `modelOutput == nil` = no model.
    public static func combine(transcript: String, modelOutput: [String]?) -> TagSuggestionResult {
        let scan = KeywordTagger.scan(transcript)
        let validation = TagVocabulary.validate(modelOutput ?? [])
        let ruledOut = Set(scan.ruledOut)
        let vetoed = validation.accepted.filter { ruledOut.contains($0) }
        let fromModel = Set(validation.accepted).subtracting(ruledOut)
        let fromKeyword = Set(scan.tags)

        let suggestions: [TagSuggestion] = JournalTag.allCases.compactMap { tag in
            let k = fromKeyword.contains(tag), m = fromModel.contains(tag)
            guard k || m else { return nil }
            let evidence = scan.mentions.first { $0.tag == tag && !$0.negated }?.phrase
            return TagSuggestion(tag: tag, source: k && m ? .keywordAndModel : (k ? .keyword : .model), evidence: evidence)
        }
        return TagSuggestionResult(suggestions: suggestions, discarded: validation.rejected, vetoed: vetoed,
                                   modelAnswered: modelOutput != nil)
    }

    /// Keyword rules plus the model when there is one. Fails open: a missing or failing model still
    /// returns the keyword suggestions. An empty transcript returns nothing and never calls the model.
    public static func suggest(transcript: String, using model: (any TagProposer)?) async -> TagSuggestionResult {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .empty }
        var raw: [String]?
        if let model {
            raw = try? await model.proposeTags(for: text, instructions: TagPrompt.instructions)
        }
        return combine(transcript: text, modelOutput: raw)
    }
}

// MARK: - Confirm / reject

/// The user's pass over a note's chips. Confirmed tags are data; everything else is not.
public struct TagReview: Codable, Sendable, Equatable {
    public enum Decision: String, Codable, Sendable {
        case pending, confirmed, rejected
    }

    /// Every chip shown, in list order (suggested and user-added).
    public private(set) var suggestions: [TagSuggestion]
    public private(set) var confirmed: Set<JournalTag>
    public private(set) var rejected: Set<JournalTag>
    /// The user tapped Done. Anything left pending was dropped.
    public private(set) var isFinished: Bool

    public init(suggestions: [TagSuggestion] = []) {
        self.suggestions = JournalTag.allCases.compactMap { t in suggestions.first { $0.tag == t } }
        confirmed = []
        rejected = []
        isFinished = false
    }

    public func decision(for tag: JournalTag) -> Decision {
        confirmed.contains(tag) ? .confirmed : rejected.contains(tag) ? .rejected : .pending
    }

    public var pending: [TagSuggestion] { suggestions.filter { decision(for: $0.tag) == .pending } }

    /// The only tags that may go into `FeatureFrame.tags`.
    public var confirmedTags: Set<JournalTag> { confirmed }

    /// Whether the note's tags were looked at. Then a tag not confirmed reads "no"; before, the tag
    /// bins are missing for this moment. Confirming any chip counts as a review.
    public var isReviewed: Bool { isFinished || !confirmed.isEmpty }

    public mutating func confirm(_ tag: JournalTag) {
        guard suggestions.contains(where: { $0.tag == tag }) else { return add(tag) }
        rejected.remove(tag)
        confirmed.insert(tag)
    }

    public mutating func reject(_ tag: JournalTag) {
        confirmed.remove(tag)
        rejected.insert(tag)
    }

    /// The user picked a tag nothing suggested. It counts as confirmed.
    public mutating func add(_ tag: JournalTag) {
        if !suggestions.contains(where: { $0.tag == tag }) {
            suggestions.append(TagSuggestion(tag: tag, source: .user))
            suggestions.sort { JournalTag.allCases.firstIndex(of: $0.tag)! < JournalTag.allCases.firstIndex(of: $1.tag)! }
        }
        rejected.remove(tag)
        confirmed.insert(tag)
    }

    /// Done: pending chips are rejected, never silently kept.
    public mutating func finish() {
        for s in pending { rejected.insert(s.tag) }
        isFinished = true
    }

    /// The transcript was edited and re-suggested. Decided chips stay as they are; stale pending chips
    /// go; new suggestions arrive pending, which reopens a finished review.
    public mutating func update(with fresh: [TagSuggestion]) {
        let decided = suggestions.filter { decision(for: $0.tag) != .pending }
        let decidedTags = Set(decided.map(\.tag))
        let added = fresh.filter { !decidedTags.contains($0.tag) }
        suggestions = JournalTag.allCases.compactMap { t in
            decided.first { $0.tag == t } ?? added.first { $0.tag == t }
        }
        if !added.isEmpty { isFinished = false }
    }
}

extension FeatureFrame {
    /// Stamps a review onto the frame: confirmed tags only, and whether the note was reviewed.
    public mutating func apply(_ review: TagReview) {
        tags = review.confirmedTags
        tagsReviewed = review.isReviewed
    }
}
