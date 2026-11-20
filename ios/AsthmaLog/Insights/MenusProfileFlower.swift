import AsthmaCore
import SwiftUI

/// Insights on the Menus look (owner, Nov 19): your trigger profile drawn as one flower in the home's language.
/// Each petal is a condition, drawn like home's fans (deep at the centre, fading out, a soft cloud rim, overlaps
/// mixing like pigment). A petal's length follows the condition's rank as one of your triggers, so the
/// archetype reads at a glance: a pollen-led flower has its longest petal in pollen yellow.
struct MenusProfileFlower: View {
    /// How much each condition is one of your triggers, 0…1 (home's fan weights).
    let weights: [String: Double]
    /// Still the sample profile (nothing learned yet), said under the name.
    let sample: Bool
    var size: CGFloat = 300
    @State private var bloomStart: Date?

    /// Home's inks (MenusEnvironment.pigment), so a condition is one colour everywhere.
    static func ink(_ name: String) -> Color {
        switch name {
        case "Temperature": Color(red: 0.86, green: 0.36, blue: 0.30)
        case "Humidity": Color(red: 0.20, green: 0.50, blue: 0.56)
        case "Wind": Color(red: 0.42, green: 0.43, blue: 0.45)
        case "PM2.5": Color(red: 0.18, green: 0.42, blue: 0.78)
        case "Ozone": Color(red: 0.86, green: 0.42, blue: 0.56)
        case "Pollen": Color(red: 0.93, green: 0.74, blue: 0.16)
        case "Pressure": Color(red: 0.45, green: 0.40, blue: 0.68)
        default: Color(red: 0.50, green: 0.40, blue: 0.70)
        }
    }

    /// A pattern bin's flower ink ("pm25" → PM2.5 blue), or nil when no flower stands for it.
    static func ink(bin: String) -> Color? {
        switch bin {
        case "pm25", "smoke_at_point": ink("PM2.5")
        case "ozone": ink("Ozone")
        case "pollen_weed", "pollen_tree", "pollen_grass": ink("Pollen")
        case "temp", "temp_drop", "heat_alert": ink("Temperature")
        case "humidity": ink("Humidity")
        case "wind", "storm": ink("Wind")
        case "pressure_change": ink("Pressure")
        default: nil
        }
    }

    /// A family's ink on Insights: its leading reading's flower, else the flower that stands for the family.
    static func ink(_ a: AirProfile.Axis) -> Color {
        guard a.status == .pattern || a.status == .early else { return Color(white: 0.6) }
        if let bin = a.lead?.bin, let c = ink(bin: bin) { return c }
        switch a.category {
        case .particulates: return ink("PM2.5")
        case .biologics: return ink("Pollen")
        case .weather: return ink("Temperature")
        case .exertion, .infections: return Color(white: 0.45)
        }
    }

    private static let profileOrder = ["Pollen", "PM2.5", "Ozone", "Humidity", "Temperature", "Pressure", "Wind"]

    /// Ranked, strongest first; ties keep the profile order (as on home).
    private var ranked: [(name: String, w: Double)] {
        Self.profileOrder.map { ($0, weights[$0] ?? 0.15) }
            .enumerated()
            .sorted { $0.element.1 > $1.element.1 + 0.001 || (abs($0.element.1 - $1.element.1) <= 0.001 && $0.offset < $1.offset) }
            .map { (name: $0.element.0, w: $0.element.1) }
    }

    /// The archetype's name and line, from the top two.
    private var archetype: (name: String, line: String) {
        let r = ranked
        guard let first = r.first else { return ("Still learning", "") }
        let lead: [String: String] = ["Pollen": "Pollen-led", "PM2.5": "Smoke and particles", "Ozone": "Ozone-sensitive",
                                      "Humidity": "Humidity-sensitive", "Temperature": "Temperature-sensitive", "Wind": "Wind-sensitive"]
        let second = r.count > 1 ? r[1].name : nil
        let line = "\(first.name == "PM2.5" ? "PM2.5" : first.name) shows up most around your inhaler use"
            + (second.map { ", with \($0 == "PM2.5" ? "PM2.5" : $0.lowercased()) close behind." } ?? ".")
        return (lead[first.name] ?? first.name, line)
    }

    var body: some View {
        let r = ranked
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text(archetype.name)
                    .font(Theme.Figtree.font(size: 30, weight: .medium))
                Text(archetype.line)
                    .font(Theme.Figtree.font(size: 16)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                if sample {
                    Text("Sample profile · still learning yours")
                        .font(Theme.Figtree.font(size: 13, weight: .medium)).foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }
            TimelineView(.animation(paused: bloomDone)) { tl in
                Canvas { ctx, s in draw(ctx, s, r, at: tl.date) }
            }
            .frame(width: size, height: size)
            .accessibilityElement()
            .accessibilityLabel("Your trigger flower: " + r.map(\.name).joined(separator: ", ") + ", largest first.")
        }
        .frame(maxWidth: .infinity)
        .onAppear { bloomStart = .now }
    }

