import Foundation

/// Baseline moments filled in afterwards, across the whole day (owner, Oct 17, 2026). A baseline only needs
/// where you were and what the air was at an hour with no inhaler use, so it doesn't have to be taken live:
/// a day later, felt air picks a few hours, finds where you were, and fetches that hour's air from history.
/// This replaces the old sample on app open, which leaned toward home and toward when the phone was in hand.
/// docs/predictive-engine.md §4: unsampled hours stay missing, never negatives.
public enum BaselineBackfill {
    /// A stay somewhere, from iOS visit monitoring (kept on the phone).
    public struct Visit: Codable, Sendable, Equatable {
        public var latitude: Double
        public var longitude: Double
        public var arrival: Date
        public var departure: Date

        public init(latitude: Double, longitude: Double, arrival: Date, departure: Date) {
            self.latitude = latitude; self.longitude = longitude; self.arrival = arrival; self.departure = departure
        }
    }

    /// A known spot: home, or where you logged a moment.
    public struct Spot: Sendable, Equatable {
        public var latitude: Double
        public var longitude: Double
        public var name: String?
        public var at: Date?

        public init(latitude: Double, longitude: Double, name: String? = nil, at: Date? = nil) {
            self.latitude = latitude; self.longitude = longitude; self.name = name; self.at = at
        }
    }

    public enum Where: String, Sendable, Equatable {
        /// From a visit that covers the hour.
        case visit
        /// Home, when no visit covers it.
        case home
        /// The nearest logged moment that day, when there's no home either.
        case loggedSpot
    }

    public struct Slot: Sendable, Equatable {
        public let date: Date
        public let latitude: Double
        public let longitude: Double
        public let name: String?
        public let source: Where
    }

    /// Waking hours split in three, one sample from each, so the day is covered rather than clumped.
    public static let parts: [ClosedRange<Int>] = [7...11, 12...16, 17...22]
    /// No baseline this close to inhaler use (it's not an ordinary hour).
    public static let clearOfInhaler: TimeInterval = 2 * 3600
    /// Nor this close to a baseline already there.
    public static let clearOfBaseline: TimeInterval = 3600

    /// The hours to fill for one day (`day` is any time that day). Deterministic per day.
    public static func plan(day: Date, inhaler: [Date], baselines: [Date], visits: [Visit], home: Spot?,
                            logged: [Spot], calendar: Calendar = .current) -> [Slot] {
        let start = calendar.startOfDay(for: day)
        var rng = SeededRandom(seed: UInt64(max(0, start.timeIntervalSince1970)))
        var out: [Slot] = []
        for part in parts {
            // Already sampled in this part of the day: leave it.
            if baselines.contains(where: { calendar.isDate($0, inSameDayAs: start) && part.contains(calendar.component(.hour, from: $0)) }) {
                continue
            }
            let hours = Array(part).shuffled(using: &rng)
            for h in hours {
                let minute = rng.int(0, 59)
                guard let t = calendar.date(bySettingHour: h, minute: minute, second: 0, of: start) else { continue }
                if inhaler.contains(where: { abs($0.timeIntervalSince(t)) < clearOfInhaler }) { continue }
                if baselines.contains(where: { abs($0.timeIntervalSince(t)) < clearOfBaseline }) { continue }
                guard let place = locate(t, visits: visits, home: home, logged: logged, calendar: calendar) else { break }
                out.append(Slot(date: t, latitude: place.spot.latitude, longitude: place.spot.longitude,
                                name: place.spot.name, source: place.source))
                break
            }
        }
        return out
    }

    /// Where you were at `t`: a covering visit, else home, else that day's nearest logged spot. Nil when
    /// nothing is known (the hour stays unsampled).
    static func locate(_ t: Date, visits: [Visit], home: Spot?, logged: [Spot], calendar: Calendar) -> (spot: Spot, source: Where)? {
        if let v = visits.first(where: { $0.arrival <= t && t <= $0.departure }) {
            return (Spot(latitude: v.latitude, longitude: v.longitude), .visit)
        }
        if let home { return (home, .home) }
        let sameDay = logged.filter { $0.at.map { calendar.isDate($0, inSameDayAs: t) } ?? false }
        if let s = sameDay.min(by: { abs($0.at!.timeIntervalSince(t)) < abs($1.at!.timeIntervalSince(t)) }) {
            return (s, .loggedSpot)
        }
        return nil
    }

    /// The days to fill: from the first real moment (or `maxDays` ago) through yesterday, oldest first,
    /// minus the ones already done.
    public static func days(firstMoment: Date?, now: Date, done: Set<Date>, maxDays: Int = 60, calendar: Calendar = .current) -> [Date] {
        guard let firstMoment else { return [] }
        let today = calendar.startOfDay(for: now)
        let earliest = max(calendar.startOfDay(for: firstMoment), calendar.date(byAdding: .day, value: -maxDays, to: today)!)
        var out: [Date] = []
        var d = earliest
        while d < today {
            if !done.contains(d) { out.append(d) }
            d = calendar.date(byAdding: .day, value: 1, to: d)!
        }
        return out
    }
}

extension SeededRandom: RandomNumberGenerator {}
