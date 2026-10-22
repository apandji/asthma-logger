import AsthmaCore
import SwiftUI

/// The Insights radar, in the app's print language: a pentagon of riso dots on the page, the five trigger
/// families on its corners. The air's three across the top (weather at the top, irritants right, allergens
/// left), the two about you below (exercise right, colds and flu left).
/// Your shape is the dots that swell and take each family's ink, out to how much more often that family shows
/// up on your flare days than on baseline ones. A family with a pattern gets a solid corner; one that's only
/// leaning gets a hollow one; one not tracked yet stays at the centre. It draws itself in once; tap a corner
/// (or a row below) to read it.
struct AirRadar: View {
    let profile: AirProfile
    @Binding var selected: AirProfile.Category?
    var size: CGFloat = 300
    /// Corner labels and taps. Off for the small radars in Profile History.
    var labels = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = 0.0

    /// The flare-vs-baseline gap that reaches the edge. Rings sit at a third and two thirds of it.
    static let fullGap = 0.5

    /// Clockwise from the top.
    static let order: [AirProfile.Category] = [.weather, .particulates, .exertion, .infections, .biologics]

    /// Corner k's direction (unit vector, screen coordinates), the first one straight up.
    static func direction(_ k: Int) -> CGPoint {
        let a = -Double.pi / 2 + 2 * Double.pi * Double(k) / Double(order.count)
        return CGPoint(x: cos(a), y: sin(a))
    }

    /// A family's ink for this person: the ink of its strongest pattern (heat → Bright Red, cold air → Medium
    /// Blue), so the radar, the card and the page's wash agree. No pattern: neutral grey.
    static func ink(_ a: AirProfile.Axis) -> Color {
        guard a.status == .pattern || a.status == .early else { return Color(white: 0.55) }
        // Families in ink: a pattern is yours, so it takes the risk highlight; leaning stays ink.
        if Crit.RiskColor.familiesInInk { return a.status == .pattern ? Verdict.red : .primary }
        if let r = a.lead, let c = WeatherColor.ink(bin: r.bin, level: r.level) { return c }
        return ink(a.category)
    }

    static func ink(_ c: AirProfile.Category) -> Color {
        switch c {
        case .weather: WeatherColor.print ? WeatherColor.weatherInk : WeatherColor.temperature(38)
        case .biologics: WeatherColor.pollen[2]
        case .particulates: WeatherColor.no2
        // About you, not the air: the key ink, like the text (Print, owner Oct 21), never a new hue.
        case .exertion: WeatherColor.coolFamilies ? WeatherColor.hex(0x9470CD) : WeatherColor.flat ? Color.primary : Theme.rescueSoft
        case .infections: WeatherColor.coolFamilies ? WeatherColor.hex(0x5F75C1) : WeatherColor.flat ? Color.primary : Theme.rescueSoft
        }
    }

