import AsthmaCore
import Foundation

/// Made-up but realistic pollen for demos (Settings › Design crit › Pollen). Display only: it never
/// enters frames, Insights or patterns, and every surface labels it "Demo".
///
/// Counts are grains/m³ for a Midwest city (St. Louis-like seasons): tree pollen peaks mid-April,
/// grass early June, ragweed early September. Each day gets a repeatable random multiplier (most days
/// are ordinary, a few are bad) and each hour a mid-morning peak. Levels use Ambee's thresholds
/// (moderate / high from: tree 100 / 213, grass 30 / 61, weed 44 / 80).
nonisolated struct PollenSample: Sendable {
    struct Kind: Sendable {
        let name: String        // "Tree"
        let species: String     // "Oak"
        let count: Int          // grains/m³
        let level: WeaveSpec.Level
    }
    let tree: Kind
    let grass: Kind
    let weed: Kind
    var kinds: [Kind] { [tree, grass, weed] }
    static let source = "Demo pollen"
}

nonisolated enum DemoPollen {
    enum Season: String, CaseIterable, Identifiable, Sendable {
        case off, now, spring, ragweed
        var id: String { rawValue }
        var title: String {
            switch self {
            case .off: "Off"
            case .now: "This season"
            case .spring: "Spring trees"
            case .ragweed: "Late-summer ragweed"
            }
        }
        static let key = "crit.demoPollen"
    }

    static func sample(at date: Date, season: Season) -> PollenSample? {
        guard season != .off else { return nil }
        let cal = Calendar(identifier: .gregorian)
        // Shift the calendar day into the chosen season, keeping the hour and day-to-day variation.
        let dayOfYear: Double = switch season {
        case .spring: 110 + Double(cal.ordinality(of: .day, in: .weekOfYear, for: date) ?? 0)
        case .ragweed: 248 + Double(cal.ordinality(of: .day, in: .weekOfYear, for: date) ?? 0)
        default: Double(cal.ordinality(of: .day, in: .year, for: date) ?? 1)
        }
        let hour = Double(cal.component(.hour, from: date))
        let dayKey = Double(cal.ordinality(of: .day, in: .era, for: date) ?? 0)
        var rng = Seeded(dayKey * 97 + 13)
        // Mostly ordinary days, now and then a bad one (a rough log-normal).
        func daily() -> Double { exp((rng.next() + rng.next() + rng.next() - 1.5) * 0.9) }
        let morning = 0.55 + 0.75 * exp(-pow((hour - 10) / 4, 2))

        func peak(_ center: Double, _ width: Double, _ height: Double) -> Double {
            height * exp(-0.5 * pow((dayOfYear - center) / width, 2))
        }

        let tree = (peak(108, 22, 420) + peak(30, 14, 35)) * daily() * morning
        let grass = (peak(158, 26, 48) + peak(250, 20, 8)) * daily() * morning
        let ragweed = peak(250, 17, 120) * daily() * morning
        let pigweed = peak(215, 22, 30) * daily() * morning
        let plantain = peak(160, 25, 18) * daily() * morning
        let weedCount = ragweed + pigweed + plantain
        let weedSpecies = [("Ragweed", ragweed), ("Pigweed", pigweed), ("Plantain", plantain)].max { $0.1 < $1.1 }!.0

        let treeSpecies: String = {
            if dayOfYear < 60 { return "Cedar" }
            let spring = ["Elm", "Maple", "Birch", "Oak", "Ash", "Cottonwood"]
            let i = Int(max(0, min(5, (dayOfYear - 75) / 12)))
            return spring[i]
        }()

        return PollenSample(
            tree: kind("Tree", treeSpecies, tree, moderate: 100, high: 213),
            grass: kind("Grass", "Grass", grass, moderate: 30, high: 61),
            weed: kind("Weed", weedSpecies, weedCount, moderate: 44, high: 80)
        )
    }

    private static func kind(_ name: String, _ species: String, _ count: Double, moderate: Double, high: Double) -> PollenSample.Kind {
        let c = max(0, Int(count.rounded()))
        let level: WeaveSpec.Level = Double(c) >= high ? .high : Double(c) >= moderate ? .medium : .low
        return .init(name: name, species: species, count: c, level: level)
    }
}
