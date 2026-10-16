import AsthmaCore
import Foundation

/// A made-up day-to-day route around St. Louis for the demo week, so demo moments have places and maps.
/// Neighborhoods and public parks only, never a real person's places. Display only, like all demo data.
nonisolated enum DemoRoute {
    struct Place { let name: String; let lat: Double; let lon: Double; let outdoor: Bool }

    static let home = Place(name: "Tower Grove South", lat: 38.5958, lon: -90.2552, outdoor: false)
    static let work = Place(name: "Cortex, Midtown", lat: 38.6315, lon: -90.2499, outdoor: false)
    static let lunch = Place(name: "Central West End", lat: 38.6455, lon: -90.2618, outdoor: true)
    static let forestPark = Place(name: "Forest Park", lat: 38.6372, lon: -90.2930, outdoor: true)
    static let towerGrove = Place(name: "Tower Grove Park", lat: 38.6071, lon: -90.2560, outdoor: true)
    static let soulard = Place(name: "Soulard Market", lat: 38.6110, lon: -90.2094, outdoor: true)
    static let garden = Place(name: "Missouri Botanical Garden", lat: 38.6128, lon: -90.2594, outdoor: true)
    static let arch = Place(name: "Gateway Arch grounds", lat: 38.6247, lon: -90.1848, outdoor: true)

    /// Where the demo person is at this time: home mornings and nights, work weekdays, out after work
    /// and on weekends.
    static func place(at date: Date, calendar: Calendar = .current) -> Place {
        let hour = calendar.component(.hour, from: date)
        let weekend = calendar.isDateInWeekend(date)
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        switch hour {
        case ..<9, 20...: return home
        case 9..<12: return weekend ? soulard : work
        case 12..<14: return weekend ? garden : lunch
        case 14..<16: return weekend ? arch : work
        default: return day % 2 == 0 ? forestPark : towerGrove
        }
    }

    /// The same spot never twice: a few dozen meters of drift, steady per moment.
    static func coordinate(for place: Place, at date: Date) -> (Double, Double) {
        let seed = Int(date.timeIntervalSince1970 / 60)
        let dx = Double((seed &* 7919) % 100) / 100 - 0.5, dy = Double((seed &* 104_729) % 100) / 100 - 0.5
        return (place.lat + dy * 0.0012, place.lon + dx * 0.0015)
    }
}
