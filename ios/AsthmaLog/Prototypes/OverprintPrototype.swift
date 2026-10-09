#if DEBUG
import AsthmaCore
import SwiftData
import SwiftUI

/// Overprint: the week as a riso print. Each family is one ink layer, printed as a halftone hill whose
/// height follows its level through the week; the layers overlap slightly off-register, like real riso.
/// Your inhaler moments are solid marks along the top edge. Divergent: print, not body.
struct OverprintPrototype: View {
    @Query(sort: \LogEvent.loggedAt) private var events: [LogEvent]
    @Environment(\.colorScheme) private var scheme
    @State private var selected: Date?

    var body: some View {
        let week = AirSky.week(events)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Three inks, one week").font(Theme.headlineSerif)
                    Text("Each colour is one kind of air, printed as hills: taller where it was higher. Your inhaler moments are along the top.")
                        .font(.subheadline).foregroundStyle(Theme.secondaryText)
                }
                .padding(.horizontal, 20)

                VStack(spacing: 6) {
                    OverprintCanvas(week: week, selected: selected ?? week.last?.day, dark: scheme == .dark)
                        .frame(height: 300)
                        .padding(14)
                        .background(Color(light: 0xF7F3EA, dark: 0x16151B), in: RoundedRectangle(cornerRadius: 18))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Particles, gases and pollen through the week")
                    DayPicker(days: week, selected: $selected)
                }
                .padding(.horizontal, 12)

                HStack(spacing: 14) {
                    ForEach(AirFamily.allCases) { f in
                        HStack(spacing: 6) { Circle().fill(f.ink).frame(width: 10, height: 10); Text(f.title) }
                    }
                }
                .font(.caption).foregroundStyle(Theme.secondaryText)
                .padding(.horizontal, 20)

                if let d = week.first(where: { $0.day == (selected ?? week.last?.day) }) {
                    SkyDayCard(day: d).padding(.horizontal, 16)
                }
                ExampleFootnote().padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
        }
        .background(Theme.stage.ignoresSafeArea())
        .navigationTitle("Overprint")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct OverprintCanvas: View {
    let week: [SkyDay]
    let selected: Date?
    let dark: Bool

    var body: some View {
        // Levels per family per third, worked out before drawing.
        let levels = AirFamily.allCases.map { f in week.flatMap { d in (0..<3).map { CGFloat(d.level(f, third: $0)) } } }
        let selectedIndex = week.firstIndex { $0.day == selected }
        let moments = week.enumerated().flatMap { di, d in d.inhalerMoments.enumerated().map { (di, $0.offset, $0.element.moment, AirSky.hourFraction($0.element.loggedAt)) } }
        Canvas { ctx, size in
            let n = levels[0].count
            let top: CGFloat = 30
            let floor = size.height
            let colW = size.width / CGFloat(max(1, levels[0].count / 3))

            if let i = selectedIndex {
                ctx.fill(Path(roundedRect: CGRect(x: CGFloat(i) * colW, y: 0, width: colW, height: size.height), cornerRadius: 10),
                         with: .color(.primary.opacity(0.05)))
            }

            // Level through the week per family, smoothed between thirds.
            func level(_ f: AirFamily, _ x: CGFloat) -> CGFloat {
                let t = x / size.width * CGFloat(n) - 0.5
                let i0 = max(0, min(n - 1, Int(t.rounded(.down)))), i1 = max(0, min(n - 1, i0 + 1))
                let u = max(0, min(1, t - CGFloat(i0)))
                func v(_ i: Int) -> CGFloat { levels[f.rawValue][i] }
                let k = (1 - cos(u * .pi)) / 2
                return v(i0) * (1 - k) + v(i1) * k
            }

            var layer = ctx
            layer.blendMode = dark ? .screen : .multiply
            let spacing: CGFloat = 7
            let offsets: [AirFamily: CGSize] = [.particles: .zero, .gases: CGSize(width: 2.5, height: -1.5), .pollen: CGSize(width: -2, height: 2)]
            let angles: [AirFamily: CGFloat] = [.particles: 0, .gases: 0.5, .pollen: 0.25]   // screen offset per ink
            for family in AirFamily.allCases {
                var dots = Path()
                let o = offsets[family]!
                var y = floor
                var row = 0
                while y > top {
                    var x = (angles[family]! + (row.isMultiple(of: 2) ? 0 : 0.5)) * spacing
                    while x < size.width {
                        let hill = floor - (floor - top) * level(family, x) / 3 * 0.92
                        if y > hill {
                            // Dots grow toward the bottom of the hill: deeper = denser ink.
                            let depth = min(1, (y - hill) / max(20, floor - hill))
                            let r = spacing * (0.16 + 0.34 * depth)
                            dots.addEllipse(in: CGRect(x: x + o.width - r, y: y + o.height - r, width: r * 2, height: r * 2))
                        }
                        x += spacing
                    }
                    y -= spacing * 0.87
                    row += 1
                }
                layer.fill(dots, with: .color(family.ink.opacity(0.85)))
            }

            // Moments along the top edge, at their hour.
            for (di, j, kind, hour) in moments {
                let x = CGFloat(di) * colW + hour * colW
                AirMark.moment(kind, center: CGPoint(x: x, y: 10 + CGFloat(j % 2) * 4), size: 16, in: ctx)
            }
        }
    }
}
#endif
