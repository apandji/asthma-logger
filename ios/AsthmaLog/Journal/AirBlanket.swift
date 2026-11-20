import AsthmaCore
import SwiftUI

/// Moments › Year (April, Nov 20): the year as an air blanket, after a temperature blanket. A row per month, a
/// stitch per day in the ink of the flower that led the air that day (home's inks), deeper when it was higher.
/// Each month is one continuous wash, so runs of days read as seasons; inhaler days are ticks beneath it. Zoomed out like this, the seasons show as bands: pollen in spring and autumn,
/// smoke in late summer, cold and flu in winter. Days with no reading are left as open stitches, not guessed.
struct AirBlanket: View {
    let year: Int
    /// Every moment with air: inhaler, manual and baseline (baselines fill in the ordinary days).
    let events: [LogEvent]
    let now: Date
    private let cal = Calendar.current

    struct Day { var lead: String; var strength: Double; var inhaler: Bool }

    /// How high each condition was, 0…1, on the same rough scales as home's fans.
    static func scores(_ c: ConditionsInput, flu: InfectionLevel?) -> [String: Double] {
        func risk(_ r: String?) -> Double? {
            switch r?.lowercased() {
            case "low"?: 0.2
            case "moderate"?: 0.55
            case "high"?: 0.85
            case "very high"?: 1
            default: nil
            }
        }
        var s: [String: Double] = [:]
        if let v = c.pm25 { s["PM2.5"] = min(1, v / 35) }
        if c.fireNearby == true { s["PM2.5"] = max(s["PM2.5"] ?? 0, 0.9) }
        if let v = c.ozonePpb { s["Ozone"] = min(1, v / 70) }
        if let p = [risk(c.pollenTreeRisk), risk(c.pollenGrassRisk), risk(c.pollenWeedRisk)].compactMap({ $0 }).max() { s["Pollen"] = p }
        if let t = c.temperatureF {
            if t < 50 { s["Cold air"] = min(1, (65 - t) / 35) } else { s["Temperature"] = min(1, max(0, t - 65) / 30) }
        }
        if let h = c.humidityPct { s["Humidity"] = min(1, max(0, (h - 50) / 45)) }
        if let w = c.windMph { s["Wind"] = min(1, w / 22) }
        if let p = c.pressureChangeHpa { s["Pressure"] = min(1, abs(p) / 5) }
        switch flu {
        case .high?: s["Flu"] = 0.9
        case .moderate?: s["Flu"] = 0.55
        default: break
        }
        return s
    }

