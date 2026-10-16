import AsthmaCore
import SwiftUI

/// The "days" scale of the zoom (gesture model B), like Photos' Days: one row per day with a small sky
/// of its most telling moment, the day's moments as dots, and its headline. Newest at the bottom.
/// Tap a day to zoom back in on it.
struct DaysView: View {
    let events: [LogEvent]
    let selectedID: UUID?
    let pollenSeason: DemoPollen.Season
    let open: (LogEvent) -> Void

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
            LazyVStack(alignment: .leading, spacing: 12) {
                Text("Days").font(.system(.title, design: .serif, weight: .medium))
                    .padding(.horizontal, 4).padding(.bottom, 4)
                ForEach(days, id: \.day) { d in
                    let t = telling(d.moments)
                    let isCurrent = d.moments.contains { $0.id == selectedID }
                    Button { open(d.moments.contains { $0.id == selectedID } ? d.moments.first { $0.id == selectedID }! : t) } label: {
                        HStack(spacing: 14) {
                            AmbientField(weave: t.weave, temperatureF: t.conditions?.best(.temperature)?.value, date: t.loggedAt,
                                         conditions: t.conditions, pollen: DemoPollen.sample(at: t.loggedAt, season: pollenSeason))
                                .frame(width: 84, height: 84)
                                .clipShape(.rect(cornerRadius: 20, style: .continuous))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(dayLabel(d.day)).font(.subheadline.weight(.semibold))
                                Text(t.weave.isEmpty ? "No air reading." : t.headline)
                                    .font(.footnote).foregroundStyle(Theme.secondaryText).lineLimit(2)
                                HStack(spacing: 4) {
                                    ForEach(d.moments) { MomentDot(moment: $0.moment, size: 7) }
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
            .padding(.bottom, 24)
        }
        .defaultScrollAnchor(.bottom)
        .scrollIndicators(.hidden)
    }

    private func dayLabel(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Today" }
        if cal.isDateInYesterday(d) { return "Yesterday" }
        return d.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}
