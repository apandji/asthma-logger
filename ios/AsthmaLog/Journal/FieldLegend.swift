import AsthmaCore
import SwiftUI

/// "Reading the colour": one small strip per condition, with a marker where this moment sits, so the
/// colour field's language is learned from your own moment rather than a separate key.
struct FieldLegend: View {
    let weave: WeaveSpec
    let temperatureF: Double?
    var pollen: PollenSample? = nil
    @AppStorage(Crit.FieldStyle.key) private var style = Crit.FieldStyle.weather
    @AppStorage("legend.expanded") private var expanded = false

    var body: some View {
        if style == .weather {
            VStack(alignment: .leading, spacing: 12) {
                Button { withAnimation(.snappy) { expanded.toggle() } } label: {
                    HStack {
                        Text("Reading the colour").font(.headline)
                        Spacer()
                        Image(systemName: "chevron.down").rotationEffect(.degrees(expanded ? 0 : -90))
                            .font(.footnote.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                    }
                }
                .buttonStyle(.plain)
                if expanded {
                    strip("Hue is temperature", "Cold", "Hot",
                          LinearGradient(colors: WeatherColor.stops.map(\.color), startPoint: .leading, endPoint: .trailing),
                          at: temperatureF.map { (min(88, max(30, $0)) - 30) / 58 } ?? fallbackTemp)
                    strip("Grey haze is dirtier air", "Clean", "Dirty",
                          LinearGradient(colors: [WeatherColor.temperature(65), WeatherColor.temperature(65).mix(with: WeatherColor.smog, by: 0.85)],
                                         startPoint: .leading, endPoint: .trailing),
                          at: weave.levels[.air].map { [0.1, 0.5, 0.9][$0.rawValue] })
                    strip("Mist is humidity", "Dry, crisp", "Humid, misty",
                          LinearGradient(colors: [WeatherColor.temperature(65), WeatherColor.temperature(65).mix(with: .white, by: 0.6)],
                                         startPoint: .leading, endPoint: .trailing),
                          at: humidityPosition)
                    HStack(spacing: 8) {
                        ForEach(0..<3) { i in Circle().fill(WeatherColor.pollen[i]).frame(width: 6, height: 6) }
                        Text(pollen.map { p in "Colour blooms are pollen: green tree, gold grass, violet weed. Stronger bloom, more pollen. Now: " + p.kinds.map { "\($0.name.lowercased()) \(Tier($0.level).word.lowercased())" }.joined(separator: ", ") + " (demo)." }
                             ?? "Colour blooms are pollen: green tree, gold grass, violet weed. Not connected yet.")
                            .font(.caption).foregroundStyle(Theme.secondaryText)
                    }
                }
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).frostedCard()
        }
    }

    private var fallbackTemp: Double? {
        switch weave.words[.temperature] {
        case "cold": 0.1
        case "hot": 0.95
        case "mild": 0.57
        default: nil
        }
    }

    private var humidityPosition: Double? {
        switch weave.words[.humidity] {
        case "dry": 0.1
        case "humid": 0.9
        case "comfortable": 0.5
        default: nil
        }
    }

    private func strip(_ title: String, _ lo: String, _ hi: String, _ fill: LinearGradient, at: Double?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.subheadline)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(fill).frame(height: 8)
                    if let at {
                        Circle().fill(.white).frame(width: 14, height: 14)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                            .offset(x: at * (geo.size.width - 14))
                    }
                }
            }
            .frame(height: 14)
            HStack {
                Text(lo)
                Spacer()
                Text(at == nil ? "No reading" : "This moment").foregroundStyle(at == nil ? Theme.secondaryText : .primary)
                Spacer()
                Text(hi)
            }
            .font(.caption2).foregroundStyle(Theme.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }
}
