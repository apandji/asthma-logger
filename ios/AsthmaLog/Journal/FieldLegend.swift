import AsthmaCore
import SwiftUI

/// "Reading the colour": one small strip per condition, with a marker where this moment sits, so the
/// colour field's language is learned from your own moment rather than a separate key.
struct FieldLegend: View {
    let weave: WeaveSpec
    let temperatureF: Double?
    var pollen: PollenSample? = nil
    var conditions: Conditions? = nil
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
                    strip("Softness is humidity", "Dry, crisp", "Humid, soft",
                          LinearGradient(colors: [WeatherColor.temperature(65), WeatherColor.temperature(65).mix(with: .white, by: 0.5)],
                                         startPoint: .leading, endPoint: .trailing),
                          at: humidityPosition)
                    Text("Colours on top: what's in the air").font(.subheadline).padding(.top, 2)
                    let present = AirLayers(conditions: conditions, weave: weave, pollen: pollen)
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 8) {
                        ForEach(Self.palette, id: \.name) { item in
                            let layer = present.all.first { $0.name == item.name }
                            HStack(spacing: 8) {
                                Circle().fill(item.color.opacity(layer.map { 0.35 + $0.amount } ?? 0.25))
                                    .frame(width: 12, height: 12)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(item.name).font(.caption)
                                    Text(layer.map { Tier($0.level).word } ?? "No reading")
                                        .font(.caption2).foregroundStyle(Theme.secondaryText)
                                }
                            }
                        }
                    }
                    Text("Each layer is faint when low and fuller when high.\(pollen == nil ? "" : " Pollen is demo data.")")
                        .font(.caption).foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).frostedCard()
        }
    }

    static let palette: [(name: String, color: Color)] = [
        ("PM2.5", WeatherColor.pm25), ("PM10", WeatherColor.pm10), ("NO₂", WeatherColor.no2), ("Ozone", WeatherColor.ozone),
        ("Tree pollen", WeatherColor.pollen[0]), ("Grass pollen", WeatherColor.pollen[1]), ("Weed pollen", WeatherColor.pollen[2]),
    ]

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
