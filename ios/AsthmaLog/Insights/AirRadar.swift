import AsthmaCore
import SwiftUI

/// The Insights radar, in the app's print language: a diamond of riso dots on the page, four families on its
/// corners (weather on top, particulates right, exertion below, biologics left, as on the FigJam board).
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

    /// Top, right, bottom, left.
    static let order: [AirProfile.Category] = [.weather, .particulates, .exertion, .biologics]

    static func ink(_ c: AirProfile.Category) -> Color {
        switch c {
        case .weather: WeatherColor.temperature(38)
        case .biologics: WeatherColor.pollen[2]
        case .particulates: WeatherColor.no2
        case .exertion: Theme.rescueSoft
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
        let r = size / 2 + 10, side: CGFloat = 84
        let offset: CGSize = [CGSize(width: 0, height: -r - 6), CGSize(width: r + side / 2, height: 0),
                              CGSize(width: 0, height: r + 6), CGSize(width: -r - side / 2, height: 0)][i]
        let on = selected == c
        return Button {
            withAnimation(Theme.snap) { selected = on ? nil : c }
        } label: {
            VStack(spacing: 2) {
                Text(c.shortTitle).font(.caption.weight(.semibold)).lineLimit(1).fixedSize()
                    .foregroundStyle(axis.status == .notTracked ? Theme.secondaryText : .primary)
                Circle().fill(on ? Self.ink(c) : .clear).frame(width: 5, height: 5)
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .sensoryFeedback(.selection, trigger: on)
        .frame(width: i % 2 == 0 ? 160 : side, alignment: i == 1 ? .leading : i == 3 ? .trailing : .center)
        .offset(offset)
        .accessibilityLabel("\(c.title): \(axis.status.spoken)")
    }
}

/// The dots: a hex grid inside the diamond. Rings at a third, two thirds and the edge print a little brighter;
/// inside your shape the dots swell and take the nearest family's ink.
private struct RadarDots: View {
    let profile: AirProfile
    let grown: Double
    let selected: AirProfile.Category?

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let R = min(size.width, size.height) / 2
            // Corner reach, top/right/bottom/left. A minimum so a quiet family still has a corner to point at.
            let reach = AirRadar.order.map { cat -> CGFloat in
                let a = profile.axis(cat)
                // A gap of half the moments (say 9 of 14 flare vs 6 of 40 baseline) is already a lot: it reaches the edge.
                return a.status == .notTracked ? 0 : CGFloat((0.12 + 0.88 * min(1, a.strength / AirRadar.fullGap)) * grown)
            }
            let inks = AirRadar.order.map(AirRadar.ink)
            let spacing: CGFloat = 7
            let n = Int(R / spacing) + 2
            for j in -n...n {
                for i in -n...n {
                    let x = CGFloat(i) * spacing + (j % 2 == 0 ? 0 : spacing / 2)
                    let y = CGFloat(j) * spacing * 0.866
                    // Diamond "radius" (L1 norm): 1 at the edge.
                    let d = (abs(x) + abs(y)) / R
                    guard d <= 1.02 else { continue }
                    // Which quadrant's corners bound this dot, and how far along between them.
                    let (a, b, t) = Self.between(x: x, y: y)
                    // The shape's edge in this direction: a straight line between the two corners' reaches.
                    let ra = reach[a], rb = reach[b]
                    let edge = 1 / ((1 - t) / max(ra, 0.0001) + t / max(rb, 0.0001))
                    let inside = d <= edge && (ra > 0 || rb > 0)
                    var r: CGFloat = 0.7
                    var color = Color.white.opacity(0.13)
                    // Rings at a third, two thirds and the edge.
                    for ring in [1.0 / 3, 2.0 / 3, 1.0] where abs(d - ring) < 0.02 { color = .white.opacity(0.45); r = 1 }
                    if inside {
                        let ink = t < 0.5 ? inks[a] : inks[b]
                        let near = edge > 0 ? d / edge : 0
                        // Denser toward the shape's edge, like ink pooling at a print's border.
                        r = 1.1 + 1.6 * near
                        let dim = selected.map { s -> Double in (AirRadar.order[t < 0.5 ? a : b] == s) ? 1 : 0.35 } ?? 1
                        color = ink.opacity((0.35 + 0.6 * near) * dim)
                    }
                    let p = CGPoint(x: c.x + x, y: c.y + y)
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(color))
                }
            }
            // The shape's outline and corners.
            var outline = Path()
            let pts = (0..<4).map { k -> CGPoint in
                let dir = [CGPoint(x: 0, y: -1), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: -1, y: 0)][k]
                return CGPoint(x: c.x + dir.x * R * reach[k], y: c.y + dir.y * R * reach[k])
            }
            outline.addLines(pts); outline.closeSubpath()
            ctx.stroke(outline, with: .color(.white.opacity(0.7)), lineWidth: 1)
            for (k, cat) in AirRadar.order.enumerated() {
                let status = profile.axis(cat).status
                guard status == .pattern || status == .early else { continue }
                let p = pts[k], rr: CGFloat = 4.5
                let dot = Path(ellipseIn: CGRect(x: p.x - rr, y: p.y - rr, width: 2 * rr, height: 2 * rr))
                if status == .pattern { ctx.fill(dot, with: .color(.white)) }
                else { ctx.stroke(dot, with: .color(.white), lineWidth: 1.2) }
            }
        }
        .accessibilityHidden(true)
    }

    /// For a point, the two corners (indices into top/right/bottom/left) of its quadrant and how far it sits
    /// from the first toward the second, measured along the diamond (so the shape's edges are straight).
    static func between(x: CGFloat, y: CGFloat) -> (Int, Int, CGFloat) {
        let up = -y   // screen y grows downward
        let (a, b, u, v): (Int, Int, CGFloat, CGFloat) =
            if x >= 0 && up >= 0 { (1, 0, x, up) }        // right → top
            else if x < 0 && up >= 0 { (0, 3, up, -x) }   // top → left
            else if x < 0 { (3, 2, -x, -up) }             // left → bottom
            else { (2, 1, -up, x) }                       // bottom → right
        let sum = u + v
        return (a, b, sum > 0 ? v / sum : 0)
    }
}

extension AirProfile.Category {
    /// The corner label.
    var shortTitle: String {
        switch self {
        case .weather: "Weather"
        case .biologics: "Biologics"
        case .particulates: "Particulates"
        case .exertion: "Exertion"
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
