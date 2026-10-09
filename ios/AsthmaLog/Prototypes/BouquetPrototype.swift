#if DEBUG
import AsthmaCore
import SwiftData
import SwiftUI

/// Bouquet, after Clever°Franke's Allevia Pollen Passport (built on Ambee) and Lupi & King's "Bruises".
/// Each day is a small bouquet made only of the pollen that was in the air: a leafy sprig when low,
/// a bloom when moderate, a full head when high (tree, grass and weed each have their own form).
/// Pollution isn't an object here, it's the atmosphere: particles veil the bouquet in haze, gases make
/// it sway. A clean day is clear and still. Inhaler moments are petals fallen on the table.
struct BouquetPrototype: View {
    @Query(sort: \LogEvent.loggedAt) private var events: [LogEvent]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selected: Date?

    var body: some View {
        let week = AirSky.week(events)
        let sel = selected ?? week.last?.day
        let specs = week.map(BouquetBuild.spec)
        let i = week.firstIndex { $0.day == sel } ?? max(0, week.count - 1)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What was in the air, gathered").font(Theme.headlineSerif)
                    Text("Each day's bouquet is the pollen that was around. Haze means particles; swaying means gases. Petals on the table are your inhaler moments.")
                        .font(.subheadline).foregroundStyle(Theme.secondaryText)
                }
                .padding(.horizontal, 20)

                VStack(spacing: 4) {
                    TimelineView(.animation(paused: reduceMotion)) { tl in
                        BouquetCanvas(spec: specs[i], time: reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate)
                    }
                    .frame(height: 360)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(specs[i].summary)
                    Text(specs[i].summary).font(.footnote).foregroundStyle(Theme.secondaryText)
                }
                .padding(.horizontal, 16)

                // The week as a row of small bouquets.
                HStack(spacing: 4) {
                    ForEach(Array(week.enumerated()), id: \.element.id) { j, d in
                        Button { withAnimation(.snappy) { selected = d.day } } label: {
                            VStack(spacing: 2) {
                                BouquetCanvas(spec: specs[j], time: 0).frame(height: 78)
                                Text(d.shortLabel).font(.caption2.weight(j == i ? .semibold : .regular))
                                    .foregroundStyle(j == i ? .primary : Theme.secondaryText)
                            }
                            .padding(.vertical, 6)
                            .background(j == i ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)

                key.padding(.horizontal, 20)
                SkyDayCard(day: week[i]).padding(.horizontal, 16)
                ExampleFootnote(extra: "All pollen here is example data, so these bouquets are made up.")
                    .padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
        }
        .background(Theme.stage.ignoresSafeArea())
        .navigationTitle("Bouquet")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var key: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 14) {
                ForEach(0..<3) { k in
                    HStack(spacing: 5) {
                        Circle().fill(BouquetBuild.colors[k]).frame(width: 9, height: 9)
                        Text(["Tree", "Grass", "Weed"][k])
                    }
                }
            }
            Text("Leaves = low · bloom = moderate · full head = high")
        }
        .font(.caption).foregroundStyle(Theme.secondaryText)
    }
}

// MARK: Spec

nonisolated struct BouquetStem: Sendable {
    let kind: Int     // 0 tree, 1 grass, 2 weed
    let level: Int    // 1 … 3
    let color: Color
}

nonisolated struct BouquetSpec: Sendable {
    let stems: [BouquetStem]
    let haze: Int     // particles, 0 … 3
    let sway: Int     // gases, 0 … 3
    let fallen: [Color]
    let stem: Color
    let hazeColor: Color
    let summary: String
}

enum BouquetBuild {
    static let colors: [Color] = [
        Color(light: 0x4E8F6F, dark: 0x7CC4A0),   // tree
        Color(light: 0xC9A400, dark: 0xE6C02E),   // grass
        Color(light: 0xA65BB8, dark: 0xD9A0E8),   // weed
    ]

    static func spec(_ day: SkyDay) -> BouquetSpec {
        func top(_ k: AirKind) -> Int { (0..<3).map { day.level(k, third: $0) }.max() ?? 0 }
        func topF(_ f: AirFamily) -> Int { (0..<3).map { day.level(f, third: $0) }.max() ?? 0 }
        var stems: [BouquetStem] = []
        for (k, kind) in [AirKind.tree, .grass, .weed].enumerated() {
            let lv = top(kind)
            // One stem per level step, so a high day is fuller as well as bigger.
            for _ in 0..<lv { stems.append(BouquetStem(kind: k, level: lv, color: colors[k])) }
        }
        // Interleave kinds so they mix like a real bouquet.
        stems = stems.enumerated().sorted { ($0.offset * 7) % 5 < ($1.offset * 7) % 5 }.map(\.element)

        var fallen: [Color] = []
        for m in day.moments {
            switch m.moment {
            case .rescue: fallen.append(Theme.rescue)
            case .maintenance: fallen.append(Theme.standard)
            case .okay: fallen.append(StrandBuild.okay)
            }
        }

        let species = day.worst.filter { $0.kind.family == .pollen && $0.level > 0 }.compactMap(\.species)
        let words = ["clear", "light haze", "hazy", "thick haze"][topF(.particles)]
        let move = ["still", "a light breeze of gases", "gases moving", "restless with gases"][topF(.gases)]
        let summary = (species.isEmpty ? "No pollen" : species.joined(separator: ", ")) + " · \(words) · \(move)"
        return BouquetSpec(stems: stems, haze: topF(.particles), sway: topF(.gases), fallen: fallen,
                           stem: Color(light: 0x7A8F6A, dark: 0x8FA67E), hazeColor: Color(light: 0x9A968E, dark: 0x6E6A64),
                           summary: summary)
    }
}

