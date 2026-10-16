import AsthmaCore
import SwiftUI

/// Today's outdoor conditions as a soft, slowly drifting colour field behind frosted glass.
///
/// Two styles (Settings › Design crit › Field):
/// - Weather (default): each condition changes the field the way it changes the sky.
///   Temperature is the hue (blue cold → green mild → gold warm → red hot), the hour sets the light
///   (indigo night, rose dawn and dusk), dirtier air greys the colour and adds grain, humidity adds a
///   milky mist (dry air is crisp), and pollen layers on soft colour blooms.
/// - Inks: the original look, one riso ink per factor, stronger with its level.
/// Purely atmospheric: the numbers live in the cards. Static with Reduce Motion; plain with Reduce Transparency.
struct AmbientField: View {
    let weave: WeaveSpec
    /// The actual temperature, when known, for a smooth hue. Falls back to the cold / mild / hot word.
    var temperatureF: Double? = nil
    /// When the moment happened: the light changes with the hour (night indigo, dawn and dusk rose).
    var date: Date? = nil
    /// Demo pollen, when switched on in Design crit (pollen isn't connected yet).
    var pollen: PollenSample? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme
    @AppStorage(Crit.FieldStyle.key) private var style = Crit.FieldStyle.weather

    var body: some View {
        if reduceTransparency {
            Theme.stage
        } else if reduceMotion {
            field(t: 0)
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                field(t: context.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    @ViewBuilder private func field(t: Double) -> some View {
        switch style {
        case .weather: weatherField(t: t)
        case .inks: inkField(t: t)
        }
    }

    // MARK: Weather

    private func weatherField(t: Double) -> some View {
        let base = Theme.stage
        let warm = WeatherColor.light(WeatherColor.temperature(temperatureF ?? WeatherColor.fallbackTemp(weave)), at: date)
        let air = weave.levels[.air]?.rawValue ?? 0
        let humid = weave.words[.humidity] == "humid"
        let dry = weave.words[.humidity] == "dry"
        let strength = scheme == .dark ? 0.78 : 0.7

        func d(_ phase: Double, _ amp: Float = 0.07) -> Float { Float(sin(t / 8 + phase)) * amp }
        let points: [SIMD2<Float>] = [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.42 + d(1)], [0.5 + d(2), 0.38 + d(3)], [1, 0.48 + d(4)],
            [0, 1], [0.5, 1], [1, 1],
        ]
        let colors: [Color] = [
            warm.opacity(strength), warm.mix(with: .white, by: 0.15).opacity(strength * 0.9), warm.opacity(strength),
            warm.mix(with: .black, by: 0.15).opacity(strength * 0.8), warm.opacity(strength * 0.95), warm.mix(with: .white, by: 0.1).opacity(strength * 0.75),
            base, base, base,
        ]
        return MeshGradient(width: 3, height: 3, points: points, colors: colors, background: base)
            // Dirtier air: the colour drains to grey and a fine grain settles over it.
            .saturation([1, 0.7, 0.4][air])
            .overlay(WeatherColor.smog.opacity([0, 0.16, 0.32][air]))
            .overlay { if air > 0 { Grain(density: air, seed: 7).opacity(scheme == .dark ? 0.5 : 0.35) } }
            // Humid air: a soft milky mist. Dry air: crisper, a touch more contrast.
            .overlay { if humid { MistLayer(t: t).opacity(WeatherColor.isNight(date) ? 0.35 : 1) } }
            .contrast(dry ? 1.12 : 1)
            // Pollen: soft colour blooms layered per kind, fuller when higher.
            .overlay { PollenBlooms(sample: pollen, t: t) }
            .overlay(base.opacity(scheme == .dark ? 0.12 : 0.04))
            .accessibilityHidden(true)
    }

    // MARK: Inks (original)

    private func inkField(t: Double) -> some View {
        let base = Theme.stage
        func d(_ phase: Double, _ amp: Float = 0.06) -> Float { Float(sin(t / 7 + phase)) * amp }
        let points: [SIMD2<Float>] = [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.45 + d(1)], [0.5 + d(2), 0.4 + d(3)], [1, 0.5 + d(4)],
            [0, 1], [0.5, 1], [1, 1],
        ]
        let colors: [Color] = [
            hue(.air), hue(.humidity), hue(.temperature),
            hue(.humidity, 0.8), hue(.pollen, 0.9, fallback: hue(.air, 0.6)), hue(.air, 0.8),
            base, base, base,
        ]
        return MeshGradient(width: 3, height: 3, points: points, colors: colors, background: base)
            .overlay(base.opacity(scheme == .dark ? 0.25 : 0.1))
            .accessibilityHidden(true)
    }

    /// The factor's ink at a strength set by its level; a quiet neutral when there's no reading.
    private func hue(_ f: WeaveSpec.Factor, _ scale: Double = 1, fallback: Color? = nil) -> Color {
        guard let level = weave.levels[f] else { return fallback ?? Theme.stage }
        let strength = [0.32, 0.55, 0.85][level.rawValue] * scale
        return WeaveSwatch.ink(f).opacity(strength)
    }
}

/// The weather colour language, shared by the field and its legend.
enum WeatherColor {
    /// Blue (cold) → sky → sage (mild) → amber (warm) → red (hot), by °F.
    /// Spread so ordinary days differ: 45° sky blue, 55° teal, 63° green, 70° gold, 78° orange, 88° red.
    static let stops: [(f: Double, color: Color)] = [
        (30, Color(red: 0.22, green: 0.34, blue: 0.86)),
        (45, Color(red: 0.30, green: 0.58, blue: 0.92)),
        (55, Color(red: 0.20, green: 0.70, blue: 0.72)),
        (63, Color(red: 0.42, green: 0.76, blue: 0.42)),
        (70, Color(red: 0.93, green: 0.78, blue: 0.32)),
        (78, Color(red: 0.97, green: 0.56, blue: 0.24)),
        (88, Color(red: 0.90, green: 0.28, blue: 0.22)),
    ]

