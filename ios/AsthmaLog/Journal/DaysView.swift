import AsthmaCore
import SwiftUI

/// The "days" scale of the zoom (gesture model B), like Photos' Days: one row per day with a small sky
/// of its most telling moment, the day's moments as dots, and its headline. Newest at the bottom.
/// Tap a day to zoom back in on it.
struct DaysView: View {
    let events: [LogEvent]
    let selectedID: UUID?
    let pollenSeason: DemoPollen.Season
    var anchorStore: AnchorFrames? = nil
    var anchorHidden = false
    let open: (LogEvent) -> Void

    /// Starts on the current moment's day, so the anchor's tile is on screen from the first frame.
    @State private var scrolledDay: Date?

    init(events: [LogEvent], selectedID: UUID?, pollenSeason: DemoPollen.Season, anchorStore: AnchorFrames? = nil,
         anchorHidden: Bool = false, open: @escaping (LogEvent) -> Void) {
        self.events = events
        self.selectedID = selectedID
        self.pollenSeason = pollenSeason
        self.anchorStore = anchorStore
        self.anchorHidden = anchorHidden
        self.open = open
        let day = events.first { $0.id == selectedID }?.loggedAt ?? events.last?.loggedAt ?? .now
        _scrolledDay = State(initialValue: Calendar.current.startOfDay(for: day))
    }

    private var days: [(day: Date, moments: [LogEvent])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: events) { cal.startOfDay(for: $0.loggedAt) }
        return grouped.keys.sorted().map { ($0, grouped[$0]!.sorted { $0.loggedAt < $1.loggedAt }) }
    }

    /// The moment that best stands for the day: the worst air, then the latest rescue, then the latest.
    private func telling(_ ms: [LogEvent]) -> LogEvent {
        ms.max { a, b in
            let la = a.weave.levels[.air]?.rawValue ?? -1, lb = b.weave.levels[.air]?.rawValue ?? -1
            if la != lb { return la < lb }
            if (a.moment == .rescue) != (b.moment == .rescue) { return b.moment == .rescue }
            return a.loggedAt < b.loggedAt
        }!
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Days").font(.system(.title, design: .serif, weight: .medium))
                    .padding(.horizontal, 4).padding(.bottom, 4)
                ForEach(days, id: \.day) { d in
                    let isCurrent = d.moments.contains { $0.id == selectedID }
                    // The current day shows the moment you came from, so the zoom's anchor stays the same sky.
                    let t = isCurrent ? d.moments.first { $0.id == selectedID }! : telling(d.moments)
                    Button { open(d.moments.contains { $0.id == selectedID } ? d.moments.first { $0.id == selectedID }! : t) } label: {
                        HStack(spacing: 14) {
                            AmbientField(weave: t.weave, temperatureF: t.conditions?.best(.temperature)?.value, date: t.loggedAt,
                                         conditions: t.conditions, pollen: DemoPollen.sample(at: t.loggedAt, season: pollenSeason))
                                .frame(width: 84, height: 84)
                                .clipShape(.rect(cornerRadius: 20, style: .continuous))
                                // One pass per tile; cheap to scroll.
                                .drawingGroup()
                                .modifier(AnchorReport(key: isCurrent ? "days" : nil, store: anchorStore, hidden: anchorHidden))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(dayLabel(d.day)).font(.subheadline.weight(.semibold))
                                Text(t.weave.isEmpty ? "No air reading." : t.headline)
                                    .font(.footnote).foregroundStyle(Theme.secondaryText).lineLimit(2)
                                // Capped, so a busy day can't push the row wider than the screen.
                                HStack(spacing: 5) {
                                    ForEach(d.moments.prefix(9)) { MomentSwatch(event: $0, size: 12) }
                                    if d.moments.count > 9 {
                                        Text("+\(d.moments.count - 9)").font(.caption2.weight(.medium))
                                            .foregroundStyle(Theme.secondaryText)
                                    }
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(.white.opacity(isCurrent ? 0.12 : 0.05), in: .rect(cornerRadius: 26, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .id(d.day)
                    .accessibilityLabel("\(dayLabel(d.day)), \(d.moments.count) moments. \(t.headline)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
            .frame(maxWidth: .infinity)  // clear the + bar
            .scrollTargetLayout()
        }
        .defaultScrollAnchor(.bottom)
        .scrollPosition(id: $scrolledDay, anchor: .center)
        .scrollIndicators(.hidden)
    }

    private func dayLabel(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Today" }
        if cal.isDateInYesterday(d) { return "Yesterday" }
        return d.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}
