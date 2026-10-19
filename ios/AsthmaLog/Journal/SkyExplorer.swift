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
    var kind: String
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
    /// Overrides the layer's usual symbol (the Weather row after a sharp temperature drop).
    var symbol: String? = nil
    /// The look-back: what this layer did before, as (window, value) rows. "Last 6 h", "6–48 h before".
    var before: [LookBackRow] = []
    /// The 48 hours before, as lines: temperature and humidity for Weather, the pollutant's own hours
    /// for PM2.5 and ozone. Filled in by the sky once its history has loaded.
    var lines: [SparkSeries] = []

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
    // Riso: Green, a gold-orange (not yellow: that's pollen's), Bright Red. On linen each prints a step deeper,
    // like the three air inks, so the set holds at one weight on either paper (owner, Oct 18).
    static var green: Color { WeatherColor.riso ? WeatherColor.hex(WeatherColor.onLinen ? 0x1E8E52 : 0x00A95C) : Color(red: 0.36, green: 0.80, blue: 0.47) }
    static var yellow: Color { WeatherColor.riso ? WeatherColor.hex(WeatherColor.onLinen ? 0xE39A2A : 0xF2A93B) : Color(red: 0.98, green: 0.80, blue: 0.25) }
    static var red: Color { WeatherColor.riso ? WeatherColor.hex(WeatherColor.onLinen ? 0xD63B4C : 0xF15060) : Color(red: 1.0, green: 0.36, blue: 0.32) }

    /// The ink to write on a verdict with: white on green and red (black fails on both), black on the gold.
    static func text(on tint: Color) -> Color { tint == yellow ? .black : .white }
}

enum SkyExplorer {
    /// Where each layer's color sits in the field (unit coordinates), same as AmbientField's mesh points.
    static let anchors: [(name: String, x: Double, y: Double)] = [
        ("PM2.5", 0, 0.3), ("NO₂", 0.33, 0.26), ("Ozone", 0.67, 0.3), ("PM10", 1, 0.26),
        ("Tree pollen", 0, 0.56), ("Weed pollen", 0.33, 0.6), ("Grass pollen", 0.67, 0.56), ("PM2.5", 1, 0.6),
    ]

    static func probe(at p: CGPoint, layers: AirLayers, conditions: Conditions?, weave: WeaveSpec,
                      temperatureF: Double?, pollen: PollenSample?) -> SkyProbe? {
        let present = Dictionary(layers.readable.map { ($0.name == "Air" ? "PM2.5" : $0.name, $0) }, uniquingKeysWith: { a, _ in a })
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
        // What came before (docs/air-outlook.md): one plain line when the weather just changed sharply.
        let before = TempDrop.line(conditions?.tempFallF)
        let note = [detail.isEmpty ? nil : detail + ".", before].compactMap { $0 }.joined(separator: " ")
        return SkyProbe(name: "Weather",
                        kind: conditions?.weatherCondition ?? weave.words[.temperature].map { $0.capitalized } ?? "",
                        value: temperatureF.map { "\(Int($0.rounded()))" } ?? "–", unit: "°F", level: nil,
                        note: note, color: .white, intensity: 0, symbol: weatherIcon(conditions))
    }

    /// Strata: the sky as a core sample. Weather on top, then each present layer as a horizontal band
    /// down the field. Only the finger's height matters; left-right says nothing, because every layer is
    /// one regional reading, not a spot on the map. Returns the probe and its band (unit y).
    /// The layers in reading order: worst on top, just under the weather, so the band nearest your eye is
    /// the one that matters most today. Ties keep a fixed order so the stack doesn't shuffle between skies.
    static func stack(_ layers: AirLayers) -> [AirLayers.Layer] {
        let order = ["Ozone", "PM2.5", "PM10", "NO₂", "Tree pollen", "Grass pollen", "Weed pollen"]
        let present = Dictionary(layers.readable.map { ($0.name == "Air" ? "PM2.5" : $0.name, $0) }, uniquingKeysWith: { a, _ in a })
        return order.compactMap { present[$0] }.enumerated().sorted { a, b in
            let la = a.element.level.rawValue, lb = b.element.level.rawValue
            if la != lb { return la > lb }
            if a.element.empty != b.element.empty { return !a.element.empty }
            if a.element.fraction != b.element.fraction { return a.element.fraction > b.element.fraction }
            return a.offset < b.offset
        }.map(\.element)
    }

