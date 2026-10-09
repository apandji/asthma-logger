#if DEBUG
import AsthmaCore
import SwiftData
import SwiftUI

/// Sampler: the week as a cross-stitch cloth. Each row is a day; columns are the three families,
/// each split into night / day / evening. A cell gets more stitches as the level rises (0, 2, 5, 9 of
/// a 3×3 block), like the woven pattern that gets denser in steps. Inhaler moments are knots in the
/// margin. No body here on purpose: it's the divergent, textile-only option.
struct SamplerPrototype: View {
    @Query(sort: \LogEvent.loggedAt) private var events: [LogEvent]
    @State private var selected: Date?

    var body: some View {
        let week = AirSky.week(events)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("A week, stitched").font(Theme.headlineSerif)
                    Text("Each row is a day. More stitches = more of that in the air outside. Knots on the left are your inhaler moments.")
                        .font(.subheadline).foregroundStyle(Theme.secondaryText)
                }
                .padding(.horizontal, 20)

                VStack(spacing: 0) {
                    header
                    ForEach(week) { d in
                        Button { withAnimation(.snappy) { selected = d.day } } label: {
                            SamplerRow(day: d, isSelected: d.day == (selected ?? week.last?.day))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(d.shortLabel): \(d.rescues) rescue moments")
                    }
                }
                .padding(12)
                .background(Color(light: 0xF4EEE3, dark: 0x22201C), in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.08)))
                .padding(.horizontal, 12)

                if let d = week.first(where: { $0.day == (selected ?? week.last?.day) }) {
                    SkyDayCard(day: d).padding(.horizontal, 16)
                }
                ExampleFootnote(extra: "Each block shows the highest level in that family for that part of the day.")
                    .padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
        }
        .background(Theme.stage.ignoresSafeArea())
        .navigationTitle("Sampler")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: SamplerRow.margin)
            ForEach(AirFamily.allCases) { f in
                VStack(spacing: 2) {
                    Text(f.title).font(.caption2.weight(.semibold)).foregroundStyle(f.ink)
                    HStack(spacing: 0) {
                        ForEach(["N", "D", "E"], id: \.self) { Text($0).frame(maxWidth: .infinity) }
                    }
                    .font(.caption2).foregroundStyle(Theme.secondaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 6)
    }
}

private struct SamplerRow: View {
    static let margin: CGFloat = 54
    let day: SkyDay
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(day.shortLabel).font(.caption.weight(isSelected ? .semibold : .regular))
                Canvas { ctx, size in
                    // French knots: one per inhaler moment.
                    for (i, m) in day.inhalerMoments.prefix(6).enumerated() {
                        let x = 4 + CGFloat(i % 3) * 9, y = 4 + CGFloat(i / 3) * 9
                        ctx.fill(Path(ellipseIn: CGRect(x: x - 3.5, y: y - 3.5, width: 7, height: 7)),
                                 with: .color(m.moment == .rescue ? Theme.rescue : Theme.standard))
                    }
                }
                .frame(width: 30, height: 18)
            }
            .frame(width: Self.margin, alignment: .leading)

            Canvas { ctx, size in
                let cellW = size.width / 9
                for (fi, family) in AirFamily.allCases.enumerated() {
                    for third in 0..<3 {
                        let lv = day.level(family, third: third)
                        let x0 = CGFloat(fi * 3 + third) * cellW
                        let cell = CGRect(x: x0 + 2, y: 2, width: cellW - 4, height: size.height - 4)
                        // Linen grid under each block.
                        ctx.stroke(Path(roundedRect: cell, cornerRadius: 3), with: .color(.primary.opacity(0.06)), lineWidth: 0.5)
                        let order = [4, 0, 8, 2, 6, 1, 7, 3, 5]      // centre first, then corners, then edges
                        let count = [0, 2, 5, 9][lv]
                        let sw = min(cell.width, cell.height) / 3
                        for k in order.prefix(count) {
                            let sx = cell.midX + (CGFloat(k % 3) - 1) * sw
                            let sy = cell.midY + (CGFloat(k / 3) - 1) * sw
                            let h = sw * 0.36
                            var stitch = Path()
                            stitch.move(to: CGPoint(x: sx - h, y: sy - h)); stitch.addLine(to: CGPoint(x: sx + h, y: sy + h))
                            stitch.move(to: CGPoint(x: sx + h, y: sy - h)); stitch.addLine(to: CGPoint(x: sx - h, y: sy + h))
                            ctx.stroke(stitch, with: .color(family.ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        }
                    }
                }
            }
            .frame(height: 40)
        }
        .padding(.vertical, 4)
        .background(isSelected ? AnyShapeStyle(.primary.opacity(0.05)) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
    }
}
#endif
