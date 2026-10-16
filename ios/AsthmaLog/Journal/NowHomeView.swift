import AsthmaCore
import CoreLocation
import SwiftData
import SwiftUI
import TipKit

/// The sky-first home (Settings › Design crit › Home: "Now"). One screen, one question: how is the air,
/// for you? The sky for where you are right now; one timeline with your moments behind the playhead
/// and the forecast ahead of it; and one honest sentence. Past and future share the frame (principle 4).
struct NowHomeView: View {
    @Environment(LogService.self) private var services
    @Environment(\.modelContext) private var context
    @Query(sort: \LogEvent.loggedAt) private var events: [LogEvent]
    @AppStorage(Prefs.useDemoData) private var demo = false
    @AppStorage(DemoPollen.Season.key) private var pollenSeason = DemoPollen.Season.off
    @AppStorage(Crit.InsightsState.key) private var forced = Crit.InsightsState.auto
    /// Reading the air somewhere other than here (an address, Home, Work). Nil is the phone's location.
    @State private var chosen = SavedPlace.load(SavedPlace.chosenKey)
    @State private var showPlaces = false
    @AppStorage(Crit.Paper.key) private var paper = Crit.Paper.black
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The full air details, opened from the pin.
    @State private var pinDetails: LogEvent?

    /// The air where the phone is. Now is always here.
    @State private var here: NowReading?
    /// The forecast's place when you've picked one (Home, Work, an address); nil means here.
    @State private var away: NowReading?
    @State private var hours: [NowHour] = []
    @State private var model = InsightsModel()
    /// Where the playhead is. Nil means now.
    @State private var focusTime: Date?
    @State private var showInsights = false
    @State private var showSettings = false
    @State private var openDay: Date?
    @State private var toast: LogEvent?
    @State private var probing = false
    /// The clock. Ticks so "now" creeps along the track while you watch.
    @State private var now = Date()
    @Namespace private var mapZoom
    @State private var tips = TipGroup(.ordered) { PullToLogTip() }

