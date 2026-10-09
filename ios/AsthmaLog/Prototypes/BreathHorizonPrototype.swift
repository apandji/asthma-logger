#if DEBUG
import AsthmaCore
import SwiftData
import SwiftUI

/// Airways v2: "you are the horizon". The warm ground and the line are you; the line breathes slowly
/// (about 6 breaths a minute). The outdoor air is the sky above, one lane per family. Rescue moments
/// rest on the line at their hour. Sky and ground never touch: being together isn't cause.
/// The wave's rhythm (not its height) follows the example check-in: long swells = breathing felt easy.
struct BreathHorizonPrototype: View {
    @Query(sort: \LogEvent.loggedAt) private var events: [LogEvent]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selected: Date?

    var body: some View {
        let week = AirSky.week(events)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("The air above your week").font(Theme.headlineSerif)
                    Text("The warm line is you, breathing. The sky above it is the air outside. Tap a day.")
                        .font(.subheadline).foregroundStyle(Theme.secondaryText)
                }
                .padding(.horizontal, 20)

                VStack(spacing: 6) {
                    TimelineView(.animation(paused: reduceMotion)) { tl in
                        HorizonCanvas(week: week, selected: selected ?? week.last?.day,
                                      time: reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate, still: reduceMotion)
                    }
                    .frame(height: 340)
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { v in
                        // Map the tap to a day column.
                        let w = max(1, v.location.x) / max(1, widthGuess)
                        let i = min(week.count - 1, max(0, Int(w * CGFloat(week.count))))
                        withAnimation(.snappy) { selected = week[i].day }
                    })
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { widthGuess = $0 }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(week.map { "\($0.shortLabel): \($0.rescues) rescue moments" }.joined(separator: ", "))

                    HStack(spacing: 0) {
                        ForEach(week) { d in
                            Text(d.shortLabel)
                                .font(.caption.weight(d.day == (selected ?? week.last?.day) ? .semibold : .regular))
                                .foregroundStyle(d.day == (selected ?? week.last?.day) ? .primary : Theme.secondaryText)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 12)

                AirKey().padding(.horizontal, 20)

                if let d = week.first(where: { $0.day == (selected ?? week.last?.day) }) {
                    SkyDayCard(day: d, felt: true).padding(.horizontal, 16)
                }

                ExampleFootnote(extra: "Breathing scores are examples: the daily check-in isn't built yet.")
                    .padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
        }
        .background(Theme.stage.ignoresSafeArea())
        .navigationTitle("Airways v2")
        .navigationBarTitleDisplayMode(.inline)
    }

    @State private var widthGuess: CGFloat = 360
}

private struct HorizonCanvas: View {
    let week: [SkyDay]
    let selected: Date?
    let time: TimeInterval
    let still: Bool

    var body: some View {
        Canvas { ctx, size in
            let n = CGFloat(week.count)
            let colW = size.width / n
            let base = size.height * 0.74
            let breath = still ? 0.5 : (sin(time * 2 * .pi / 10) + 1) / 2   // 10 s = 6 breaths a minute
            let amp = 4 + breath * 6
            let lift = breath * 5

            // Selected day: a soft column of light.
            if let i = week.firstIndex(where: { $0.day == selected }) {
                let r = CGRect(x: CGFloat(i) * colW + 2, y: 0, width: colW - 4, height: size.height)
                ctx.fill(Path(roundedRect: r, cornerRadius: 14), with: .color(.primary.opacity(0.05)))
            }

            // Sky: one lane per family, marks placed by third of the day, drifting gently.
            let lanes: [AirFamily: CGFloat] = [.particles: 0.13, .gases: 0.33, .pollen: 0.53]
            for (di, day) in week.enumerated() {
                var rng = Seeded(day.day.timeIntervalSince1970 / 3600)
                for family in AirFamily.allCases {
                    for third in 0..<3 {
                        for kind in family.kinds {
                            let lv = day.level(kind, third: third)
                            guard lv > 0 else { continue }
                            let x = CGFloat(di) * colW + colW * (CGFloat(third) + 0.2 + rng.next() * 0.6) / 3
                            let drift = still ? 0 : sin(time * 0.35 + rng.next() * 6.28) * 2.5
                            let y = size.height * lanes[family]! + (rng.next() - 0.5) * 30 + drift
                            ctx.fill(AirMark.path(kind, center: CGPoint(x: x, y: y), radius: AirMark.radius(lv) * 0.85),
                                     with: .color(family.ink.opacity(lv == 1 ? 0.4 : 0.9)))
                        }
                    }
                }
            }

            // You: a breathing line whose rhythm follows the (example) check-in, warm ground below.
            var pts: [CGPoint] = []
            var phase: CGFloat = 0
            let step: CGFloat = 2
            var x: CGFloat = 0
            while x <= size.width {
                let di = min(week.count - 1, Int(x / colW))
                let felt = week[di].exampleFelt
                let cycles: CGFloat = felt >= 7 ? 1 : felt >= 5 ? 1.5 : 2.2
                pts.append(CGPoint(x: x, y: base - amp * sin(phase) - lift))
                phase += 2 * .pi * cycles * step / colW
                x += step
            }
            var line = Path()
            line.addLines(pts)
            var ground = line
            ground.addLine(to: CGPoint(x: size.width, y: size.height))
            ground.addLine(to: CGPoint(x: 0, y: size.height))
            ground.closeSubpath()
            let warm = Color(light: 0xF2B48C, dark: 0xB86A45)
            ctx.fill(ground, with: .linearGradient(Gradient(colors: [warm.opacity(0.75), warm.opacity(0)]),
                                                   startPoint: CGPoint(x: 0, y: base - 14), endPoint: CGPoint(x: 0, y: size.height)))
            ctx.stroke(line, with: .color(Color(light: 0xD9774A, dark: 0xFFA27A)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

            // Moments ride the line at their hour.
            func lineY(_ x: CGFloat) -> CGFloat { pts[min(pts.count - 1, max(0, Int(x / step)))].y }
            for (di, day) in week.enumerated() {
                for m in day.inhalerMoments {
                    let mx = CGFloat(di) * colW + AirSky.hourFraction(m.loggedAt) * colW
                    AirMark.moment(m.moment, center: CGPoint(x: mx, y: lineY(mx) - 11), size: 18, in: ctx)
                }
            }
        }
    }
}
#endif