    /// The bands (unit y), weather first: a compact stack of equal rows centred in the sky, so the icons
    /// on the scale sit evenly whatever the count. Touches above or below the stack read its ends.
    static func bands(count layers: Int, height: Double) -> [ClosedRange<Double>] {
        let n = layers + 1
        let row = min(0.11, 0.72 / Double(n))      // ~44 pt of a 400 pt sky, tighter when there are many
        let start = 0.5 - row * Double(n) / 2
        return (0..<n).map { (start + row * Double($0))...(start + row * Double($0 + 1)) }
    }

    static func strata(at y: Double, layers: AirLayers, conditions: Conditions?, weave: WeaveSpec,
                       temperatureF: Double?, pollen: PollenSample?) -> (probe: SkyProbe, band: ClosedRange<Double>)? {
        let stack = stack(layers)
        let bands = bands(count: stack.count, height: 1)
        let i = max(0, min(bands.count - 1, bands.firstIndex { $0.contains(y) } ?? (y < bands[0].lowerBound ? 0 : bands.count - 1)))
        if i == 0 {
            guard var w = probe(at: CGPoint(x: 0.5, y: 0.1), layers: layers, conditions: conditions, weave: weave,
                                temperatureF: temperatureF, pollen: pollen) else { return nil }
            w.before = lookBack("Weather", conditions)
            return (w, bands[0])
        }
        let layer = stack[i - 1]
        let (v, unit) = reading(layer.name, conditions, pollen)
        let position = (Double(layer.level.rawValue) + max(0, min(1, layer.fraction))) / 3
        var p = SkyProbe(name: layer.name, kind: kind(layer.name, pollen), value: v, unit: unit,
                         level: layer.level, note: note(layer.name), color: layer.color, intensity: position)
        p.before = lookBack(layer.name, conditions)
        return (p, bands[i])
    }

    /// One layer's reading, by name (the rail's items).
    static func layerProbe(_ name: String, layers: AirLayers, conditions: Conditions?, pollen: PollenSample?) -> SkyProbe? {
        guard let layer = layers.readable.first(where: { ($0.name == "Air" ? "PM2.5" : $0.name) == name }) else { return nil }
        let (v, unit) = reading(name, conditions, pollen)
        let position = (Double(layer.level.rawValue) + max(0, min(1, layer.fraction))) / 3
        var p = SkyProbe(name: name, kind: kind(name, pollen), value: v, unit: unit,
                         level: layer.level, note: note(name), color: layer.color, intensity: position)
        p.before = lookBack(name, conditions)
        return p
    }

