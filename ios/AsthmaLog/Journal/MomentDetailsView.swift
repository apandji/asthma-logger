import AsthmaCore
import Charts
import SwiftUI

/// Everything about one moment, opened by pinching its card. Leads with the weather, then the air,
/// then how both moved in the hours around it, where it was, the voice note, and every source.
struct MomentDetailsView: View {
    let event: LogEvent
    /// In-place mode (the Journal's zoom): the map is the hero, shared with the sky panel, on black.
    var mapNamespace: Namespace.ID? = nil
    var onClose: (() -> Void)? = nil
    @State private var pull: CGFloat = 0
    @AppStorage(LevelStyle.key) private var style = LevelStyle.signal
    @State private var around: HourlyHistory?
    @AppStorage(DemoPollen.Season.key) private var pollenSeason = DemoPollen.Season.off
    private var pollen: PollenSample? { DemoPollen.sample(at: event.loggedAt, season: pollenSeason) }

    var body: some View {
        if let mapNamespace { inPlace(mapNamespace) } else { page }
    }

    /// The Journal's zoom: the map grows out of the sky into a sharp hero, the details rise beneath it.
    /// Pull down, pinch closed or tap the chevron to go back.
    private func inPlace(_ ns: Namespace.ID) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // The same line as the Moment scale, in the same place, so zooming in keeps your bearings.
            ScaleHeader(title: event.statement, reserveTwoLines: true) {
                MomentDot(moment: event.moment, size: 8)
                Text(event.detailsLine)
            }
            inPlaceScroll(ns)
        }
        .background(Color.black.ignoresSafeArea())
        .task { await loadAround() }
    }

    private func inPlaceScroll(_ ns: Namespace.ID) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                MomentMap(event: event)
                    .frame(height: event.latitude == nil ? 64 : 320)
                    .opacity(event.latitude == nil ? 0 : 1)
                    .matchedGeometryEffect(id: "map-\(event.id)", in: ns)
                    .mask(LinearGradient(stops: [.init(color: .black, location: 0.7), .init(color: .clear, location: 1)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(alignment: .topLeading) {
                        Button { onClose?() } label: {
                            Image(systemName: "chevron.down").font(.body.weight(.semibold))
                                .frame(width: 44, height: 44)
                                .glassEffect(.regular.interactive(), in: .circle)
                        }
                        .padding(.leading, 16).padding(.top, 8)
                        .accessibilityLabel("Close")
                    }
                    .padding(.horizontal, -16)
                content
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)  // clear the + bar
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, y in
            pull = y
            if y < -90 { onClose?() }   // pull down past the top to go back
        }
    }

    private var page: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                content
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .background { AmbientField(weave: event.weave, temperatureF: event.conditions?.best(.temperature)?.value, date: event.loggedAt, conditions: event.conditions, pollen: pollen).ignoresSafeArea() }
        .navigationTitle(event.moment == .okay ? "I'm okay" : event.moment.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadAround() }
    }

    @ViewBuilder private var content: some View {
                if mapNamespace == nil { header }
                if let c = event.conditions, !c.observations.isEmpty {
                    weather(c)
                    air(c)
                    aroundChart
                } else {
                    Text(event.envError ?? (event.envStatus == .pending ? "Checking the air…" : "No outdoor readings for this moment."))
                        .font(.subheadline).foregroundStyle(Theme.secondaryText)
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading).frostedCard()
                }
                if mapNamespace == nil {
                    MomentMap(event: event)
                        .frame(height: 200)
                        .clipShape(.rect(cornerRadius: 22, style: .continuous))
                }
                VoiceNoteButton(event: event).frame(maxWidth: .infinity)
                if let c = event.conditions, !c.observations.isEmpty { sources(c) }
                NavigationLink(value: event) {
                    Text("Edit, retry or delete").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).buttonBorderShape(.capsule)
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
            HStack(alignment: .firstTextBaseline) {
                Text("Air").font(.headline)
                Spacer()
                if let aqi = c.best(.aqi) {
                    // The AQI is an index across pollutants, so it's a summary, not a row.
                    Text(aqiLine(aqi)).font(.caption).foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(.bottom, 6)
            let rows = airRows(c)
            if rows.isEmpty {
                Text("No air readings from nearby monitors.").font(.subheadline).foregroundStyle(Theme.secondaryText).padding(.vertical, 8)
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                if i > 0 { Divider() }
                airRowBody(r.name, r.obs, level: r.level, ink: r.ink)
            }
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

    /// Only pollutants with a reading get a row: a missing monitor isn't a value worth a line.
    @ViewBuilder private func airRow(_ name: String, _ o: EnvObservation?, level: WeaveSpec.Level?, ink: Color = WeaveSwatch.ink(.air)) -> some View {
        if o != nil { airRowBody(name, o, level: level, ink: ink) }
    }

    private func airRowBody(_ name: String, _ o: EnvObservation?, level: WeaveSpec.Level?, ink: Color) -> some View {
        HStack(spacing: 12) {
            LevelIndicator(level: level, ink: ink, style: style).frame(minWidth: 30)
            Text(name)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(level.map { Tier($0).word } ?? "No reading").foregroundStyle(level == nil ? Theme.secondaryText : .primary)
                if let o { Text(ObservationCopy.value(o)).font(.caption.monospacedDigit()).foregroundStyle(Theme.secondaryText) }
            }
        }
        .font(.subheadline).padding(.vertical, 8)
    }

    struct AirRow { let name: String; let obs: EnvObservation; let level: WeaveSpec.Level?; let ink: Color }

    /// Pollutants with a reading, in a fixed order. Built step by step so the type checker stays quick.
    private func airRows(_ c: Conditions) -> [AirRow] {
        var rows: [AirRow] = []
        if let o = c.best(.pm25) { rows.append(AirRow(name: "PM2.5", obs: o, level: band(Banding.pm25(o.value)), ink: WeatherColor.pm25)) }
        if let o = c.best(.pm10) { rows.append(AirRow(name: "PM10", obs: o, level: band(Banding.pm10(o.value)), ink: WeatherColor.pm10)) }
        if let o = c.best(.ozone) { rows.append(AirRow(name: "Ozone", obs: o, level: band(Banding.ozone(ppb: o.value)), ink: WeatherColor.ozone)) }
        if let o = c.best(.no2) { rows.append(AirRow(name: "NO₂", obs: o, level: band(Banding.no2(ppb: o.value)), ink: WeatherColor.no2)) }
        return rows
    }

    /// "Overall AQI 14 · Good · mostly ozone"
    private func aqiLine(_ o: EnvObservation) -> String {
        let parts = (o.category ?? "").components(separatedBy: " · ")
        let word = o.value <= 50 ? "Good" : o.value <= 100 ? "OK" : "Not good"
        var line = "Overall AQI \(Int(o.value)) · \(word)"
        if parts.count > 1, let p = parts.last, !p.isEmpty { line += " · mostly \(p)" }
        return line
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
                Text("6 hours either side").font(.headline)
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
