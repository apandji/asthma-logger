import Foundation

/// Test sprays, not puffs. Metered-dose inhalers are primed by spraying into the air before first use, and
/// again after they've sat unused (Ventolin HFA: 4 sprays; ProAir HFA: 3), quickly, one after another. Real
/// puffs are usually 30 to 60 seconds apart. So three or more presses inside ten seconds probably weren't
/// taken: the app asks ("Were those test sprays?") instead of counting them as a rescue.
public enum Priming {
    public static let minSprays = 3
    public static let within: TimeInterval = 10

    /// `span`: from the first press to the last of this use.
    public static func looksLike(puffs: Int, span: TimeInterval) -> Bool {
        puffs >= minSprays && span <= within
    }
}
