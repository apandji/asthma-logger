import Foundation

/// A made-up week of moments for demos and critiques: standard doses morning and evening, a few rescue
/// moments, and I'm okay samples, each with outdoor values labelled source "Demo". Deterministic, so a
/// demo looks the same every time. Never mixed into real data silently: the app tags these and can remove them.
public enum DemoWeek {
    public struct Moment: Sendable {
        public let kind: MomentKind
        public let at: Date
        public let conditions: Conditions
    }

    public static let source = "Demo"

    public static func moments(endingAt now: Date, calendar: Calendar = .current) -> [Moment] {
        // (day offset from today, hour, minute, kind, pm25, ozone ppb, °F, humidity %)
        let plan: [(Int, Int, Int, MomentKind, Double, Double, Double, Double)] = [
            (-6, 8, 5, .maintenance, 7, 30, 61, 58), (-6, 13, 0, .okay, 9, 41, 70, 50), (-6, 21, 10, .maintenance, 8, 28, 63, 62),
            (-5, 8, 0, .maintenance, 10, 35, 64, 60), (-5, 16, 40, .rescue, 22, 72, 91, 71), (-5, 17, 55, .rescue, 24, 75, 92, 74),
            (-5, 21, 0, .maintenance, 15, 52, 80, 66),
            (-4, 8, 15, .maintenance, 6, 29, 58, 55), (-4, 12, 30, .okay, 7, 38, 66, 48), (-4, 21, 5, .maintenance, 6, 27, 60, 57),
            (-3, 7, 50, .maintenance, 12, 44, 71, 69), (-3, 18, 20, .rescue, 30, 68, 88, 82), (-3, 21, 20, .maintenance, 18, 50, 79, 78),
            (-2, 8, 10, .maintenance, 5, 26, 55, 45), (-2, 14, 0, .okay, 6, 40, 67, 42), (-2, 21, 0, .maintenance, 5, 25, 57, 47),
            (-1, 8, 0, .maintenance, 9, 37, 65, 66), (-1, 11, 45, .rescue, 14, 58, 76, 81), (-1, 15, 30, .okay, 11, 49, 78, 70),
            (-1, 21, 15, .maintenance, 10, 33, 68, 72),
            (0, 7, 55, .maintenance, 8, 34, 62, 61),
        ]
        let today = calendar.startOfDay(for: now)
        return plan.compactMap { day, h, m, kind, pm, o3, t, rh in
            guard let d = calendar.date(byAdding: .day, value: day, to: today),
                  let at = calendar.date(bySettingHour: h, minute: m, second: 0, of: d), at <= now else { return nil }
            let obs = [
                EnvObservation(signal: .pm25, value: pm, unit: "µg/m³", asOf: at, source: source, spatialScale: .station, distanceKm: 4.8),
                EnvObservation(signal: .ozone, value: o3, unit: "ppb", asOf: at, source: source, spatialScale: .station, distanceKm: 4.8),
                EnvObservation(signal: .temperature, value: t, unit: "°F", asOf: at, source: source, spatialScale: .modelGrid),
                EnvObservation(signal: .humidity, value: rh, unit: "%", asOf: at, source: source, spatialScale: .modelGrid),
            ]
            return Moment(kind: kind, at: at, conditions: Conditions(observations: obs, fetchedAt: at))
        }
    }
}