    /// Inhaler moments only; calm moments stay in the comparison, not on the track.
    private var moments: [LogEvent] { events.filter { $0.moment != .okay } }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .opacity(probing ? 0.4 : 1)
                    .animation(Theme.smooth, value: probing)
                // One sky at a time; the next settles in with a breath, not a cut.
                ZStack { sky.id(focusKey).transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.985))) }
                    .animation(Theme.smooth, value: focusKey)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 4)
                NowTimeline(moments: moments, baselines: events.filter { $0.moment == .okay }.map(\.loggedAt),
                            hours: hours, now: now, focusTime: $focusTime, onPastEnd: { showInsights = true })
                    .frame(height: 104)
                    .padding(.bottom, 84)  // clear the +
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                // The grain is the paper's, not the map's: it runs under the whole page.
                ZStack { Theme.paper(paper); SkyGrain(responds: false).opacity(0.5) }.ignoresSafeArea()
            }
            // Linen is a light page whatever the system says; black is a dark one.
            .environment(\.colorScheme, paper == .linen ? .light : .dark)
            .sheet(item: $pinDetails) { e in
                NavigationStack { MomentDetailsView(event: e) }
                    .presentationDragIndicator(.visible)
            }
            .overlay(alignment: .bottom) {
                CaptureBar(showInsights: $showInsights, tip: tips.currentTip as? PullToLogTip, toast: $toast)
            }
            .overlay(alignment: .bottomLeading) { rail }
            .overlay(alignment: .top) {
                if let e = toast {
                    LoggedToast(event: e) {
                        withAnimation(.snappy) { toast = nil }
                        Task { await services.delete(e, in: context) }
                    }
                }
            }
            .sheet(isPresented: $showInsights) {
                InsightsView().presentationDragIndicator(.visible).presentationBackground(Theme.paper(paper)).presentationCornerRadius(32)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showPlaces) { PlacePicker(chosen: $chosen).presentationDetents([.medium, .large]) }
            .onChange(of: chosen) { _, new in
                away = new.map { NowReading(lat: $0.lat, lon: $0.lon, place: $0.name, conditions: Conditions()) }
                hours = []
                Task { await loadForecastPlace() }
            }

            .sheet(item: $openDay) { day in
                DaySheet(day: day, moments: moments.filter { Calendar.current.isDate($0.loggedAt, inSameDayAs: day) })
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await load() }
            // Every moment's map, newest first, drawn ahead of time: scrubbing never finds a blank.
            .task(id: moments.count) {
                for m in moments.reversed() {
                    if Task.isCancelled { return }
                    guard let lat = m.latitude, let lon = m.longitude else { continue }
                    _ = await MapSnapshots.image(id: m.id.uuidString, latitude: lat, longitude: lon,
                                                 size: SkyPanel.mapSize, dark: true, scale: SkyPanel.mapScale)
                }
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30))
                    now = Date()
                }
            }

            .task(id: events.count) {
                try? await Task.sleep(for: .seconds(1.2))
                guard !Task.isCancelled else { return }
                model.rebuild(events: events, demo: demo)
                await model.narrate(styleScore: 50, useModel: false)
                if let p = away ?? here { await model.loadForecast(latitude: p.lat, longitude: p.lon, placeLabel: p.place ?? "here") }
            }
            // A new moment brings the playhead back to now.
            .onChange(of: events.last?.id) { _, _ in
                withAnimation(.smooth(duration: 0.6)) { focusTime = nil }
                announce(events.last)
            }
        }
    }

    /// "Rescue logged · Undo" for a moment that just arrived from the felt button or the watch. The +
    /// shows its own toast, so the same moment is never announced twice.
    private func announce(_ e: LogEvent?) {
        guard let e, e.moment != .okay, Date().timeIntervalSince(e.loggedAt) < 120, toast?.id != e.id else { return }
        withAnimation(Theme.lift) { toast = e }
        Task {
            try? await Task.sleep(for: .seconds(4))
            if toast?.id == e.id { withAnimation(Theme.smooth) { toast = nil } }
        }
    }

    /// A moment logged in the last couple of minutes: Now shows it, not the live reading.
    private var justNow: LogEvent? {
        guard let m = moments.last, now.timeIntervalSince(m.loggedAt) < 120 else { return nil }
        return m
    }

    // MARK: What the playhead is on

    private enum Focus { case now, moment(LogEvent), hour(NowHour) }

    /// What the sky is showing, as a key, so a change can animate as one move.
    private var focusKey: String {
        switch focus {
        case .now: justNow.map { "just-\($0.id)" } ?? "now"
        case .moment(let m): "m-\(m.id)"
        case .hour(let h): "h-\(h.date.timeIntervalSinceReferenceDate)"
        }
    }

    private var focus: Focus {
        guard let t = focusTime else { return .now }
        if let m = moments.min(by: { abs($0.loggedAt.timeIntervalSince(t)) < abs($1.loggedAt.timeIntervalSince(t)) }),
           abs(m.loggedAt.timeIntervalSince(t)) < 20 * 60 { return .moment(m) }
        if t > now, let h = hours.min(by: { abs($0.date.timeIntervalSince(t)) < abs($1.date.timeIntervalSince(t)) }) { return .hour(h) }
        // Behind now there's nothing between moments: the nearest one stands in.
        if t < now, let m = moments.min(by: { abs($0.loggedAt.timeIntervalSince(t)) < abs($1.loggedAt.timeIntervalSince(t)) }) { return .moment(m) }
        return .now
    }

    // MARK: Header

    private var header: some View {
        Group {
            switch focus {
            case .now:
                if let j = justNow {
                    // Just logged: the moment's own reading, in the present.
                    ScaleHeader(title: AirWords.sentence(tense: .present, weave: j.weave, conditions: j.conditions),
                                reserveTwoLines: true, byline: outlook(at: now).text, bylineTint: outlook(at: now).tint, onByline: { showInsights = true }, compact: true) {
                        MomentTag(moment: j.moment)
                        Text(["Just now", j.placeName ?? here?.place].compactMap { $0 }.joined(separator: " · "))
                    }
                    .onTapGesture { pinDetails = j }
                } else {
                    ScaleHeader(title: here?.statement ?? "Checking the air near you…", reserveTwoLines: true,
                                byline: outlook(at: now).text, bylineTint: outlook(at: now).tint, onByline: { showInsights = true }, compact: true) {
                        Circle().fill(.primary).frame(width: 8, height: 8)
                        Text(["Now", here?.place].compactMap { $0 }.joined(separator: " · "))
                    }
                    .onTapGesture { showInsights = true }
                }
            case .moment(let m):
                ScaleHeader(title: m.pastStatement, reserveTwoLines: true, reserveByline: true, compact: true) {
                    MomentTag(moment: m.moment)
                    Text(m.whenAndWhere)
                }
            case .hour(let h):
                // The look-ahead: what the forecast says, then how it compares (or that we're still learning).
                ScaleHeader(title: h.statement, reserveTwoLines: true,
                            byline: outlook(at: h.date).text, bylineTint: outlook(at: h.date).tint, onByline: { showInsights = true }, compact: true) {
                    Image(systemName: "arrow.right").font(.caption2.weight(.bold))
                    Text("Forecast · \(h.date.formatted(.dateTime.weekday(.abbreviated).hour().minute())) ·")
                    placeChip
                }
                .onTapGesture { showInsights = true }
            }
        }
        .padding(.top, 2)
        .animation(Theme.smooth, value: focusKey)
    }

    /// Tap to read the air somewhere else.
    private var placeChip: some View {
        Button { showPlaces = true } label: {
            HStack(spacing: 3) {
                Text(chosen?.name ?? here?.place ?? "Here")
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .foregroundStyle(chosen == nil ? Theme.secondaryText : Theme.tint)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Change place")
    }

    /// The one sentence for a time, with its color once felt air has learned. Never a percent, never
    /// "attack", never a cause. Green: like your okay days. Yellow: a bit like your rescue days.
    /// Red: matches the days you reached for your rescue.
    private func outlook(at t: Date) -> (text: String, tint: Color?) {
        let learned = forced == .learned || (forced == .auto && (model.progress?.isMet ?? false))
        if learned {
            if forced == .learned, !(model.progress?.isMet ?? false) {
                // Demo: a rough afternoon, so every color can be seen on the track.
                let h = Calendar.current.component(.hour, from: t)
                if (14...17).contains(h) { return ("Matches your flare days.", Self.red) }
                if (11...13).contains(h) || (18...19).contains(h) { return ("A bit like your flare days.", Self.yellow) }
                return ("Looks like your baseline.", Self.green)
            }
            if let w = model.days.flatMap(\.windows).first(where: { $0.start <= t && t < $0.end }) {
                // A window's peak is a summed log likelihood ratio; past 1 it's clearly a rescue-day pattern.
                return w.peakScore >= 1 ? ("Matches your flare days.", Self.red)
                                        : ("A bit like your flare days.", Self.yellow)
            }
            if let day = model.days.first(where: { Calendar.current.isDate($0.day, inSameDayAs: t) }), day.isPersonal {
                return day.band == .elevated ? ("A bit like your flare days.", Self.yellow) : ("Looks like your baseline.", Self.green)
            }
            return ("Looks like your baseline.", Self.green)
        }
        return (sentence, nil)
    }

    private static let green = Verdict.green, yellow = Verdict.yellow, red = Verdict.red

    /// Before felt air has learned: how far along it is.
    private var sentence: String {
        if let p = model.progress, !p.isMet {
            let needRescue = max(0, p.minAttacks - p.attacks), needCalm = max(0, p.minBaselines - p.baselines)
            var parts: [String] = []
            if needCalm > 0 { parts.append("\(needCalm) baseline moment\(needCalm == 1 ? "" : "s")") }
            if needRescue > 0 { parts.append("\(needRescue) rescue moment\(needRescue == 1 ? "" : "s")") }
            // "14 calm days and 1 rescue moment to go." Short enough for two lines.
            // Short enough for one line on the pill: "14 baseline and 1 rescue moment to go."
            return parts.joined(separator: " and ").replacingOccurrences(of: " moments and", with: " and") + " to go."
        }
        return "Still learning your days."
    }

    private static func when(_ d: Date) -> String {
        let cal = Calendar.current
        let day = cal.isDateInToday(d) ? "This" : cal.isDateInTomorrow(d) ? "Tomorrow" : d.formatted(.dateTime.weekday(.wide))
        let h = cal.component(.hour, from: d)
        let part = h < 12 ? "morning" : h < 17 ? "afternoon" : "evening"
        return cal.isDateInToday(d) ? "This \(part)" : "\(day) \(part)"
    }

    // MARK: Sky

    @ViewBuilder private var sky: some View {
        switch focus {
        case .now:
            if let j = justNow {
                // Just logged: the map alone first, then a scan from the pin in the inhaler's ink, and the
                // particles appear where it has passed.
                NowSky(conditions: j.conditions ?? here?.conditions, weave: j.weave.isEmpty ? (here?.weave ?? WeaveSpec()) : j.weave, date: j.loggedAt,
                       pollen: DemoPollen.sample(at: j.loggedAt, season: pollenSeason), probing: $probing,
                       mapID: j.latitude == nil ? "here" : j.id.uuidString,
                       coordinate: j.latitude.flatMap { lat in j.longitude.map { (lat, $0) } } ?? here.map { ($0.lat, $0.lon) },
                       captureInk: j.moment == .rescue ? Theme.rescueSoft : Theme.standardSoft, onPin: { pinDetails = j })
                    .id(j.id)
                    .onTapGesture { pinDetails = j }
            } else {
                NowSky(conditions: here?.conditions, weave: here?.weave ?? WeaveSpec(), date: now,
                       pollen: DemoPollen.sample(at: now, season: pollenSeason), probing: $probing,
                       mapID: "here", coordinate: here.map { ($0.lat, $0.lon) }, onPin: { pinDetails = liveSnapshot() })
                    .onTapGesture { openDay = Calendar.current.startOfDay(for: now) }
            }
        case .moment(let m):
            NowSky(conditions: m.conditions, weave: m.weave, date: m.loggedAt,
                   pollen: DemoPollen.sample(at: m.loggedAt, season: pollenSeason), probing: $probing,
                   mapID: m.id.uuidString, coordinate: m.latitude.flatMap { lat in m.longitude.map { (lat, $0) } },
                   mapNamespace: mapZoom, onPin: { pinDetails = m })
                .onTapGesture { pinDetails = m }
        case .hour(let h):
            NowSky(conditions: h.conditions, weave: h.weave, date: h.date,
                   pollen: DemoPollen.sample(at: h.date, season: pollenSeason), probing: $probing,
                   mapID: mapID, coordinate: forecastCoordinate)
        }
    }

    private var mapID: String { chosen.map { "place-\($0.lat)-\($0.lon)" } ?? "here" }

    /// The live reading as an unsaved moment, so the details page can show it. Never inserted.
    private func liveSnapshot() -> LogEvent? {
        guard let here else { return nil }
        let e = LogEvent(moment: .okay, loggedAt: now)
        e.conditions = here.conditions
        e.envStatus = .ready
        e.placeName = here.place
        e.latitude = here.lat
        e.longitude = here.lon
        return e
    }
    /// Straight from the choice, so the map id and its coordinates can never disagree mid-reload.
    private var forecastCoordinate: (Double, Double)? { chosen.map { ($0.lat, $0.lon) } ?? here.map { ($0.lat, $0.lon) } }

    // MARK: Right edge

    /// Bottom-left, where nothing else lives, so the header can run the full width.
    private var rail: some View {
        HStack(spacing: 10) {
            Button { showSettings = true } label: { railIcon("gearshape") }.accessibilityLabel("Settings")
        }
        .buttonStyle(PressStyle())
        .padding(.leading, 16)
        .padding(.bottom, 16)
    }

    private func railIcon(_ name: String) -> some View {
        Image(systemName: name).font(.body.weight(.semibold)).frame(width: 44, height: 44)
            .glassEffect(.regular.interactive(), in: .circle)
    }

    // MARK: Data

    private func load() async {
        guard let fix = try? await services.location.currentLocation(timeout: .seconds(6)) else { return }
        let lat = fix.coordinate.latitude, lon = fix.coordinate.longitude
        // The map first: it's the slowest part and the first thing you see.
        Task { _ = await MapSnapshots.image(id: "here", latitude: lat, longitude: lon, size: SkyPanel.mapSize, dark: true, scale: SkyPanel.mapScale) }
        async let c = services.conditions.conditions(latitude: lat, longitude: lon)
        async let marks = try? CLGeocoder().reverseGeocodeLocation(fix)
        let place = await marks?.first.map { [$0.locality ?? $0.subAdministrativeArea, $0.administrativeArea].compactMap { $0 }.joined(separator: ", ") }
        here = NowReading(lat: lat, lon: lon, place: place, conditions: await c)
        await loadForecastPlace()
    }

    /// The forecast for the chosen place, or for here.
    private func loadForecastPlace() async {
        if let chosen {
            away = NowReading(lat: chosen.lat, lon: chosen.lon, place: chosen.name, conditions: Conditions())
        } else {
            away = nil
        }
        guard let p = away ?? here else { return }
        let id = mapID
        Task { _ = await MapSnapshots.image(id: id, latitude: p.lat, longitude: p.lon, size: SkyPanel.mapSize, dark: true, scale: SkyPanel.mapScale) }
        // For a place that isn't here we have no live reading to carry forward.
        hours = await NowHour.forecast(latitude: p.lat, longitude: p.lon, now: away == nil ? here?.conditions : nil)
        await model.loadForecast(latitude: p.lat, longitude: p.lon, placeLabel: p.place ?? "here")
    }
}

/// The air where you are, right now. Nothing is saved.
struct NowReading {
    let lat: Double, lon: Double
    let place: String?
    let conditions: Conditions
    var weave: WeaveSpec { WeaveSpec(conditions.input) }
    /// "It's 62° and comfortable. The air is clear."
    var statement: String { AirWords.sentence(tense: .present, weave: weave, conditions: conditions) }
}

/// One voice across past, present and forecast: "It was… / It's… / It will be…".
nonisolated enum AirWords {
    enum Tense { case past, present, future, carried }

    /// "It was 51° and comfortable. The air was a bit hazy." / "It's… The air is…" / "It will be… The air will be…"
    static func sentence(tense: Tense, weave: WeaveSpec, conditions: Conditions?) -> String {
        let verb = switch tense { case .past: "was"; case .present: "is"; case .future: "will be"; case .carried: "should stay" }
        let it = switch tense { case .past: "It was"; case .present: "It's"; case .future, .carried: "It will be" }
        let temp = conditions?.best(.temperature).map { "\(Int($0.value.rounded()))°" }
        let feel = weave.words[.humidity] ?? weave.words[.temperature]
        let weather = [temp, feel].compactMap { $0 }.joined(separator: " and ")
        let air = weave.levels[.air].map { ["clear", "a bit hazy", "heavy"][$0.rawValue] }
        // One sentence: "It's 54° and humid, with clear air."
        _ = verb
        switch (weather.isEmpty, air) {
        case (false, let air?): return "\(it) \(weather), with \(air) air."
        case (false, nil): return "\(it) \(weather)."
        case (true, let air?): return "\(it.replacingOccurrences(of: "It's", with: "The air is").replacingOccurrences(of: "It was", with: "The air was").replacingOccurrences(of: "It will be", with: "The air will be")) \(air)."
        case (true, nil): return "No air reading."
        }
    }
}

extension LogEvent {
    /// "It was 51° and comfortable. The air was a bit hazy."
    var pastStatement: String { AirWords.sentence(tense: .past, weave: weave, conditions: conditions) }
}

/// One forecast hour, shown with the same sky as a logged moment. Apple Weather for temperature and
/// humidity; AirNow's daily category for PM2.5 and ozone, as a typical value for that category.
/// Every reading is labelled forecast and never enters a pattern.
struct NowHour: Identifiable, Sendable {
    let date: Date
    let conditions: Conditions
    /// No air forecast was published for this place, so today's readings stand in (low confidence).
    var airCarried = false
    var id: Date { date }
    var weave: WeaveSpec { WeaveSpec(conditions.input) }
    /// "It will be 78° and humid. The air will be a bit hazy." (or "should stay", when carried forward)
    var statement: String { AirWords.sentence(tense: airCarried ? .carried : .future, weave: weave, conditions: conditions) }

    static let source = "Forecast"
    /// Typical PM2.5 (µg/m³) and ozone (ppb) for each AirNow category, so the sky can color it.
    private static let pm25ByCategory: [Int: Double] = [1: 6, 2: 20, 3: 45, 4: 80, 5: 200, 6: 300]
    private static let ozoneByCategory: [Int: Double] = [1: 35, 2: 62, 3: 78, 4: 95, 5: 130, 6: 200]

    /// `now` is the current reading for the place: when AirNow has no forecast for it (many areas only
    /// publish in ozone season), today's PM2.5 and ozone are carried forward, marked low confidence.
    static func forecast(latitude: Double, longitude: Double, now: Conditions? = nil) async -> [NowHour] {
        guard let hours = try? await WeatherProvider().hourly(latitude: latitude, longitude: longitude, hours: 48) else { return [] }
        var aq: [String: (pm25: Int?, ozone: Int?)] = [:]
        if let key = Secrets.airNow { aq = (try? await AirNowProvider(key: key).forecast(latitude: latitude, longitude: longitude)) ?? [:] }
        let carried = aq.isEmpty ? now : nil
        return hours.map { h in
            var obs = [
                EnvObservation(signal: .temperature, value: h.temperatureF, unit: "°F", asOf: h.date, source: source, spatialScale: .modelGrid, isForecast: true),
                EnvObservation(signal: .humidity, value: h.humidityPct, unit: "%", asOf: h.date, source: source, spatialScale: .modelGrid, isForecast: true),
            ]
            let day = aq[AirNowProvider.dayString(h.date)]
            if let c = day?.pm25, let v = pm25ByCategory[c] {
                obs.append(EnvObservation(signal: .pm25, value: v, unit: "µg/m³", asOf: h.date, source: source, spatialScale: .modelGrid, confidence: .low, isForecast: true))
            }
            if let c = day?.ozone, let v = ozoneByCategory[c] {
                obs.append(EnvObservation(signal: .ozone, value: v, unit: "ppb", asOf: h.date, source: source, spatialScale: .modelGrid, confidence: .low, isForecast: true))
            }
            var airCarried = false
            if let carried {
                for signal in [Signal.pm25, .ozone, .aqi] {
                    guard let o = carried.best(signal) else { continue }
                    obs.append(EnvObservation(signal: signal, value: o.value, unit: o.unit, asOf: h.date, source: "Today's reading, carried forward",
                                              spatialScale: o.spatialScale, distanceKm: o.distanceKm, confidence: .low, isForecast: true))
                    airCarried = true
                }
            }
            return NowHour(date: h.date, conditions: Conditions(observations: obs, fetchedAt: .now), airCarried: airCarried)
        }
    }
}

/// A sky for a place and time, without a moment behind it, or for a moment. The colour underneath is
/// the weather only. The air is particles: each layer is its own coloured dots, sprinkled evenly over
/// the whole place (colour = which, how many and how big = how much), so nothing reads as a spot on the
/// map. You read it on the scale of icons at the right edge, never by touching the map.
struct NowSky: View {
    let conditions: Conditions?
    let weave: WeaveSpec
    let date: Date
    let pollen: PollenSample?
    @Binding var probing: Bool
    /// The place under the sky, pinned.
    var mapID: String = "here"
    var coordinate: (Double, Double)? = nil
    var mapNamespace: Namespace.ID? = nil
    /// Set while this sky is a moment logged seconds ago: its ripple takes the moment's color.
    var captureInk: Color? = nil
    /// Tapping the pin opens the full air details for this place and time.
    var onPin: (() -> Void)? = nil
    @AppStorage(Crit.Paper.key) private var paper = Crit.Paper.black
    @AppStorage(Crit.SkyTexture.key) private var texture = Crit.SkyTexture.dots
    @State private var probe: SkyProbe?
    /// The row of the scale being read: 0 weather, then the layers in reading order.
    @State private var row: Int?
    @State private var pulse: Task<Void, Never>?
    @State private var rippleAt: Date?
    @State private var rippleInk: Color = .white
    @AppStorage("sky.touched") private var touched = false

    private var temperature: Double? { conditions?.best(.temperature)?.value }
    private var layers: AirLayers { AirLayers(conditions: conditions, weave: weave, pollen: pollen, smooth: true) }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let stack = SkyExplorer.stack(layers)
            let mids = SkyExplorer.bands(count: stack.count, height: 1).map { CGFloat($0.lowerBound + $0.upperBound) / 2 * size.height }
            ZStack {
                AmbientField(weave: weave, temperatureF: temperature, date: date, conditions: conditions, pollen: pollen, tintsLayers: false)
                if let (lat, lon) = coordinate {
                    // Pinned: the map never moves; the air is one regional reading, not a spot on a street.
                    PlaceMap(id: paper == .linen ? mapID + "-light" : mapID, latitude: lat, longitude: lon, dark: paper == .black)
                        .frame(width: size.width, height: size.height)
                        .modifier(MapZoomSource(id: mapID, namespace: mapNamespace))
                        .saturation(0)
                        .blendMode(paper == .linen ? .multiply : .screen)
                        .opacity(0.75)
                        .frame(width: size.width, height: size.height)
                        .clipped()
                        .allowsHitTesting(false)
                    // You are here: the map is centred on the place.
                    Circle().fill((captureInk ?? Theme.standard).opacity(0.9)).frame(width: 7, height: 7)
                        .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 1.2).frame(width: 13, height: 13))
                        .shadow(color: .black.opacity(0.25), radius: 2)
                }
                ParticleField(particles: stack.map { ($0.color, $0.empty ? 0 : (Double($0.level.rawValue) + max(0, min(1, $0.fraction))) / 3) },
                              selected: row.flatMap { $0 > 0 ? $0 - 1 : nil },
                              animated: texture == .dots,
                              rippleAt: rippleAt, inviting: !touched && rippleInk == .white,
                              rippleInk: rippleInk, scan: rippleInk != .white)
            }
            .frame(width: size.width, height: size.height)
            .drawingGroup()
            .onAppear { rippleInk = captureInk ?? .white; rippleAt = .now }
            // Every new sky (a moment, a forecast hour, now) ripples once; a fresh log ripples in its color.
            .onChange(of: date) { _, _ in rippleInk = captureInk ?? .white; rippleAt = .now }
            .mask {
                EllipticalGradient(colors: [.black, .black, .clear], center: UnitPoint(x: 0.5, y: 0.55),
                                   startRadiusFraction: 0, endRadiusFraction: 0.7)
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.26),
                                                 .init(color: .black, location: 0.78), .init(color: .clear, location: 1)],
                                         startPoint: .top, endPoint: .bottom))
            }
            // The label sits beside the icon being read, never at a spot on the map.
            .overlay {
                if let probe, let row, row < mids.count {
                    SkyProbeOverlay(point: CGPoint(x: size.width - 64 - 118, y: mids[row]), probe: probe, width: size.width,
                                    showsGlow: false, beside: true)
                        .transition(.opacity)
                }
            }
            // The pin wants a tap: the full details for here and now.
            .overlay {
                if let onPin {
                    Button(action: onPin) { Color.clear.frame(width: 48, height: 48).contentShape(Circle()) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Air details")
                }
            }
            // The scale: the legend, and the only place you read the air. Slide up and down it.
            .overlay(alignment: .trailing) {
                StrataScale(layers: layers, probe: probe, height: size.height)
                    .padding(.trailing, 18)
                    .frame(width: 64, height: size.height, alignment: .trailing)
                    .contentShape(Rectangle())
                    .gesture(scrub(size, mids: mids, stack: stack))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Air layers")
                    .accessibilityAdjustableAction { dir in
                        let n = stack.count + 1
                        select(dir == .increment ? min(n - 1, (row ?? -1) + 1) : max(0, (row ?? 1) - 1), size: size)
                    }
            }
        }
        .padding(.horizontal, 8)
        .onDisappear { stopPulse() }
    }

    private func scrub(_ size: CGSize, mids: [CGFloat], stack: [AirLayers.Layer]) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                if !probing { probing = true; touched = true; startPulse() }
                let nearest = mids.enumerated().min { abs($0.element - drag.location.y) < abs($1.element - drag.location.y) }?.offset ?? 0
                if nearest != row { select(nearest, size: size) }
            }
            .onEnded { _ in
                stopPulse()
                withAnimation(.easeOut(duration: 0.25)) { probe = nil; row = nil }
                probing = false
            }
    }

    private func select(_ r: Int, size: CGSize) {
        let bands = SkyExplorer.bands(count: SkyExplorer.stack(layers).count, height: 1)
        guard r < bands.count else { return }
        let y = (bands[r].lowerBound + bands[r].upperBound) / 2
        let hit = SkyExplorer.strata(at: y, layers: layers, conditions: conditions, weave: weave, temperatureF: temperature, pollen: pollen)
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.snappy(duration: 0.2)) { row = r; probe = hit?.probe }
    }

    private func startPulse() {
        pulse?.cancel()
        pulse = Task { @MainActor in
            let soft = UIImpactFeedbackGenerator(style: .soft), rigid = UIImpactFeedbackGenerator(style: .rigid)
            let heavy = UIImpactFeedbackGenerator(style: .heavy)
            soft.prepare(); rigid.prepare(); heavy.prepare()
            while !Task.isCancelled {
                let x = probe?.intensity ?? 0
                switch x {
                case ..<0.34: soft.impactOccurred(intensity: 0.55 + x)
                case ..<0.67: rigid.impactOccurred(intensity: 0.6 + x * 0.4)
                default: heavy.impactOccurred(intensity: 0.8 + x * 0.2)
                }
                try? await Task.sleep(for: .milliseconds(Int(420 - 300 * x)))
            }
        }
    }

    private func stopPulse() { pulse?.cancel(); pulse = nil }
}

