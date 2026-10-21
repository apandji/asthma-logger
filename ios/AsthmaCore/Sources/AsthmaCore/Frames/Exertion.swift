import Foundation

/// Active in the hour before a moment, from what the phone already knows: a Health workout in the hour
/// before, running or cycling (Motion) for a few minutes of the half hour before, or a burst of steps.
/// Exercise is a common asthma trigger (exercise-induced bronchoconstriction; NAEPP EPR-3, GINA), so it
/// sits in the profile's "Self" family beside the tags you say. Nil when neither Health nor Motion could
/// say: missing, never "no".
public enum Exertion {
    public static let vigorousMinutes: Double = 5
    public static let briskSteps = 2000   // in the 30 minutes before: about 20 minutes of brisk walking
    /// iOS keeps about a week of Motion activity. Older than that, Motion can't say (missing, not "still").
    public static let motionKeepsDays = 7

    /// - workout: a Health workout overlapping the hour before (nil: Health not allowed or unavailable).
    /// - vigorousMinutes: running or cycling minutes in the 30 minutes before (nil: Motion unavailable).
    /// - steps: steps in the 30 minutes before (nil: unavailable).
    public static func active(workout: Bool?, vigorousMinutes: Double?, steps: Int?) -> Bool? {
        if workout == nil && vigorousMinutes == nil && steps == nil { return nil }
        if workout == true { return true }
        if let m = vigorousMinutes, m >= Self.vigorousMinutes { return true }
        if let s = steps, s >= briskSteps { return true }
        return false
    }

    /// What Health and Motion said about the time before a moment. Each nil means that source can't say.
    public struct Reading: Equatable, Sendable {
        /// A Health workout overlapping the hour before. Nil: Health not allowed, or no Health data at all.
        public var workout: Bool?
        /// Its kind, when there was one.
        public var workoutKind: ExertionSource.WorkoutKind?
        /// Running and cycling minutes in the 30 minutes before (Motion). Nil: Motion can't say.
        public var runningMinutes: Double?
        public var cyclingMinutes: Double?
        /// Steps in the 30 minutes before (Health). Nil: Health can't say.
        public var steps: Int?

        public init(workout: Bool? = nil, workoutKind: ExertionSource.WorkoutKind? = nil,
                    runningMinutes: Double? = nil, cyclingMinutes: Double? = nil, steps: Int? = nil) {
            self.workout = workout
            self.workoutKind = workoutKind
            self.runningMinutes = runningMinutes
            self.cyclingMinutes = cyclingMinutes
            self.steps = steps
        }

        /// Running plus cycling, nil when Motion can't say.
        public var vigorousMinutes: Double? {
            if runningMinutes == nil && cyclingMinutes == nil { return nil }
            return (runningMinutes ?? 0) + (cyclingMinutes ?? 0)
        }
    }

    /// The decision and the signal that made it (nil when not active, or not known).
    public struct Decision: Equatable, Sendable {
        public var active: Bool?
        public var source: ExertionSource?
        public init(active: Bool?, source: ExertionSource?) {
            self.active = active
            self.source = source
        }
    }

    /// Same rule as `active`, and which signal fired first: a workout, then Motion (whichever of running or
    /// cycling was longer), then steps.
    public static func decide(_ r: Reading) -> Decision {
        let active = active(workout: r.workout, vigorousMinutes: r.vigorousMinutes, steps: r.steps)
        guard active == true else { return Decision(active: active, source: nil) }
        if r.workout == true { return Decision(active: true, source: .workout(r.workoutKind ?? .other)) }
        if let m = r.vigorousMinutes, m >= vigorousMinutes {
            return Decision(active: true, source: (r.cyclingMinutes ?? 0) > (r.runningMinutes ?? 0) ? .cycling : .running)
        }
        return Decision(active: true, source: .steps)
    }

    /// Whether Motion still has the half hour before `date` (it keeps about a week).
    public static func motionCanSay(at date: Date, now: Date = .now) -> Bool {
        date > now.addingTimeInterval(-Double(motionKeepsDays) * 86_400)
    }

    /// The fact line on a moment. Nil when not active or unknown: say nothing, never "you weren't active".
    public static func line(active: Bool?) -> String? {
        active == true ? "You'd been active in the hour before." : nil
    }

    /// What it came from, in words: "A run, from Apple Health." Nil when the source wasn't kept (moments
    /// stamped before it was, and the demo trigger). Never step counts or minutes.
    public static func detail(_ source: ExertionSource?) -> String? {
        guard let source else { return nil }
        let what = source.words
        return what.prefix(1).uppercased() + what.dropFirst() + ", from " + source.from + "."
    }
}

/// Which signal said "active": a Health workout (and its kind), Motion running or cycling, or Health steps.
/// Stored on the moment as `rawValue` so the line can say what it came from.
public enum ExertionSource: Equatable, Hashable, Sendable {
    case workout(WorkoutKind)
    case running
    case cycling
    case steps

    public enum WorkoutKind: String, CaseIterable, Sendable {
        case run, walk, hike, bikeRide, swim, game, strength, classSession, stairs, other

        public var words: String {
            switch self {
            case .run: "a run"
            case .walk: "a walk"
            case .hike: "a hike"
            case .bikeRide: "a bike ride"
            case .swim: "a swim"
            case .game: "a game"
            case .strength: "a workout"
            case .classSession: "a class"
            case .stairs: "a stair climb"
            case .other: "a workout"
            }
        }
    }

    public var rawValue: String {
        switch self {
        case .workout(let k): "workout." + k.rawValue
        case .running: "motion.running"
        case .cycling: "motion.cycling"
        case .steps: "steps"
        }
    }

    public init?(rawValue: String) {
        switch rawValue {
        case "motion.running": self = .running
        case "motion.cycling": self = .cycling
        case "steps": self = .steps
        default:
            guard rawValue.hasPrefix("workout.") else { return nil }
            self = .workout(WorkoutKind(rawValue: String(rawValue.dropFirst("workout.".count))) ?? .other)
        }
    }

    /// "a walk", "a run", "a lot of steps".
    public var words: String {
        switch self {
        case .workout(let k): k.words
        case .running: "a run"
        case .cycling: "a bike ride"
        case .steps: "a lot of steps"
        }
    }

    /// Where it was read: Apple Health (workouts, steps) or the iPhone's motion sensor.
    public var from: String {
        switch self {
        case .workout, .steps: "Apple Health"
        case .running, .cycling: "your iPhone's motion"
        }
    }
}
