import AsthmaCore
import SwiftUI

/// Touch and hold the sky to explore it: whatever colour is under your finger is named, with its
/// reading and one line of plain help. The sky is the legend. Positions match AmbientField's mesh:
/// the top band is the base (temperature + humidity), the middle bands are the pollutant and pollen
/// layers, each sitting where its colour is drawn.
struct SkyProbe: Equatable {
    let title: String
    let value: String
    let help: String
    let color: Color
}

enum SkyExplorer {
    /// Where each layer's colour sits in the field (unit coordinates), same as AmbientField's mesh points.
    static let anchors: [(name: String, x: Double, y: Double)] = [
        ("PM2.5", 0, 0.3), ("NO₂", 0.33, 0.26), ("Ozone", 0.67, 0.3), ("PM10", 1, 0.26),
        ("Tree pollen", 0, 0.56), ("Weed pollen", 0.33, 0.6), ("Grass pollen", 0.67, 0.56), ("PM2.5", 1, 0.6),
    ]

    static func probe(at p: CGPoint, layers: AirLayers, conditions: Conditions?, weave: WeaveSpec,
                      temperatureF: Double?, pollen: PollenSample?) -> SkyProbe {
        let present = Dictionary(layers.all.map { ($0.name == "Air" ? "PM2.5" : $0.name, $0) }, uniquingKeysWith: { a, _ in a })
        if p.y > 0.16 && p.y < 0.78 {
            let nearest = anchors.filter { present[$0.name] != nil }
                .min { hypot($0.x - p.x, ($0.y - p.y) * 1.6) < hypot($1.x - p.x, ($1.y - p.y) * 1.6) }
            if let a = nearest, hypot(a.x - p.x, (a.y - p.y) * 1.6) < 0.45, let layer = present[a.name] {
                return SkyProbe(title: "\(layer.name) · \(Tier(layer.level).word)",
                                value: value(layer.name, conditions, pollen) ?? "",
                                help: help(layer.name, pollen), color: layer.color)
            }
        }
        // The base: temperature and humidity.
        var parts: [String] = []
        if let t = temperatureF { parts.append("\(Int(t.rounded()))°" + (weave.words[.temperature].map { ", \($0)" } ?? "")) }
        if let h = conditions?.best(.humidity)?.value { parts.append("\(Int(h.rounded()))% humidity" + (weave.words[.humidity].map { ", \($0)" } ?? "")) }
        return SkyProbe(title: "The sky", value: parts.joined(separator: " · "),
                        help: "Its hue is the temperature; its softness is the humidity.", color: .white)
    }

    private static func value(_ name: String, _ c: Conditions?, _ pollen: PollenSample?) -> String? {
        func obs(_ s: Signal) -> String? { c?.best(s).map { ObservationCopy.value($0) } }
        switch name {
        case "PM2.5": return obs(.pm25) ?? c?.best(.aqi).map { "AQI \(Int($0.value))" }
        case "PM10": return obs(.pm10)
        case "NO₂": return obs(.no2)
        case "Ozone": return obs(.ozone)
        case "Tree pollen": return pollen.map { "\($0.tree.count) grains/m³ · demo" }
        case "Grass pollen": return pollen.map { "\($0.grass.count) grains/m³ · demo" }
        case "Weed pollen": return pollen.map { "\($0.weed.count) grains/m³ · demo" }
        default: return nil
        }
    }

    private static func help(_ name: String, _ pollen: PollenSample?) -> String {
        switch name {
        case "PM2.5": "Fine particles from smoke, traffic and cooking."
        case "PM10": "Coarser dust and grit from roads, building work and dry ground."
        case "NO₂": "A gas from traffic exhaust and gas stoves."
        case "Ozone": "Forms in sunlight from traffic fumes, highest on hot afternoons."
        case "Tree pollen": "From trees like \(pollen?.tree.species ?? "oak"), mostly in spring."
        case "Grass pollen": "Mostly late spring and early summer."
        case "Weed pollen": "Mostly \(pollen?.weed.species.lowercased() ?? "ragweed"), which peaks in late summer."
        default: ""
        }
    }
}

/// The glow under your finger and the label above it.
struct SkyProbeOverlay: View {
    let point: CGPoint
    let probe: SkyProbe
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle()
                .fill(RadialGradient(colors: [probe.color.opacity(0.55), probe.color.opacity(0.15), .clear],
                                     center: .center, startRadius: 0, endRadius: 90))
                .frame(width: 180, height: 180)
                .blur(radius: 6)
                .position(point)
            VStack(alignment: .leading, spacing: 3) {
                Text(probe.title).font(.subheadline.weight(.semibold))
                if !probe.value.isEmpty { Text(probe.value).font(.caption.monospacedDigit()) }
                Text(probe.help).font(.caption).foregroundStyle(Theme.secondaryText)
            }
            .padding(12)
            .frame(width: 230, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .position(x: min(max(point.x, 131), width - 131), y: max(70, point.y - 110))
        }
        .allowsHitTesting(false)
        .animation(.interactiveSpring(duration: 0.2), value: point)
    }
}
