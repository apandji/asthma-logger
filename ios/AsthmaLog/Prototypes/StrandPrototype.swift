#if DEBUG
import AsthmaCore
import SwiftData
import SwiftUI

/// Strand, after Posavec & Quick's "Air Transformed" necklaces and Lupi & King's "Bruises".
/// The week is a necklace of 21 beads, one per part of the day. A bead grows and gets spikier as the
/// worst particle or gas level rises: small and smooth is clean air. Pollen hangs below as a flower
/// charm, only when it's moderate or high. Inhaler moments sit just inside the thread at their hour;
/// "I'm okay" moments are warm spots. Tap a bead for that day.
struct StrandPrototype: View {
    @Query(sort: \LogEvent.loggedAt) private var events: [LogEvent]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selected: Date?
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        let week = AirSky.week(events)
        let sel = selected ?? week.last?.day
        let spec = StrandBuild.spec(week, selected: sel)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("A week you could wear").font(Theme.headlineSerif)
                    Text("One bead for each part of the day. Bigger and spikier when the air was worse. Flowers hang where pollen was up.")
                        .font(.subheadline).foregroundStyle(Theme.secondaryText)
                }
                .padding(.horizontal, 20)

                TimelineView(.animation(paused: reduceMotion)) { tl in
                    StrandCanvas(spec: spec, time: reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate)
                }
                .frame(height: 440)
                .padding(.horizontal, 8)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { canvasSize = $0 }
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { v in
                    if let i = StrandLayout.bead(near: v.location, size: canvasSize, count: spec.beads.count) {
                        withAnimation(.snappy) { selected = week[min(week.count - 1, i / 3)].day }
                    }
                })
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(week.map { "\($0.shortLabel): \($0.rescues) rescue moments" }.joined(separator: ", "))

                key.padding(.horizontal, 20)

                if let d = week.first(where: { $0.day == sel }) {
                    SkyDayCard(day: d).padding(.horizontal, 16)
                }
                ExampleFootnote(extra: "Each bead is the worst of particles and gases for that part of the day.")
                    .padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
        }
        .background(Theme.stage.ignoresSafeArea())
        .navigationTitle("Strand")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var key: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<4) { lv in
                    Canvas { ctx, size in
                        StrandDraw.bead(ctx, at: CGPoint(x: size.width / 2, y: size.height / 2), level: lv, color: StrandBuild.beadColor(lv))
                    }
                    .frame(width: 28, height: 28)
                }
                Text("Clean → worse air")
            }
            HStack(spacing: 14) {
                HStack(spacing: 6) { MomentGlyph(moment: .rescue, size: 13); Text("Rescue") }
                HStack(spacing: 6) { Circle().fill(Theme.standard).frame(width: 7, height: 7); Text("Standard") }
                HStack(spacing: 6) { Circle().fill(StrandBuild.okay).frame(width: 7, height: 7); Text("I'm okay") }
            }
        }
        .font(.caption).foregroundStyle(Theme.secondaryText)
    }
}

// MARK: Spec (plain values, worked out before drawing)

nonisolated struct StrandBead: Sendable {
    let air: Int
    let pollen: Int
    let pollenLobes: Int
    let color: Color
    let pollenColor: Color
    let selected: Bool
}

nonisolated struct StrandKnot: Sendable {
    /// Position in bead units, 0 ..< 21.
    let at: Double
    let kind: Int   // 0 rescue, 1 standard, 2 okay
    let color: Color
}

nonisolated struct StrandSpec: Sendable {
    let beads: [StrandBead]
    let knots: [StrandKnot]
    let labels: [String]
    let thread: Color
}

enum StrandBuild {
    static let okay = Color(light: 0xE0A82E, dark: 0xF2C14E)

    static func beadColor(_ level: Int) -> Color {
        switch level {
        case 0, 1: Color(light: 0x8FB3A0, dark: 0x7FA894)      // sage: clean
        case 2: Color(light: 0x6A78C9, dark: 0x8A9BFF)         // periwinkle
        default: Color(light: 0x34307A, dark: 0xB9B3FF)        // deep ink
        }
    }