    static func isNight(_ date: Date?) -> Bool {
        guard let date else { return false }
        let h = Calendar.current.component(.hour, from: date)
        return h < 5 || h >= 21
    }

    /// The light of the hour over the temperature hue: deep indigo at night, rose at dawn and dusk.
    static func light(_ c: Color, at date: Date?) -> Color {
        guard let date else { return c }
        let h = Double(Calendar.current.component(.hour, from: date)) + Double(Calendar.current.component(.minute, from: date)) / 60
        let night = Color(red: 0.22, green: 0.20, blue: 0.62)
        let rose = Color(red: 0.92, green: 0.48, blue: 0.56)
        switch h {
        case ..<5, 21...: return c.mix(with: night, by: 0.62)
        case 5..<8: return c.mix(with: rose, by: 0.3 * (1 - abs(h - 6.5) / 1.5) + 0.1)
        case 17..<21: return c.mix(with: rose, by: 0.15 + 0.25 * (h - 17) / 4).mix(with: night, by: max(0, (h - 19.5) / 1.5) * 0.4)
        default: return c
        }
    }
    static let smog = Color(red: 0.52, green: 0.50, blue: 0.46)
    static let pollen: [Color] = [
        Color(red: 0.36, green: 0.80, blue: 0.46),   // tree: green
        Color(red: 0.98, green: 0.80, blue: 0.22),   // grass: gold
        Color(red: 0.72, green: 0.42, blue: 0.95),   // weed: violet
    ]

    static func temperature(_ f: Double) -> Color {
        guard let first = stops.first, let last = stops.last else { return .gray }
        if f <= first.f { return first.color }
        if f >= last.f { return last.color }
        for (a, b) in zip(stops, stops.dropFirst()) where f <= b.f {
            return a.color.mix(with: b.color, by: (f - a.f) / (b.f - a.f))
        }
        return last.color
    }

    static func fallbackTemp(_ w: WeaveSpec) -> Double {
        switch w.words[.temperature] {
        case "cold": 32
        case "hot": 92
        default: 65
        }
    }
}

/// Fine dust over the field; denser for dirtier air.
private struct Grain: View {
    let density: Int
    let seed: Int

    var body: some View {
        Canvas { ctx, size in
            var rng = Seeded(Double(seed * 7919 + density))
            let n = Int(size.width * size.height / 900) * density
            for _ in 0..<n {
                let x = rng.next() * size.width, y = rng.next() * size.height * 0.75
                let r = 0.6 + rng.next() * 0.9
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.black.opacity(0.35)))
            }
        }
        .allowsHitTesting(false)
    }
}

/// A slow, soft milky veil for humid air.
private struct MistLayer: View {
    let t: Double

    var body: some View {
        LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.08), .clear],
                       startPoint: UnitPoint(x: 0.5 + sin(t / 11) * 0.2, y: 0), endPoint: .center)
            .blur(radius: 30)
            .allowsHitTesting(false)
    }
}

/// Pollen as soft colour blooms layered over the field, like Apple Card picking up colour:
/// green for trees, gold for grass, violet for weeds. Each one is faint when low, fuller when high,
/// and drifts slowly; where they overlap the colours mix. Nothing when there's no pollen data.
private struct PollenBlooms: View {
    let sample: PollenSample?
    let t: Double
    @Environment(\.colorScheme) private var scheme

    /// Where each kind's bloom sits (unit coordinates) and how it drifts.
    private let anchors: [(x: Double, y: Double, phase: Double)] = [(0.18, 0.22, 0), (0.82, 0.16, 2.1), (0.55, 0.42, 4.2)]

    var body: some View {
        if let sample {
            Canvas { ctx, size in
                ctx.blendMode = scheme == .dark ? .plusLighter : .normal
                for (k, kind) in sample.kinds.enumerated() where kind.count > 0 {
                    let a = anchors[k]
                    let strength = [0.22, 0.45, 0.7][kind.level.rawValue]
                    let radius = min(size.width, size.height) * [0.32, 0.42, 0.52][kind.level.rawValue]
                    let c = CGPoint(x: size.width * (a.x + sin(t / 9 + a.phase) * 0.06),
                                    y: size.height * (a.y + cos(t / 11 + a.phase) * 0.04))
                    let color = WeatherColor.pollen[k]
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)),
                             with: .radialGradient(Gradient(colors: [color.opacity(strength), color.opacity(strength * 0.4), .clear]),
                                                   center: c, startRadius: 0, endRadius: radius))
                }
            }
            .blur(radius: 24)
            .allowsHitTesting(false)
        }
    }
}

extension View {
    /// Frosted glass card over the ambient field: dark-tinted material in dark mode, light material in light.
    func frostedCard(cornerRadius: CGFloat = 22) -> some View {
        modifier(FrostedCard(cornerRadius: cornerRadius))
    }
}

private struct FrostedCard: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(Color.black.opacity(scheme == .dark ? 0.35 : 0), in: shape)
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.strokeBorder(.white.opacity(scheme == .dark ? 0.08 : 0.4), lineWidth: 0.5))
    }
}

/// Small deterministic random numbers so example values don't jump between redraws.
nonisolated struct Seeded {
    private var s: UInt64
    init(_ seed: Double) { s = UInt64(abs(seed)) &* 2654435761 | 1 }
    mutating func next() -> Double {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return Double(s >> 11) / Double(1 << 53)
    }
}