    /// Watercolour palette (April, Nov 20: calmer than the flowers' full inks, mid-tone like paint on paper).
    /// Same hue for each condition as the garden, so they still read as one family.
    static func ink(_ name: String) -> Color {
        func hex(_ v: UInt32) -> Color {
            Color(red: Double(v >> 16 & 0xFF) / 255, green: Double(v >> 8 & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
        }
        return switch name {
        case "Pollen": hex(0xE9C35A)
        case "Cold air": hex(0xA6C8E0)
        case "Wind": hex(0xB3B0C7)
        case "Ozone": hex(0xE59AB2)
        case "PM2.5": hex(0x7097D6)
        case "Humidity": hex(0x7FBDB6)
        case "Flu": hex(0xA9C08A)
        case "Pressure": hex(0xA99BD6)
        case "Temperature": hex(0xE8907A)
        default: MenusProfileFlower.ink(name)
        }
    }

    /// Each day of the year that has air: the condition that was highest (strongest across its moments).
    private var days: [Date: Day] {
        var best: [Date: [String: Double]] = [:]
        var inhaler: Set<Date> = []
        for e in events where cal.component(.year, from: e.loggedAt) == year {
            let d = cal.startOfDay(for: e.loggedAt)
            if e.moment == .rescue { inhaler.insert(d) }
            guard let c = e.conditions else { continue }
            var day = best[d] ?? [:]
            for (k, v) in Self.scores(c.input, flu: e.infection) { day[k] = max(day[k] ?? 0, v) }
            best[d] = day
        }
        var out: [Date: Day] = [:]
        for d in Set(best.keys).union(inhaler) {
            let lead = best[d]?.max { $0.value < $1.value }
            out[d] = Day(lead: lead?.key ?? "", strength: lead?.value ?? 0, inhaler: inhaler.contains(d))
        }
        return out
    }

    /// Too few of your own days to show seasons: a sample year stands in, labelled as such.
    private var usesSample: Bool { days.values.filter { !$0.lead.isEmpty }.count < 45 }

    /// A made-up Midwest year, so the blanket shows what it's for (April, Nov 20): tree pollen in April, grass in
    /// late May, storms through spring, ozone and heat waves in summer, wildfire smoke drifting in late July to
    /// early September, ragweed in September, cold and flu in winter. Inhaler days fall more in the peaks.
    /// Deterministic per year, never stored, never in patterns.
    static func sample(year: Int) -> [Date: Day] {
        let cal = Calendar.current
        var seed = UInt64(year) &* 2654435761
        func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 11) / Double(1 << 53) }
        func bump(_ d: Double, _ c: Double, _ w: Double) -> Double {
            let x = min(abs(d - c), 365 - abs(d - c)); return exp(-(x / w) * (x / w))
        }
        let start = cal.date(from: DateComponents(year: year, month: 1, day: 1))!
        var out: [Date: Day] = [:]
        var smokeRun = 0, heatRun = 0
        for i in 0..<365 {
            let d = Double(i)
            if (205...245).contains(i), smokeRun == 0, rnd() < 0.12 { smokeRun = 3 + Int(rnd() * 5) }
            if (185...225).contains(i), heatRun == 0, rnd() < 0.08 { heatRun = 4 + Int(rnd() * 4) }
            var v: [String: Double] = [:]
            v["Pollen"] = max(0.95 * bump(d, 103, 20), 0.85 * bump(d, 145, 16), 0.9 * bump(d, 250, 17))
            v["Temperature"] = heatRun > 0 ? 0.95 : 0.45 * bump(d, 200, 30)
            v["PM2.5"] = smokeRun > 0 ? 0.85 + 0.15 * rnd() : 0.15 + 0.1 * rnd()
            v["Ozone"] = 0.7 * bump(d, 190, 32)
            v["Humidity"] = 0.12 + 0.5 * bump(d, 205, 38)
            v["Pressure"] = (95...180).contains(i) && rnd() < 0.18 ? 0.75 + 0.25 * rnd() : 0.1
            v["Wind"] = 0.2 + 0.5 * max(bump(d, 75, 22), bump(d, 310, 22)) * rnd()
            // A cold or flu going around is a short spell, not the whole winter: two spells of about a week.
            v["Flu"] = (8...15).contains(i) || (40...46).contains(i) ? 0.9 : 0
            // Winter is cold air (and dry, still days), not illness.
            // Winter is cold air, with autumn's first cold snaps in November.
            v["Cold air"] = max(0.85 * max(bump(d, 20, 32), bump(d, 350, 22)), 0.65 * bump(d, 315, 16))
            for k in v.keys { v[k] = min(1, max(0, v[k]! * (0.85 + 0.3 * rnd()))) }
            if smokeRun > 0 { smokeRun -= 1 }
            if heatRun > 0 { heatRun -= 1 }
            let lead = v.max { $0.value < $1.value }!
            let p = 0.025 + 0.3 * max(0, v["Pollen"]! - 0.55) + 0.45 * max(0, v["PM2.5"]! - 0.6)
                + 0.2 * max(0, v["Flu"]! - 0.5) + 0.15 * max(0, v["Temperature"]! - 0.8)
            let day = cal.date(byAdding: .day, value: i, to: start)!
            out[day] = Day(lead: lead.key, strength: lead.value, inhaler: rnd() < p)
        }
        return out
    }