// MARK: Drawing

private struct BouquetCanvas: View {
    let spec: BouquetSpec
    let time: TimeInterval

    var body: some View {
        Canvas { ctx, size in
            BouquetDraw.draw(ctx, size: size, spec: spec, time: time)
        }
    }
}

nonisolated enum BouquetDraw {
    static func draw(_ ctx: GraphicsContext, size: CGSize, spec: BouquetSpec, time: TimeInterval) {
        let h = size.height, w = size.width
        let s = min(w / 0.9, h)                      // scale for thumbnails
        let base = CGPoint(x: w / 2, y: h * 0.84)
        let line = max(1, s * 0.006)

        // The table, with fallen petals for moments.
        var table = Path()
        table.move(to: CGPoint(x: w * 0.12, y: h * 0.93)); table.addLine(to: CGPoint(x: w * 0.88, y: h * 0.93))
        ctx.stroke(table, with: .color(spec.stem.opacity(0.25)), lineWidth: line)
        var rng = Seeded(Double(spec.stems.count * 31 + spec.fallen.count * 7 + spec.haze))
        for (i, c) in spec.fallen.enumerated() {
            let x = w / 2 + (CGFloat(i) - CGFloat(spec.fallen.count - 1) / 2) * s * 0.05 + CGFloat(rng.next() - 0.5) * s * 0.03
            let y = h * 0.93 - s * 0.012
            let r = s * 0.032
            var petal = Path(ellipseIn: CGRect(x: -r, y: -r * 0.55, width: r * 2, height: r * 1.1))
            petal = petal.applying(CGAffineTransform(rotationAngle: CGFloat(rng.next() * 3)).concatenating(CGAffineTransform(translationX: x, y: y)))
            ctx.fill(petal, with: .color(c))
        }

        let swayAmp: Double = [0.0, 0.025, 0.055, 0.1][spec.sway]
        if spec.stems.isEmpty {
            // No pollen: a single bare sprig.
            stem(ctx, from: base, angle: 0.05, length: s * 0.4, color: spec.stem.opacity(0.6), width: line * 1.2, leaves: 1, scale: s)
        }
        let n = spec.stems.count
        for (i, st) in spec.stems.enumerated() {
            let spread = n > 1 ? (CGFloat(i) / CGFloat(n - 1) - 0.5) * 1.1 : 0
            let jitter = CGFloat(rng.next() - 0.5) * 0.12
            let angle = spread + jitter + CGFloat(sin(time * (0.8 + Double(i) * 0.13) + Double(i) * 1.9) * swayAmp)
            let length = s * (0.42 + 0.08 * CGFloat(st.level) + CGFloat(rng.next()) * 0.1)
            let tip = stem(ctx, from: base, angle: angle, length: length, color: spec.stem, width: line * 1.6,
                           leaves: 1, scale: s)
            head(ctx, kind: st.kind, level: st.level, tip: tip, angle: angle, scale: s, color: st.color)
        }

        // Ribbon where the stems gather.
        let rb = s * 0.03
        var ribbon = Path()
        ribbon.addEllipse(in: CGRect(x: base.x - rb * 1.6, y: base.y - rb * 0.6, width: rb * 1.6, height: rb * 1.2))
        ribbon.addEllipse(in: CGRect(x: base.x, y: base.y - rb * 0.6, width: rb * 1.6, height: rb * 1.2))
        ctx.fill(ribbon, with: .color(spec.stem.opacity(0.8)))

        // Particles: a haze over everything, thicker on worse days, drifting slowly.
        if spec.haze > 0 {
            let alpha: Double = [0, 0.1, 0.22, 0.36][spec.haze]
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .radialGradient(Gradient(colors: [spec.hazeColor.opacity(alpha), spec.hazeColor.opacity(0)]),
                                           center: CGPoint(x: w / 2, y: h * 0.45), startRadius: 0, endRadius: min(w, h) * 0.5))
            var drift = ctx
            drift.addFilter(.blur(radius: s * 0.02))
            for k in 0..<(spec.haze * 5) {
                let x = (CGFloat(rng.next()) * w + CGFloat(time) * s * 0.01 * CGFloat(k % 3 + 1)).truncatingRemainder(dividingBy: w)
                let y = CGFloat(rng.next()) * h * 0.8
                let r = s * (0.03 + CGFloat(rng.next()) * 0.04)
                drift.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(spec.hazeColor.opacity(alpha)))
            }
        }
    }

    /// Draws a gently curved stem with leaves; returns the tip.
    @discardableResult
    static func stem(_ ctx: GraphicsContext, from base: CGPoint, angle: CGFloat, length: CGFloat, color: Color,
                     width: CGFloat, leaves: Int, scale s: CGFloat) -> CGPoint {
        let tip = CGPoint(x: base.x + sin(angle) * length, y: base.y - cos(angle) * length)
        let ctrl = CGPoint(x: base.x + sin(angle * 0.4) * length * 0.55, y: base.y - cos(angle * 0.4) * length * 0.55)
        var p = Path()
        p.move(to: base)
        p.addQuadCurve(to: tip, control: ctrl)
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
        for k in 0..<leaves {
            let t: CGFloat = 0.45 + CGFloat(k) * 0.2
            let pt = CGPoint(x: base.x + (tip.x - base.x) * t, y: base.y + (tip.y - base.y) * t)
            let side: CGFloat = k.isMultiple(of: 2) ? 1 : -1
            let lw = s * 0.05, lh = s * 0.018
            var leaf = Path(ellipseIn: CGRect(x: 0, y: -lh, width: lw, height: lh * 2))
            leaf = leaf.applying(CGAffineTransform(rotationAngle: angle - .pi / 2 + side * 0.9)
                .concatenating(CGAffineTransform(translationX: pt.x, y: pt.y)))
            ctx.fill(leaf, with: .color(color.opacity(0.85)))
        }
        return tip
    }

    static func head(_ ctx: GraphicsContext, kind: Int, level: Int, tip: CGPoint, angle: CGFloat, scale s: CGFloat, color: Color) {
        if level == 1 {
            // Low: a small closed bud, so you can still tell which kind it is.
            let r = s * 0.02
            ctx.fill(Path(ellipseIn: CGRect(x: tip.x - r, y: tip.y - r * 1.3, width: r * 2, height: r * 2.6)), with: .color(color.opacity(0.85)))
            return
        }
        let big = level == 3
        switch kind {
        case 0:
            // Tree: a round blossom.
            let r = s * (big ? 0.09 : 0.06)
            var p = Path()
            for i in 0..<5 {
                let a = CGFloat(i) * 2 * .pi / 5 + angle
                p.addEllipse(in: CGRect(x: tip.x + cos(a) * r * 0.6 - r * 0.55, y: tip.y + sin(a) * r * 0.6 - r * 0.55, width: r * 1.1, height: r * 1.1))
            }
            ctx.fill(p, with: .color(color))
            ctx.fill(Path(ellipseIn: CGRect(x: tip.x - r * 0.3, y: tip.y - r * 0.3, width: r * 0.6, height: r * 0.6)), with: .color(.white.opacity(0.55)))
        case 1:
            // Grass: a spike of seeds along the top of the stem.
            let count = big ? 9 : 5
            let len = s * (big ? 0.18 : 0.12)
            for k in 0..<count {
                let t = CGFloat(k) / CGFloat(count)
                let pt = CGPoint(x: tip.x - sin(angle) * len * t, y: tip.y + cos(angle) * len * t)
                let side: CGFloat = k.isMultiple(of: 2) ? 1 : -1
                let gw = s * 0.04, gh = s * 0.016
                var seed = Path(ellipseIn: CGRect(x: 0, y: -gh, width: gw, height: gh * 2))
                seed = seed.applying(CGAffineTransform(rotationAngle: angle - .pi / 2 + side * 0.55)
                    .concatenating(CGAffineTransform(translationX: pt.x, y: pt.y)))
                ctx.fill(seed, with: .color(color))
            }
        default:
            // Weed (ragweed): small spiky heads along a branching tip.
            let count = big ? 8 : 5
            let len = s * (big ? 0.18 : 0.12)
            for k in 0..<count {
                let t = CGFloat(k) / CGFloat(count)
                let off = (k.isMultiple(of: 2) ? 1 : -1) * s * 0.028
                let pt = CGPoint(x: tip.x - sin(angle) * len * t + cos(angle) * off, y: tip.y + cos(angle) * len * t + sin(angle) * off)
                let r = s * (big ? 0.026 : 0.019) * (1 - t * 0.3)
                var star = Path()
                for i in 0..<12 {
                    let a = CGFloat(i) * .pi / 6
                    let rr = i.isMultiple(of: 2) ? r : r * 0.5
                    let q = CGPoint(x: pt.x + cos(a) * rr, y: pt.y + sin(a) * rr)
                    i == 0 ? star.move(to: q) : star.addLine(to: q)
                }
                star.closeSubpath()
                ctx.fill(star, with: .color(color))
            }
        }
    }
}
#endif
