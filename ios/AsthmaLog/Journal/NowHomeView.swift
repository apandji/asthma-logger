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
    @State private var showMonth = false
    @State private var openDay: Date?
    @State private var toast: LogEvent?
    @State private var probing = false
    /// The clock. Ticks so "now" creeps along the track while you watch.
    @State private var now = Date()
    /// A moment's details, in place, with the timeline still under it.
    @State private var expanded = false
    @Namespace private var mapZoom
    @State private var tips = TipGroup(.ordered) { PullToLogTip() }
    @Namespace private var month

    /// Inhaler moments only; calm moments stay in the comparison, not on the track.
    private var moments: [LogEvent] { events.filter { $0.moment != .okay } }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .opacity(probing ? 0.4 : 1)
                    .animation(.easeOut(duration: 0.2), value: probing)
                Group {
                    if expanded, case .moment(let m) = focus {
                        MomentDetailsView(event: m, onClose: { withAnimation(.spring(duration: 0.5, bounce: 0.1)) { expanded = false } }, airOnly: true)
                            .id(m.id)
                            // Tap the table to go back to the sky.
                            .onTapGesture { withAnimation(.spring(duration: 0.5, bounce: 0.1)) { expanded = false } }
                            .transition(.opacity)
                    } else {
                        sky.transition(.opacity)
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.top, 4)
                NowTimeline(moments: moments, hours: hours, now: now, focusTime: $focusTime)
                    .frame(height: 104)
                    .padding(.bottom, 84)  // clear the +
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                // The grain is the paper's, not the map's: it runs under the whole page.
                ZStack { Color.black; SkyGrain(responds: false).opacity(0.5) }.ignoresSafeArea()
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
                InsightsView().presentationDragIndicator(.visible).presentationBackground(.ultraThinMaterial)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showPlaces) { PlacePicker(chosen: $chosen).presentationDetents([.medium, .large]) }
            .onChange(of: chosen) { _, new in
                away = new.map { NowReading(lat: $0.lat, lon: $0.lon, place: $0.name, conditions: Conditions()) }
                hours = []
                Task { await loadForecastPlace() }
            }
            .sheet(isPresented: $showMonth) {
                MomentsOverview(events: Array(events), namespace: month, anchorDay: focusTime,
                                open: { e in focusTime = e.loggedAt; showMonth = false },
                                close: { showMonth = false })
                    .padding(.top, 12)
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.black)
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
            // Scrubbing off a moment while its details are open closes them.
            .onChange(of: focusTime) { _, _ in
                if expanded, case .moment = focus {} else if expanded { withAnimation(.easeOut(duration: 0.25)) { expanded = false } }
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
        withAnimation(.snappy) { toast = e }
        Task {
            try? await Task.sleep(for: .seconds(4))
            if toast?.id == e.id { withAnimation(.snappy) { toast = nil } }
        }
    }

    /// A moment logged in the last couple of minutes: Now shows it, not the live reading.
    private var justNow: LogEvent? {
        guard let m = moments.last, now.timeIntervalSince(m.loggedAt) < 120 else { return nil }
        return m
    }

    // MARK: What the playhead is on

    private enum Focus { case now, moment(LogEvent), hour(NowHour) }

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
                                reserveTwoLines: true, byline: outlook(at: now).text, bylineTint: outlook(at: now).tint, compact: true) {
                        MomentDot(moment: j.moment, size: 8)
                        Text(["Just now", j.moment == .rescue ? "Rescue" : "Standard", j.placeName ?? here?.place].compactMap { $0 }.joined(separator: " · "))
                    }
                    .onTapGesture { withAnimation(.spring(duration: 0.5, bounce: 0.1)) { focusTime = j.loggedAt; expanded = true } }
                } else {
                    ScaleHeader(title: here?.statement ?? "Checking the air near you…", reserveTwoLines: true,
                                byline: outlook(at: now).text, bylineTint: outlook(at: now).tint, compact: true) {
                        Circle().fill(.white).frame(width: 8, height: 8)
                        Text(["Now", here?.place].compactMap { $0 }.joined(separator: " · "))
                    }
                    .onTapGesture { showInsights = true }
                }
            case .moment(let m):
                ScaleHeader(title: m.pastStatement, reserveTwoLines: true, reserveByline: true, compact: true) {
                    MomentDot(moment: m.moment, size: 8)
                    Text(m.detailsLine)
                }
            case .hour(let h):
                // The look-ahead: what the forecast says, then how it compares (or that we're still learning).
                ScaleHeader(title: h.statement, reserveTwoLines: true,
                            byline: outlook(at: h.date).text, bylineTint: outlook(at: h.date).tint, compact: true) {
                    Image(systemName: "arrow.right").font(.caption2.weight(.bold))
                    Text("Forecast · \(h.date.formatted(.dateTime.weekday(.abbreviated).hour().minute())) ·")
                    placeChip
                }
                .onTapGesture { showInsights = true }
            }
        }
        .padding(.top, 2)
        .animation(.easeInOut(duration: 0.25), value: focusTime)
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
        .buttonStyle(.plain)
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
                if (14...17).contains(h) { return ("Matches days you reached for your rescue.", Self.red) }
                if (11...13).contains(h) || (18...19).contains(h) { return ("A bit like your rescue days.", Self.yellow) }
                return ("Looks like one of your okay days.", Self.green)
            }
            if let w = model.days.flatMap(\.windows).first(where: { $0.start <= t && t < $0.end }) {
                // A window's peak is a summed log likelihood ratio; past 1 it's clearly a rescue-day pattern.
                return w.peakScore >= 1 ? ("Matches days you reached for your rescue.", Self.red)
                                        : ("A bit like your rescue days.", Self.yellow)
            }
            if let day = model.days.first(where: { Calendar.current.isDate($0.day, inSameDayAs: t) }), day.isPersonal {
                return day.band == .elevated ? ("A bit like your rescue days.", Self.yellow) : ("Looks like one of your okay days.", Self.green)
            }
            return ("Looks like one of your okay days.", Self.green)
        }
        return (sentence, nil)
    }

    private static let green = Verdict.green, yellow = Verdict.yellow, red = Verdict.red

    /// Before felt air has learned: how far along it is.
    private var sentence: String {
        if let p = model.progress, !p.isMet {
            let needRescue = max(0, p.minAttacks - p.attacks), needCalm = max(0, p.minBaselines - p.baselines)
            var parts: [String] = []
            if needCalm > 0 { parts.append("\(needCalm) calm day\(needCalm == 1 ? "" : "s")") }
            if needRescue > 0 { parts.append("\(needRescue) rescue moment\(needRescue == 1 ? "" : "s")") }
            // "14 calm days and 1 rescue moment to go." Short enough for two lines.
            return parts.joined(separator: " and ") + " to go before felt air can compare."
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
            if let j = justNow, !j.weave.isEmpty {
                NowSky(conditions: j.conditions, weave: j.weave, date: j.loggedAt,
                       pollen: DemoPollen.sample(at: j.loggedAt, season: pollenSeason), probing: $probing,
                       mapID: j.latitude == nil ? "here" : j.id.uuidString,
                       coordinate: j.latitude.flatMap { lat in j.longitude.map { (lat, $0) } } ?? here.map { ($0.lat, $0.lon) })
                    .onTapGesture { withAnimation(.spring(duration: 0.5, bounce: 0.1)) { focusTime = j.loggedAt; expanded = true } }
            } else {
                NowSky(conditions: here?.conditions, weave: here?.weave ?? WeaveSpec(), date: now,
                       pollen: DemoPollen.sample(at: now, season: pollenSeason), probing: $probing,
                       mapID: "here", coordinate: here.map { ($0.lat, $0.lon) })
                    .onTapGesture { openDay = Calendar.current.startOfDay(for: now) }
            }
        case .moment(let m):
            NowSky(conditions: m.conditions, weave: m.weave, date: m.loggedAt,
                   pollen: DemoPollen.sample(at: m.loggedAt, season: pollenSeason), probing: $probing,
                   mapID: m.id.uuidString, coordinate: m.latitude.flatMap { lat in m.longitude.map { (lat, $0) } },
                   mapNamespace: mapZoom)
                .onTapGesture { withAnimation(.spring(duration: 0.5, bounce: 0.1)) { expanded = true } }
        case .hour(let h):
            NowSky(conditions: h.conditions, weave: h.weave, date: h.date,
                   pollen: DemoPollen.sample(at: h.date, season: pollenSeason), probing: $probing,
                   mapID: mapID, coordinate: forecastCoordinate)
        }
    }

    private var mapID: String { chosen.map { "place-\($0.lat)-\($0.lon)" } ?? "here" }
    /// Straight from the choice, so the map id and its coordinates can never disagree mid-reload.
    private var forecastCoordinate: (Double, Double)? { chosen.map { ($0.lat, $0.lon) } ?? here.map { ($0.lat, $0.lon) } }

    // MARK: Right edge

    /// Bottom-left, where nothing else lives, so the header can run the full width.
    private var rail: some View {
        HStack(spacing: 10) {
            Button { showMonth = true } label: { railIcon("calendar") }.accessibilityLabel("Month")
            Button { showSettings = true } label: { railIcon("gearshape") }.accessibilityLabel("Settings")
        }
        .buttonStyle(.plain)
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
        var parts: [String] = []
        if !weather.isEmpty { parts.append("\(it) \(weather).") }
        if let air { parts.append("The air \(verb) \(air).") }
        // One sentence per line: weather, then air.
        return parts.isEmpty ? "No air reading." : parts.joined(separator: "\n")
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

/// A sky you can touch, without a moment behind it: the same colors, mask and hold-to-read as the
/// Journal's panel, for the air right now or a forecast hour.
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
    @AppStorage(Crit.LayerStrength.key) private var strengthStyle = Crit.LayerStrength.smooth
    @AppStorage(Crit.SkyTexture.key) private var texture = Crit.SkyTexture.dots
    @State private var point: CGPoint?
    @State private var probe: SkyProbe?
    @State private var pulse: Task<Void, Never>?
    @State private var rippleAt: Date?
    @AppStorage("sky.touched") private var touched = false
    @AppStorage(Crit.SkyReading.key) private var reading = Crit.SkyReading.strata
    /// Strata: the band (points) under the finger.
    @State private var band: ClosedRange<CGFloat>?

    private var temperature: Double? { conditions?.best(.temperature)?.value }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                AmbientField(weave: weave, temperatureF: temperature, date: date, conditions: conditions, pollen: pollen)
                if let (lat, lon) = coordinate {
                    // Pinned: the map never moves with the finger, so reading the sky can't feel like
                    // exploring the map. The air is one regional reading, not a spot on a street.
                    PlaceMap(id: mapID, latitude: lat, longitude: lon)
                        .frame(width: size.width, height: size.height)
                        .modifier(MapZoomSource(id: mapID, namespace: mapNamespace))
                        .saturation(0)
                        .blendMode(.screen)
                        .opacity(point == nil ? 0.45 : 0.75)
                        .frame(width: size.width, height: size.height)
                        .clipped()
                        .allowsHitTesting(false)
                }
                if texture != .plain {
                    SkyGrain(point: point, ink: probe?.levelInk, intensity: probe?.intensity ?? 0, responds: texture == .dots, rippleAt: rippleAt, inviting: !touched, band: band)
                }
                if let point, let probe {
                    SkyProbeOverlay(point: point, probe: probe, width: size.width, showsLabel: false, band: band).transition(.opacity)
                }
            }
            .frame(width: size.width, height: size.height)
            .drawingGroup()
            .onAppear { rippleAt = .now }
            // Every new sky (a moment, a forecast hour, now) ripples once.
            .onChange(of: date) { _, _ in rippleAt = .now }
            .mask {
                EllipticalGradient(colors: [.black, .black, .clear], center: UnitPoint(x: 0.5, y: 0.55),
                                   startRadiusFraction: 0, endRadiusFraction: 0.7)
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.26),
                                                 .init(color: .black, location: 0.78), .init(color: .clear, location: 1)],
                                         startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                if let point, let probe {
                    SkyProbeOverlay(point: point, probe: probe, width: size.width, showsGlow: false).transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .gesture(explore(size))
        }
        .padding(.horizontal, 8)
        .onDisappear { stopPulse() }
    }

    private func explore(_ size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { drag in
                if !probing { probing = true; touched = true; startPulse() }
                let unit = CGPoint(x: drag.location.x / size.width, y: drag.location.y / size.height)
                let layers = AirLayers(conditions: conditions, weave: weave, pollen: pollen, smooth: strengthStyle == .smooth)
                withAnimation(.easeOut(duration: 0.12)) {
                    point = drag.location
                    if reading == .strata {
                        let hit = SkyExplorer.strata(at: unit.y, layers: layers, conditions: conditions, weave: weave,
                                                     temperatureF: temperature, pollen: pollen)
                        probe = hit?.probe
                        band = hit.map { ($0.band.lowerBound * size.height)...($0.band.upperBound * size.height) }
                    } else {
                        probe = SkyExplorer.probe(at: unit, layers: layers, conditions: conditions, weave: weave,
                                                  temperatureF: temperature, pollen: pollen)
                    }
                }
            }
            .onEnded { _ in
                stopPulse()
                withAnimation(.easeOut(duration: 0.25)) { point = nil; probe = nil; band = nil }
                probing = false
            }
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
