import Foundation

/// A stay somewhere (from CLVisit or similar).
public struct Visit: Sendable, Equatable {
    public var latitude: Double
    public var longitude: Double
    public var arrival: Date
    public var departure: Date

    public init(latitude: Double, longitude: Double, arrival: Date, departure: Date) {
        self.latitude = latitude
        self.longitude = longitude
        self.arrival = arrival
        self.departure = departure
    }

    public var dwell: TimeInterval { max(0, departure.timeIntervalSince(arrival)) }
}

/// A cluster of visits with a suggested role. The user confirms and names it.
public struct PlaceCandidate: Sendable, Equatable, Identifiable {
    public var id: Int
    public var latitude: Double
    public var longitude: Double
    public var visitCount: Int
    public var distinctDays: Int
    public var totalDwell: TimeInterval
    /// Hours spent here between 22:00 and 06:00.
    public var nightHours: Double
    /// Hours spent here 09:00–17:00 on weekdays.
    public var workdayHours: Double
    public var suggestion: PlaceKind
}

public enum Places {
    public static let defaultRadiusMeters = 150.0

    /// Greedy clustering: each visit joins the nearest cluster within `radius`, else starts one.
    /// Then: most night hours (≥3 nights) → home; most weekday-daytime hours (≥3 days, not home) → work;
    /// ≥3 distinct days → frequent; else other.
    public static func cluster(_ visits: [Visit], radiusMeters: Double = defaultRadiusMeters,
                               calendar: Calendar = .current) -> [PlaceCandidate] {
        struct Acc {
            var lat: Double, lon: Double, weight: Double
            var visits: [Visit] = []
        }
        var clusters: [Acc] = []
        for v in visits.sorted(by: { $0.arrival < $1.arrival }) {
            let nearest = clusters.indices
                .map { ($0, Geo.haversineKm(v.latitude, v.longitude, clusters[$0].lat, clusters[$0].lon) * 1000) }
                .filter { $0.1 <= radiusMeters }
                .min { $0.1 < $1.1 }
            let w = max(v.dwell, 60)
            if let (i, _) = nearest {
                let c = clusters[i]
                let total = c.weight + w
                clusters[i].lat = (c.lat * c.weight + v.latitude * w) / total
                clusters[i].lon = (c.lon * c.weight + v.longitude * w) / total
                clusters[i].weight = total
                clusters[i].visits.append(v)
            } else {
                clusters.append(Acc(lat: v.latitude, lon: v.longitude, weight: w, visits: [v]))
            }
        }

        var nightCounts: [Int: Int] = [:]
        var workdayCounts: [Int: Int] = [:]
        var out = clusters.enumerated().map { i, c -> PlaceCandidate in
            let days = Set(c.visits.map { calendar.startOfDay(for: $0.arrival) })
            let h = hours(c.visits, calendar: calendar)
            nightCounts[i] = h.nights
            workdayCounts[i] = h.workdays
            return PlaceCandidate(id: i, latitude: c.lat, longitude: c.lon, visitCount: c.visits.count,
                                  distinctDays: days.count, totalDwell: c.visits.map(\.dwell).reduce(0, +),
                                  nightHours: h.night, workdayHours: h.work, suggestion: .other)
        }

        let home = out.filter { nightCounts[$0.id, default: 0] >= 3 }.max { $0.nightHours < $1.nightHours }?.id
        let work = out.filter { $0.id != home && workdayCounts[$0.id, default: 0] >= 3 }
            .max { $0.workdayHours < $1.workdayHours }?.id
        for i in out.indices {
            if out[i].id == home { out[i].suggestion = .home }
            else if out[i].id == work { out[i].suggestion = .work }
            else if out[i].distinctDays >= 3 { out[i].suggestion = .frequent }
        }
        return out.sorted { $0.totalDwell > $1.totalDwell }
    }

    /// Night hours, weekday-daytime hours, and how many distinct nights / workdays they span.
    static func hours(_ visits: [Visit], calendar: Calendar) -> (night: Double, work: Double, nights: Int, workdays: Int) {
        let step: TimeInterval = 15 * 60
        var night = 0.0, work = 0.0
        var nightKeys = Set<Date>(), workKeys = Set<Date>()
        for v in visits {
            var t = v.arrival
            while t < v.departure {
                let c = calendar.dateComponents([.hour, .weekday], from: t)
                let h = c.hour ?? 0
                if h >= 22 || h < 6 {
                    night += step / 3600
                    // Attribute early-morning hours to the previous evening's night.
                    let anchor = h < 6 ? t.addingTimeInterval(-6 * 3600) : t
                    nightKeys.insert(calendar.startOfDay(for: anchor))
                }
                let wd = c.weekday ?? 1
                if (2...6).contains(wd) && h >= 9 && h < 17 {
                    work += step / 3600
                    workKeys.insert(calendar.startOfDay(for: t))
                }
                t = t.addingTimeInterval(step)
            }
        }
        return (night, work, nightKeys.count, workKeys.count)
    }

    /// Which confirmed place (if any) a point falls in.
    public static func match(latitude: Double, longitude: Double,
                             places: [(kind: PlaceKind, latitude: Double, longitude: Double)],
                             radiusMeters: Double = defaultRadiusMeters) -> PlaceKind? {
        places
            .map { ($0.kind, Geo.haversineKm(latitude, longitude, $0.latitude, $0.longitude) * 1000) }
            .filter { $0.1 <= radiusMeters }
            .min { $0.1 < $1.1 }?.0
    }
}
