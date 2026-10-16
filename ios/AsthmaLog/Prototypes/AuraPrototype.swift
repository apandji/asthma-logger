#if DEBUG
import AsthmaCore
import SwiftData
import SwiftUI

/// Aura: one day as a clock seen from above. You are the soft, breathing shape in the middle;
/// the day's hours run around you (midnight at the top) and the outdoor air sits in rings outside,
/// particles nearest, then gases, then pollen. Moments sit on your edge at their hour.
/// The air never crosses into you.
struct AuraPrototype: View {
    @Query(sort: \LogEvent.loggedAt) private var events: [LogEvent]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selected: Date?

    var body: some View {
        let week = AirSky.week(events)
        let day = week.first { $0.day == (selected ?? week.last?.day) } ?? week.last!
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("You, and the air around you").font(Theme.headlineSerif)
                    Text("The day goes round like a clock. You're in the middle; the air outside is in rings around you.")
                        .font(.subheadline).foregroundStyle(Theme.secondaryText)
                }
                .padding(.horizontal, 20)

                TimelineView(.animation(paused: reduceMotion)) { tl in
                    AuraCanvas(day: day, time: reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate, still: reduceMotion)
                }
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, 12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.shortLabel): \(day.rescues) rescue moments")

                DayPicker(days: week, selected: $selected).padding(.horizontal, 16)
                AirKey().padding(.horizontal, 20)
                SkyDayCard(day: day).padding(.horizontal, 16)
                ExampleFootnote().padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
        }
        .background(Theme.stage.ignoresSafeArea())
        .navigationTitle("Aura")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AuraCanvas: View {
    let day: SkyDay
    let time: TimeInterval
    let still: Bool

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let s = min(size.width, size.height) / 2
            let breath = still ? 0.5 : (sin(time * 2 * .pi / 10) + 1) / 2
            func angle(_ hourFraction: CGFloat) -> CGFloat { hourFraction * 2 * .pi - .pi / 2 }
            func at(_ a: CGFloat, _ r: CGFloat) -> CGPoint { CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r) }

            // Faint rings and the hour ticks.
            let rings: [AirFamily: CGFloat] = [.particles: 0.58, .gases: 0.74, .pollen: 0.9]
            for (_, r) in rings {
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - s * r, y: c.y - s * r, width: s * r * 2, height: s * r * 2)),
                           with: .color(.primary.opacity(0.06)), lineWidth: 1)
            }
            for (h, label) in [(0, "12a"), (6, "6a"), (12, "noon"), (18, "6p")] {
                let p = at(angle(CGFloat(h) / 24), s * 0.47)
                ctx.draw(Text(label).font(.caption2).foregroundStyle(.secondary), at: p)
            }

            // Air: marks spread over each third's arc in their family's ring.
            var rng = Seeded(day.day.timeIntervalSince1970 / 60)
            for family in AirFamily.allCases {
                for third in 0..<3 {
                    for kind in family.kinds {
                        let lv = day.level(kind, third: third)
                        guard lv > 0 else { continue }
                        for _ in 0..<lv {
                            let hf = (CGFloat(third) * 8 + 0.6 + rng.next() * 6.8) / 24
                            let wobble = still ? 0 : sin(time * 0.3 + rng.next() * 6.28) * 0.012
                            let r = s * (rings[family]! + (rng.next() - 0.5) * 0.07)
                            ctx.fill(AirMark.path(kind, center: at(angle(hf + wobble), r), radius: AirMark.radius(lv) * 0.85),
                                     with: .color(family.ink.opacity(0.9)))
                        }
                    }
                }
            }

            // You: a soft membrane, a little more uneven on harder days, breathing slowly.
            let base = s * (0.3 + 0.03 * breath)
            let wob = CGFloat(10 - day.exampleFelt) * 0.006
            var you = Path()
            for i in 0...180 {
                let a = CGFloat(i) / 180 * 2 * .pi
                let t = CGFloat(time)
                let r = base * (1 + wob * sin(3 * a + t * 0.25) + wob * 0.6 * sin(5 * a - t * 0.18))
                i == 0 ? you.move(to: at(a, r)) : you.addLine(to: at(a, r))
            }
            you.closeSubpath()
            let warm = Color(light: 0xF2B48C, dark: 0xB86A45)
            ctx.fill(you, with: .radialGradient(Gradient(colors: [warm.opacity(0.95), warm.opacity(0.45)]),
                                                 center: c, startRadius: 0, endRadius: base * 1.1))
            ctx.stroke(you, with: .color(Color(light: 0xD9774A, dark: 0xFFA27A)), lineWidth: 2)

            // Moments on your edge.
            for m in day.inhalerMoments {
                AirMark.moment(m.moment, center: at(angle(AirSky.hourFraction(m.loggedAt)), base), size: 18, in: ctx)
            }
        }
    }
}
#endif
