#if DEBUG
import AsthmaCore
import SwiftData
import SwiftUI

/// Prototype of April's "airways" view: one tube per day whose width follows the daily breathing
/// check-in (0–10, wider = easier), with particles *beside* it sized by the air-quality band
/// (never entering it: being together isn't cause). Tube tint = temperature band. Moments sit at
/// their hour. The check-in doesn't exist yet, so scores here are examples (labelled on screen).
struct AirwaysPrototype: View {
    @Query(sort: \LogEvent.loggedAt) private var events: [LogEvent]
    @State private var selected: Date?

    private let days = 7

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your airways this week")
                        .font(Theme.headlineSerif)
                    Text("Each tube is a day. It's wider when you said breathing felt easy. The dots beside it are the air outside.")
                        .font(.subheadline).foregroundStyle(Theme.secondaryText)
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        ForEach(week) { day in
                            Button { withAnimation(.snappy) { selected = day.day } } label: {
                                AirwayColumn(day: day, isSelected: day.day == (selected ?? week.last?.day))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .defaultScrollAnchor(.trailing)
                .scrollIndicators(.hidden)

                key.padding(.horizontal, 20)

                if let day = week.first(where: { $0.day == (selected ?? week.last?.day) }) {
                    detail(day).padding(.horizontal, 16)
                }

                Text("Example check-in scores: the daily breathing check-in isn't built yet. Moments and air are from your Journal.")
                    .font(.caption).foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
        }
        .background(Theme.stage.ignoresSafeArea())
        .navigationTitle("Airways")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Data

    struct Day: Identifiable {
        let day: Date
        let moments: [LogEvent]
        /// 0–10, wider = easier. Example values until the check-in exists.
        let score: Int
        /// Air band per third of the day (night, day, evening); nil = no reading.
        let air: [WeaveSpec.Level?]
        let tempWord: String?
        var id: Date { day }
    }

    private var week: [Day] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<days).reversed().map { back in
            let day = cal.date(byAdding: .day, value: -back, to: today)!
            let next = cal.date(byAdding: .day, value: 1, to: day)!
            let ms = events.filter { $0.loggedAt >= day && $0.loggedAt < next }
            let air: [WeaveSpec.Level?] = (0..<3).map { third in
                let lo = cal.date(byAdding: .hour, value: third * 8, to: day)!
                let hi = cal.date(byAdding: .hour, value: 8, to: lo)!
                return ms.filter { $0.loggedAt >= lo && $0.loggedAt < hi }.compactMap { $0.weave.levels[.air] }.max()
            }
            let temp = ms.last(where: { $0.weave.words[.temperature] != nil })?.weave.words[.temperature]
            return Day(day: day, moments: ms, score: Self.exampleScore(ms), air: air, tempWord: temp)
        }
    }

    /// Stand-in for the check-in: fewer rescue moments and better air → easier breathing.
    private static func exampleScore(_ ms: [LogEvent]) -> Int {
        let rescues = ms.filter { $0.moment == .rescue }.count
        let worstAir = ms.compactMap { $0.weave.levels[.air]?.rawValue }.max() ?? 0
        return max(2, min(9, 9 - rescues * 2 - worstAir))
    }

    // MARK: Pieces

    private var key: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                ForEach(WeaveSpec.Level.allCases, id: \.self) { l in
                    Canvas { ctx, size in
                        ctx.fill(Sparkle.path(center: CGPoint(x: size.width / 2, y: size.height / 2), radius: AirwayColumn.dot(l) * 0.9), with: .color(Theme.secondaryText))
                    }
                    .frame(width: AirwayColumn.dot(l) * 2, height: AirwayColumn.dot(l) * 2)
                }
                Text("Air: good → poor")
            }
            HStack(spacing: 6) { MomentGlyph(moment: .rescue, size: 14); Text("Rescue") }
            HStack(spacing: 6) { MomentGlyph(moment: .maintenance, size: 14); Text("Standard") }
        }
        .font(.caption).foregroundStyle(Theme.secondaryText)
    }

    private func detail(_ day: Day) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(day.day.formatted(.dateTime.weekday(.wide).month().day())).font(.headline)
            LabeledContent("Breathing (example)", value: "\(day.score) of 10")
            LabeledContent("Rescue moments", value: "\(day.moments.filter { $0.moment == .rescue }.count)")
            LabeledContent("Air at its worst", value: day.air.compactMap { $0 }.max().map { ["Good", "Moderate", "Poor"][$0.rawValue] } ?? "No reading")
            if let t = day.tempWord { LabeledContent("Temperature", value: t.capitalized) }
        }
        .font(.subheadline)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frostedCard()
    }
}

/// One day: a soft tube (width from the score, gently pinched mid-day when breathing was hard),
/// particles on both sides per third of the day, and moments at their hour.
struct AirwayColumn: View {
    let day: AirwaysPrototype.Day
    let isSelected: Bool

    private let height: CGFloat = 340
    private let columnWidth: CGFloat = 92

