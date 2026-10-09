#if DEBUG
import AsthmaCore
import SwiftUI

// Shared data and marks for the air visualization prototypes (Airways v2, Aura, Sampler, Overprint).
// PM2.5 and ozone come from your moments. What Ambee would add (PM10, NO₂, tree / grass / weed pollen
// and species) is example data, flagged `isExample`, until there's a source. Every reading becomes one
// level on its own official scale: 0 none or no reading, 1 low, 2 moderate, 3 high. Raw values and
// units are only shown, never compared.

enum AirFamily: Int, CaseIterable, Identifiable {
    case particles, gases, pollen
    var id: Self { self }

    var title: String {
        switch self {
        case .particles: "Particles"
        case .gases: "Gases"
        case .pollen: "Pollen"
        }
    }

    var kinds: [AirKind] { AirKind.allCases.filter { $0.family == self } }

    /// Riso-like inks, data marks only.
    var ink: Color {
        switch self {
        case .particles: Color(light: 0x4F5FC9, dark: 0x8A9BFF)
        case .gases: Color(light: 0xD45A35, dark: 0xFF8466)
        case .pollen: Color(light: 0xA65BB8, dark: 0xD9A0E8)
        }
    }
}

enum AirKind: Int, CaseIterable, Identifiable {
    case pm25, pm10, ozone, no2, tree, grass, weed
    var id: Self { self }

    var family: AirFamily {
        switch self {
        case .pm25, .pm10: .particles
        case .ozone, .no2: .gases
        case .tree, .grass, .weed: .pollen
        }
    }

    var name: String {
        switch self {
        case .pm25: "PM2.5"
        case .pm10: "PM10"
        case .ozone: "Ozone"
        case .no2: "NO₂"
        case .tree: "Tree pollen"
        case .grass: "Grass pollen"
        case .weed: "Weed pollen"
        }
    }

    /// Scallops, points or petals: the shape tells kinds apart inside a family.
    var lobes: Int {
        switch self {
        case .pm25: 12
        case .pm10: 6
        case .ozone: 8
        case .no2: 5
        case .tree: 5
        case .grass: 6
        case .weed: 8
        }
    }
}

struct AirReading: Identifiable {
    let kind: AirKind
    /// 0 none, 1 low, 2 moderate, 3 high.
    let level: Int
    /// Raw value with its own unit, for display only ("18 µg/m³").
    let value: String
    /// Top species for pollen ("Ragweed").
    let species: String?
    let isExample: Bool
    var id: AirKind { kind }
}

struct SkyDay: Identifiable {
    let day: Date
    let moments: [LogEvent]
    /// Readings per third of the day: night (0–8), day (8–16), evening (16–24).
    let thirds: [[AirReading]]
    var id: Date { day }

    var rescues: Int { moments.filter { $0.moment == .rescue }.count }
    var inhalerMoments: [LogEvent] { moments.filter { $0.moment != .okay } }

    func level(_ kind: AirKind, third: Int) -> Int { thirds[third].first { $0.kind == kind }?.level ?? 0 }
    func level(_ family: AirFamily, third: Int) -> Int { family.kinds.map { level($0, third: third) }.max() ?? 0 }

    /// The day's worst reading per kind.
    var worst: [AirReading] {
        AirKind.allCases.compactMap { k in thirds.compactMap { $0.first { $0.kind == k } }.max { $0.level < $1.level } }
    }

    /// Stand-in for the daily breathing check-in (0–10, higher = easier), which doesn't exist yet.
    var exampleFelt: Int {
        let worstAir = AirFamily.allCases.map { f in (0..<3).map { level(f, third: $0) }.max() ?? 0 }.max() ?? 0
        return max(2, min(9, 10 - rescues * 2 - worstAir))
    }

    var shortLabel: String {
        Calendar.current.isDateInToday(day) ? "Today" : day.formatted(.dateTime.weekday(.abbreviated))
    }
}

enum AirSky {
    static let thirdNames = ["Night", "Day", "Evening"]

