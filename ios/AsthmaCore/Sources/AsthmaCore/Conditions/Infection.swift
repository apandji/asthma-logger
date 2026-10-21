import Foundation

/// Flu-like illness going around: the hook-up for the Infections trigger (docs/research/trigger-lens.md).
/// **Later, not MVP** (owner, Oct 21): nothing real is fetched or stamped. The `ili` bin is counted (v6) and
/// the Colds and flu axis is on the radar, so data sets can show it; on real moments it reads "Not tracked yet".
/// Turning it on is a source and a switch, not a migration:
///
/// 1. A live `InfectionSource` (Ambee ILI: `GET /ili/forecast/by-lat-lng`, weekly, US by metro area).
/// 2. `Infection.isEnabled = true`.
///
/// It's a day-level reading for the area, never about the person: "flu-like illness was often high around
/// here on your flare days", never "you were sick". Ambee has no history, so a level is only known for days
/// it was stamped as they happened; older moments stay missing, not "low".
public enum Infection {
    /// Off for the MVP. While false the app stamps nothing on real moments, so the bin has no rows.
    public static let isEnabled = false
    public static let bin = "ili"

    /// A level from a provider's word ("Low", "Moderate", "High", "Very High"). Anything else is unknown.
    /// Ambee doesn't document its response fields yet: check against a live response before trusting this.
    public static func level(fromRisk risk: String?) -> InfectionLevel {
        switch risk?.lowercased().trimmingCharacters(in: .whitespaces) {
        case "low", "minimal": .low
        case "moderate", "medium": .moderate
        case "high", "very high", "very_high": .high
        default: .unknown
        }
    }
}

public enum InfectionLevel: String, Codable, Sendable, CaseIterable {
    case low, moderate, high, unknown
}

/// One area-level reading, with its provenance (root AGENTS.md → Honest numbers).
public struct InfectionReading: Codable, Sendable, Equatable {
    public var level: InfectionLevel
    public var source: String
    /// When the provider made this reading.
    public var asOf: Date
    /// The day it speaks for (a forecast week covers several).
    public var day: Date
    /// "metro" for Ambee's US CBSA coverage. Never "at your location".
    public var spatialScale: String
    public var isForecast: Bool

    public init(level: InfectionLevel, source: String, asOf: Date, day: Date,
                spatialScale: String = "metro", isForecast: Bool = true) {
        self.level = level; self.source = source; self.asOf = asOf; self.day = day
        self.spatialScale = spatialScale; self.isForecast = isForecast
    }
}

/// Where a reading comes from. Fails open: nil means missing, and a log never waits on it.
public protocol InfectionSource: Sendable {
    func reading(latitude: Double, longitude: Double, on day: Date) async -> InfectionReading?
}

/// The MVP source: always missing.
public struct NoInfectionSource: InfectionSource {
    public init() {}
    public func reading(latitude: Double, longitude: Double, on day: Date) async -> InfectionReading? { nil }
}
