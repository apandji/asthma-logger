import Foundation

/// When rescue use says "check in": two lines from the guidelines, worded the way they word them, with the
/// source named. Never a diagnosis, never a percentage, never "attack". Shown as a card on Now, not a push.
///
/// - **Again within 4 hours.** US asthma action plans built on the NHLBI template treat needing quick-relief
///   medicine more than every 4 hours as a red-zone sign: get help now.
/// - **More than 2 days in a week.** NAEPP EPR-3 and its 2020 focused update: short-acting reliever use for
///   symptoms on more than 2 days a week generally indicates inadequate control. GINA counts reliever use
///   more than twice a week as a sign asthma isn't well controlled.
/// Research and citations: docs/research/guidance-and-archetypes.md.
public enum RelieverUse {
    public enum Check: Equatable, Sendable {
        /// The latest rescue came within 4 hours of the one before, and is itself within the last 4 hours.
        case againWithin4Hours
        /// Rescue use on more than 2 of the last 7 days.
        case moreThanTwoDaysThisWeek

        public var title: String {
            switch self {
            case .againWithin4Hours: "Rescue inhaler again within 4 hours"
            case .moreThanTwoDaysThisWeek: "Rescue inhaler on more than 2 days this week"
            }
        }

        public var body: String {
            switch self {
            case .againWithin4Hours:
                "Many asthma action plans say needing it more than every 4 hours is a sign to get help now. Follow your action plan. If it isn't helping or breathing is hard, call 911."
            case .moreThanTwoDaysThisWeek:
                "Guidelines say using it on more than 2 days a week can mean asthma isn't well controlled. It's worth checking in with your doctor about your plan."
            }
        }

        public var source: String {
            switch self {
            case .againWithin4Hours: "NHLBI asthma action plan"
            case .moreThanTwoDaysThisWeek: "NAEPP 2020 · GINA"
            }
        }
    }

    public static let hours4: TimeInterval = 4 * 3600

    /// `rescues`: when each rescue moment began (puffs a minute apart are already one moment). Real moments
    /// only, never demo ones.
    public static func check(rescues: [Date], now: Date, calendar: Calendar = .current) -> Check? {
        let past = rescues.filter { $0 <= now }.sorted()
        if past.count >= 2, let last = past.last, now.timeIntervalSince(last) <= hours4,
           last.timeIntervalSince(past[past.count - 2]) <= hours4 {
            return .againWithin4Hours
        }
        guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) else { return nil }
        let days = Set(past.filter { $0 >= weekAgo }.map { calendar.startOfDay(for: $0) })
        return days.count > 2 ? .moreThanTwoDaysThisWeek : nil
    }
}
