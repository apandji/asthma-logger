import AsthmaCore
import SwiftUI

/// Touch and hold the sky to explore it: whatever color is under your finger is named, with its
/// reading and one line of plain help. The sky is the legend. Positions match AmbientField's mesh:
/// the top band is the base (temperature + humidity), the middle bands are the pollutant and pollen
/// layers, each sitting where its color is drawn.
struct SkyProbe: Equatable {
    /// "NO₂"
    let name: String
    /// "Traffic exhaust" — what it is, in two or three words.
    let kind: String
    /// "3.1"
    let value: String
    /// "ppb"
    let unit: String
    let level: WeaveSpec.Level?
    /// One plain line.
    let note: String
    let color: Color
    /// 0 (clean) … 1 (high and rising): drives the haptic pulse.
    let intensity: Double

    /// What the highlight is tinted with: the level, in the same three colors as the verdict line
    /// (good green, OK yellow, not good red). The layer's own ink stays in the sky; its name is in the label.
    var levelInk: Color {
        switch level {
        case .low?: Verdict.green
        case .medium?: Verdict.yellow
        case .high?: Verdict.red
        case nil: .white
        }
    }
}

/// The three verdict colors, shared by the outlook line and the sky highlight.
enum Verdict {
    static let green = Color(red: 0.36, green: 0.80, blue: 0.47)
    static let yellow = Color(red: 0.98, green: 0.80, blue: 0.25)
    static let red = Color(red: 1.0, green: 0.36, blue: 0.32)
}

enum SkyExplorer {
    /// Where each layer's color sits in the field (unit coordinates), same as AmbientField's mesh points.
    static let anchors: [(name: String, x: Double, y: Double)] = [
        ("PM2.5", 0, 0.3), ("NO₂", 0.33, 0.26), ("Ozone", 0.67, 0.3), ("PM10", 1, 0.26),
        ("Tree pollen", 0, 0.56), ("Weed pollen", 0.33, 0.6), ("Grass pollen", 0.67, 0.56), ("PM2.5", 1, 0.6),
    ]

    static func probe(at p: CGPoint, layers: AirLayers, conditions: Conditions?, weave: WeaveSpec,
                      temperatureF: Double?, pollen: PollenSample?) -> SkyProbe? {
        let present = Dictionary(layers.all.map { ($0.name == "Air" ? "PM2.5" : $0.name, $0) }, uniquingKeysWith: { a, _ in a })
        if p.y > 0.16 && p.y < 0.82 {
            let nearest = anchors.filter { present[$0.name] != nil }
                .min { hypot($0.x - p.x, ($0.y - p.y) * 1.6) < hypot($1.x - p.x, ($1.y - p.y) * 1.6) }
            if let a = nearest, hypot(a.x - p.x, (a.y - p.y) * 1.6) < 0.45, let layer = present[a.name] {
                let (v, unit) = reading(layer.name, conditions, pollen)
                let position = (Double(layer.level.rawValue) + max(0, min(1, layer.fraction))) / 3
                return SkyProbe(name: layer.name, kind: kind(layer.name, pollen), value: v, unit: unit,
                                level: layer.level, note: note(layer.name), color: layer.color, intensity: position)
            }
        }
        // The top of the sky is the weather at that moment. Elsewhere, no layer under the finger: no label.
        guard p.y <= 0.3 else { return nil }
        let humidity = conditions?.best(.humidity)?.value
        let detail = [humidity.map { "\(Int($0.rounded()))% humidity" }, weave.words[.humidity]].compactMap { $0 }.joined(separator: ", ")
        return SkyProbe(name: "Weather",
                        kind: conditions?.weatherCondition ?? weave.words[.temperature].map { $0.capitalized } ?? "",
                        value: temperatureF.map { "\(Int($0.rounded()))" } ?? "–", unit: "°F", level: nil,
                        note: detail.isEmpty ? "" : detail + ".", color: .white, intensity: 0)
    }

    /// Strata: the sky as a core sample. Weather on top, then each present layer as a horizontal band
    /// down the field. Only the finger's height matters; left-right says nothing, because every layer is
    /// one regional reading, not a spot on the map. Returns the probe and its band (unit y).
    static func strata(at y: Double, layers: AirLayers, conditions: Conditions?, weave: WeaveSpec,
                       temperatureF: Double?, pollen: PollenSample?) -> (probe: SkyProbe, band: ClosedRange<Double>)? {
        let order = ["Ozone", "PM2.5", "PM10", "NO₂", "Tree pollen", "Grass pollen", "Weed pollen"]
        let present = Dictionary(layers.all.map { ($0.name == "Air" ? "PM2.5" : $0.name, $0) }, uniquingKeysWith: { a, _ in a })
        let stack = order.compactMap { present[$0] }
        let top = 0.14, bottom = 0.86
        let weatherBottom = stack.isEmpty ? bottom : top + (bottom - top) / Double(stack.count + 1)
        if y < weatherBottom {
            guard let w = probe(at: CGPoint(x: 0.5, y: 0.1), layers: layers, conditions: conditions, weave: weave,
                                temperatureF: temperatureF, pollen: pollen) else { return nil }
            return (w, 0...weatherBottom)
        }
        let each = (bottom - weatherBottom) / Double(max(1, stack.count))
        let i = min(stack.count - 1, Int((min(y, bottom - 0.001) - weatherBottom) / each))
        guard i >= 0, i < stack.count else { return nil }
        let layer = stack[i]
        let (v, unit) = reading(layer.name, conditions, pollen)
        let position = (Double(layer.level.rawValue) + max(0, min(1, layer.fraction))) / 3
        let p = SkyProbe(name: layer.name, kind: kind(layer.name, pollen), value: v, unit: unit,
                         level: layer.level, note: note(layer.name), color: layer.color, intensity: position)
        let start = weatherBottom + each * Double(i)
        return (p, start...(i == stack.count - 1 ? 1 : start + each))
    }

