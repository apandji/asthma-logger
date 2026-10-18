import AsthmaCore
import SwiftUI

/// The air at a moment, in one glance under the sentence, in the three families the rail and the Insights radar
/// use (`AirProfile.Category`), in the rail's order and with its icons: weather dynamics (its words, never a
/// judgement), then particles & gases and biologics, each in Good / OK / Not good with the level's colour. The
/// worst layer of a family stands for it; a family with no reading says so rather than looking clean.
struct AirReadings: View {
    let conditions: Conditions?
    let weave: WeaveSpec
    let pollen: PollenSample?
    /// Still being fetched: three shimmering placeholders, then the readings arrive one by one.
    var pending = false
    @State private var shown = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let layers = AirLayers(conditions: conditions, weave: weave, pollen: pollen)
        FlowLayout(spacing: 8) {
            if pending {
                ForEach(Self.families, id: \.self) { f in
                    chip { Image(systemName: Self.icon(f)).font(.caption); Text(f.title) }
                        .foregroundStyle(Theme.secondaryText).shimmer(true)
                }
            } else {
                // The magic moment: each reading lands in turn, with a tick, as if just fetched.
                if shown > 0 { weather.transition(.scale(scale: 0.8).combined(with: .opacity)) }
                if shown > 1 { judged(.particulates, worst([layers.pm25, layers.pm10, layers.no2, layers.ozone])).transition(.scale(scale: 0.8).combined(with: .opacity)) }
                if shown > 2 { judged(.biologics, worst([layers.tree, layers.grass, layers.weed])).transition(.scale(scale: 0.8).combined(with: .opacity)) }
            }
        }
        .font(.subheadline.weight(.medium))
        .frame(minHeight: 32, alignment: .leading)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
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

    private var weather: some View {
        let t = conditions?.best(.temperature)?.value
        let words = [weave.words[.temperature], weave.words[.humidity] == "comfortable" ? nil : weave.words[.humidity]]
            .compactMap { $0?.capitalized }
        return chip {
            Image(systemName: Icons.weather).font(.caption)
            // The sentence above already says the temperature: the chip gives its words ("Mild · Humid").
            Text(AirProfile.Category.weather.title + " · " + (words.isEmpty ? (t.map { "\(Int($0.rounded()))°" } ?? "No reading") : words.joined(separator: " · ")))
        }
    }

    private func judged(_ family: AirProfile.Category, _ layer: AirLayers.Layer?) -> some View {
        chip {
            Image(systemName: Self.icon(family)).font(.caption)
            if let layer {
                let tier = Tier(layer.level)
                Text("\(family.title) · \(tier.word)")
                Circle().fill(Self.color(tier)).frame(width: 7, height: 7)
            } else {
                Text("\(family.title) · No reading").foregroundStyle(Theme.secondaryText)
            }
        }
    }

    /// The rail's order: weather, particles & gases, biologics.
    static let families: [AirProfile.Category] = [.weather, .particulates, .biologics]

    static func icon(_ f: AirProfile.Category) -> String {
        switch f {
        case .weather: Icons.weather
        case .particulates: Icons.particles
        case .biologics: Icons.biologics
        case .exertion: Icons.me
        }
    }

    private func chip(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: 6) { content() }
            .lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(Color.primary.opacity(0.1)))
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
