import AsthmaCore
import Charts
import SwiftUI

/// Everything about one moment, opened by pinching its card. Leads with the weather, then the air,
/// then how both moved in the hours around it, where it was, the voice note, and every source.
struct MomentDetailsView: View {
    let event: LogEvent
    @AppStorage(LevelStyle.key) private var style = LevelStyle.signal
    @State private var around: HourlyHistory?
    @AppStorage(DemoPollen.Season.key) private var pollenSeason = DemoPollen.Season.off
    private var pollen: PollenSample? { DemoPollen.sample(at: event.loggedAt, season: pollenSeason) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if let c = event.conditions, !c.observations.isEmpty {
                    FieldLegend(weave: event.weave, temperatureF: c.best(.temperature)?.value, pollen: pollen)
                    weather(c)
                    air(c)
                    aroundChart
                } else {
                    Text(event.envError ?? (event.envStatus == .pending ? "Checking the air…" : "No outdoor readings for this moment."))
                        .font(.subheadline).foregroundStyle(Theme.secondaryText)
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading).frostedCard()
                }
                MomentMap(event: event)
                    .frame(height: 200)
                    .clipShape(.rect(cornerRadius: 22, style: .continuous))
                VoiceNoteButton(event: event).frame(maxWidth: .infinity)
                if let c = event.conditions, !c.observations.isEmpty { sources(c) }
                NavigationLink(value: event) {
                    Text("Edit, retry or delete").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).buttonBorderShape(.capsule)
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .background { AmbientField(weave: event.weave, temperatureF: event.conditions?.best(.temperature)?.value, date: event.loggedAt, pollen: pollen).ignoresSafeArea() }
        .navigationTitle(event.moment == .okay ? "I'm okay" : event.moment.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadAround() }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.loggedAt.formatted(.dateTime.weekday(.wide).month().day().hour().minute()))
                .font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondaryText)
            Text(event.placeName ?? "Outdoors near you")
                .font(.system(.title, design: .serif, weight: .medium))
        }
    }

    private func weather(_ c: Conditions) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if let t = c.best(.temperature) {
                    Text("\(Int(t.value.rounded()))°").font(.system(size: 64, weight: .light, design: .rounded))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.weave.words[.temperature]?.capitalized ?? "Temperature").font(.headline)
                    Text(event.weave.words[.humidity].map { $0.capitalized + " air" } ?? "").font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                tile("humidity", "Humidity", c.best(.humidity).map { "\(Int($0.value.rounded()))%" })
                tile("drop", "Dew point", c.best(.dewpoint).map { "\(Int($0.value.rounded()))°F" })
                tile("wind", "Wind", c.best(.windSpeed).map { "\(Int($0.value.rounded())) mph" })
                tile("sun.max", "UV index", c.best(.uvIndex).map { "\(Int($0.value.rounded()))" })
            }
            if !c.alerts.isEmpty {
                ForEach(c.alerts, id: \.name) { a in
                    Label(a.name, systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(.orange)
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).frostedCard()
    }

    @ViewBuilder private func tile(_ symbol: String, _ name: String, _ value: String?) -> some View {
        if let value { tileBody(symbol, name, value) }
    }

    private func tileBody(_ symbol: String, _ name: String, _ value: String?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).frame(width: 22).foregroundStyle(Theme.secondaryText)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.caption).foregroundStyle(Theme.secondaryText)
                Text(value ?? "—").font(.headline.monospacedDigit())
            }
        }
    }

    private func air(_ c: Conditions) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Air").font(.headline).padding(.bottom, 6)
            airRow("PM2.5", c.best(.pm25), level: c.best(.pm25).map { band(Banding.pm25($0.value)) } ?? nil)
            Divider()
            airRow("Ozone", c.best(.ozone), level: c.best(.ozone).map { band(Banding.ozone(ppb: $0.value)) } ?? nil)
            Divider()
            airRow("AQI", c.best(.aqi), level: c.best(.aqi).map { $0.value <= 50 ? .low : $0.value <= 100 ? .medium : .high })
            Divider()
            if let pollen {
                ForEach(Array(pollen.kinds.enumerated()), id: \.offset) { k, kind in
                    if k > 0 { Divider() }
                    HStack(spacing: 12) {
                        LevelIndicator(level: kind.level, ink: WeatherColor.pollen[k], style: style).frame(minWidth: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(kind.name) pollen")
                            if kind.count > 0 && kind.name != "Grass" {
                                Text(kind.species).font(.caption).foregroundStyle(Theme.secondaryText)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(Tier(kind.level).word)
                            Text("\(kind.count) grains/m³ · Demo").font(.caption.monospacedDigit()).foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .font(.subheadline).padding(.vertical, 8)
                }
            } else {
                HStack {
                    LevelIndicator(level: nil, ink: WeaveSwatch.ink(.pollen), style: style).frame(minWidth: 30)
                    Text("Pollen")
                    Spacer()
                    Text("Not included yet").foregroundStyle(Theme.secondaryText)
                }
                .font(.subheadline).padding(.vertical, 8)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).frostedCard()
    }

    private func airRow(_ name: String, _ o: EnvObservation?, level: WeaveSpec.Level?) -> some View {
        HStack(spacing: 12) {
            LevelIndicator(level: level, ink: WeaveSwatch.ink(.air), style: style).frame(minWidth: 30)
            Text(name)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(level.map { Tier($0).word } ?? "No reading").foregroundStyle(level == nil ? Theme.secondaryText : .primary)
                if let o { Text(ObservationCopy.value(o)).font(.caption.monospacedDigit()).foregroundStyle(Theme.secondaryText) }
            }
        }
        .font(.subheadline).padding(.vertical, 8)
    }

    private func band(_ b: PollutantBand) -> WeaveSpec.Level? {
        switch b {
        case .low: .low
        case .moderate: .medium
        case .high: .high
        case .unknown: nil
        }
    }

    /// Temperature and PM2.5 six hours either side, with this moment marked.
    @ViewBuilder private var aroundChart: some View {
        if let h = around, h.temperature.count > 1 || h.pm25.count > 1 {
            VStack(alignment: .leading, spacing: 10) {
                Text("Around this moment").font(.headline)
                if h.temperature.count > 1 { mini("Temperature °F", h.temperature, WeaveSwatch.ink(.temperature)) }
                if h.pm25.count > 1 { mini("PM2.5 µg/m³", h.pm25, WeaveSwatch.ink(.air)) }
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).frostedCard()
        }
    }

    private func mini(_ title: String, _ line: [HourPoint], _ ink: Color) -> some View {
        let lo = line.map(\.value).min() ?? 0, hi = line.map(\.value).max() ?? 1
        let pad = max((hi - lo) * 0.25, 2)
        return VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(Theme.secondaryText)
            Chart {
                ForEach(line) { p in
                    LineMark(x: .value("Time", p.date), y: .value(title, p.value))
                        .foregroundStyle(ink).interpolationMethod(.monotone)
                }
                RuleMark(x: .value("Moment", event.loggedAt))
                    .foregroundStyle(event.moment == .rescue ? Theme.rescue : Theme.standard)
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartYScale(domain: (lo - pad)...(hi + pad))
            .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 3)) { AxisValueLabel(format: .dateTime.hour()) } }
            .chartYAxis { AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) }
            .frame(height: 90)
        }
    }

    private func sources(_ c: Conditions) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sources").font(.headline)
            ForEach(Array(c.observations.enumerated()), id: \.offset) { _, o in
                Text(ObservationCopy.line(o)).font(.caption).foregroundStyle(Theme.secondaryText)
            }
            if c.observations.contains(where: { $0.source == WeatherProvider.source }) { WeatherAttributionView() }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).frostedCard()
    }

    private func loadAround() async {
        guard around == nil, !event.isDemo, let lat = event.latitude, let lon = event.longitude else { return }
        let from = event.loggedAt.addingTimeInterval(-6 * 3600)
        let to = min(event.loggedAt.addingTimeInterval(6 * 3600), .now)
        around = await HourlyHistory.load(latitude: lat, longitude: lon, from: from, to: to)
    }
}
