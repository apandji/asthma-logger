import Foundation

/// One hourly sea-level pressure, hPa, from past hours or forecast hours.
public struct PressurePoint: Sendable, Equatable {
    public var date: Date
    public var hPa: Double

    public init(date: Date, hPa: Double) {
        self.date = date
        self.hPa = hPa
    }
}

/// How the air pressure moved in the 3 hours before an hour. The value matters less than the swing, so the bin
/// is the change. Same rule for a logged moment and a forecast hour (`TempDrop`'s shape).
///
/// The step is 1.6 hPa in 3 hours: where forecasters' wording goes from "slowly" to plain "falling" or
/// "rising" (the UK Met Office's pressure-tendency terms). It's a weather convention, not a clinical edge.
public enum PressureChange {
    public static let windowHours: Double = 3
    public static let stepHpa: Double = 1.6
    static let nowTolerance: TimeInterval = 60 * 60

    /// The reading at `date` minus the reading about `windowHours` before, hPa. Negative = falling. Nil when
    /// either end is missing (missing, not "steady").
    public static func change(at date: Date, in points: [PressurePoint]) -> Double? {
        let usable = points.filter { $0.hPa.isFinite && $0.date <= date }
        guard let now = usable.filter({ date.timeIntervalSince($0.date) <= nowTolerance }).max(by: { $0.date < $1.date })
        else { return nil }
        let target = now.date.addingTimeInterval(-windowHours * 3600)
        let earlier = usable.filter { $0.date < now.date && abs($0.date.timeIntervalSince(target)) <= nowTolerance }
        guard let then = earlier.min(by: { abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target)) })
        else { return nil }
        return now.hPa - then.hPa
    }

    public static func band(_ change: Double?) -> PressureBand {
        guard let c = change, c.isFinite else { return .unknown }
        if c <= -stepHpa { return .falling }
        if c >= stepHpa { return .rising }
        return .steady
    }
}

public enum PressureBand: String, Codable, Sendable, CaseIterable {
    case falling, rising, steady, unknown
}
