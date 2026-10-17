import Foundation

/// One hourly temperature, from past hours (Apple Weather history) or forecast hours.
public struct TempPoint: Sendable, Equatable {
    public var date: Date
    public var temperatureF: Double

    public init(date: Date, temperatureF: Double) {
        self.date = date
        self.temperatureF = temperatureF
    }
}

/// A sharp fall in outdoor temperature before an hour: the first event detector of the air outlook
/// (docs/air-outlook.md). Same rule for a logged moment and a forecast hour, so it is one bin.
public enum TempDrop {
    /// How far back to look.
    public static let windowHours: Double = 3
    /// A fall of at least this much (°F) inside the window counts as a sharp drop.
    public static let sharpDropF: Double = 10
    /// The reading "at" the hour may be up to this old; hourly data sits on the hour.
    static let nowTolerance: TimeInterval = 60 * 60

    /// Warmest reading in the `windowHours` before `date` minus the reading at `date`, in °F.
    /// Positive = it got colder. Nil when there is no reading at `date` or none earlier in the window
    /// (missing, not "no drop").
    public static func degreesFallen(at date: Date, in points: [TempPoint]) -> Double? {
        let usable = points.filter { $0.temperatureF.isFinite && $0.date <= date }
        guard let now = usable.filter({ date.timeIntervalSince($0.date) <= nowTolerance }).max(by: { $0.date < $1.date })
        else { return nil }
        let start = date.addingTimeInterval(-windowHours * 3600)
        let earlier = usable.filter { $0.date >= start && $0.date < now.date }
        guard let warmest = earlier.map(\.temperatureF).max() else { return nil }
        return warmest - now.temperatureF
    }

    /// The Weather row's "what came before" line, or nil when there was no sharp drop.
    /// Describes the weather only; whether it matters for you is Insights' job.
    public static func line(_ degreesFallen: Double?) -> String? {
        guard band(degreesFallen) == .sharp, let d = degreesFallen else { return nil }
        return "Dropped \(Int(d.rounded()))°F in the 3 hours before."
    }

    /// Nil degrees → unknown. A rise reads as no drop.
    public static func band(_ degreesFallen: Double?) -> TempDropBand {
        guard let d = degreesFallen, d.isFinite else { return .unknown }
        return d >= sharpDropF ? .sharp : .none
    }
}

public enum TempDropBand: String, Codable, Sendable, CaseIterable {
    case sharp, none, unknown
}