    /// The look-back rows for a layer (weather, PM2.5, ozone), from the 48 hours stored with the reading.
    /// A window shows only when at least half its hours were read; otherwise it's missing, not clean.
    static func lookBack(_ name: String, _ c: Conditions?) -> [LookBackRow] {
        guard let lb = c?.lookBack else { return [] }
        func peak(_ w: WindowPeak, needed: Int, _ text: (Double) -> String) -> String? {
            guard w.hours >= needed, let v = w.worst else { return nil }
            return text(v)
        }
        let (a, b): (String?, String?) = switch name {
        case "Weather":
            (peak(lb.tempFallNow, needed: 3) { $0 < 1 ? "Steady" : "Fell \(Int($0.rounded()))°" },
             peak(lb.tempFallEarlier, needed: 21) { $0 < 1 ? "Steady" : "Fell \(Int($0.rounded()))°" })
        case "PM2.5", "Air":
            (peak(lb.pm25Now, needed: 3) { "Up to \(Int($0.rounded())) µg/m³" },
             peak(lb.pm25Earlier, needed: 21) { "Up to \(Int($0.rounded())) µg/m³" })
        case "Ozone":
            (peak(lb.ozoneNow, needed: 3) { "Up to \(Int($0.rounded())) ppb" },
             peak(lb.ozoneEarlier, needed: 21) { "Up to \(Int($0.rounded())) ppb" })
        default: (nil, nil)
        }
        return [a.map { LookBackRow(window: "Last 6 h", value: $0) }, b.map { LookBackRow(window: "6–48 h before", value: $0) }]
            .compactMap { $0 }
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

    /// The Weather row's symbol: changes when the weather just did something worth reading.
    static func weatherIcon(_ conditions: Conditions?) -> String {
        TempDrop.band(conditions?.tempFallF) == .sharp ? Icons.tempDrop : Icons.weather
    }

    /// One symbol per layer: `Icons` is the single source.
    static func icon(_ name: String) -> String { Icons.layer(name) }

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
    /// The label sits level with `point` (beside a scale icon) instead of above or below a finger.
    var beside = false
    /// The label in one fixed place, the sky's top left (the rail: the reading stays put, the name follows).
    var topLeading = false
    @AppStorage(LevelStyle.key) private var style = LevelStyle.signal
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            if showsGlow, let band {
                // One regional reading: the layer lights up edge to edge, not a spot.
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, probe.color.opacity(0.4), probe.color.opacity(0.4), .clear],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: width, height: band.upperBound - band.lowerBound)
                    .blur(radius: 8)
                    .position(x: width / 2, y: (band.lowerBound + band.upperBound) / 2)
            } else if showsGlow {
            Circle()
                .fill(RadialGradient(colors: [probe.color.opacity(0.5), probe.color.opacity(0.15), .clear],
                                     center: .center, startRadius: 0, endRadius: 80))
                .frame(width: 160, height: 160)
                .blur(radius: 6)
                .position(point)
            }
            if showsLabel && topLeading {
                label.frame(width: 224, alignment: .leading)
                    .padding(.leading, 12).padding(.top, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if showsLabel {
                // Above the finger, or below it when there's no room above.
                label
                    .frame(width: 224, alignment: .leading)
                    .position(x: min(max(point.x, 124), width - 124),
                              y: beside ? max(64, point.y) : (point.y > 150 ? point.y - 104 : point.y + 104))
            }
        }
        .allowsHitTesting(false)
        .animation(reduceMotion ? nil : .interactiveSpring(duration: 0.2), value: point)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: band)
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label {
                    Text(probe.name)
                } icon: {
                    // The connection to the field: this is the ink of the particles you're reading.
                    Image(systemName: probe.symbol ?? SkyExplorer.icon(probe.name)).foregroundStyle(probe.level == nil ? .primary : probe.color)
                }
                .font(.subheadline.weight(.semibold))
                Text(probe.kind).font(.caption).foregroundStyle(Theme.secondaryText)
                Spacer(minLength: 0)
            }
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(probe.value).font(.system(.title, design: .rounded, weight: .semibold)).monospacedDigit()
                Text(probe.unit).font(.caption).foregroundStyle(Theme.secondaryText).lineLimit(1).fixedSize()
                Spacer(minLength: 8)
                if let level = probe.level {
                    VStack(alignment: .trailing, spacing: 4) {
                        AmountDots(level: level, ink: probe.color)
                        Text(Tier(level).word).font(.caption2.weight(.semibold))
                    }
                }
            }
            if !probe.note.isEmpty {
                Text(probe.note).font(.caption).foregroundStyle(Theme.secondaryText).fixedSize(horizontal: false, vertical: true)
            }
            if !probe.lines.isEmpty {
                // The 48 hours before, drawn: the reading is the right-hand end of each line.
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(probe.lines, id: \.name) { line in
                        Sparkline(series: line)
                    }
                    HStack {
                        Text("48 h before").font(.caption2).foregroundStyle(Theme.secondaryText)
                        Spacer()
                        Text("now").font(.caption2).foregroundStyle(Theme.secondaryText)
                    }
                }
                .padding(.top, 6)
                .overlay(alignment: .top) { Rectangle().fill(Theme.secondaryText.opacity(0.25)).frame(height: 0.5) }
            }
            if !probe.before.isEmpty {
                // The look-back: what came before this reading.
                VStack(alignment: .leading, spacing: 4) {
                    Text("Before this").font(.caption2.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                    ForEach(probe.before, id: \.window) { row in
                        HStack {
                            Text(row.window).foregroundStyle(Theme.secondaryText)
                            Spacer(minLength: 8)
                            Text(row.value).monospacedDigit()
                        }
                        .font(.caption)
                    }
                }
                .padding(.top, 4)
                .overlay(alignment: .top) { Rectangle().fill(Theme.secondaryText.opacity(0.25)).frame(height: 0.5).offset(y: -2) }
            }
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .contentTransition(.numericText())
    }
}

