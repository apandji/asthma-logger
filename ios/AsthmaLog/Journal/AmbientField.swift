import AsthmaCore
import SwiftUI

/// A moment's outdoor conditions as a soft colour field, like a sky.
///
/// Two styles (Settings › Design crit › Colour field):
/// - Weather (default), in layers:
///   - Base: temperature is the hue (blue cold → green mild → gold warm → red hot) under the light of
///     the hour (indigo night, rose dawn and dusk); humidity is the softness (dry crisp and saturated,
///     humid paler and softer).
///   - On top, each pollutant and pollen type adds its own colour, faint when low and fuller when high,
///     like Apple Card picking up hues: PM2.5 slate, PM10 sand, NO₂ rust, ozone icy cyan; tree green,
///     grass gold, weed violet. Unknown values add nothing.
/// - Inks: the original look, one riso ink per factor.
/// Still (no idle motion); it eases between moments. Plain with Reduce Transparency.
struct AmbientField: View {
    let weave: WeaveSpec
    /// The actual temperature, when known, for a smooth hue. Falls back to the cold / mild / hot word.
    var temperatureF: Double? = nil
    /// When the moment happened: the light changes with the hour (night indigo, dawn and dusk rose).
    var date: Date? = nil
    /// Per-pollutant readings for the colour layers.
    var conditions: Conditions? = nil
    /// Demo pollen, when switched on in Design crit (pollen isn't connected yet).
    var pollen: PollenSample? = nil
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme
    @AppStorage(Crit.FieldStyle.key) private var style = Crit.FieldStyle.weather

    var body: some View {
        if reduceTransparency {
            Theme.stage
        } else {
            switch style {
            case .weather: weatherField
            case .inks: inkField(t: 0)
            }
        }
    }

    // MARK: Weather

    private var weatherField: some View {
        let base = Theme.stage
        let humidity = weave.words[.humidity]
        var sky = WeatherColor.light(WeatherColor.temperature(temperatureF ?? WeatherColor.fallbackTemp(weave)), at: date)
        if humidity == "humid" { sky = sky.mix(with: .white, by: 0.16) }
        let strength = scheme == .dark ? 0.75 : 0.66

        let layers = AirLayers(conditions: conditions, weave: weave, pollen: pollen)
        func tint(_ c: Color, _ layer: AirLayers.Layer?) -> Color {
            guard let layer else { return c }
            return c.mix(with: layer.color, by: layer.amount)
        }
        let mid = sky.mix(with: base, by: 0.3)
        let low = sky.mix(with: base, by: 0.55)
        // Rows: sky · pollutants · pollen · ground.
        let points: [SIMD2<Float>] = [
            [0, 0], [0.33, 0], [0.67, 0], [1, 0],
            [0, 0.3], [0.33, 0.26], [0.67, 0.3], [1, 0.26],
            [0, 0.56], [0.33, 0.6], [0.67, 0.56], [1, 0.6],
            [0, 1], [0.33, 1], [0.67, 1], [1, 1],
        ]
        let colors: [Color] = [
            sky, sky, sky, sky,
            tint(mid, layers.pm25), tint(mid, layers.no2), tint(mid, layers.ozone), tint(mid, layers.pm10),
            tint(low, layers.tree), tint(low, layers.weed), tint(low, layers.grass), tint(low, layers.pm25),
            base, base, base, base,
        ].enumerated().map { $0.offset < 12 ? $0.element.opacity(strength) : $0.element }

        return MeshGradient(width: 4, height: 4, points: points, colors: colors, background: base)
            // Humidity is the softness: dry crisp and saturated, humid paler.
            .saturation(humidity == "dry" ? 1.15 : humidity == "humid" ? 0.8 : 1)
            .contrast(humidity == "dry" ? 1.06 : 1)
            .accessibilityHidden(true)
    }

    // MARK: Inks (original)

    private func inkField(t: Double) -> some View {
        // Still: no drift.
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

/// The colour layers on top of the sky: one per pollutant and pollen type, at a strength from its level.
struct AirLayers {
    struct Layer {
        let name: String
        let color: Color
        let level: WeaveSpec.Level
        var amount: Double { [0.14, 0.36, 0.6][level.rawValue] }
    }

    var pm25: Layer?, pm10: Layer?, no2: Layer?, ozone: Layer?
    var tree: Layer?, grass: Layer?, weed: Layer?

    var all: [Layer] { [pm25, pm10, no2, ozone, tree, grass, weed].compactMap { $0 } }

    init(conditions c: Conditions?, weave: WeaveSpec, pollen: PollenSample?) {
        func level(_ b: PollutantBand) -> WeaveSpec.Level? {
            switch b { case .low: .low; case .moderate: .medium; case .high: .high; case .unknown: nil }
        }
        if let v = c?.best(.pm25)?.value, let l = level(Banding.pm25(v)) { pm25 = Layer(name: "PM2.5", color: WeatherColor.pm25, level: l) }
        if let v = c?.best(.pm10)?.value, let l = level(Banding.pm10(v)) { pm10 = Layer(name: "PM10", color: WeatherColor.pm10, level: l) }
        if let v = c?.best(.no2)?.value, let l = level(Banding.no2(ppb: v)) { no2 = Layer(name: "NO₂", color: WeatherColor.no2, level: l) }
        if let v = c?.best(.ozone)?.value, let l = level(Banding.ozone(ppb: v)) { ozone = Layer(name: "Ozone", color: WeatherColor.ozone, level: l) }
        // No per-pollutant readings (older moments, AQI only): the overall air level drives the PM2.5 layer.
        if pm25 == nil && pm10 == nil && no2 == nil && ozone == nil, let air = weave.levels[.air] {
            pm25 = Layer(name: "Air", color: WeatherColor.pm25, level: air)
        }
        if let p = pollen {
            let kinds = p.kinds
            if kinds[0].count > 0 { tree = Layer(name: "Tree pollen", color: WeatherColor.pollen[0], level: kinds[0].level) }
            if kinds[1].count > 0 { grass = Layer(name: "Grass pollen", color: WeatherColor.pollen[1], level: kinds[1].level) }
            if kinds[2].count > 0 { weed = Layer(name: "Weed pollen", color: WeatherColor.pollen[2], level: kinds[2].level) }
        }
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
    /// Pollutant layers: fine particles slate, coarse dust sand, NO₂ rust (it's a brown gas), ozone icy cyan.
    static let pm25 = Color(red: 0.42, green: 0.48, blue: 0.60)
    static let pm10 = Color(red: 0.86, green: 0.72, blue: 0.50)
    static let no2 = Color(red: 0.74, green: 0.38, blue: 0.24)
    static let ozone = Color(red: 0.66, green: 0.92, blue: 1.0)
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