    static func spec(_ week: [SkyDay], selected: Date?) -> StrandSpec {
        var beads: [StrandBead] = []
        var knots: [StrandKnot] = []
        for (di, day) in week.enumerated() {
            for third in 0..<3 {
                let air = max(day.level(.particles, third: third), day.level(.gases, third: third))
                let pollenKind = AirFamily.pollen.kinds.max { day.level($0, third: third) < day.level($1, third: third) } ?? .weed
                beads.append(StrandBead(air: air, pollen: day.level(.pollen, third: third), pollenLobes: pollenKind.lobes,
                                        color: beadColor(air), pollenColor: AirFamily.pollen.ink, selected: day.day == selected))
            }
            for m in day.moments {
                let at = Double(di * 3) + Double(AirSky.hourFraction(m.loggedAt)) * 3
                switch m.moment {
                case .rescue: knots.append(StrandKnot(at: at, kind: 0, color: Theme.rescue))
                case .maintenance: knots.append(StrandKnot(at: at, kind: 1, color: Theme.standard))
                case .okay: knots.append(StrandKnot(at: at, kind: 2, color: okay))
                }
            }
        }
        return StrandSpec(beads: beads, knots: knots, labels: week.map(\.shortLabel), thread: Color(light: 0xB9B2A6, dark: 0x5A564F))
    }
}

// MARK: Layout and drawing

nonisolated enum StrandLayout {
    /// A necklace laid on the page: a deep U from top-left to top-right.
    static func curve(_ size: CGSize) -> [CGPoint] {
        let m: CGFloat = 26, top: CGFloat = 26, depth = size.height - 90
        return (0...200).map { i in
            let t = CGFloat(i) / 200
            let u = 2 * t - 1
            return CGPoint(x: m + t * (size.width - 2 * m), y: top + depth * (1 - pow(abs(u), 2.4)))
        }
    }

    /// Point and inward normal at a fraction of the curve's length.
    static func at(_ f: CGFloat, _ pts: [CGPoint], _ cum: [CGFloat]) -> (CGPoint, CGVector) {
        let target = f * (cum.last ?? 0)
        var i = 1
        while i < cum.count - 1 && cum[i] < target { i += 1 }
        let a = pts[i - 1], b = pts[i]
        let seg = max(0.0001, cum[i] - cum[i - 1])
        let k = (target - cum[i - 1]) / seg
        let p = CGPoint(x: a.x + (b.x - a.x) * k, y: a.y + (b.y - a.y) * k)
        let dx = b.x - a.x, dy = b.y - a.y, len = max(0.0001, hypot(dx, dy))
        return (p, CGVector(dx: dy / len, dy: -dx / len))
    }

    static func lengths(_ pts: [CGPoint]) -> [CGFloat] {
        var cum: [CGFloat] = [0]
        for i in 1..<pts.count { cum.append(cum[i - 1] + hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y)) }
        return cum
    }

    /// Bead units (0 … count) → fraction of the thread, leaving room for the clasp at each end.
    static func fraction(_ beadUnits: Double, count: Int) -> CGFloat {
        0.05 + 0.9 * CGFloat(beadUnits / Double(max(1, count)))
    }

    static func bead(near p: CGPoint, size: CGSize, count: Int) -> Int? {
        guard size.width > 0, count > 0 else { return nil }
        let pts = curve(size), cum = lengths(pts)
        let hits = (0..<count).map { i -> (Int, CGFloat) in
            let (c, _) = at(fraction(Double(i) + 0.5, count: count), pts, cum)
            return (i, hypot(c.x - p.x, c.y - p.y))
        }
        return hits.min { $0.1 < $1.1 }.flatMap { $0.1 < 40 ? $0.0 : nil }
    }
}

