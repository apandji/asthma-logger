import Foundation

/// Active in the hour before a moment, from what the phone already knows: a Health workout in the hour
/// before, running or cycling (Motion) for a few minutes of the half hour before, or a burst of steps.
/// Exercise is a common asthma trigger (exercise-induced bronchoconstriction; NAEPP EPR-3, GINA), so it
/// sits in the profile's "Self" family beside the tags you say. Nil when neither Health nor Motion could
/// say: missing, never "no".
public enum Exertion {
    public static let vigorousMinutes: Double = 5
    public static let briskSteps = 2000   // in the 30 minutes before: about 20 minutes of brisk walking

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
}
