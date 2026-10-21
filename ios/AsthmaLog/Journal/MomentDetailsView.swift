import AsthmaCore
import Charts
import SwiftUI

/// Everything about one moment: the one place its readings live (docs/design/moment-details.md).
/// Printed on the same paper as Now, in the order you'd want after a rescue:
/// 1. **The moment**: what it was, when and where, and the sentence you were reading on Now, carried over.
///    Facts about it ("Before this") sit under the sentence, one line each.
/// 2. **The air**: Weather · Pollutants · Allergens, the rail's three families in their inks, each reading
///    with its unit, its amount dots and its word, and one quiet line saying where the numbers came from.
/// 3. **Your words**: the voice note and its confirmed tags.
/// 4. **The evidence**: the hours around it, where it was, every reading in full.
/// 5. **Edit this moment.**
struct MomentDetailsView: View {
    let event: LogEvent
    /// The sentence the header showed for this moment on Now (marks and all), so opening details keeps
    /// your place. Nil from elsewhere: the moment's own past-tense sentence stands in.
    var read: String? = nil
    /// In-place mode (the Journal zoom, a Design-crit home): the map is the hero, shared with the sky panel.
    var mapNamespace: Namespace.ID? = nil
    var onClose: (() -> Void)? = nil
    @AppStorage(Crit.Paper.key) private var paper = Crit.Paper.black
    @AppStorage(DemoPollen.Season.key) private var pollenSeason = DemoPollen.Season.off
    @State private var around: HourlyHistory?

    /// The same pollen the sky drew: the moment's own (Ambee, live or sample), else the demo season.
    private var pollen: PollenSample? { DemoPollen.from(event.conditions) ?? DemoPollen.sample(at: event.loggedAt, season: pollenSeason) }
    /// The same layers (and levels) the sky and the rail read, so a word here never disagrees with the rail.
    private var layers: AirLayers { AirLayers(conditions: event.conditions, weave: event.weave, pollen: pollen) }
    /// A live snapshot from Now (not saved): no voice note, no edit.
    private var isSaved: Bool { event.modelContext != nil }
    private var hasReadings: Bool { !(event.conditions?.observations.isEmpty ?? true) || pollen != nil }

    var body: some View {
        if let mapNamespace { inPlace(mapNamespace) } else { page }
    }