    static func week(_ events: [LogEvent], days: Int = 7) -> [SkyDay] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<days).reversed().map { back in
            let day = cal.date(byAdding: .day, value: -back, to: today)!
            let next = cal.date(byAdding: .day, value: 1, to: day)!
            let ms = events.filter { $0.loggedAt >= day && $0.loggedAt < next }
            let thirds = (0..<3).map { third -> [AirReading] in
                let lo = cal.date(byAdding: .hour, value: third * 8, to: day)!
                let hi = cal.date(byAdding: .hour, value: 8, to: lo)!
                let inputs = ms.filter { $0.loggedAt >= lo && $0.loggedAt < hi }.compactMap { $0.conditions?.input }
                var rng = Seeded(day.timeIntervalSince1970 + Double(third) * 7919)
                return AirKind.allCases.map { reading($0, third: third, inputs: inputs, rng: &rng) }
            }
            return SkyDay(day: day, moments: ms, thirds: thirds)
        }
    }

    private static func reading(_ kind: AirKind, third: Int, inputs: [ConditionsInput], rng: inout Seeded) -> AirReading {
        // Real where the app has it.
        switch kind {
        case .pm25:
            if let v = inputs.compactMap(\.pm25).max() {
                return AirReading(kind: kind, level: level(Banding.pm25(v)), value: "\(Int(v.rounded())) µg/m³", species: nil, isExample: false)
            }
        case .ozone:
            if let v = inputs.compactMap(\.ozonePpb).max() {
                return AirReading(kind: kind, level: level(Banding.ozone(ppb: v)), value: "\(Int(v.rounded())) ppb", species: nil, isExample: false)
            }
        default: break
        }
        // Example values: ozone builds in the afternoon, traffic gases at the edges of the day,
        // and in October ragweed is fading while trees and grass are mostly done.
        let bias: Double = switch kind {
        case .pm25, .pm10: third == 0 ? -0.6 : 0.2
        case .ozone: third == 1 ? 1.0 : -0.8
        case .no2: third == 1 ? -0.3 : 0.4
        case .tree: -1.4
        case .grass: -0.9
        case .weed: third == 1 ? 0.9 : 0.2
        }
        let lv = max(0, min(3, Int((rng.next() * 3.2 + bias).rounded(.down))))
        let edges: [Double] = switch kind {   // level starts; match Banding / EPA / Ambee's pollen risk
        case .pm25: [0, 3, 12, 35]          // µg/m³, Banding.pm25
        case .pm10: [0, 10, 55, 155]        // µg/m³, EPA
        case .ozone: [0, 20, 55, 70]        // ppb, Banding.ozone
        case .no2: [0, 10, 54, 101]         // ppb, EPA
        case .tree: [0, 10, 100, 213]       // grains/m³, Ambee risk
        case .grass: [0, 5, 30, 61]
        case .weed: [0, 5, 44, 80]
        }
        let raw = edges[lv] + rng.next() * (lv == 3 ? edges[3] * 0.4 : edges[min(3, lv + 1)] - edges[lv])
        let unit = switch kind.family {
        case .particles: "µg/m³"
        case .gases: "ppb"
        case .pollen: "grains/m³"
        }
        let species: String? = switch kind {
        case .tree: ["Oak", "Birch", "Maple", "Cedar"][Int(rng.next() * 4) % 4]
        case .weed: "Ragweed"
        case .grass: "Grass"
        default: nil
        }
        return AirReading(kind: kind, level: lv, value: "\(Int(raw.rounded())) \(unit)", species: lv > 0 ? species : nil, isExample: true)
    }

    private static func level(_ b: PollutantBand) -> Int {
        switch b {
        case .low: 1
        case .moderate: 2
        case .high: 3
        case .unknown: 0
        }
    }

    static func hourFraction(_ d: Date) -> CGFloat {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return (CGFloat(c.hour ?? 0) + CGFloat(c.minute ?? 0) / 60) / 24
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

// MARK: Marks

enum AirMark {
    /// Size by level: none, low, moderate, high.
    static func radius(_ level: Int) -> CGFloat { [0, 4, 7, 11][max(0, min(3, level))] }

    /// Particles = scalloped discs, gases = spiky stars, pollen = flowers.
    static func path(_ kind: AirKind, center c: CGPoint, radius r: CGFloat) -> Path {
        var p = Path()
        let n = kind.lobes
        switch kind.family {
        case .particles:
            let steps = n * 8
            for i in 0...steps {
                let a = CGFloat(i) / CGFloat(steps) * 2 * .pi
                let rr = r * (0.84 + 0.16 * abs(cos(a * CGFloat(n) / 2)))
                let pt = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
        case .gases:
            for i in 0..<(n * 2) {
                let a = CGFloat(i) * .pi / CGFloat(n) - .pi / 2
                let rr = i.isMultiple(of: 2) ? r : r * 0.45
                let pt = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
        case .pollen:
            let pr = r * 0.46
            for i in 0..<n {
                let a = CGFloat(i) * 2 * .pi / CGFloat(n) - .pi / 2
                p.addEllipse(in: CGRect(x: c.x + cos(a) * r * 0.52 - pr, y: c.y + sin(a) * r * 0.52 - pr, width: pr * 2, height: pr * 2))
            }
            p.addEllipse(in: CGRect(x: c.x - r * 0.42, y: c.y - r * 0.42, width: r * 0.84, height: r * 0.84))
        }
        p.closeSubpath()
        return p
    }

    /// Moments drawn straight into a Canvas: rescue = five-petal flower, standard = sparkle.
    static func moment(_ m: MomentKind, center c: CGPoint, size: CGFloat, in ctx: GraphicsContext) {
        switch m {
        case .rescue:
            let r = size * 0.22
            var p = Path()
            for i in 0..<5 {
                let a = CGFloat(i) * 2 * .pi / 5 - .pi / 2
                p.addEllipse(in: CGRect(x: c.x + cos(a) * r - r, y: c.y + sin(a) * r - r, width: r * 2, height: r * 2))
            }
            p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            ctx.fill(p, with: .color(Theme.rescue))
        case .maintenance:
            ctx.fill(Sparkle.path(center: c, radius: size * 0.48), with: .color(Theme.standard))
        case .okay:
            break
        }
    }
}

struct AirMarkView: View {
    let kind: AirKind
    let level: Int
    var box: CGFloat = 24

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            if level == 0 {
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6)), with: .color(.secondary), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            } else {
                ctx.fill(AirMark.path(kind, center: c, radius: AirMark.radius(level)), with: .color(kind.family.ink))
            }
        }
        .frame(width: box, height: box)
        .accessibilityHidden(true)
    }
}