/// The air as particles: every cell of a fine grid gets at most one dot, given to a layer by a fixed
/// hash with odds that rise with that layer's amount, so each layer is an even sprinkle over the whole
/// place in its own ink. More of it means more dots and bigger ones. The layer being read stays lit and
/// the rest fade back. A ripple runs through the dots when a sky appears.
struct ParticleField: View {
    /// Each layer's ink and amount (0 none … 1 high), in reading order.
    let particles: [(Color, Double)]
    var selected: Int? = nil
    var animated = true
    var rippleAt: Date? = nil
    var inviting = true
    var rippleInk: Color = .white
    /// A scan: the ring runs out from the pin in the inhaler's ink and the particles exist only where it
    /// has already passed. Before it, the map alone.
    var scan = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let spacing: CGFloat = 8
    private let rippleSeconds = 1.6
    private let rippleEvery = 5.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion || !animated)) { frame in
            canvas(at: frame.date)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func canvas(at time: Date) -> some View {
        var age = rippleAt.map { time.timeIntervalSince($0) } ?? rippleSeconds
        if inviting, age >= rippleSeconds { age = age.truncatingRemainder(dividingBy: rippleEvery) }
        let seconds = scan ? 2.2 : rippleSeconds
        let wave = (animated && !reduceMotion && age < seconds) ? age / seconds : nil
        let breath = (animated && !reduceMotion) ? time.timeIntervalSinceReferenceDate : 0
        // Odds per layer: a floor so any present layer shows, rising with amount; capped so the map shows.
        var weights = particles.map { $0.1 > 0 ? 0.012 + 0.09 * $0.1 : 0 }
        let total = weights.reduce(0, +)
        if total > 0.3 { weights = weights.map { $0 * 0.3 / total } }
        let cumulative = weights.reduce(into: [Double]()) { $0.append(($0.last ?? 0) + $1) }
        return Canvas(rendersAsynchronously: true) { ctx, size in
            // Every ripple starts at the pin: the place, then the air around it.
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = wave.map { CGFloat($0) * hypot(size.width, size.height) * 0.6 }
            let fade = wave.map { scan ? 1 : 1 - $0 } ?? 0
            let cols = Int(size.width / spacing) + 1, rows = Int(size.height / spacing) + 1
            for i in 0..<cols {
                for j in 0..<rows {
                    var h = UInt32(truncatingIfNeeded: i &* 73856093 ^ j &* 19349663)
                    h = (h ^ (h >> 13)) &* 1274126177
                    let u = Double(h & 0xFFFF) / 65535, jx = Double((h >> 16) & 0xFF) / 255, jy = Double((h >> 24) & 0xFF) / 255
                    let x = (CGFloat(i) + 0.2 + 0.6 * jx) * spacing, y = (CGFloat(j) + 0.2 + 0.6 * jy) * spacing
                    let k = cumulative.firstIndex { u < $0 }
                    let dist = hypot(x - centre.x, y - centre.y)
                    // The scan: nothing exists ahead of the ring yet.
                    if scan, let radius, dist > radius + 8 { continue }
                    var r: CGFloat, color: Color
                    if let k {
                        let amount = CGFloat(particles[k].1)
                        r = 0.8 + 2.6 * amount
                        let dim = selected != nil && selected != k
                        color = particles[k].0.opacity(dim ? 0.15 : 0.9)
                        if selected == k { r *= 1.6 }
                        if breath > 0, !dim { r += 0.3 * CGFloat(0.5 + 0.5 * sin(breath * 1.3 + Double(x + y) / 70)) }
                    } else {
                        r = 0.55
                        color = Color.black.opacity(0.18)
                    }
                    if let radius {
                        let d = abs(dist - radius)
                        let width = scan ? 44.0 : 36.0
                        if d < width {
                            let t = (1 - d / width) * fade
                            r += t * t * (scan ? 2.6 : 2.2)
                            // The front wears the ink; in a scan, even the particles take it as they're born.
                            if k == nil || scan { color = rippleInk.opacity(0.2 + 0.7 * Double(t)).mix(with: color, by: scan && k != nil ? 0.4 : 0) }
                        }
                    }
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(color))
                }
            }
        }
    }
}

/// One day's moments, under the sky you tapped.
struct DaySheet: View {
    let day: Date
    let moments: [LogEvent]

    var body: some View {
        NavigationStack {
            List {
                if moments.isEmpty {
                    Text("Nothing logged this day.").foregroundStyle(Theme.secondaryText)
                }
                ForEach(moments) { m in
                    NavigationLink(value: m) {
                        HStack(spacing: 12) {
                            MomentSwatch(event: m, size: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.detailsLine).font(.subheadline.weight(.medium))
                                Text(m.statement).font(.caption).foregroundStyle(Theme.secondaryText)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: LogEvent.self) { MomentDetailsView(event: $0) }
        }
    }
}

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSinceReferenceDate }
}

/// Shares the map with the details view when there's a namespace to share it in.
struct MapZoomSource: ViewModifier {
    let id: String
    let namespace: Namespace.ID?
    func body(content: Content) -> some View {
        if let namespace { content.matchedGeometryEffect(id: "map-\(id)", in: namespace) } else { content }
    }
}