/// The rail's groups, in the language of Personal Insights: Weather, Pollutants, Allergens, then Self
/// (set apart: it isn't in the sky, and choosing it slides the map away to your words and activity).
enum RailGroup: String, CaseIterable {
    case weather, particles, biologics

    /// The families a read marks as patterns (each marked sentence, by its words), for the rail's badge.
    static func marked(in read: String) -> Set<RailGroup> {
        var out: Set<RailGroup> = []
        var run = ""
        for ch in read {
            guard TheRead.Mark(rawValue: String(ch)) != nil else { run.append(ch); continue }
            let clause = (run.components(separatedBy: ". ").last ?? run).lowercased()
            if ["pollen", "mold", "mould"].contains(where: clause.contains) { out.insert(.biologics) }
            if ["particle", "ozone", "smoke", "nitrogen", "pm2", "pm10", "air quality"].contains(where: clause.contains) { out.insert(.particles) }
            if ["temperature", "humid", "cold", "heat", "hot", "dry", "rain", "storm", "wind"].contains(where: clause.contains) { out.insert(.weather) }
            run = ""
        }
        return out
    }

    var title: String {
        switch self {
        case .weather: "Weather"
        case .particles: "Pollutants"
        case .biologics: "Allergens"
        }
    }

    var icon: String {
        switch self {
        case .weather: Icons.weather
        case .particles: Icons.particles
        case .biologics: Icons.biologics
        }
    }

    /// The sky's layers inside the group, in a fixed order.
    var items: [String] {
        switch self {
        case .weather: []
        case .particles: ["PM2.5", "PM10", "Ozone", "NO₂"]
        case .biologics: ["Tree pollen", "Grass pollen", "Weed pollen"]
        }
    }
}

enum RailRow: Hashable {
    case header(RailGroup)
    case item(String)
    /// Your voice (words, tags; slide in to record) and your body (activity, Apple Health): stops of their own.
    case voice, body

    /// Voice and Body stay open when you let go on them.
    var isSelf: Bool { self == .voice || self == .body }

    /// Folded: four stops. Held: every group with its items' dots underneath, laid out once for the whole
    /// hold so nothing shifts under the finger. Items only for layers this sky has.
    static func rows(expanded: Bool, layers: AirLayers, includesSelf: Bool) -> [RailRow] {
        let present = Set(layers.readable.map { $0.name == "Air" ? "PM2.5" : $0.name })
        var out: [RailRow] = []
        for g in RailGroup.allCases {
            out.append(.header(g))
            if expanded { out += g.items.filter(present.contains).map { .item($0) } }
        }
        if includesSelf { out += [.voice, .body] }
        return out
    }

    /// Row centres (unit y), evenly spaced. Self is a stop like the others.
    static func mids(_ rows: [RailRow]) -> [Double] { mids(count: rows.count) }

    static func mids(count: Int) -> [Double] {
        let units = Double(max(1, count - 1))
        let span = min(0.72, 0.075 * units)
        let start = 0.5 - span / 2
        return (0..<count).map { start + span * Double($0) / units }
    }

    /// The column is laid out against the bottom of the sky, which never moves, over a fixed reference
    /// height: the stops stay put as the header grows and shrinks above. Only when the sky is shorter than
    /// the reference, the rail keeps its size and draws over what's above (no longer compressed).
    static let reference: CGFloat = 520

    /// Row centres in points, bottom-anchored.
    static func ys(_ rows: [RailRow], in height: CGFloat) -> [CGFloat] { ys(count: rows.count, in: height) }

    static func ys(count: Int, in height: CGFloat) -> [CGFloat] {
        // Never compressed (owner, Oct 18: "it should stay consistent and on top of everything"): the column is
        // the same size, the same distance from the bottom, whatever the sky's height. A short sky (a long
        // sentence, a card) lets the top of the rail rise over the header instead of squeezing it.
        let base = reference
        return mids(count: count).map { height - (1 - CGFloat($0)) * base }
    }