// MARK: Shared pieces

/// The day's readings, grouped by family, with raw values, species and an "example" tag.
struct SkyDayCard: View {
    let day: SkyDay
    var felt: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(day.day.formatted(.dateTime.weekday(.wide).month().day())).font(.headline)
                Spacer()
                Text(day.rescues == 1 ? "1 rescue moment" : "\(day.rescues) rescue moments")
                    .font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
            if felt {
                LabeledContent("Breathing felt (example)", value: "\(day.exampleFelt) of 10").font(.subheadline)
            }
            ForEach(AirFamily.allCases) { family in
                VStack(alignment: .leading, spacing: 4) {
                    Text(family.title.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(family.ink)
                    ForEach(day.worst.filter { $0.kind.family == family }) { r in
                        HStack(spacing: 8) {
                            AirMarkView(kind: r.kind, level: r.level, box: 22)
                            Text(r.species.map { "\(r.kind.name) · \($0)" } ?? r.kind.name)
                            Spacer()
                            Text(["None", "Low", "Moderate", "High"][r.level]).foregroundStyle(Theme.secondaryText)
                            Text(r.value).font(.caption.monospacedDigit()).foregroundStyle(Theme.secondaryText)
                            if r.isExample {
                                Text("example").font(.caption2).padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(.quaternary, in: Capsule())
                            }
                        }
                        .font(.subheadline)
                    }
                }
            }
            Text("Worst reading of the day, outdoor. Each level uses its own scale: EPA for air, NAB for pollen.")
                .font(.caption).foregroundStyle(Theme.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frostedCard()
    }
}

/// Key for the marks: one row per family.
struct AirKey: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(AirFamily.allCases) { f in
                HStack(spacing: 4) {
                    ForEach(f.kinds) { k in AirMarkView(kind: k, level: 2, box: 18) }
                    Text(f.kinds.map { $0.name.replacingOccurrences(of: " pollen", with: "") }.joined(separator: " · "))
                        .padding(.leading, 4)
                }
            }
            HStack(spacing: 4) {
                ForEach(1...3, id: \.self) { AirMarkView(kind: .pm25, level: $0, box: 24) }
                Text("Bigger = higher").padding(.leading, 4)
            }
        }
        .font(.caption).foregroundStyle(Theme.secondaryText)
    }
}

/// Mon … Today chips for picking one day.
struct DayPicker: View {
    let days: [SkyDay]
    @Binding var selected: Date?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days) { d in
                let on = d.day == (selected ?? days.last?.day)
                Button { withAnimation(.snappy) { selected = d.day } } label: {
                    VStack(spacing: 4) {
                        Text(d.shortLabel).font(.caption.weight(on ? .semibold : .regular))
                        Circle().fill(d.rescues > 0 ? Theme.rescue : .clear).frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(on ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ExampleFootnote: View {
    var extra: String = ""
    var body: some View {
        Text("PM2.5 and ozone are from your moments when they have a reading. PM10, NO₂ and pollen are example values until there's a source (Ambee). \(extra)")
            .font(.caption).foregroundStyle(Theme.secondaryText)
    }
}
#endif