    /// The number and its unit, apart, so the number can be set large.
    private static func reading(_ name: String, _ c: Conditions?, _ pollen: PollenSample?) -> (String, String) {
        func obs(_ s: Signal) -> (String, String) {
            guard let o = c?.best(s) else { return ("–", "") }
            let rounded = o.value.rounded()
            let n = rounded == o.value || abs(o.value) >= 10 ? String(Int(rounded)) : String(format: "%.1f", o.value)
            return (n, o.unit)
        }
        switch name {
        case "PM2.5":
            if c?.best(.pm25) != nil { return obs(.pm25) }
            return c?.best(.aqi).map { (String(Int($0.value)), "AQI") } ?? ("–", "")
        case "PM10": return obs(.pm10)
        case "NO₂": return obs(.no2)
        case "Ozone": return obs(.ozone)
        case "Tree pollen": return (pollen.map { "\($0.tree.count)" } ?? "–", "grains/m³")
        case "Grass pollen": return (pollen.map { "\($0.grass.count)" } ?? "–", "grains/m³")
        case "Weed pollen": return (pollen.map { "\($0.weed.count)" } ?? "–", "grains/m³")
        default: return ("–", "")
        }
    }

    private static func kind(_ name: String, _ pollen: PollenSample?) -> String {
        switch name {
        case "PM2.5": "Fine particles"
        case "PM10": "Dust"
        case "NO₂": "Traffic exhaust"
        case "Ozone": "Sunlit smog"
        case "Tree pollen": pollen?.tree.species ?? "Trees"
        case "Grass pollen": "Grasses"
        case "Weed pollen": pollen?.weed.species ?? "Weeds"
        default: ""
        }
    }

    private static func note(_ name: String) -> String {
        switch name {
        case "PM2.5": "Smoke, exhaust, cooking."
        case "PM10": "Road dust, building sites, dry soil."
        case "NO₂": "Cars and gas stoves."
        case "Ozone": "Builds on sunny afternoons."
        case "Tree pollen": "Mostly spring."
        case "Grass pollen": "Late spring into summer."
        case "Weed pollen": "Late summer into fall."
        default: ""
        }
    }


}

/// The glow under your finger and a small, structured label: what it is, the reading set large with
/// its unit, the amount bars and level, and one plain line.
struct SkyProbeOverlay: View {
    let point: CGPoint
    let probe: SkyProbe
    let width: CGFloat
    var showsGlow = true
    var showsLabel = true
    /// Strata: the band (in points) the finger is in. The glow is then the whole band, full width.
    var band: ClosedRange<CGFloat>? = nil
    @AppStorage(LevelStyle.key) private var style = LevelStyle.signal

    var body: some View {
        ZStack(alignment: .topLeading) {
            if showsGlow, let band {
                // One regional reading: the layer lights up edge to edge, not a spot.
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, probe.levelInk.opacity(0.4), probe.levelInk.opacity(0.4), .clear],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: width, height: band.upperBound - band.lowerBound)
                    .blur(radius: 8)
                    .position(x: width / 2, y: (band.lowerBound + band.upperBound) / 2)
            } else if showsGlow {
            Circle()
                .fill(RadialGradient(colors: [probe.levelInk.opacity(0.5), probe.levelInk.opacity(0.15), .clear],
                                     center: .center, startRadius: 0, endRadius: 80))
                .frame(width: 160, height: 160)
                .blur(radius: 6)
                .position(point)
            }
            if showsLabel {
                // Above the finger, or below it when there's no room above.
                label
                    .frame(width: 224, alignment: .leading)
                    .position(x: min(max(point.x, 124), width - 124),
                              y: point.y > 150 ? point.y - 104 : point.y + 104)
            }
        }
        .allowsHitTesting(false)
        .animation(.interactiveSpring(duration: 0.2), value: point)
        .animation(.snappy(duration: 0.25), value: band)
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(probe.name).font(.subheadline.weight(.semibold))
                Text(probe.kind).font(.caption).foregroundStyle(Theme.secondaryText)
                Spacer(minLength: 0)
            }
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(probe.value).font(.system(.title, design: .rounded, weight: .semibold)).monospacedDigit()
                Text(probe.unit).font(.caption).foregroundStyle(Theme.secondaryText).lineLimit(1).fixedSize()
                Spacer(minLength: 8)
                if let level = probe.level {
                    VStack(alignment: .trailing, spacing: 2) {
                        LevelIndicator(level: level, ink: probe.levelInk, style: .signal)
                        Text(Tier(level).word).font(.caption2.weight(.semibold))
                    }
                }
            }
            if !probe.note.isEmpty {
                Text(probe.note).font(.caption).foregroundStyle(Theme.secondaryText).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .contentTransition(.numericText())
    }
}
