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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "calendar").font(.system(size: 17, weight: .medium)).frame(width: 22)
                Text("Coming days").font(Theme.Figtree.font(size: 17, weight: .medium))
            }
            .padding(.vertical, 15)
            ForEach(days) { d in
                Divider().padding(.leading, 32)
                HStack(spacing: 10) {
                    Circle().fill(d.lead.map(AirBlanket.ink) ?? Color.primary.opacity(0.15)).frame(width: 10, height: 10)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.dayName(d.date)).font(Theme.Figtree.font(size: 16))
                        Text(d.lead.map { "\(Self.word($0)) leads" } ?? "Nothing stands out")
                            .font(Theme.Figtree.font(size: 13)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text(Self.likenessWord(d.likeness)).font(Theme.Figtree.font(size: 15, weight: (d.likeness ?? 0) >= 1 ? .medium : .regular))
                        .foregroundStyle((d.likeness ?? 0) > 0 ? Color.primary : .secondary)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.top, 12).padding(.bottom, Self.note(d) == nil ? 12 : 6)
                .accessibilityElement(children: .combine)
                // What might help on a day like your inhaler days, or a calm line on an ordinary one (April, Nov 20).
                if let note = Self.note(d) {
                    Text(note).font(Theme.Figtree.font(size: 14)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 32).padding(.bottom, 12)
                }
            }
            Text(days.contains { ($0.likeness ?? 0) > 0 } ? AirAdvice.disclaimer : "Outdoor forecast. Not a prediction of how you'll feel.")
                .font(Theme.Figtree.font(size: 13)).foregroundStyle(.secondary)
                .padding(.leading, 32).padding(.vertical, 12)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(uiColor: .secondarySystemGroupedBackground)))
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
        default: "Ordinary"
        }
    }
}