    var body: some View {
        ZStack {
            RadarDots(profile: profile, grown: grown, selected: selected)
                .frame(width: size, height: size)
            if labels {
                ForEach(Array(Self.order.enumerated()), id: \.element) { i, c in
                    corner(c, index: i)
                }
            }
        }
        // Only the height is claimed: the side labels sit in the page's margins, never widening it.
        .frame(maxWidth: labels ? .infinity : size)
        .frame(height: labels ? size + 64 : size)
        .onAppear {
            if reduceMotion { grown = 1 } else { withAnimation(.spring(duration: 1.4, bounce: 0.25).delay(0.15)) { grown = 1 } }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Your air profile")
    }

    /// A corner's label, placed just outside the diamond. Tap to read it.
    private func corner(_ c: AirProfile.Category, index i: Int) -> some View {
        let axis = profile.axis(c)
        let r = size / 2 + 14, side: CGFloat = 96
        let d = Self.direction(i)
        // Side corners hang their label outward; the top one sits above.
        let edge: CGFloat = abs(d.x) < 0.1 ? 0 : (d.x > 0 ? side / 2 : -side / 2)
        let offset = CGSize(width: d.x * r + edge, height: d.y * r + (abs(d.x) < 0.1 ? -6 : 0))
        let on = selected == c
        return Button {
            withAnimation(Theme.snap) { selected = on ? nil : c }
        } label: {
            VStack(spacing: 2) {
                Text(c.shortTitle).font(.caption.weight(.semibold)).lineLimit(1).fixedSize()
                    .foregroundStyle(axis.status == .notTracked ? Theme.secondaryText : .primary)
                Circle().fill(on ? Self.ink(axis) : .clear).frame(width: 5, height: 5)
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .sensoryFeedback(.selection, trigger: on)
        .frame(width: abs(d.x) < 0.1 ? 160 : side, alignment: d.x > 0.1 ? .leading : d.x < -0.1 ? .trailing : .center)
        .offset(offset)
        .accessibilityLabel("\(c.title): \(axis.status.spoken)")
    }
}

/// The dots: a hex grid inside the diamond. Rings at a third, two thirds and the edge print a little brighter;
/// inside your shape the dots swell and take the nearest family's ink.
private struct RadarDots: View {
    @Environment(\.colorScheme) private var scheme
    /// The grid and outline: white on black paper, near-black on linen.
    private var ink: Color { scheme == .light ? Color(red: 0.12, green: 0.1, blue: 0.09) : .white }
    let profile: AirProfile
    let grown: Double
    let selected: AirProfile.Category?

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let R = min(size.width, size.height) / 2
            let n = AirRadar.order.count
            // Corner reach. A minimum so a quiet family still has a corner to point at.
            let reach = AirRadar.order.map { cat -> CGFloat in
                let a = profile.axis(cat)
                // A gap of half the moments (say 9 of 14 flare vs 6 of 40 baseline) is already a lot: it reaches the edge.
                return a.status == .notTracked ? 0 : CGFloat((0.12 + 0.88 * min(1, a.strength / AirRadar.fullGap)) * grown)
            }
            let inks = AirRadar.order.map { AirRadar.ink(profile.axis($0)) }
            let dirs = (0..<n).map(AirRadar.direction)
            let spacing: CGFloat = 7
            let m = Int(R / spacing) + 2
            for j in -m...m {
                for i in -m...m {
                    let x = CGFloat(i) * spacing + (j % 2 == 0 ? 0 : spacing / 2)
                    let y = CGFloat(j) * spacing * 0.866
                    let p = CGPoint(x: x, y: y)
                    // Which two corners bound this dot, and how far it sits from the first toward the second.
                    let (a, b, t) = Self.between(p, dirs)
                    // Polygon "radius": 1 on the outline, along this direction.
                    let d = Self.radius(p, dirs[a], dirs[b], 1, 1).map { hypot(x, y) / (R * $0) } ?? 0
                    guard d <= 1.02 else { continue }
                    // The shape's edge in this direction: the straight line between the two corners' reaches.
                    let edge = Self.radius(p, dirs[a], dirs[b], reach[a], reach[b]) ?? 0
                    let inside = (reach[a] > 0 || reach[b] > 0) && hypot(x, y) <= R * edge
                    var r: CGFloat = 0.7
                    var color = ink.opacity(0.13)
                    // Rings at a third, two thirds and the edge.
                    for ring in [1.0 / 3, 2.0 / 3, 1.0] where abs(d - ring) < 0.02 { color = ink.opacity(0.45); r = 1 }
                    if inside {
                        let ink = t < 0.5 ? inks[a] : inks[b]
                        let outer = Self.radius(p, dirs[a], dirs[b], 1, 1) ?? 1
                        let near = edge > 0 ? d / (edge / outer) : 0
                        // Denser toward the shape's edge, like ink pooling at a print's border.
                        r = 1.1 + 1.6 * near
                        let dim = selected.map { s -> Double in (AirRadar.order[t < 0.5 ? a : b] == s) ? 1 : 0.35 } ?? 1
                        color = ink.opacity((0.35 + 0.6 * near) * dim)
                    }
                    let q = CGPoint(x: c.x + x, y: c.y + y)
                    ctx.fill(Path(ellipseIn: CGRect(x: q.x - r, y: q.y - r, width: 2 * r, height: 2 * r)), with: .color(color))
                }
            }
            // The shape's outline and corners.
            var outline = Path()
            let pts = (0..<n).map { k in CGPoint(x: c.x + dirs[k].x * R * reach[k], y: c.y + dirs[k].y * R * reach[k]) }
            outline.addLines(pts); outline.closeSubpath()
            ctx.stroke(outline, with: .color(ink.opacity(0.7)), lineWidth: 1)
            for (k, cat) in AirRadar.order.enumerated() {
                let status = profile.axis(cat).status
                guard status == .pattern || status == .early else { continue }
                let p = pts[k], rr: CGFloat = 4.5
                let dot = Path(ellipseIn: CGRect(x: p.x - rr, y: p.y - rr, width: 2 * rr, height: 2 * rr))
                if status == .pattern { ctx.fill(dot, with: .color(ink)) }
                else { ctx.stroke(dot, with: .color(ink), lineWidth: 1.2) }
            }
        }
        .accessibilityHidden(true)
    }

    /// For a point, the two neighbouring corners whose wedge holds it, and how far it sits from the first toward
    /// the second (by angle).
    static func between(_ p: CGPoint, _ dirs: [CGPoint]) -> (Int, Int, CGFloat) {
        let n = dirs.count
        let step = 2 * Double.pi / Double(n)
        var ang = atan2(Double(p.y), Double(p.x)) + Double.pi / 2   // 0 at the top corner, clockwise
        if ang < 0 { ang += 2 * Double.pi }
        let a = Int(ang / step) % n
        return (a, (a + 1) % n, CGFloat((ang - Double(a) * step) / step))
    }

    /// How far along `p`'s direction the line from corner A (reach `ra`) to corner B (reach `rb`) lies, in units of
    /// the radius. Nil when both reaches are zero.
    static func radius(_ p: CGPoint, _ ua: CGPoint, _ ub: CGPoint, _ ra: CGFloat, _ rb: CGFloat) -> CGFloat? {
        let len = hypot(p.x, p.y)
        guard len > 0 else { return max(ra, rb) }
        let u = CGPoint(x: p.x / len, y: p.y / len)
        let A = CGPoint(x: ua.x * ra, y: ua.y * ra), B = CGPoint(x: ub.x * rb, y: ub.y * rb)
        let e = CGPoint(x: B.x - A.x, y: B.y - A.y)
        let den = u.x * e.y - u.y * e.x
        guard abs(den) > 1e-9 else { return ra == 0 && rb == 0 ? nil : max(ra, rb) }
        return (A.x * B.y - A.y * B.x) / den
    }
}

extension AirProfile.Category {
    /// The corner label.
    var shortTitle: String {
        switch self {
        case .weather: "Weather"
        case .biologics: "Allergens"
        case .particulates: "Irritants"
        case .exertion: "Exercise"
        case .infections: "Colds and flu"
        }
    }
}

extension AirProfile.Status {
    var word: String {
        switch self {
        case .pattern: "Often"
        case .early: "Maybe"
        case .nothing: "Not much"
        case .notTracked: "Not tracked yet"
        }
    }

    var spoken: String {
        switch self {
        case .pattern: "shows up more on your flare days"
        case .early: "leaning, not enough moments yet"
        case .nothing: "nothing more often on flare days"
        case .notTracked: "not tracked yet"
        }
    }
}
