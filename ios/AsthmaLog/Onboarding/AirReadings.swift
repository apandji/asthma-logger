import AsthmaCore
import SwiftUI

/// The air at a moment, in one glance under the sentence, in the three families the rail and the Insights radar
/// use (`AirProfile.Category`), in the rail's order and with its icons: weather (its words, never a judgement),
/// then pollutants and biologics, each in Good / OK / Not good with the level's colour. The worst layer of a
/// family stands for it; a family with no reading says so rather than looking clean.
/// Each chip names its family ("Pollutants · Good") when the row fits on one line, a little smaller if it must;
/// on a narrow screen it falls back to the icon and the word. VoiceOver always hears the family.
struct AirReadings: View {
    let conditions: Conditions?
    let weave: WeaveSpec
    let pollen: PollenSample?
    /// Still being fetched: three shimmering placeholders, then the readings arrive one by one.
    var pending = false
    @State private var shown = 0
    @State private var width: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Named if the row fits on one line, a little smaller if it must, else the icon and the word. Chosen from
        // the text's measured width (not ViewThatFits, which loops inside the header's height measurement).
        let fit = fitting
        row(named: fit.named).font(fit.style)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
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

    /// The first of named-subheadline, named-footnote, plain-subheadline whose row fits the width.
    private var fitting: (named: Bool, style: Font) {
        guard width > 0 else { return (true, .subheadline.weight(.medium)) }
        let values = [weatherValue, word(airWorst), word(pollenWorst)]
        func needed(_ textStyle: UIFont.TextStyle, named: Bool) -> CGFloat {
            let font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: textStyle).pointSize, weight: .medium)
            return zip(Self.families, values).reduce(CGFloat(16)) { sum, pair in   // 2 gaps of 8
                let text = (named ? Self.name(pair.0) + " " : "") + pair.1
                let dot: CGFloat = pair.0 == .weather ? 0 : 13
                return sum + (text as NSString).size(withAttributes: [.font: font]).width + 18 + 6 + dot + 20 + (named ? 6 : 0)
            }
        }
        if needed(.subheadline, named: true) <= width { return (true, .subheadline.weight(.medium)) }
        if needed(.footnote, named: true) <= width { return (true, .footnote.weight(.medium)) }
        return (false, .subheadline.weight(.medium))
    }

    private var layers: AirLayers { AirLayers(conditions: conditions, weave: weave, pollen: pollen) }
    private var airWorst: AirLayers.Layer? { worst([layers.pm25, layers.pm10, layers.no2, layers.ozone]) }
    private var pollenWorst: AirLayers.Layer? { worst([layers.tree, layers.grass, layers.weed]) }
    private func word(_ l: AirLayers.Layer?) -> String { l.map { Tier($0.level).word } ?? "No reading" }

    private var weatherValue: String {
        let t = conditions?.best(.temperature)?.value
        let words = [weave.words[.temperature], weave.words[.humidity] == "comfortable" ? nil : weave.words[.humidity]]
            .compactMap { $0?.capitalized }
        // The sentence above already says the temperature: the chip gives its words ("Mild · Humid").
        return words.isEmpty ? (t.map { "\(Int($0.rounded()))°" } ?? "No reading") : words.joined(separator: " · ")
    }

    private func row(named: Bool) -> some View {
        HStack(spacing: 8) {
            if pending {
                ForEach(Self.families, id: \.self) { f in
                    chip(f, named: true) { EmptyView() }.foregroundStyle(Theme.secondaryText).shimmer(true)
                }
            } else {
                // The magic moment: each reading lands in turn, with a tick, as if just fetched.
                if shown > 0 { weather(named: named).transition(.scale(scale: 0.8).combined(with: .opacity)) }
                if shown > 1 { judged(.particulates, airWorst, named: named).transition(.scale(scale: 0.8).combined(with: .opacity)) }
                if shown > 2 { judged(.biologics, pollenWorst, named: named).transition(.scale(scale: 0.8).combined(with: .opacity)) }
            }
        }
    }

    private func weather(named: Bool) -> some View {
        chip(.weather, named: named) { Text(weatherValue) }
    }

    private func judged(_ family: AirProfile.Category, _ layer: AirLayers.Layer?, named: Bool) -> some View {
        chip(family, named: named) {
            if let layer {
                let tier = Tier(layer.level)
                Text(tier.word)
                Circle().fill(Self.color(tier)).frame(width: 7, height: 7)
            } else {
                Text("No reading").foregroundStyle(Theme.secondaryText)
            }
        }
    }

    /// The family's name on a chip: "Weather" is enough there (the radar says "Weather dynamics").
    static func name(_ f: AirProfile.Category) -> String {
        f == .weather ? "Weather" : f.title
    }

    /// The rail's order: weather, pollutants, biologics.
    static let families: [AirProfile.Category] = [.weather, .particulates, .biologics]

    static func icon(_ f: AirProfile.Category) -> String {
        switch f {
        case .weather: Icons.weather
        case .particulates: Icons.particles
        case .biologics: Icons.biologics
        case .exertion: Icons.me
        }
    }

    /// Icon, the family's name in the quieter ink when it's named, then the value.
    private func chip(_ family: AirProfile.Category, named: Bool, @ViewBuilder _ value: () -> some View) -> some View {
        HStack(spacing: 6) {
            Image(systemName: Self.icon(family)).font(.caption)
            if named {
                Text(Self.name(family)).foregroundStyle(Theme.secondaryText)
            }
            value()
        }
        .lineLimit(1)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(Color.primary.opacity(0.1)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(family.title))
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