    /// The name tag beside the thumb.
    var name: String {
        switch self {
        case .header(let g): g.title
        case .item(let n): n
        case .voice: "Your voice"
        case .body: "Your body"
        }
    }

    /// Whether this row has a reading to show (group headers only name themselves).
    var reads: Bool {
        switch self {
        case .header(let g): g.items.isEmpty   // Weather reads; Pollutants and Allergens just name.
        case .item, .voice, .body: true
        }
    }
}

/// The rail on the right edge of the sky. Folded: one icon per group (size says how much, worst item), and
/// Self below. Held: each group shows its items as dots beneath it; slide to read any of them.
struct GroupRail: View {
    let layers: AirLayers
    let rows: [RailRow]
    let mids: [CGFloat]
    let selected: RailRow?
    var weatherSymbol = Icons.weather
    /// The sky's base ink (the temperature), so the Weather stop wears the colour it paints.
    var weatherInk: Color? = nil
    /// Print: how far the weather is from mild (0…1), for the Weather stop's fill.
    var weatherAmount: Double = 0
    /// The moment wants a note: Voice wears a small dot.
    var voiceBadge = false
    /// Families the read marks as patterns: their icon wears a small dot (the sentence's underline, here).
    var patterns: Set<RailGroup> = []
    /// The thumb's height while the rail is held: a lens. The stop under it grows and the two beside it
    /// ease away, like the Dock, so the rail reads as a scale you slide along.
    var fingerY: CGFloat? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ForEach(Array(rows.enumerated()), id: \.element) { i, row in
                let near = fingerY.map { max(0, 1 - abs(mids[i] - $0) / 64) } ?? 0
                let push: CGFloat = fingerY.map { f in mids[i] < f ? -1 : (mids[i] > f ? 1 : 0) } ?? 0
                mark(row)
                    .scaleEffect(1 + 0.3 * near * near)
                    .position(x: 0, y: mids[i] + push * 6 * near * (1 - near))
                    .animation(reduceMotion ? nil : .interactiveSpring(response: 0.18, dampingFraction: 0.8), value: fingerY)
            }
        }
        .frame(width: 0)
        .allowsHitTesting(false)
    }

    private func amount(_ name: String) -> Double {
        guard let l = layers.readable.first(where: { ($0.name == "Air" ? "PM2.5" : $0.name) == name }), !l.empty else { return 0 }
        return (Double(l.level.rawValue) + l.fraction) / 3
    }

    /// Print: the key never changes hue. Each family's ink, full when something's in the air, faint when not.
    private func groupInk(_ g: RailGroup) -> Color? {
        if WeatherColor.print {
            let has: Double
            switch g {
            case .weather: has = weatherAmount
            default: has = g.items.map(amount).max() ?? 0
            }
            let ink: Color = g == .weather ? WeatherColor.amber : g == .particles ? WeatherColor.aqua : WeatherColor.gold
            return ink.opacity(has > 0 ? 1 : 0.38)
        }
        if g == .weather { return weatherInk.map(legible) }
        guard let top = g.items.max(by: { amount($0) < amount($1) }), amount(top) > 0 else { return nil }
        return legible(WeatherColor.ink(for: top))
    }

    /// A dark ink (Slate, Brick) lifted a little on black glass so it still reads; untouched on paper.
    private func legible(_ c: Color) -> Color { scheme == .dark ? c.mix(with: .white, by: 0.25) : c }

    @ViewBuilder private func mark(_ row: RailRow) -> some View {
        let on = selected == row
        switch row {
        case .header(let g):
            let worst = g.items.map(amount).max() ?? 0.25
            let size = 12 + 10 * CGFloat(g == .weather ? 0.25 : worst)
            // The rail is the sky's legend: each stop wears the ink it paints the sky with (owner, Oct 18), the
            // weather its temperature, a group its strongest layer's. Nothing in the air: plain.
            Image(systemName: g == .weather ? weatherSymbol : g.icon)
                .font(.system(size: on ? size + 3 : size, weight: .semibold))
                .foregroundStyle(groupInk(g).map { AnyShapeStyle($0) } ?? AnyShapeStyle(Color.primary.opacity(on ? 1 : 0.6)))
                .frame(width: 30, height: 30)
                .background { if on { Circle().strokeBorder(Color.primary.opacity(0.8), lineWidth: 1.5) } }
                .overlay(alignment: .topTrailing) {
                    if patterns.contains(g) && !on {
                        Circle().fill(Color.primary.opacity(0.85)).frame(width: 6, height: 6).offset(x: -1, y: 3)
                    }
                }
                .accessibilityLabel(patterns.contains(g) ? "\(g.title), often on your flare days" : g.title)
        case .item(let name):
            // A dot: bigger when there's more of it.
            let d = 5 + 7 * CGFloat(amount(name))
            Circle().fill(amount(name) > 0 ? legible(WeatherColor.ink(for: name)) : Color.primary.opacity(on ? 0.95 : 0.4))
                .frame(width: on ? d + 3 : d, height: on ? d + 3 : d)
                .frame(width: 30, height: 18)
                .background { if on { Circle().strokeBorder(Color.primary.opacity(0.8), lineWidth: 1.2).frame(width: 20, height: 20) } }
                .accessibilityLabel(name)
        case .voice, .body:
            // Their own stops, with the group icons' look.
            Image(systemName: row == .voice ? Icons.voice : Icons.body)
                .font(.system(size: on ? 18 : 15, weight: .semibold))
                .foregroundStyle(on ? Color.primary : Color.primary.opacity(0.6))
                .frame(width: 30, height: 30)
                .background { if on { Circle().strokeBorder(Color.primary.opacity(0.8), lineWidth: 1.5) } }
                .overlay(alignment: .topTrailing) {
                    if row == .voice && voiceBadge && !on {
                        Circle().fill(Theme.rescueSoft).frame(width: 7, height: 7).offset(x: -2, y: 3)
                    }
                }
                .accessibilityLabel(row == .voice ? (voiceBadge ? "Your voice, nothing said yet" : "Your voice") : "Your body")
        }
    }
}

