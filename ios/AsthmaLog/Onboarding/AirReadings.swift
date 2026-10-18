import AsthmaCore
import SwiftUI

/// The air at a moment, in one glance under the sentence: the weather (a reading, with its word), then the
/// air and pollen, each in Good / OK / Not good with the level's colour. The worst item of each group stands
/// for it; a group with no reading says so rather than looking clean.
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
        HStack(spacing: 8) {
            if pending {
                ForEach(["Weather", "Air", "Pollen"], id: \.self) { name in
                    chip { Text(name).foregroundStyle(Theme.secondaryText) }.shimmer(true)
                }
            } else {
                // The magic moment: each reading lands in turn, with a tick, as if just fetched.
                if shown > 0 { weather.transition(.scale(scale: 0.8).combined(with: .opacity)) }
                if shown > 1 { judged("Air", worst([layers.pm25, layers.pm10, layers.no2, layers.ozone])).transition(.scale(scale: 0.8).combined(with: .opacity)) }
                if shown > 2 { judged("Pollen", worst([layers.tree, layers.grass, layers.weed])).transition(.scale(scale: 0.8).combined(with: .opacity)) }
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
            Text(words.isEmpty ? (t.map { "\(Int($0.rounded()))°" } ?? "No reading") : words.joined(separator: " · "))
        }
    }

    private func judged(_ name: String, _ layer: AirLayers.Layer?) -> some View {
        chip {
            if let layer {
                let tier = Tier(layer.level)
                Circle().fill(Self.color(tier)).frame(width: 7, height: 7)
                Text("\(name) · \(tier.word)")
            } else {
                Text("\(name) · No reading").foregroundStyle(Theme.secondaryText)
            }
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
