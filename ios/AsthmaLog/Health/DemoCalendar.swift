import Foundation

/// A believable week of calendar events for demos and the simulator (Settings › Demo › Demo calendar), so
/// "what was on" and "what you'll be doing" show without a real calendar. The real thing is EventKit
/// (CalendarReader); this only stands in for its events. Some are outdoors and active (soccer, run club, the
/// park), so the forecast's beside-the-air line has something to say.
enum DemoCalendar {
    static let key = "demo.calendar"
    static var isOn: Bool { UserDefaults.standard.bool(forKey: key) }

    /// (weekday 1 = Sunday…7, start hour, start minute, minutes, title, place)
    private static let week: [(Int, Int, Int, Int, String, String?)] = [
        (2, 9, 30, 30, "Standup", nil), (3, 9, 30, 30, "Standup", nil), (4, 9, 30, 30, "Standup", nil),
        (5, 9, 30, 30, "Standup", nil), (6, 9, 30, 30, "Standup", nil),
        (2, 12, 0, 60, "Lunch in Tower Grove Park", "Tower Grove Park"),
        (4, 12, 0, 60, "Lunch in Tower Grove Park", "Tower Grove Park"),
        (3, 18, 0, 90, "Soccer practice", "Francis Park"), (5, 18, 0, 90, "Soccer practice", "Francis Park"),
        (4, 15, 0, 60, "Design review", nil), (6, 17, 0, 60, "Walk to the market", "Soulard Market"),
        (7, 9, 0, 120, "Farmers market", "Tower Grove Farmers Market"),
        (1, 8, 0, 60, "Run club", "Forest Park"), (1, 14, 0, 120, "Gardening", "Home"),
    ]

    static func events(from: Date, to: Date, calendar cal: Calendar = .current) -> [CalendarReader.Event] {
        var out: [CalendarReader.Event] = []
        var day = cal.startOfDay(for: from)
        while day < to {
            let wd = cal.component(.weekday, from: day)
            for (w, h, m, mins, title, place) in week where w == wd {
                guard let start = cal.date(bySettingHour: h, minute: m, second: 0, of: day) else { continue }
                let end = start.addingTimeInterval(Double(mins) * 60)
                if end > from && start < to {
                    out.append(.init(id: "demo-\(Int(start.timeIntervalSince1970))", title: title, start: start, end: end,
                                     location: place, isAllDay: false))
                }
            }
            day = cal.date(byAdding: .day, value: 1, to: day) ?? to
        }
        return out.sorted { $0.start < $1.start }
    }
}
