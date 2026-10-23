import AsthmaCore
import Foundation

/// One switch for demos (Settings › Demo and development › Demo scenario): the air of a day worth showing,
/// on Now and on every moment logged while it's on, so the header, the chips, the sky, the advice card and
/// the journal's exposure question all play out on cue. Replaces the separate Pollen and Air event switches
/// (it sets both underneath). Its readings are labelled "Demo scenario": shown, never in patterns
/// (`Ambee.isDemo`, `Conditions.bestReal`).
enum DemoScenario: String, CaseIterable, Identifiable {
    case off, pollen, storm, smoke, cold, mold, heat
    var id: String { rawValue }
    nonisolated static let key = "demo.scenario"
    nonisolated static let heatSource = "Demo day"

    nonisolated static var current: DemoScenario {
        UserDefaults.standard.string(forKey: key).flatMap(DemoScenario.init(rawValue:)) ?? .off
    }

    var title: String {
        switch self {
        case .off: "Off (real air)"
        case .pollen: "Spring pollen day"
        case .storm: "Thunderstorm with high pollen"
        case .smoke: "Wildfire smoke"
        case .cold: "Cold snap"
        case .mold: "Rainy and humid (mold)"
        case .heat: "Hot, high-ozone day"
        }
    }

    /// What it shows, in a line, for the Settings footer.
    var shows: String {
        switch self {
        case .off: "Real air, with Ambee's sample pollen until the contract."
        case .pollen: "Tree pollen high. The journal asks if you were outside."
        case .storm: "Thunderstorm while grass and weed pollen are high: the storm card."
        case .smoke: "Fine particles high from smoke: the smoke card, and the journal asks if you were outside."
        case .cold: "28 °F after a sharp drop: the temperature-drop card, and the journal asks about cold air."
        case .mold: "Rain, warm and humid: the mold card."
        case .heat: "95 °F with ozone high. These readings count toward patterns, so the hot, hazy person's day matches."
        }
    }

    /// The air event card it brings up, and the pollen season behind the forecast.
    var event: Crit.DemoEvent {
        switch self {
        case .off, .pollen, .heat: .none
        case .storm: .storm
        case .smoke: .smoke
        case .cold: .tempDrop
        case .mold: .mold
        }
    }

    var season: DemoPollen.Season {
        switch self {
        case .off: .off
        case .pollen: .spring
        case .storm: .ragweed
        case .smoke, .cold, .mold, .heat: .now
        }
    }

    /// Turns it on: the scenario, and the event and pollen switches it stands for.
    func choose() {
        let d = UserDefaults.standard
        d.set(rawValue, forKey: Self.key)
        d.set(event.rawValue, forKey: Crit.DemoEvent.key)
        d.set(season.rawValue, forKey: DemoPollen.Season.key)
    }

    /// The scenario's readings, put first so they're what's shown. Idempotent: an earlier pass is replaced.
    nonisolated func apply(to c: inout Conditions, at date: Date = .now) {
        c.observations.removeAll { $0.source == Ambee.scenarioSource }
        guard self != .off else { return }
        nonisolated func obs(_ s: Signal, _ v: Double, _ unit: String) -> EnvObservation {
            EnvObservation(signal: s, value: v, unit: unit, asOf: date, source: Ambee.scenarioSource,
                           spatialScale: .region, confidence: .low)
        }
        // A hot, high-ozone day reads as ordinary air, so it drives the verdict and the patterns like real air
        // would (the demo run's step 2). Only for the made-up data sets it's staged on.
        if self == .heat {
            c.observations.removeAll { $0.source == Self.heatSource }
            let real = { (s: Signal, v: Double, u: String) in
                EnvObservation(signal: s, value: v, unit: u, asOf: date, source: Self.heatSource, spatialScale: .region, confidence: .low)
            }
            c.observations.insert(contentsOf: [real(.temperature, 95, "°F"), real(.ozone, 92, "ppb")], at: 0)
            return
        }
        var add: [EnvObservation] = []
        switch self {
        case .off, .heat: break
        case .pollen:
            add = [obs(.pollenTree, 420, "grains/m³"), obs(.pollenGrass, 24, "grains/m³"), obs(.temperature, 68, "°F")]
        case .storm:
            add = [obs(.pollenGrass, 95, "grains/m³"), obs(.pollenWeed, 110, "grains/m³")]
            c.weatherCondition = "Thunderstorms"
        case .smoke:
            add = [obs(.pm25, 142, "µg/m³")]
        case .cold:
            add = [obs(.temperature, 28, "°F")]
            c.tempFallF = 16
        case .mold:
            add = [obs(.humidity, 88, "%"), obs(.temperature, 76, "°F")]
            c.weatherCondition = "Rain"
        }
        c.observations.insert(contentsOf: add, at: 0)
    }
}