    private var bloomDone: Bool { bloomStart.map { Date().timeIntervalSince($0) > 1.6 } ?? false }

    /// The bloom (as home's fans): each petal springs out from the centre, strongest first.
    private func grow(_ k: Int, at t: Date) -> CGFloat {
        guard let s = bloomStart else { return 0 }
        let p = CGFloat(min(1, max(0, (t.timeIntervalSince(s) - 0.08 * Double(k)) / 0.8)))
        return p >= 1 ? 1 : 1 - exp(-6 * p) * cos(9 * p)
    }

    private func draw(_ ctx: GraphicsContext, _ s: CGSize, _ r: [(name: String, w: Double)], at t: Date) {
        let c = CGPoint(x: s.width / 2, y: s.height / 2)
        let labelRoom: CGFloat = 56
        let R = s.width / 2 - labelRoom
        // Size by rank, the same steps as home: the lead clearly biggest.
        let steps: [CGFloat] = [1, 0.8, 0.68, 0.58, 0.5, 0.44, 0.4]
        let n = r.count
        // Balanced round the centre: the lead points up, the second down, the rest in pairs either side.
        let seat: [Int] = n == 6 ? [0, 3, 1, 5, 2, 4] : n == 7 ? [0, 4, 1, 6, 3, 2, 5] : Array(0..<n)
        // Each petal is one of home's fans, opened to its share of the round with a little air between.
        let spread = 2 * Double.pi / Double(max(n, 1)) * 0.86
        var labels: [(String, CGPoint, Color, UnitPoint)] = []
        ctx.drawLayer { paint in
            // Home's fans (April, Nov 20): no blur, the colour does the softening; overlaps mix like pigment.
            paint.blendMode = .multiply
            for (k, item) in r.enumerated() {
                let ink = Self.ink(item.name)
                let len = R * steps[min(k, steps.count - 1)] * grow(k, at: t)
                guard len > 1 else { continue }
                let mid = -Double.pi / 2 + 2 * Double.pi * Double(seat[k % seat.count]) / Double(n)
                // The petal is home's fan: a wedge from the centre with a rim of wide soft bumps (one per ~40°),
                // the same 0.93 + 0.07 swell, deep where it meets the centre and fading out to the rim.
                var p = Path()
                p.move(to: c)
                let bumps = max(2, Int((spread * 180 / .pi / 40).rounded())), stepsN = 120
                for j in 0...stepsN {
                    let u = Double(j) / Double(stepsN)
                    let a = mid - spread / 2 + spread * u
                    let q = (u * Double(bumps)).truncatingRemainder(dividingBy: 1)
                    let rr = len * CGFloat(0.93 + 0.07 * (1 - pow(2 * q - 1, 2)).squareRoot())
                    p.addLine(to: CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr))
                }
                p.closeSubpath()
                paint.fill(p, with: .radialGradient(Gradient(stops: [.init(color: ink, location: 0), .init(color: ink.opacity(0.55), location: 0.5),
                                                                     .init(color: ink.opacity(0.08), location: 1)]),
                                                    center: c, startRadius: 0, endRadius: len))
                // Names on one ring round the flower (owner, Nov 19), each at its petal's angle.
                let ring = R + 22
                let tip = CGPoint(x: c.x + cos(mid) * ring, y: c.y + sin(mid) * ring)
                let anchor = UnitPoint.center
                labels.append((item.name, tip, ink, anchor))
            }
        }
        // Paper grain over it, as on home.
        ctx.drawLayer { g in
            g.blendMode = .multiply
            g.addFilter(.blur(radius: 0.35))
            var rng = IslandRNG(seed: 0xF10)
            var dots = Path()
            for _ in 0..<Int(s.width * s.height / 40) {
                let x = CGFloat.random(in: 0...s.width, using: &rng), y = CGFloat.random(in: 0...s.height, using: &rng)
                let d = CGFloat.random(in: 0.35...1.1, using: &rng)
                dots.addEllipse(in: CGRect(x: x, y: y, width: d, height: d))
            }
            g.fill(dots, with: .color(Color(red: 0.35, green: 0.3, blue: 0.25).opacity(0.08)))
        }
        for (name, at, ink, anchor) in labels {
            ctx.draw(Text(name).font(Theme.Figtree.font(size: 13, weight: .medium)).foregroundStyle(ink.mix(with: .black, by: 0.3)), at: at, anchor: anchor)
        }
    }
}