/// The strata, as a column of riso dots on the right edge of the sky: weather on top, then one dot per
/// layer in reading order. Each dot's size is how much of that layer there is now; its ink is its level.
/// The one under the finger grows and names itself. The scale is the legend and the affordance: it shows
/// there's something to read and which way to slide.
struct StrataScale: View {
    let layers: AirLayers
    let probe: SkyProbe?
    let height: CGFloat
    /// `SkyExplorer.weatherIcon(conditions)`, so the top dot changes with the weather.
    var weatherSymbol: String = SkyExplorer.icon("Weather")

    var body: some View {
        let stack = SkyExplorer.stack(layers)
        let mids = SkyExplorer.bands(count: stack.count, height: 1).map { CGFloat($0.lowerBound + $0.upperBound) / 2 * height }
        ZStack(alignment: .topTrailing) {
            dot(name: "Weather", level: nil, amount: 0.25, on: probe?.name == "Weather")
                .position(x: 0, y: mids[0])
            ForEach(Array(stack.enumerated()), id: \.offset) { i, layer in
                dot(name: layer.name, level: layer.level, amount: layer.empty ? 0 : (Double(layer.level.rawValue) + layer.fraction) / 3,
                    on: probe?.name == layer.name)
                    .position(x: 0, y: mids[i + 1])
            }
        }
        .frame(width: 0, height: height)
        .allowsHitTesting(false)
    }

    /// An icon per layer: size says how much of it there is, color says which layer (its own ink, the
    /// same one it paints the sky with). The one being read is full-strength and ringed; its name lives
    /// in the label, not here.
    private func dot(name: String, level: WeaveSpec.Level?, amount: Double, on: Bool) -> some View {
        // One ink for the whole scale (the weather's), so it sits quietly on the field. Size is the amount;
        // the layer's own colour appears in the label once you're reading it.
        let size = 11 + 11 * CGFloat(amount)
        return Image(systemName: name == "Weather" ? weatherSymbol : SkyExplorer.icon(name))
            .font(.system(size: on ? size + 3 : size, weight: .semibold))
            .foregroundStyle(on ? Color.primary : Color.primary.opacity(0.55))
            .frame(width: 30, height: 30)
            .background { if on { Circle().strokeBorder(Color.primary.opacity(0.8), lineWidth: 1.5) } }
            .animation(.snappy(duration: 0.2), value: on)
            .accessibilityLabel(name)
    }
}

