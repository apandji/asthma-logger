import EventKit
import Foundation

/// Your calendar, read on this iPhone, for two things:
/// - **Around then**: what was on around a moment ("Team sync, 10–11"), a memory aid in the note. Never a
///   feeling: a meeting is never called stressful; you tick Stress if it was.
/// - **The look-ahead**: what you'll be doing at a forecast hour, beside the air for it.
/// Event titles never leave the phone and never become patterns. Asked in onboarding's data cards.
@MainActor
final class CalendarReader {
    static let shared = CalendarReader()
    private let store = EKEventStore()

    struct Event: Identifiable, Equatable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let location: String?
        let isAllDay: Bool

        /// "Team sync, 10–11 AM" (the time the way the phone writes it).
        var line: String {
            if isAllDay { return title }
            let s = start.formatted(date: .omitted, time: .shortened)
            let e = end.formatted(date: .omitted, time: .shortened)
            return "\(title), \(s)–\(e)"
        }
    }

    var isAllowed: Bool { DemoCalendar.isOn || EKEventStore.authorizationStatus(for: .event) == .fullAccess }
    var wasAsked: Bool { EKEventStore.authorizationStatus(for: .event) != .notDetermined }

    @discardableResult
    func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    /// Events overlapping `from…to`, timed ones first, then all-day ones.
    func events(from: Date, to: Date) -> [Event] {
        // Demo calendar (Settings › Demo): a stand-in week, for demos and the simulator.
        if DemoCalendar.isOn { return DemoCalendar.events(from: from, to: to) }
        guard isAllowed else { return [] }
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: nil)
        return store.events(matching: predicate)
            .filter { $0.status != .canceled }
            .sorted { ($0.isAllDay ? 1 : 0, $0.startDate) < ($1.isAllDay ? 1 : 0, $1.startDate) }
            .map { Event(id: $0.eventIdentifier ?? UUID().uuidString, title: $0.title ?? "Event", start: $0.startDate,
                         end: $0.endDate, location: $0.location?.isEmpty == false ? $0.location : nil, isAllDay: $0.isAllDay) }
    }

    /// What was on around a moment (from an hour before to a quarter after), for its header.
    func around(_ t: Date) -> Event? {
        events(from: t.addingTimeInterval(-3600), to: t.addingTimeInterval(900)).first { !$0.isAllDay }
    }

    /// What's on at an hour (a timed event covering it), for the look-ahead.
    func event(at hour: Date) -> Event? {
        events(from: hour, to: hour.addingTimeInterval(3600)).first { !$0.isAllDay }
    }
}