    var body: some View {
        let sample = usesSample
        let data = sample ? Self.sample(year: year) : days
        let today = sample ? .distantFuture : cal.startOfDay(for: now)
        VStack(alignment: .leading, spacing: 0) {
            // The card's title, as on Day and Month: the year, and what you're looking at.
            VStack(alignment: .leading, spacing: 2) {
                Text(String(year)).font(Theme.Figtree.font(size: 17, weight: .medium))
                Text(sample ? "Sample year · yours fills in as you log" : "The air each day, in the colour that led it")
                    .font(Theme.Figtree.font(size: 13)).foregroundStyle(.secondary)
            }
            .padding(.vertical, 15)
            Divider().padding(.bottom, 12)
        VStack(alignment: .leading, spacing: 4) {
            ForEach(1...12, id: \.self) { m in
                let first = cal.date(from: DateComponents(year: year, month: m, day: 1))!
                let count = cal.range(of: .day, in: .month, for: first)!.count
                HStack(alignment: .top, spacing: 6) {
                    Text(first.formatted(.dateTime.month(.narrow)))
                        .font(Theme.Figtree.font(size: 11, weight: .medium)).foregroundStyle(.secondary)
                        .frame(width: 12, height: Self.band, alignment: .leading)
                    // One continuous wash per month (April, Nov 20: consecutive days flow into each other):
                    // each day is a colour stop in its leading ink, days with no reading fade to paper, and the
                    // inhaler days are small ticks under the wash, like the timeline's.
                    GeometryReader { g in
                        let w = g.size.width * CGFloat(count) / 31
                        let dates = (0..<count).map { cal.date(byAdding: .day, value: $0, to: first)! }
                        ZStack(alignment: .topLeading) {
                            // Flat, no blur (April, Nov 20: the blur shaded the band like a tube): one even
                            // wash across the month, days blending only into their neighbours, on a faint track.
                            RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.primary.opacity(0.04))
                                .frame(width: w, height: Self.band)
                            RoundedRectangle(cornerRadius: 5, style: .continuous).fill(LinearGradient(stops: dates.enumerated().map { i, d in
                                    .init(color: wash(data[d], future: d > today), location: (CGFloat(i) + 0.5) / CGFloat(count))
                                }, startPoint: .leading, endPoint: .trailing))
                                .frame(width: w, height: Self.band)
                            ForEach(Array(dates.enumerated()), id: \.offset) { i, d in
                                if data[d]?.inhaler == true {
                                    Capsule().fill(Color.primary)
                                        .frame(width: 2, height: 5)
                                        .offset(x: w * (CGFloat(i) + 0.5) / CGFloat(count) - 1, y: Self.band + 3)
                                }
                            }
                        }
                    }
                }
                .frame(height: Self.band + 10)
            }
            legend(data).padding(.top, 12)
        }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary(data))
    }

    /// A month's band, thick enough to read as a season (April, Nov 20).
    static let band: CGFloat = 24

    /// A day's colour in the wash: its leading flower's ink, deeper when the air was higher; paper when there's
    /// no reading (so the wash fades out rather than guessing).
    private func wash(_ day: Day?, future: Bool) -> Color {
        guard let day, !day.lead.isEmpty, !future else { return Self.ink("PM2.5").opacity(0) }
        return Self.ink(day.lead).opacity(0.45 + 0.55 * day.strength)
    }

    /// Only the inks that appear this year, most days first, then the dot.
    private func legend(_ data: [Date: Day]) -> some View {
        let counts = Dictionary(grouping: data.values.filter { !$0.lead.isEmpty }, by: \.lead).mapValues(\.count)
        let shown = counts.sorted { $0.value > $1.value }.map(\.key)
        return FlowLayout(spacing: 12) {
            ForEach(shown, id: \.self) { k in
                HStack(spacing: 5) {
                    Capsule().fill(LinearGradient(colors: [Self.ink(k).opacity(0.35), Self.ink(k), Self.ink(k).opacity(0.35)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 14, height: 8)
                    Text(k).font(Theme.Figtree.font(size: 12)).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 5) {
                Capsule().fill(Color.primary).frame(width: 2, height: 6)
                Text("Inhaler").font(Theme.Figtree.font(size: 12)).foregroundStyle(.secondary)
            }
            HStack(spacing: 5) {
                Capsule().fill(Color.primary.opacity(0.06)).frame(width: 14, height: 8)
                Text("No reading").font(Theme.Figtree.font(size: 12)).foregroundStyle(.secondary)
            }
        }
    }

    private func summary(_ data: [Date: Day]) -> String {
        let counts = Dictionary(grouping: data.values.filter { !$0.lead.isEmpty }, by: \.lead).mapValues(\.count)
        let top = counts.sorted { $0.value > $1.value }.prefix(3).map(\.key)
        let inhaler = data.values.filter(\.inhaler).count
        return "\(year) as an air blanket. Leading most days: \(top.joined(separator: ", ")). \(inhaler) inhaler days marked."
    }
}