    private var page: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background { paperBackground }
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadAround() }
    }

    private var paperBackground: some View {
        ZStack {
            Theme.paper(paper)
            SkyGrain(responds: false).opacity(0.5)
        }
        .ignoresSafeArea()
    }

    /// The Journal's zoom: the map grows out of the sky into a sharp hero, the details rise beneath it.
    /// Pull down or tap the chevron to go back.
    private func inPlace(_ ns: Namespace.ID) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
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
                        .padding(.leading, 20).padding(.top, 8)
                        .accessibilityLabel("Close")
                    }
                    .padding(.horizontal, -20)
                header
                content
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)  // clear the + bar
        }
        .scrollIndicators(.hidden)
        .background { paperBackground }
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, y in
            if y < -90 { onClose?() }   // pull down past the top to go back
        }
        .task { await loadAround() }
    }

    @ViewBuilder private var content: some View {
        if hasReadings {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(ReadingFamily.allCases, id: \.self) { family($0) }
            }
        } else {
            Text(event.envError ?? (event.envStatus == .pending ? "Checking the air…" : "No outdoor readings for this moment."))
                .font(.subheadline).foregroundStyle(Theme.secondaryText)
        }
        if isSaved { words }
        aroundChart
        whereSection
        if let c = event.conditions, !c.observations.isEmpty { everyReading(c) }
        if isSaved {
            NavigationLink { EventDetailView(event: event) } label: {
                Text("Edit this moment").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).buttonBorderShape(.capsule).tint(.primary)
        }
    }

    // MARK: 1. The moment

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            // The context line, as on Now: the kind as a word, then when and where.
            HStack(spacing: 10) {
                if isSaved { MomentTag(moment: event.moment) } else { MomentTag(moment: event.moment, text: "Now") }
                Text(isSaved ? event.whenAndWhere : (event.placeName ?? "Near you"))
                    .font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondaryText)
                    .lineLimit(2)
            }
            // The page's one Recursive sentence: the read you came from.
            MarkedText(text: sentence, font: Theme.Typeface.sentence(size: 22), kerning: Theme.serifKerning)
            facts
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sentence: String {
        if let read, !read.isEmpty { return read }
        return event.conditions?.input.hasAnyValue == true ? event.pastStatement : event.statement
    }

    /// Facts about the moment, one line each under the sentence: what was taken, and what happened before it
    /// (exertion).
    @ViewBuilder private var facts: some View {
        let lines = useLines
        if !lines.isEmpty || event.exerted == true {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(lines, id: \.self) { fact(Icons.inhaler, $0) }
                // Before this: active in the hour before (Health / Motion), in words, or nothing.
                ExertionLine(event: event, card: false)
            }
        }
    }

    private func fact(_ symbol: String, _ text: String) -> some View {
        Label { Text(text) } icon: { Image(systemName: symbol).foregroundStyle(Theme.secondaryText) }
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// "Albuterol · 2 puffs · felt button": each use, the one place puffs show (a fact you logged).
    private var useLines: [String] {
        event.uses.sorted { $0.at < $1.at }.map { u in
            let name = Inhaler.load().first { $0.id == u.inhalerID }?.name ?? u.inhalerName
                ?? (u.kind == .rescue ? "Rescue inhaler" : "Daily inhaler")
            return [name, u.puffs == 1 ? "1 puff" : "\(u.puffs) puffs", Self.device(u)].compactMap { $0 }.joined(separator: " · ")
        }
    }

    private static func device(_ u: InhalerUse) -> String? {
        switch InhalerUse.Device(rawValue: u.deviceRaw) {
        case .button?: "felt button"
        case .watch?: "Apple Watch"
        case .phone?: "this iPhone"
        default: nil
        }
    }

    // MARK: 2. The air

    private static func ink(_ f: ReadingFamily) -> Color {
        switch f {
        case .weather: WeatherColor.weatherInk
        case .pollutants: WeatherColor.aqua
        case .allergens: WeatherColor.gold
        }
    }

    private static func icon(_ f: ReadingFamily) -> String {
        switch f {
        case .weather: Icons.weather
        case .pollutants: Icons.particles
        case .allergens: Icons.biologics
        }
    }

    /// One family: its name in its ink (as on the rail), a reading per row, and where they came from.
    private func family(_ f: ReadingFamily) -> some View {
        let rows = rows(f)
        let obs = event.conditions.map(f.observations(in:)) ?? []
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: Self.icon(f)).foregroundStyle(Self.ink(f))
                Text(f.title)
                Spacer()
                if f == .pollutants, let aqi = event.conditions?.best(.aqi) {
                    Text(ObservationCopy.aqiSummary(aqi)).font(.caption).foregroundStyle(Theme.secondaryText)
                }
            }
            .font(.subheadline.weight(.semibold))
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(Self.ink(f)).frame(height: 1.5) }
            ForEach(rows) { r in
                row(r, ink: Self.ink(f))
                if r.id != rows.last?.id { Rectangle().fill(Theme.secondaryText.opacity(0.18)).frame(height: 0.5).padding(.leading, 30) }
            }
            if f == .weather, let alerts = event.conditions?.alerts, !alerts.isEmpty {
                ForEach(alerts, id: \.name) { a in
                    Label(a.name, systemImage: "exclamationmark.triangle.fill").font(.footnote.weight(.medium)).padding(.top, 8)
                }
            }
            if let line = provenance(f, obs) {
                Text(line).font(.caption).foregroundStyle(Theme.secondaryText).padding(.top, 8)
            }
        }
    }

    private func provenance(_ f: ReadingFamily, _ obs: [EnvObservation]) -> String? {
        if f == .allergens, obs.isEmpty, pollen != nil { return "Sample pollen for this season, not a reading" }
        return ObservationCopy.provenance(obs)
    }

    struct Row: Identifiable {
        let id: String
        var detail: String? = nil
        /// The reading with its unit, or nil: no reading (missing, never "good").
        var value: String?
        /// Air and pollen: Good / OK / Not good. Weather: its plain word (Hot, Humid), never a judgement.
        var word: String?
        var level: WeaveSpec.Level?
    }

    private func rows(_ f: ReadingFamily) -> [Row] {
        let c = event.conditions
        func v(_ s: Signal) -> String? { c?.best(s).map(ObservationCopy.value) }
        func cap(_ w: String?) -> String? { w.map { $0.prefix(1).uppercased() + $0.dropFirst() } }
        switch f {
        case .weather:
            var out: [Row] = []
            if let t = v(.temperature) { out.append(Row(id: "Temperature", detail: c?.weatherCondition, value: t, word: cap(event.weave.words[.temperature]))) }
            if let h = v(.humidity) { out.append(Row(id: "Humidity", value: h, word: cap(event.weave.words[.humidity]))) }
            if let d = v(.dewpoint) { out.append(Row(id: "Dew point", value: d)) }
            if let w = v(.windSpeed) { out.append(Row(id: "Wind", value: w)) }
            if let u = v(.uvIndex) { out.append(Row(id: "UV index", value: u)) }
            return out
        case .pollutants:
            let l = layers
            return [("PM2.5", Signal.pm25, l.pm25), ("PM10", .pm10, l.pm10), ("Ozone", .ozone, l.ozone), ("NO₂", .no2, l.no2)].map { name, s, layer in
                Row(id: name, value: v(s), word: layer.map { Tier($0.level).word }, level: layer?.level)
            }
        case .allergens:
            let kinds = pollen?.kinds ?? []
            let l = layers
            return [("Tree pollen", l.tree), ("Grass pollen", l.grass), ("Weed pollen", l.weed)].enumerated().map { i, pair in
                let kind = i < kinds.count ? kinds[i] : nil
                return Row(id: pair.0, detail: kind.flatMap { $0.count > 0 && $0.name != "Grass" ? $0.species : nil },
                           value: kind.map { "\($0.count) grains/m³" }, word: pair.1.map { Tier($0.level).word }, level: pair.1?.level)
            }
        }
    }

    private func row(_ r: Row, ink: Color) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: Icons.layer(r.id) == "circle.fill" ? Self.weatherIcon(r.id) : Icons.layer(r.id))
                .font(.subheadline).foregroundStyle(r.value == nil ? Theme.secondaryText : ink).frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(r.id).foregroundStyle(r.value == nil ? Theme.secondaryText : .primary)
                if let d = r.detail { Text(d).font(.caption).foregroundStyle(Theme.secondaryText) }
            }
            Spacer(minLength: 8)
            if let value = r.value {
                if let level = r.level { AmountDots(level: level, ink: ink) }
                VStack(alignment: .trailing, spacing: 1) {
                    if let w = r.word { Text(w) }
                    Text(value).font(r.word == nil ? .subheadline.monospacedDigit() : .caption.monospacedDigit())
                        .foregroundStyle(r.word == nil ? .primary : Theme.secondaryText)
                }
                .frame(minWidth: 76, alignment: .trailing)
            } else {
                Text("No reading").font(.caption).foregroundStyle(Theme.secondaryText)
            }
        }
        .font(.subheadline)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private static func weatherIcon(_ name: String) -> String {
        switch name {
        case "Temperature": "thermometer.medium"
        case "Humidity": Icons.humidity
        case "Dew point": Icons.dewPoint
        case "Wind": Icons.wind
        case "UV index": Icons.uv
        default: "circle"
        }
    }

    // MARK: 3. Your words

    private var words: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("What you said", Icons.voice)
            if let t = event.voiceTranscript, !t.isEmpty {
                Text("“\(t)”").font(.body).fixedSize(horizontal: false, vertical: true)
            } else {
                Text(event.moment == .rescue ? "Nothing said yet. A few words about where you were or what you were doing help felt air learn." : "Nothing said.")
                    .font(.subheadline).foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if event.tagsReviewed, !event.tags.isEmpty {
                // Confirmed tags only: these are what become bins.
                FlowTags(tags: event.tags.sorted().map(\.label))
            }
            VoiceNoteButton(event: event)
        }
    }

    private func sectionTitle(_ text: String, _ symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .labelStyle(.titleAndIcon)
    }

    // MARK: 4. The evidence

    /// Temperature and PM2.5 six hours either side, in their families' inks, with this moment marked.
    @ViewBuilder private var aroundChart: some View {
        if let h = around, h.temperature.count > 1 || h.pm25.count > 1 {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("The hours around it", "chart.xyaxis.line")
                if h.temperature.count > 1 { mini("Temperature °F", h.temperature, WeatherColor.weatherInk) }
                if h.pm25.count > 1 { mini("PM2.5 µg/m³", h.pm25, WeatherColor.aqua) }
            }
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
                // The moment: a plain rule in the page's ink (colour stays with the air).
                RuleMark(x: .value("Moment", event.loggedAt))
                    .foregroundStyle(Color.primary.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
            .chartYScale(domain: (lo - pad)...(hi + pad))
            .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 3)) { AxisValueLabel(format: .dateTime.hour()) } }
            .chartYAxis { AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) }
            .frame(height: 90)
        }
    }

    /// Where it was: a small map, the place, and indoors or out. The map says *where you were*, never
    /// where the air was measured: every reading is for the area around it.
    @ViewBuilder private var whereSection: some View {
        if event.latitude != nil || event.placeName != nil {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Where", "mappin.and.ellipse")
                if mapNamespace == nil, event.latitude != nil {
                    MomentMap(event: event)
                        .frame(height: 150)
                        .clipShape(.rect(cornerRadius: 16, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text([event.placeName, indoorWords].compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline)
                    Text("The readings are for the outdoor air around here, not this exact spot.")
                        .font(.caption).foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// "Indoors" when you said so; "Likely indoors" when it's the phone's guess.
    private var indoorWords: String? {
        if let confirmed = event.indoorConfirmedRaw.flatMap(IndoorOutdoor.init(rawValue:)) {
            return confirmed == .indoor ? "Indoors" : confirmed == .outdoor ? "Outdoors" : nil
        }
        switch event.indoorGuess {
        case .indoor?: return "Likely indoors"
        case .outdoor?: return "Likely outdoors"
        default: return nil
        }
    }

    /// Every reading with its full provenance, folded away: honest, one tap down.
    private func everyReading(_ c: Conditions) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(c.observations.enumerated()), id: \.offset) { _, o in
                        Text(ObservationCopy.line(o)).font(.caption).foregroundStyle(Theme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 8)
            } label: {
                sectionTitle("Every reading", "list.bullet").foregroundStyle(Color.primary)
            }
            .tint(Theme.secondaryText)
            if c.observations.contains(where: { $0.source == WeatherProvider.source }) { WeatherAttributionView() }
            NavigationLink("Where your data comes from") { SourcesView() }
                .font(.footnote.weight(.semibold)).tint(.primary)
        }
    }

    private func loadAround() async {
        guard around == nil, !event.isDemo, let lat = event.latitude, let lon = event.longitude else { return }
        let from = event.loggedAt.addingTimeInterval(-6 * 3600)
        let to = min(event.loggedAt.addingTimeInterval(6 * 3600), .now)
        around = await HourlyHistory.load(latitude: lat, longitude: lon, from: from, to: to)
    }
}

/// Confirmed tags as quiet chips that wrap.
private struct FlowTags: View {
    let tags: [String]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(tags, id: \.self) { t in
                Text(t).font(.footnote.weight(.medium))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.5))
            }
        }
    }
}
