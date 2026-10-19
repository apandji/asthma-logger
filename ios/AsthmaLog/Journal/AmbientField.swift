import AsthmaCore
import SwiftUI
import UIKit

/// A moment's outdoor conditions as a soft color field, like a sky.
///
/// Two styles (Settings › Design crit › Color field):
/// - Weather (default), in layers:
///   - Base: temperature is the hue (blue cold → green mild → gold warm → red hot) under the light of
///     the hour (indigo night, rose dawn and dusk); humidity is the softness (dry crisp and saturated,
///     humid paler and softer).
///   - On top, each pollutant and pollen type adds its own color, faint when low and fuller when high,
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
    /// Per-pollutant readings for the color layers.
    var conditions: Conditions? = nil
    /// Demo pollen, when switched on in Design crit (pollen isn't connected yet).
    var pollen: PollenSample? = nil
    /// False: the field is weather only (the air is drawn as particles on top).
    var tintsLayers = true
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme
    @AppStorage(Crit.FieldStyle.key) private var style = Crit.FieldStyle.weather
    @AppStorage(Crit.LayerStrength.key) private var strengthStyle = Crit.LayerStrength.smooth
    @AppStorage(Crit.LayerSpread.key) private var spread = Crit.LayerSpread.vibe
    @AppStorage(Crit.Paper.key) private var paper = Crit.Paper.black

    var body: some View {
        if reduceTransparency {
            Theme.stage
        } else {
            Group {
                switch style {
                case .weather: weatherField
                case .inks: inkField(t: 0)
                }
            }
            // The mesh eases between readings (MeshGradient colours animate), so a sky that stays on screen
            // while its inputs change flows rather than cuts.
            .animation(.smooth(duration: 0.35), value: weave)
            .animation(.smooth(duration: 0.35), value: temperatureF)
        }
    }

    // MARK: Weather

    private var weatherField: some View {
        // Linen: ink on paper. Light colors wash out on an off-white page, so the sky is laid down fuller
        // (near-opaque), a touch darker, more saturated, and the layers overprint harder, like riso inks.
        let linen = paper == .linen || scheme == .light
        let base = linen ? Theme.linen : Theme.stage
        let humidity = weave.words[.humidity]
        var sky = WeatherColor.light(WeatherColor.temperature(temperatureF ?? WeatherColor.fallbackTemp(weave)), at: date)
        if humidity == "humid" { sky = sky.mix(with: .white, by: linen ? 0.08 : 0.16) }
        // Under the particles the weather is the paper, not a colour: a grey that leans warm or cool.
        if !tintsLayers { sky = sky.mix(with: Color(white: 0.42), by: 0.15) }
        // Linen: a light wash of the weather on the paper (owner, Oct 18), not a near-opaque fill; the
        // particles carry the ink.
        if linen { sky = sky.mix(with: base, by: 0.5) }
        let strength = linen ? 0.7 : (!tintsLayers ? 0.62 : (scheme == .dark ? 0.75 : 0.66))
        let overprint = linen ? 1.5 : 1.0

        let layers = AirLayers(conditions: conditions, weave: weave, pollen: pollen, smooth: strengthStyle == .smooth)
        func tint(_ c: Color, _ layer: AirLayers.Layer?) -> Color {
            guard let layer else { return c }
            return c.mix(with: layer.color, by: min(0.9, layer.amount * overprint))
        }
        // On linen the sky holds its color further down the field instead of fading to the paper.
        let mid = sky.mix(with: base, by: linen ? 0.35 : 0.3)
        let low = sky.mix(with: base, by: linen ? 0.65 : 0.55)
        // Rows: sky · pollutants · pollen · ground.
        let points: [SIMD2<Float>] = [
            [0, 0], [0.33, 0], [0.67, 0], [1, 0],
            [0, 0.3], [0.33, 0.26], [0.67, 0.3], [1, 0.26],
            [0, 0.56], [0.33, 0.6], [0.67, 0.56], [1, 0.6],
            [0, 1], [0.33, 1], [0.67, 1], [1, 1],
        ]
        // Vibe: every layer is folded into every point, so the air is a haze over the whole place and no
        // color can be read as a position. A little unevenness per point keeps it from going flat.
        func haze(_ c: Color, _ weight: Double) -> Color {
            layers.all.reduce(c) { $0.mix(with: $1.color, by: min(0.85, $1.amount * 0.7 * weight * overprint)) }
        }
        // Weather only (particles on top): the hue holds through the field so hot / cold, humid / dry read.
        let middle: [Color] = !tintsLayers ? Array(repeating: sky.mix(with: base, by: 0.08), count: 4) + Array(repeating: sky.mix(with: base, by: 0.22), count: 4) : spread == .spots
            ? [tint(mid, layers.pm25), tint(mid, layers.no2), tint(mid, layers.ozone), tint(mid, layers.pm10),
               tint(low, layers.tree), tint(low, layers.weed), tint(low, layers.grass), tint(low, layers.pm25)]
            : [haze(mid, 1.0), haze(mid, 1.15), haze(mid, 0.9), haze(mid, 1.05),
               haze(low, 1.1), haze(low, 0.95), haze(low, 1.2), haze(low, 1.0)]
        let colors: [Color] = ([sky, sky, sky, sky] + middle + [base, base, base, base])
            .enumerated().map { $0.offset < 12 ? $0.element.opacity(strength) : $0.element }

        return MeshGradient(width: 4, height: 4, points: points, colors: colors, background: base)
            // Humidity is the softness: dry crisp and saturated, humid paler.
            .saturation((humidity == "dry" ? 1.15 : humidity == "humid" ? 0.8 : 1) * (linen ? 1.3 : 1))
            .contrast((humidity == "dry" ? 1.06 : 1) * (linen ? 1.08 : 1))
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

/// The color layers on top of the sky: one per pollutant and pollen type, at a strength from its level.
struct AirLayers {
    struct Layer {
        let name: String
        let color: Color
        let level: WeaveSpec.Level
        /// Where the reading sits inside its level, 0…1 (used by the "smooth" strength).
        var fraction: Double = 0.5
        var smooth = false
        /// Nothing in the air (zero pollen): readable as "0 · Good", but adds no color to the sky.
        var empty = false

        /// Color strength. Steps: one strength per level. Smooth: rises with the amount inside the
        /// level's own range, never reaching the next level's, so the jump between levels stays clear.
        var amount: Double {
            guard smooth else { return [0.14, 0.36, 0.6][level.rawValue] }
            let range = [(0.08, 0.2), (0.3, 0.45), (0.55, 0.7)][level.rawValue]
            return range.0 + (range.1 - range.0) * max(0, min(1, fraction))
        }
    }

    var pm25: Layer?, pm10: Layer?, no2: Layer?, ozone: Layer?
    var tree: Layer?, grass: Layer?, weed: Layer?

    /// Layers that color the sky.
    var all: [Layer] { [pm25, pm10, no2, ozone, tree, grass, weed].compactMap { $0 }.filter { !$0.empty } }
    /// Layers you can read, zero pollen included, so every sky has the same strata.
    var readable: [Layer] { [pm25, pm10, no2, ozone, tree, grass, weed].compactMap { $0 } }

    /// Level edges per layer (start of low, moderate, high, and a ceiling for "high"):
    /// EPA for pollutants (µg/m³ or ppb), Ambee's risk thresholds for pollen (grains/m³).
    static let edges: [String: [Double]] = [
        "PM2.5": [0, 12, 35, 150], "PM10": [0, 55, 155, 355], "NO₂": [0, 54, 101, 360], "Ozone": [0, 55, 71, 125],
        "Tree pollen": [0, 100, 213, 940], "Grass pollen": [0, 30, 61, 342], "Weed pollen": [0, 44, 80, 296],
    ]

    init(conditions c: Conditions?, weave: WeaveSpec, pollen: PollenSample?, smooth: Bool = false) {
        func level(_ b: PollutantBand) -> WeaveSpec.Level? {
            switch b { case .low: .low; case .moderate: .medium; case .high: .high; case .unknown: nil }
        }
        func layer(_ name: String, _ color: Color, _ l: WeaveSpec.Level, _ value: Double?) -> Layer {
            var f = 0.5
            if let value, let e = Self.edges[name] {
                let lo = e[l.rawValue], hi = e[l.rawValue + 1]
                f = (value - lo) / max(0.001, hi - lo)
            }
            return Layer(name: name, color: color, level: l, fraction: f, smooth: smooth)
        }
        if let v = c?.best(.pm25)?.value, let l = level(Banding.pm25(v)) { pm25 = layer("PM2.5", WeatherColor.pm25, l, v) }
        if let v = c?.best(.pm10)?.value, let l = level(Banding.pm10(v)) { pm10 = layer("PM10", WeatherColor.pm10, l, v) }
        if let v = c?.best(.no2)?.value, let l = level(Banding.no2(ppb: v)) { no2 = layer("NO₂", WeatherColor.no2, l, v) }
        if let v = c?.best(.ozone)?.value, let l = level(Banding.ozone(ppb: v)) { ozone = layer("Ozone", WeatherColor.ozone, l, v) }
        // AirNow's official AQI wins when it says the air is worse than the nearest station's reading
        // (the station can sit just under a cut-off while the AQI, a NowCast over hours, is over it).
        // Its main pollutant takes the bump; otherwise PM2.5.
        if let aqi = c?.best(.aqi) {
            let l: WeaveSpec.Level = aqi.value <= 50 ? .low : aqi.value <= 100 ? .medium : .high
            let f = (aqi.value - [0, 51, 101][l.rawValue]) / [50.0, 49, 99][l.rawValue]
            let isOzone = (aqi.category ?? "").localizedCaseInsensitiveContains("ozone")
            if isOzone {
                if ozone == nil || ozone!.level < l { ozone = Layer(name: "Ozone", color: WeatherColor.ozone, level: l, fraction: f, smooth: smooth) }
            } else if pm25 == nil || pm25!.level < l {
                pm25 = Layer(name: "PM2.5", color: WeatherColor.pm25, level: l, fraction: f, smooth: smooth)
            }
        }
        // No per-pollutant readings and no AQI (older moments): the overall air level drives the PM2.5 layer.
        if pm25 == nil && pm10 == nil && no2 == nil && ozone == nil, let air = weave.levels[.air] {
            pm25 = Layer(name: "Air", color: WeatherColor.pm25, level: air, smooth: smooth)
        }
        // The moment's own pollen (Ambee, or its sample) first; the Design-crit demo season only stands in
        // when a moment has none.
        if let p = DemoPollen.from(c) ?? pollen {
            let kinds = p.kinds
            func pollenLayer(_ i: Int, _ name: String) -> Layer {
                var l = layer(name, WeatherColor.pollen[i], kinds[i].level, Double(kinds[i].count))
                l.empty = kinds[i].count == 0
                return l
            }
            tree = pollenLayer(0, "Tree pollen")
            grass = pollenLayer(1, "Grass pollen")
            weed = pollenLayer(2, "Weed pollen")
        }
    }
}

/// The weather color language, shared by the field and its legend.
enum WeatherColor {
    /// Each layer's own ink, by name: the color it paints the sky with, the scale and the grain.
    static func ink(for name: String) -> Color {
        switch name {
        case "PM2.5", "Air": pm25
        case "PM10": pm10
        case "NO₂": no2
        case "Ozone": ozone
        case "Tree pollen": pollen[0]
        case "Grass pollen": pollen[1]
        case "Weed pollen": pollen[2]
        default: .white
        }
    }

    /// Riso inks (Design crit › Inks, docs/design/color-review-riso.md): the sky, layers and verdicts drawn
    /// only from real RISO spot inks, so every colour on screen is one a press could print.
    static var riso: Bool { UserDefaults.standard.string(forKey: Crit.Inks.key) != Crit.Inks.current.rawValue }
    /// Simple (the default, owner Oct 18): one ink per family. Weather is cool / mild / hot, pollutants all Aqua,
    /// allergens all Violet; amount is size and density, never a different hue. The hour has no colour.
    static var simple: Bool { UserDefaults.standard.string(forKey: Crit.Inks.key) == Crit.Inks.simple.rawValue }
    /// Print (the default, owner Oct 18, docs/design/color-review-riso.md): paper and three inks, one per
    /// family, and hue says only *which*. Weather is one ink too (Amber): its amount is how far the temperature
    /// is from mild, hot or cold alike, the way the lift table bins it. Hot vs cold is in the words.
    static var print: Bool {
        let v = UserDefaults.standard.string(forKey: Crit.Inks.key)
        return v == nil || v == Crit.Inks.print.rawValue
    }
    /// One ink per family in Print and Simple.
    static var flat: Bool { print || simple }
    /// Weather's ink: Fluorescent Pink, a hue with no hot-or-cold meaning (amber said "hot"; blue said "cold"),
    /// and the one free region of the wheel next to aqua, violet and the verdict's green / yellow / red.
    static let amber = Color(red: 0xFF / 255, green: 0x48 / 255, blue: 0xB0 / 255)
    static let paperTone = Color(red: 0x8C / 255, green: 0x8A / 255, blue: 0x86 / 255)
    /// 0 at mild (57–73°F), 1 by 32°F or 98°F.
    static func weatherAmount(_ f: Double) -> Double { max(0, min(1, (abs(f - 65) - 8) / 25)) }
    static let aqua = Color(red: 0x5E / 255, green: 0xC8 / 255, blue: 0xE5 / 255)
    static let violet = Color(red: 0x9D / 255, green: 0x7A / 255, blue: 0xD2 / 255)
    /// Allergens' ink: bright Yellow (riso Yellow). Pollen is yellow, and it sits a third of the wheel from
    /// pink and aqua. The verdict's middle step is a gold-orange so the two never meet.
    static let gold = Color(red: 0xFF / 255, green: 0xE8 / 255, blue: 0x00 / 255)

    static func hex(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    /// Blue (cold) → sky → sage (mild) → amber (warm) → red (hot), by °F.
    /// Spread so ordinary days differ: 45° sky blue, 55° teal, 63° green, 70° gold, 78° orange, 88° red.
    static var stops: [(f: Double, color: Color)] {
        if simple {
            // Medium Blue below 50°F, plain (a quiet paper grey) through the 60s, Orange from the high 70s.
            let plain = hex(0x8C8A86)
            return [(40, hex(0x3255A4)), (52, plain), (72, plain), (84, hex(0xFF6C2F))]
        }
        if riso {
            // Medium Blue · Aqua · Teal · Kelly Green · Sunflower · Orange · Bright Red
            return [(30, hex(0x3255A4)), (45, hex(0x5EC8E5)), (55, hex(0x00838A)), (63, hex(0x67B346)),
                    (70, hex(0xFFB511)), (78, hex(0xFF6C2F)), (88, hex(0xF15060))]
        }
        return [
            (30, Color(red: 0.22, green: 0.34, blue: 0.86)),
            (45, Color(red: 0.30, green: 0.58, blue: 0.92)),
            (55, Color(red: 0.20, green: 0.70, blue: 0.72)),
            (63, Color(red: 0.42, green: 0.76, blue: 0.42)),
            (70, Color(red: 0.93, green: 0.78, blue: 0.32)),
            (78, Color(red: 0.97, green: 0.56, blue: 0.24)),
            (88, Color(red: 0.90, green: 0.28, blue: 0.22)),
        ]
    }

    /// One ink per factor, used everywhere a pattern shows: the Insights wash, the radar, the card dots.
    /// Heat is the hot end of the temperature scale, cold the cold end; pollutants and pollen their layer inks.
    /// Nil for what isn't the air (journal tags, time, place): the family's own ink stands in.
    static func ink(bin: String, level: String) -> Color? {
        if print, ["temp", "temp_drop", "heat_alert", "humidity"].contains(bin) { return amber }
        let c: Color? = switch bin {
        case "temp": temperature(level == "hot" ? 88 : level == "cold" ? 30 : 62)
        case "temp_drop": temperature(32)
        case "heat_alert": temperature(92)
        case "humidity": level == "dry" ? temperature(70) : temperature(48)
        case "pm25": pm25
        case "pm10": pm10
        case "no2": no2
        case "ozone": ozone
        case "smoke_at_point": flat ? aqua : Color(red: 0.6, green: 0.42, blue: 0.25)
        case "pollen_tree": pollen[0]
        case "pollen_grass": pollen[1]
        case "pollen_weed": pollen[2]
        default: nil
        }
        return c
    }

    /// Multiply, like a second drum over the first: each channel of the first ink darkened by the second, at
    /// `amount` coverage. A hot night stays red under the blue (not the same lavender-grey as a cold one).
    static func overprint(_ base: Color, _ ink: Color, _ amount: Double) -> Color {
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        UIColor(base).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(ink).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let k = CGFloat(max(0, min(1, amount)))
        func m(_ x: CGFloat, _ y: CGFloat) -> Double { Double(x * (1 - k + k * y)) }
        return Color(red: m(r1, r2), green: m(g1, g2), blue: m(b1, b2))
    }

    /// The hour as a second ink over the temperature's: Federal Blue at night, Fluorescent Pink at dawn and
    /// dusk, nothing by day.
    static func overprintHour(_ c: Color, at date: Date) -> Color {
        let cal = Calendar.current
        let h = Double(cal.component(.hour, from: date)) + Double(cal.component(.minute, from: date)) / 60
        let night = hex(0x3D5588), pink = hex(0xFF48B0)
        switch h {
        case ..<5, 21...: return overprint(c, night, 0.7)
        case 5..<8: return overprint(c, pink, 0.4 * (1 - abs(h - 6.5) / 1.5) + 0.1)
        case 17..<21:
            let dusk = overprint(c, pink, 0.15 + 0.3 * (h - 17) / 4)
            return overprint(dusk, night, max(0, (h - 19.5) / 1.5) * 0.6)
        default: return c
        }
    }

    static func isNight(_ date: Date?) -> Bool {
        guard let date else { return false }
        let h = Calendar.current.component(.hour, from: date)
        return h < 5 || h >= 21
    }

    /// The light of the hour over the temperature hue: deep indigo at night, rose at dawn and dusk.
    static func light(_ c: Color, at date: Date?) -> Color {
        guard let date else { return c }
        if flat {
            // No hue for the hour: night only prints darker.
            let h = Calendar.current.component(.hour, from: date)
            return h < 5 || h >= 21 ? overprint(c, Color(white: 0.55), 1) : c
        }
        if riso { return overprintHour(c, at: date) }
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
    /// Riso: Slate, Flat Gold, Brick, Aqua; pollen Green, Sunflower, Violet.
    static var pm25: Color { flat ? aqua : riso ? hex(0x5E695E) : Color(red: 0.42, green: 0.48, blue: 0.60) }
    static var pm10: Color { flat ? aqua : riso ? hex(0xBB8B41) : Color(red: 0.86, green: 0.72, blue: 0.50) }
    static var no2: Color { flat ? aqua : riso ? hex(0xA75154) : Color(red: 0.74, green: 0.38, blue: 0.24) }
    static var ozone: Color { flat ? aqua : riso ? hex(0x5EC8E5) : Color(red: 0.66, green: 0.92, blue: 1.0) }
    static var pollen: [Color] {
        flat ? [gold, gold, gold] : riso ? [hex(0x00A95C), hex(0xFFB511), hex(0x9D7AD2)]
             : [Color(red: 0.36, green: 0.80, blue: 0.46),   // tree: green
                Color(red: 0.98, green: 0.80, blue: 0.22),   // grass: gold
                Color(red: 0.72, green: 0.42, blue: 0.95)]   // weed: violet
    }

    static func temperature(_ f: Double) -> Color {
        // Print: paper, with Amber laid on as the temperature leaves mild, in either direction.
        if print { return paperTone.mix(with: amber, by: 0.7 * weatherAmount(f)) }
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

/// Riso grain over the sky: a halftone of tiny ink dots on a slightly turned grid. At rest it's a
/// print texture; under a finger the dots swell and take the ink of the layer being read, so the sky
/// reads as a surface that answers touch.
struct SkyGrain: View {
    /// Where the finger is, in the sky's own coordinates.
    var point: CGPoint? = nil
    /// The ink of the layer under the finger.
    var ink: Color? = nil
    /// 0 clean … 1 high: how far the dots swell.
    var intensity: Double = 0
    /// Static grain only, no response.
    var responds = true
    /// When the sky appeared: a wave runs out through the dots to say "touch me". Until the sky has
    /// been touched once it runs again every few seconds.
    var rippleAt: Date? = nil
    var inviting = true
    /// Strata: the band (in points) being read. The swell then runs the full width of the band.
    var band: ClosedRange<CGFloat>? = nil
    /// Strata: the ripple is a horizontal wave sweeping down through the layers, not a ring.
    var sweeps = false
    /// The ripple's ink. White to invite touch; the moment's orange or blue when a log has just landed,
    /// when it also runs as a ring from the + (bottom right), whatever the reading mode.
    var rippleInk: Color = .white
    var rippleFromCapture = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let spacing: CGFloat = 10
    private let angle: CGFloat = 12 * .pi / 180
    private let reach: CGFloat = 80
    private let rippleSeconds = 1.6
    private let rippleEvery = 5.0

    var body: some View {
        // Alive at rest: a slow breath moves through the grain (24 fps is plenty; off with Reduce Motion).
        TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion || !responds)) { frame in
            grain(at: frame.date)
        }
    }

    private func grain(at time: Date) -> some View {
        // The wavefront: a ring that grows from the centre and fades as it goes.
        var age = rippleAt.map { time.timeIntervalSince($0) } ?? rippleSeconds
        if inviting, age >= rippleSeconds { age = age.truncatingRemainder(dividingBy: rippleEvery) }
        let wave = (responds && !reduceMotion && age < rippleSeconds) ? age / rippleSeconds : nil
        let breath = reduceMotion || !responds ? 0.0 : time.timeIntervalSinceReferenceDate
        return Canvas(rendersAsynchronously: true) { ctx, size in
            let cosA = cos(angle), sinA = sin(angle)
            // A new sky's ripple starts at the pin (the map is centred on the place): "you are here", then
            // the air around it. A fresh log's starts at the +.
            let centre = rippleFromCapture ? CaptureReveal.origin(in: size) : CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = wave.map { rippleFromCapture ? CaptureReveal.radius(CGFloat($0), in: size) : CGFloat($0) * hypot(size.width, size.height) * 0.6 }
            let sweeps = false  // the ring from the pin says more than a sweep did; kept as a flag for the crit
            let strong: CGFloat = rippleFromCapture ? 1.6 : 1
            let fade = wave.map { 1 - $0 } ?? 0
            let diag = hypot(size.width, size.height)
            let n = Int(diag / spacing) + 2
            let rest: CGFloat = 0.9   // small, so the map reads through
            let ink = ink ?? .white
            // A turned grid, big enough to cover the corners.
            for i in -n...n {
                for j in -n...n {
                    let gx = CGFloat(i) * spacing, gy = CGFloat(j) * spacing
                    let x = size.width / 2 + gx * cosA - gy * sinA
                    let y = size.height / 2 + gx * sinA + gy * cosA
                    guard x > -4, y > -4, x < size.width + 4, y < size.height + 4 else { continue }
                    // Printed, not plotted: each dot a little different.
                    let wobble = CGFloat((i &* 73 &+ j &* 151) & 7) / 7
                    var r = rest * (0.7 + 0.5 * wobble)
                    var color = Color.black.opacity(0.26)
                    if breath > 0 {
                        // A slow swell drifting across the field, like breathing.
                        let phase = breath * 1.1 + Double(x + y) / 90
                        let b = CGFloat(0.5 + 0.5 * sin(phase))
                        r += 0.35 * b
                        color = Color.black.opacity(0.2 + 0.12 * Double(b))
                    }
                    if responds, point != nil {
                        // Reading a layer: every dot in the field becomes that layer, the same everywhere.
                        // Size and ink say how much of it there is, never where. The finger only chose which.
                        let amount = CGFloat(intensity)
                        r += (0.5 + 2.6 * amount) * (0.75 + 0.5 * wobble)
                        color = ink.opacity(0.3 + 0.55 * Double(amount))
                    } else if let radius {
                        // Dots near the wavefront swell and go white, then settle back. The front is a ring
                        // from the centre (blob) or a line sweeping top to bottom (strata).
                        let d = sweeps ? abs(y - radius / 0.6 / hypot(size.width, size.height) * size.height)
                                       : abs(hypot(x - centre.x, y - centre.y) - radius)
                        let width = 36 * strong
                        if d < width {
                            let t = (1 - d / width) * fade
                            r += t * t * 2.4 * strong
                            color = rippleInk.opacity(0.15 + 0.7 * Double(t))
                        }
                    }
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A fresh log wipes the new sky in from the +: a circle grows from the button's spot over the same
/// 1.6 s as the grain's ripple, so the ring is the wavefront and the new sky is what it leaves behind.
struct CaptureReveal: ViewModifier {
    @State private var t: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The + sits below the sky's bottom corner on the rail's side (under the timeline).
    static func origin(in size: CGSize) -> CGPoint {
        let left = UserDefaults.standard.bool(forKey: Prefs.railLeft)
        return CGPoint(x: left ? 36 : size.width - 36, y: size.height + 150)
    }
    static func radius(_ t: CGFloat, in size: CGSize) -> CGFloat { t * hypot(size.width, size.height) * 1.1 }

    func body(content: Content) -> some View {
        content
            .mask {
                GeometryReader { g in
                    let r = reduceMotion ? Self.radius(1, in: g.size) : Self.radius(t, in: g.size)
                    Circle().frame(width: 2 * r, height: 2 * r).position(Self.origin(in: g.size))
                }
            }
            .onAppear { withAnimation(.linear(duration: 1.6)) { t = 1 } }
    }
}