/// A group on the rail (Pollutants, Allergens): everything it tracks, each with its amount and level,
/// so the header gives the overview and the items below give the detail.
struct GroupSummary: View {
    let group: RailGroup
    let layers: AirLayers

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(group.title, systemImage: group.icon).font(.subheadline.weight(.semibold))
            ForEach(group.items, id: \.self) { name in
                let layer = layers.readable.first { ($0.name == "Air" ? "PM2.5" : $0.name) == name }
                HStack(spacing: 8) {
                    Image(systemName: Icons.layer(name)).font(.caption)
                        .foregroundStyle(layer?.color ?? Theme.secondaryText).frame(width: 18)
                    Text(name).font(.subheadline)
                        .foregroundStyle(layer == nil ? Theme.secondaryText : .primary)
                    Spacer(minLength: 6)
                    if let layer {
                        AmountDots(level: layer.level, ink: layer.color)
                        Text(Tier(layer.level).word).font(.caption2.weight(.semibold)).frame(width: 52, alignment: .trailing)
                    } else {
                        Text("No reading").font(.caption2).foregroundStyle(Theme.secondaryText)
                    }
                }
            }
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

/// How much, in the field's own language: three particles, each bigger than the last, filled up to the
/// level in the layer's ink. One a little, three a lot.
struct AmountDots: View {
    let level: WeaveSpec.Level
    let ink: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                let on = i <= level.rawValue
                let d: CGFloat = [6, 9, 12][i]
                Circle()
                    .fill(on ? ink : ink.opacity(0.18))
                    .frame(width: d, height: d)
            }
        }
        .accessibilityLabel("\(level.rawValue + 1) of 3")
    }
}

/// One look-back row in the reading's label: the window and what happened in it.
struct LookBackRow: Equatable {
    let window: String
    let value: String
}

/// One line for the label's sparklines: a name, a unit, the points, and its ink.
struct SparkSeries: Equatable {
    let name: String
    let unit: String
    let points: [HourPoint]
    let ink: Color
    static func == (a: SparkSeries, b: SparkSeries) -> Bool { a.name == b.name && a.points.count == b.points.count }
}

/// A small line graph of the hours before a reading, with the first and last values labelled. The
/// moment is the right-hand end.
struct Sparkline: View {
    let series: SparkSeries

    var body: some View {
        let values = series.points.map(\.value)
        let lo = values.min() ?? 0, hi = values.max() ?? 1
        HStack(alignment: .center, spacing: 8) {
            Text(series.name).font(.caption2).foregroundStyle(Theme.secondaryText).frame(width: 60, alignment: .leading)
            Canvas { ctx, size in
                guard series.points.count > 1 else { return }
                let span = max(1, hi - lo)
                let first = series.points.first!.date, last = series.points.last!.date
                let total = max(1, last.timeIntervalSince(first))
                var path = Path()
                for (i, p) in series.points.enumerated() {
                    let x = CGFloat(p.date.timeIntervalSince(first) / total) * size.width
                    let y = size.height - 2 - CGFloat((p.value - lo) / span) * (size.height - 4)
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                ctx.stroke(path, with: .color(series.ink), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                // The reading: a dot at the end.
                if let p = series.points.last {
                    let y = size.height - 2 - CGFloat((p.value - lo) / span) * (size.height - 4)
                    ctx.fill(Path(ellipseIn: CGRect(x: size.width - 3, y: y - 3, width: 6, height: 6)), with: .color(series.ink))
                }
            }
            .frame(height: 26)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(Int((values.last ?? 0).rounded()))\(series.unit)").font(.caption.weight(.semibold)).monospacedDigit()
                Text("\(Int(lo.rounded()))–\(Int(hi.rounded()))").font(.caption2).foregroundStyle(Theme.secondaryText).monospacedDigit()
            }
            .frame(width: 46, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(series.name): from \(Int((values.first ?? 0).rounded())) to \(Int((values.last ?? 0).rounded())) \(series.unit) over the last two days")
    }
}
