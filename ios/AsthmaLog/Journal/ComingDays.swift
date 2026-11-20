import AsthmaCore
import SwiftUI

/// Home, under the flowers (April, Nov 20): the next few days at a glance, from the same forecast the timeline
/// shows past Now. Each day: what will lead the air (in its flower's ink) and how much it looks like your inhaler
/// days, in words. Never a percent, never "you will". Outdoor forecast only.
struct ComingDays: View {
    struct Day: Identifiable {
        let date: Date
        /// The condition that leads the day's air ("Pollen"), or nil when the forecast says nothing stands out.
        let lead: String?
        /// 0 ordinary, 0.5 a little like your inhaler days, 1 like them; nil while still learning.
        let likeness: Double?
        var id: Date { date }
    }

    let days: [Day]

    /// The first day that looks like your inhaler days, if any: the summary and the one set of tips are about it.
    private var flagged: Day? { days.first { ($0.likeness ?? 0) >= 1 } ?? days.first { ($0.likeness ?? 0) > 0 } }

    /// The forecast in one sentence, like Home's headline (April, Nov 20): "Tomorrow looks like your inhaler
    /// days, with pollen leading." or "The next few days look like your usual days."
    private var summary: String {
        if let f = flagged {
            let when = Self.dayName(f.date) == "Rest of today" ? "Today" : Self.dayName(f.date)
            let lead = f.lead.map { ", with \(Self.word($0).lowercased()) leading" } ?? ""
            return (f.likeness ?? 0) >= 1 ? "\(when) looks like your inhaler days\(lead)." : "\(when) looks a little like your inhaler days\(lead)."
        }
        if days.allSatisfy({ $0.likeness == nil }) { return "Still learning which days look like yours." }
        return "The next few days look like your usual days."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "calendar").font(.system(size: 15, weight: .medium)).frame(width: 22)
                Text("Forecast").font(Theme.Figtree.font(size: 15, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .padding(.top, 15)
            // The forecast, said once, big.
            Text(summary).font(Theme.Figtree.font(size: 22, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8).padding(.bottom, 14)
            // Each day on one line: the day, what leads, and a word.
            ForEach(days) { d in
                Divider()
                HStack(spacing: 10) {
                    Circle().fill(d.lead.map(AirBlanket.ink) ?? Color.primary.opacity(0.15)).frame(width: 10, height: 10)
                    Text(Self.dayName(d.date)).font(Theme.Figtree.font(size: 16, weight: (d.likeness ?? 0) >= 1 ? .medium : .regular))
                    Text(d.lead.map(Self.word) ?? "Nothing stands out").font(Theme.Figtree.font(size: 14)).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(Self.shortWord(d.likeness)).font(Theme.Figtree.font(size: 14, weight: (d.likeness ?? 0) >= 1 ? .medium : .regular))
                        .foregroundStyle((d.likeness ?? 0) > 0 ? Color.primary : .secondary)
                }
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
            }
            // What might help, once, for the day it's about.
            if let f = flagged, let tip = Self.note(f) {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("For \(Self.dayName(f.date).lowercased() == "rest of today" ? "today" : Self.dayName(f.date).lowercased())")
                        .font(Theme.Figtree.font(size: 13, weight: .medium)).foregroundStyle(.secondary)
                    Text(tip).font(Theme.Figtree.font(size: 15)).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 12)
            }
            Text(flagged != nil ? AirAdvice.disclaimer : "Outdoor forecast. Not a prediction of how you'll feel.")
                .font(Theme.Figtree.font(size: 12)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 14)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(uiColor: .secondarySystemGroupedBackground)))
    }

    static func shortWord(_ v: Double?) -> String {
        switch v {
        case nil: "Learning"
        // A plain flag, the summary says why (April, Nov 20: "Like yours" didn't read).
        case let x? where x >= 1: "Heads-up"
        case let x? where x > 0: "Maybe"
        default: "Usual"
        }
    }

    /// On a day that looks like your inhaler days: the leading trigger's going-out suggestion (docs/air-advice.md:
    /// a provocation, not cited guidance). On an ordinary day: a calm line, never "a good day".
    static func note(_ d: Day) -> String? {
        guard let likeness = d.likeness else { return nil }
        if likeness > 0, let lead = d.lead, let factor = factor(lead) {
            let w = AirAdvice.warning(factor)
            return w.goingOut + " " + w.stayingPut
        }
        if likeness == 0 { return "Nothing in the forecast looks like your inhaler days." }
        return nil
    }

    static func factor(_ lead: String) -> AirAdvice.Factor? {
        switch lead {
        case "Pollen": .treePollen
        case "PM2.5": .pm25
        case "Ozone": .ozone
        default: nil
        }
    }

    static func dayName(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Rest of today" }
        if cal.isDateInTomorrow(d) { return "Tomorrow" }
        return d.formatted(.dateTime.weekday(.wide))
    }

    static func word(_ lead: String) -> String {
        switch lead {
        case "PM2.5": "Fine particles"
        case "Cold air": "Cold air"
        default: lead
        }
    }

    static func likenessWord(_ v: Double?) -> String {
        switch v {
        case nil: "Still learning"
        case let x? where x >= 1: "Like your inhaler days"
        case let x? where x > 0: "A little like them"
        default: "Usual"
        }
    }
}