    static func dot(_ l: WeaveSpec.Level) -> CGFloat { [4, 7, 11][l.rawValue] }

    var body: some View {
        VStack(spacing: 8) {
            Canvas { ctx, size in
                let cx = size.width / 2
                // Width from the check-in; a soft mid-day narrowing on harder days, but never closed.
                let w = 26 + CGFloat(day.score) * 3.4
                let pinch = CGFloat(10 - day.score) * 0.9
                var left: [CGPoint] = [], right: [CGPoint] = []
                for j in 0...120 {
                    let t = CGFloat(j) / 120
                    let y = size.height * t
                    // Scalloped wall like the shape pack's wavy columns: rounder on easy days, choppier on hard ones.
                    let bumps = CGFloat(day.score >= 7 ? 5 : 8)
                    let ripple = abs(sin(t * .pi * bumps)) * (day.score >= 7 ? 3 : 4.5)
                    let half = max(11, w / 2 - pinch * sin(t * .pi)) + ripple
                    left.append(CGPoint(x: cx - half, y: y)); right.append(CGPoint(x: cx + half, y: y))
                }
                var tube = Path()
                tube.addLines(left + right.reversed()); tube.closeSubpath()
                ctx.fill(tube, with: .color(tint.opacity(isSelected ? 0.95 : 0.7)))

                // Particles beside the tube (seeded per day so they don't jump).
                var seed = UInt64(day.day.timeIntervalSince1970)
                func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(seed >> 33) / CGFloat(UInt32.max >> 1) }
                for (third, level) in day.air.enumerated() {
                    guard let level else { continue }
                    let n = 2 + level.rawValue * 2
                    for _ in 0..<n {
                        let side: CGFloat = rnd() < 0.5 ? -1 : 1
                        let y = size.height * (CGFloat(third) + rnd()) / 3
                        let x = cx + side * (w / 2 + 10 + rnd() * 12)
                        ctx.fill(Sparkle.path(center: CGPoint(x: x, y: y), radius: Self.dot(level) * 0.9),
                                 with: .color(Theme.secondaryText.opacity(0.8)))
                    }
                }
            }
            .frame(width: columnWidth, height: height)
            .overlay(alignment: .top) {
                // Moments at their hour, on the tube's centre line.
                ZStack(alignment: .top) {
                    ForEach(day.moments.filter { $0.moment != .okay }) { m in
                        MomentGlyph(moment: m.moment, size: 18)
                            .offset(y: height * hourFraction(m.loggedAt) - 9)
                    }
                }
            }
            Text(label).font(.footnote.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : Theme.secondaryText)
            Text("\(day.score)/10").font(.caption2.monospacedDigit()).foregroundStyle(Theme.secondaryText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): breathing \(day.score) of 10 (example), \(day.moments.filter { $0.moment == .rescue }.count) rescue moments")
    }

    private var tint: Color {
        switch day.tempWord {
        case "hot": Color(light: 0xF2C9A8, dark: 0x8A5A3C)
        case "cold": Color(light: 0xC9DAD3, dark: 0x3E5A52)
        default: Color(light: 0xB8C2E6, dark: 0x4A5482)
        }
    }

    private var label: String {
        Calendar.current.isDateInToday(day.day) ? "Today" : day.day.formatted(.dateTime.weekday(.abbreviated))
    }

    private func hourFraction(_ d: Date) -> CGFloat {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return (CGFloat(c.hour ?? 0) + CGFloat(c.minute ?? 0) / 60) / 24
    }
}

/// Soft four-point sparkle (shape pack 19/20): one air particle.
enum Sparkle {
    static func path(center c: CGPoint, radius r: CGFloat) -> Path {
        var p = Path()
        let pts = (0..<4).map { i -> CGPoint in
            let a = CGFloat(i) * .pi / 2 - .pi / 2
            return CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
        }
        p.move(to: pts[0])
        for i in 0..<4 { p.addQuadCurve(to: pts[(i + 1) % 4], control: c) }
        p.closeSubpath()
        return p
    }
}

/// Rescue = five-petal flower (shape pack 14), standard = sparkle (19). Shape differs, not just colour.
struct MomentGlyph: View {
    let moment: MomentKind
    let size: CGFloat

    var body: some View {
        Canvas { ctx, sz in
            let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
            switch moment {
            case .rescue:
                let r = sz.width * 0.22
                for i in 0..<5 {
                    let a = CGFloat(i) * 2 * .pi / 5 - .pi / 2
                    let pc = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                    ctx.fill(Path(ellipseIn: CGRect(x: pc.x - r, y: pc.y - r, width: r * 2, height: r * 2)), with: .color(Theme.rescue))
                }
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(Theme.rescue))
            case .maintenance:
                ctx.fill(Sparkle.path(center: c, radius: sz.width * 0.48), with: .color(Theme.standard))
            case .okay:
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - sz.width * 0.3, y: c.y - sz.width * 0.3, width: sz.width * 0.6, height: sz.width * 0.6)), with: .color(Theme.secondaryText), lineWidth: 2)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
#endif
