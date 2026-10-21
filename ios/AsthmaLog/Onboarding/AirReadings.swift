import AsthmaCore
import SwiftUI

/// The air at a moment, in one glance under the sentence, in the three families the rail and the Insights radar
/// use (`AirProfile.Category`), in the rail's order and with its icons: weather (its words, never a judgement),
/// then pollutants and allergens, each in Good / OK / Not good with the level's colour. The worst layer of a
/// family stands for it; a family with no reading says so rather than looking clean.
/// Each chip is the icon and the value; holding it names the family in a small tip above.
struct AirReadings: View {
    let conditions: Conditions?
    let weave: WeaveSpec
    let pollen: PollenSample?
    /// Still being fetched: three shimmering placeholders, then the readings arrive one by one.
    var pending = false
    @State private var shown = 0
    @State private var held: AirProfile.Category?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        row
            .font(.subheadline.weight(.medium))
            .frame(minHeight: 32, alignment: .leading)
            .padding(.horizontal, 20)
            .task(id: pending) {
                guard !pending else { shown = 0; return }
                if reduceMotion { shown = 3; return }
                let tick = UISelectionFeedbackGenerator()
                for i in 1...3 {
                    try? await Task.sleep(for: .milliseconds(i == 1 ? 150 : 320))
                    withAnimation(Theme.lift) { shown = i }
                    tick.selectionChanged()
                }
            }
    }

    private var layers: AirLayers { AirLayers(conditions: conditions, weave: weave, pollen: pollen) }
    private var airWorst: AirLayers.Layer? { worst([layers.pm25, layers.pm10, layers.no2, layers.ozone]) }
    private var pollenWorst: AirLayers.Layer? { worst([layers.tree, layers.grass, layers.weed]) }

    private var weatherValue: String {
        let t = conditions?.best(.temperature)?.value
        let words = [weave.words[.temperature], weave.words[.humidity] == "comfortable" ? nil : weave.words[.humidity]]
            .compactMap { $0?.capitalized }
        // The sentence above already says the temperature: the chip gives its words ("Mild · Humid").
        return words.isEmpty ? (t.map { "\(Int($0.rounded()))°" } ?? "No reading") : words.joined(separator: " · ")
    }

    private var row: some View {
        HStack(spacing: 6) {
            if pending {
                ForEach(Self.families, id: \.self) { f in
                    chip(f) { Text(Self.name(f)) }.foregroundStyle(Theme.secondaryText).shimmer(true)
                }
            } else {
                // The magic moment: each reading lands in turn, with a tick, as if just fetched.
                if shown > 0 { weather.transition(.scale(scale: 0.8).combined(with: .opacity)) }
                if shown > 1 { judged(.particulates, airWorst).transition(.scale(scale: 0.8).combined(with: .opacity)) }
                if shown > 2 { judged(.biologics, pollenWorst).transition(.scale(scale: 0.8).combined(with: .opacity)) }
            }
        }
    }

    private var weather: some View {
        chip(.weather) { Text(weatherValue) }
    }

    private func judged(_ family: AirProfile.Category, _ layer: AirLayers.Layer?) -> some View {
        chip(family) {
            if let layer {
                let tier = Tier(layer.level)
                Text(tier.word)
                Circle().fill(Self.color(tier)).frame(width: 6, height: 6)
            } else {
                Text("No reading").foregroundStyle(Theme.secondaryText)
            }
        }
    }

    /// The family's name on a chip: "Weather" is enough there (the radar says "Weather dynamics").
    static func name(_ f: AirProfile.Category) -> String {
        f == .weather ? "Weather" : f.title
    }

    /// The rail's order: weather, pollutants, allergens.
    static let families: [AirProfile.Category] = [.weather, .particulates, .biologics]

    static func icon(_ f: AirProfile.Category) -> String {
        switch f {
        case .weather: Icons.weather
        case .particulates: Icons.particles
        case .biologics: Icons.biologics
        case .exertion, .infections: Icons.category(f)
        }
    }

    /// Icon and value. Holding the chip names its family in a small tip above it (drawn over, so nothing moves),
    /// a moment after the finger lifts it fades. VoiceOver always hears the family.
    private func chip(_ family: AirProfile.Category, @ViewBuilder _ value: () -> some View) -> some View {
        HStack(spacing: 6) {
            Image(systemName: Self.icon(family)).font(.caption)
            value()
        }
        .lineLimit(1)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(Color.primary.opacity(0.1)))
        .overlay(alignment: .top) {
            if held == family {
                Text(Self.name(family))
                    .font(.caption2.weight(.semibold))
                    .fixedSize()
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(.regularMaterial))
                    .offset(y: -30)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
                    .allowsHitTesting(false)
            }
        }
        .onLongPressGesture(minimumDuration: 0.25, maximumDistance: 30) {
            fold(family)
        } onPressingChanged: { down in
            guard down else { fold(family); return }
            withAnimation(Theme.lift) { held = family }
            UISelectionFeedbackGenerator().selectionChanged()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(family.title))
    }

    /// Let go: the tip stays a moment, then fades.
    private func fold(_ family: AirProfile.Category) {
        Task {
            try? await Task.sleep(for: .seconds(1))
            withAnimation(Theme.lift) { if held == family { held = nil } }
        }
    }

    private func worst(_ layers: [AirLayers.Layer?]) -> AirLayers.Layer? {
        layers.compactMap { $0 }.max { $0.level < $1.level }
    }

    static func color(_ t: Tier) -> Color {
        switch t {
        case .good: Verdict.green
        case .ok: Verdict.yellow
        case .notGood: Verdict.red
        }
    }
}
