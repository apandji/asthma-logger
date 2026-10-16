import AsthmaCore
import SwiftUI

/// Today's outdoor conditions as a soft, slowly drifting colour field behind frosted glass.
///
/// Two styles (Settings › Design crit › Field):
/// - Weather (default): each condition changes the field the way it changes the sky.
///   Temperature is the hue (blue cold → sage mild → amber warm → red hot), dirtier air greys the colour
///   and adds grain, humidity adds a milky mist (dry air is crisp), and pollen adds coloured specks.
/// - Inks: the original look, one riso ink per factor, stronger with its level.
/// Purely atmospheric: the numbers live in the cards. Static with Reduce Motion; plain with Reduce Transparency.
struct AmbientField: View {
    let weave: WeaveSpec
    /// The actual temperature, when known, for a smooth hue. Falls back to the cold / mild / hot word.
    var temperatureF: Double? = nil
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
        let warm = WeatherColor.temperature(temperatureF ?? WeatherColor.fallbackTemp(weave))
        let air = weave.levels[.air]?.rawValue ?? 0
        let humid = weave.words[.humidity] == "humid"
        let dry = weave.words[.humidity] == "dry"
        let strength = scheme == .dark ? 0.55 : 0.6

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
            .overlay { if humid { MistLayer(t: t) } }
            .contrast(dry ? 1.12 : 1)
            // Pollen: specks layered per kind, more when higher.
            .overlay { PollenSpecks(sample: pollen, t: t) }
            .overlay(base.opacity(scheme == .dark ? 0.2 : 0.06))
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
    static let stops: [(f: Double, color: Color)] = [
        (25, Color(red: 0.20, green: 0.38, blue: 0.85)),
        (45, Color(red: 0.36, green: 0.66, blue: 0.86)),
        (65, Color(red: 0.58, green: 0.78, blue: 0.62)),
        (80, Color(red: 0.95, green: 0.70, blue: 0.33)),
        (95, Color(red: 0.88, green: 0.30, blue: 0.22)),
    ]
    static let smog = Color(red: 0.52, green: 0.50, blue: 0.46)
    static let pollen: [Color] = [
        Color(red: 0.40, green: 0.72, blue: 0.42),   // tree: green
        Color(red: 0.93, green: 0.80, blue: 0.25),   // grass: yellow
        Color(red: 0.70, green: 0.45, blue: 0.82),   // weed: purple
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

/// Pollen as coloured specks drifting in the upper field: green tree, yellow grass, purple weed,
/// each layered on by its own level. Nothing when there's no pollen data.
private struct PollenSpecks: View {
    let sample: PollenSample?
    let t: Double

    var body: some View {
        if let sample {
            Canvas { ctx, size in
                for (k, kind) in sample.kinds.enumerated() where kind.count > 0 {
                    var rng = Seeded(Double(31 + k * 101))
                    let count = [10, 34, 70][kind.level.rawValue]
                    for _ in 0..<count {
                        let speed = 2 + rng.next() * 4
                        let x = (rng.next() * size.width + sin(t / 5 + rng.next() * 6) * 8)
                        let y = (rng.next() * size.height * 0.7 + t * speed).truncatingRemainder(dividingBy: size.height * 0.7)
                        let r = 1.6 + rng.next() * 2.6
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                                 with: .color(WeatherColor.pollen[k].opacity(0.75)))
                    }
                }
            }
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