nonisolated enum StrandDraw {
    /// Small and smooth for clean air; bigger and spikier as it gets worse (Posavec & Quick).
    static func bead(_ ctx: GraphicsContext, at c: CGPoint, level: Int, color: Color) {
        let r: CGFloat = [5, 7, 10, 13][max(0, min(3, level))]
        let inner: CGFloat = [1, 0.9, 0.72, 0.52][max(0, min(3, level))]
        let spikes = 11
        var p = Path()
        for i in 0..<(spikes * 2) {
            let a = CGFloat(i) * .pi / CGFloat(spikes)
            let rr = i.isMultiple(of: 2) ? r : r * inner
            let pt = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        ctx.fill(p, with: .color(color))
        // A little highlight so it reads as an object.
        let h = r * 0.35
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.45, y: c.y - r * 0.5, width: h, height: h)), with: .color(.white.opacity(0.35)))
    }

    static func flower(_ ctx: GraphicsContext, at c: CGPoint, radius r: CGFloat, lobes: Int, color: Color) {
        var p = Path()
        let pr = r * 0.46
        for i in 0..<lobes {
            let a = CGFloat(i) * 2 * .pi / CGFloat(lobes)
            p.addEllipse(in: CGRect(x: c.x + cos(a) * r * 0.52 - pr, y: c.y + sin(a) * r * 0.52 - pr, width: pr * 2, height: pr * 2))
        }
        ctx.fill(p, with: .color(color))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.3, y: c.y - r * 0.3, width: r * 0.6, height: r * 0.6)), with: .color(.white.opacity(0.5)))
    }

    static func rescue(_ ctx: GraphicsContext, at c: CGPoint, size: CGFloat, color: Color) {
        let r = size * 0.22
        var p = Path()
        for i in 0..<5 {
            let a = CGFloat(i) * 2 * .pi / 5 - .pi / 2
            p.addEllipse(in: CGRect(x: c.x + cos(a) * r - r, y: c.y + sin(a) * r - r, width: r * 2, height: r * 2))
        }
        p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        ctx.fill(p, with: .color(color))
    }
}

private struct StrandCanvas: View {
    let spec: StrandSpec
    let time: TimeInterval

    var body: some View {
        Canvas { ctx, size in
            let pts = StrandLayout.curve(size)
            let cum = StrandLayout.lengths(pts)
            let n = spec.beads.count

            // Thread and clasps.
            var thread = Path()
            thread.addLines(pts)
            ctx.stroke(thread, with: .color(spec.thread), lineWidth: 1.5)
            for end in [pts.first!, pts.last!] {
                ctx.stroke(Path(ellipseIn: CGRect(x: end.x - 5, y: end.y - 5, width: 10, height: 10)), with: .color(spec.thread), lineWidth: 2)
            }

            // Day labels, inside the U at each day's middle bead.
            for (d, label) in spec.labels.enumerated() {
                let (p, nrm) = StrandLayout.at(StrandLayout.fraction(Double(d * 3) + 1.5, count: n), pts, cum)
                ctx.draw(Text(label).font(.caption2).foregroundStyle(.secondary),
                         at: CGPoint(x: p.x + nrm.dx * 46, y: p.y + nrm.dy * 46))
            }

            // Moments, just inside the thread.
            for k in spec.knots {
                let (p, nrm) = StrandLayout.at(StrandLayout.fraction(k.at, count: n), pts, cum)
                let q = CGPoint(x: p.x + nrm.dx * 24, y: p.y + nrm.dy * 24)
                switch k.kind {
                case 0: StrandDraw.rescue(ctx, at: q, size: 14, color: k.color)
                case 1: ctx.fill(Path(ellipseIn: CGRect(x: q.x - 3.5, y: q.y - 3.5, width: 7, height: 7)), with: .color(k.color))
                default: ctx.fill(Path(ellipseIn: CGRect(x: q.x - 3.5, y: q.y - 3.5, width: 7, height: 7)), with: .color(k.color.opacity(0.85)))
                }
            }

            // Charms hang straight down from their bead, swaying a little.
            for (i, b) in spec.beads.enumerated() where b.pollen >= 2 {
                let (p, _) = StrandLayout.at(StrandLayout.fraction(Double(i) + 0.5, count: n), pts, cum)
                let len: CGFloat = b.pollen == 3 ? 26 : 20
                let swing = sin(time * 0.9 + Double(i) * 1.7) * 0.14
                let end = CGPoint(x: p.x + sin(swing) * len, y: p.y + cos(swing) * len)
                var line = Path(); line.move(to: p); line.addLine(to: end)
                ctx.stroke(line, with: .color(spec.thread), lineWidth: 1)
                StrandDraw.flower(ctx, at: end, radius: b.pollen == 3 ? 10 : 7, lobes: b.pollenLobes, color: b.pollenColor)
            }

            // Beads on top, with a soft halo on the selected day.
            for (i, b) in spec.beads.enumerated() {
                let (p, _) = StrandLayout.at(StrandLayout.fraction(Double(i) + 0.5, count: n), pts, cum)
                if b.selected {
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 17, y: p.y - 17, width: 34, height: 34)), with: .color(.primary.opacity(0.07)))
                }
                StrandDraw.bead(ctx, at: p, level: b.air, color: b.color)
            }
        }
    }
}
#endif
