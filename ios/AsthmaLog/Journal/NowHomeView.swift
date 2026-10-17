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
    @AppStorage(Crit.DemoEvent.key) private var demoEvent = Crit.DemoEvent.none
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
    /// The timeline is moving: skies change without their ripple until it settles.
    @State private var scrubbing = false
    /// A sideways drag on the sky: where it started in time, and the finger.
    @State private var skyDrag: (start: Date, point: CGPoint)?
    @State private var skyPress: CGFloat = 0
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
                ZStack { sky.id(focusKey).transition(.opacity) }
                    .animation(scrubbing ? nil : .easeInOut(duration: 0.25), value: focusKey)
                    // Swiping the sky sideways scrubs time, and the surface dents under the finger as it goes.
                    .distortionEffect(ShaderLibrary.dent(.float2(skyDrag?.point ?? .zero), .float(170), .float(skyPress)),
                                      maxSampleOffset: CGSize(width: 24, height: 24), isEnabled: skyDrag != nil && !reduceMotion)
                    .gesture(skyScrub)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 4)
                NowTimeline(moments: moments, baselines: events.filter { $0.moment == .okay }.map(\.loggedAt),
                            tint: { airTint($0.weave) },
                            forecastTints: hours.map { ($0.date, verdictStrength(outlook(at: $0.date).tint)) },
                            hours: hours, now: now, focusTime: $focusTime, scrubbing: $scrubbing, onPastEnd: { showInsights = true })
                    .frame(height: 104)
                    // Full width; the + and Settings float over its ends, which fade out beneath them.
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.2),
                                                 .init(color: .black, location: 0.8), .init(color: .clear, location: 1)],
                                         startPoint: .leading, endPoint: .trailing))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                // The page takes the weather's colour, as in Apple Weather: hue from the temperature, light from
                // the hour (rose dawn, blue day, amber dusk, indigo night), deepening to black at the bottom.
                // The forecast is the same, quieter. The grain runs over all of it.
                ZStack {
                    LinearGradient(colors: [pageTop, pageTop.mix(with: .black, by: 0.6), pageBottom],
                                   startPoint: .top, endPoint: .bottom)
                    SkyGrain(responds: false).opacity(0.5)
                }
                .ignoresSafeArea()
                .animation(scrubbing ? nil : .easeInOut(duration: 0.5), value: focusKey)
            }
            // Linen is a light page whatever the system says; black is a dark one.
            // Black paper, or linen when chosen; the forecast shifts the paper to warm graphite (above).
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
            .environment(\.skySettled, !scrubbing)
            .sensoryFeedback(.impact(weight: .medium, intensity: 0.9), trigger: inFuture)
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

    /// Whether the playhead is ahead of now. Crossing it gives one firmer haptic.
    private var inFuture: Bool { if case .hour = focus { true } else { false } }

    /// Drag the sky sideways to move through time: a screen-width is about a day, as on the timeline but
    /// slower, and letting go lands on the nearest moment (or stays in the forecast). The dent gives it feel.
    private var skyScrub: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { v in
                guard abs(v.translation.width) > abs(v.translation.height) || skyDrag != nil else { return }
                if skyDrag == nil {
                    skyDrag = (focusTime ?? now, v.startLocation)
                    scrubbing = true
                    withAnimation(Theme.snap) { skyPress = 1 }
                }
                skyDrag?.point = v.location
                let t = skyDrag!.start.addingTimeInterval(-Double(v.translation.width) * 86_400 / 360)
                if abs(t.timeIntervalSince(now)) < 15 * 60 { focusTime = nil }
                else if t < now {
                    focusTime = moments.min { abs($0.loggedAt.timeIntervalSince(t)) < abs($1.loggedAt.timeIntervalSince(t)) }?.loggedAt ?? t
                } else { focusTime = min(t, hours.last?.date ?? t) }
            }
            .onEnded { _ in
                withAnimation(Theme.smooth) { skyPress = 0 }
                skyDrag = nil
                scrubbing = false
            }
    }

    /// An air event right now: the demo switch, or what the real data shows (a thunderstorm while pollen is
    /// high, or a sharp temperature drop). Smoke has no real source yet, so it only appears in the demo.
    private var liveEvent: AirEvent? {
        switch demoEvent {
        case .storm: return .storm
        case .smoke: return .smoke
        case .tempDrop: return .tempDrop
        case .none: break
        }
        guard let c = here?.conditions else { return nil }
        let stormy = (c.weatherCondition ?? "").localizedCaseInsensitiveContains("thunder")
        let pollenHigh = DemoPollen.sample(at: now, season: pollenSeason)?.kinds.contains { $0.level == .high } ?? false
        if stormy && pollenHigh { return .storm }
        if TempDrop.band(c.tempFallF) == .sharp { return .tempDrop }
        return nil
    }

    /// The live air, with the demo event's readings added (labelled Demo) so the particles show it too.
    private var liveAir: (conditions: Conditions?, weave: WeaveSpec, pollen: PollenSample?) {
        var c = here?.conditions
        var pollen = DemoPollen.sample(at: now, season: pollenSeason)
        switch demoEvent {
        case .storm:
            pollen = DemoPollen.sample(at: now, season: .ragweed)
            c?.weatherCondition = "Thunderstorms"
        case .smoke:
            c?.observations.append(EnvObservation(signal: .pm25, value: 142, unit: "µg/m³", asOf: now, source: "Demo",
                                                  spatialScale: .region, confidence: .low))
        case .tempDrop:
            c?.tempFallF = 16
        case .none: break
        }
        return (c, c.map { WeaveSpec($0.input) } ?? here?.weave ?? WeaveSpec(), pollen)
    }

    /// A day that matches your flare days warms the bottom of the page, faintly.
    private var pageBottom: Color {
        let t: Date = switch focus {
        case .now: now
        case .moment(let m): m.loggedAt
        case .hour(let h): h.date
        }
        return outlook(at: t).tint == Self.red ? Self.red.mix(with: .black, by: 0.72) : .black
    }

    /// The top of the page's colour for what the playhead is on. An air event takes the page over:
    /// slate for a storm, ochre for smoke, ice for a temperature drop.
    private var pageTop: Color {
        if case .now = focus, let e = liveEvent {
            switch e {
            case .storm: return Color(red: 0.2, green: 0.25, blue: 0.33)
            case .smoke: return Color(red: 0.55, green: 0.37, blue: 0.18)
            case .tempDrop: return Color(red: 0.42, green: 0.6, blue: 0.85)
            }
        }
        let (t, d): (Double?, Date) = switch focus {
        case .now: (liveAir.conditions?.best(.temperature)?.value, now)
        case .moment(let m): (m.conditions?.best(.temperature)?.value, m.loggedAt)
        case .hour(let h): (h.conditions.best(.temperature)?.value, h.date)
        }
        let c = WeatherColor.light(WeatherColor.temperature(t ?? 62), at: d).mix(with: .black, by: 0.22)
        return inFuture ? c.mix(with: Color(white: 0.2), by: 0.45) : c
    }

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

    /// Top to bottom: where (a plain line, or a field you can change in the forecast), what the air is (the
    /// serif sentence), how it compares (the verdict pill). The inhaler tag sits with the place on moments.
    private var header: some View {
        Group {
            switch focus {
            case .now:
                if let j = justNow {
                    VerdictHeader(tag: j.moment, place: AnyView(placeLabel(j.latitude, j.longitude, j.placeName ?? here?.place)),
                                  title: AirWords.sentence(tense: .present, weave: j.weave, conditions: j.conditions),
                                  verdict: outlook(at: now).text, tint: outlook(at: now).tint, onVerdict: { showInsights = true })
                } else if let e = liveEvent {
                    VerdictHeader(place: AnyView(HStack(spacing: 8) { placeLabel(here?.lat, here?.lon, here?.place, current: true); EventChip(event: e, demo: demoEvent != .none) }),
                                  title: e.sentence(temperature: liveAir.conditions?.best(.temperature)?.value, fallF: liveAir.conditions?.tempFallF),
                                  verdict: outlook(at: now).text, tint: outlook(at: now).tint, onVerdict: { showInsights = true })
                } else {
                    VerdictHeader(place: AnyView(placeLabel(here?.lat, here?.lon, here?.place, current: true)),
                                  title: here?.statement ?? "Checking the air near you…",
                                  verdict: outlook(at: now).text, tint: outlook(at: now).tint, onVerdict: { showInsights = true })
                }
            case .moment(let m):
                VerdictHeader(tag: m.moment, place: AnyView(placeLabel(m.latitude, m.longitude, m.placeName)),
                              title: m.pastStatement, verdict: nil, tint: nil,
                              when: m.loggedAt.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()))
            case .hour(let h):
                VerdictHeader(place: AnyView(placeField), title: h.statement,
                              verdict: outlook(at: h.date).text, tint: outlook(at: h.date).tint, onVerdict: { showInsights = true })
            }
        }
        .padding(.top, 2)
        .animation(scrubbing ? nil : .easeInOut(duration: 0.22), value: focusKey)
    }

    /// The place as words: Home or Work (with their icon) when it's within 150 m of the saved one, else the
    /// place name. "Here" gets the location arrow; other places get no icon.
    private func placeLabel(_ lat: Double?, _ lon: Double?, _ name: String?, current: Bool = false) -> some View {
        let known = Self.knownPlace(lat, lon)
        // Home and Work get their icons; every other place gets the location arrow (filled for where you are now).
        let icon = known?.icon ?? (current ? "location.fill" : "location")
        let text = known?.name ?? name.map(Self.clean) ?? "Here"
        return HStack(spacing: 6) {
            Image(systemName: icon).font(.caption)
            Text(text).lineLimit(1)
        }
        .font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondaryText)
    }

    static func knownPlace(_ lat: Double?, _ lon: Double?) -> (icon: String, name: String)? {
        guard let lat, let lon else { return nil }
        let here = CLLocation(latitude: lat, longitude: lon)
        func near(_ p: SavedPlace?) -> Bool { p.map { here.distance(from: CLLocation(latitude: $0.lat, longitude: $0.lon)) < 150 } ?? false }
        if near(SavedPlace.load(SavedPlace.homeKey)) { return ("house.fill", "Home") }
        if near(SavedPlace.load(SavedPlace.workKey) ?? SavedPlace.washU) { return ("building.2.fill", "Work") }
        return nil
    }

    /// The forecast's place, as a field you can change: Here, Home, Work or an address.
    private var placeField: some View {
        let home = SavedPlace.load(SavedPlace.homeKey), work = SavedPlace.load(SavedPlace.workKey) ?? SavedPlace.washU
        let (icon, name): (String, String) = switch chosen {
        case nil: ("location.fill", Self.knownPlace(here?.lat, here?.lon)?.name ?? here?.place.map(Self.clean) ?? "Here")
        case let p? where p == home: ("house.fill", "Home")
        case let p? where p == work: ("building.2.fill", "Work")
        case let p?: ("location", Self.clean(p.name))
        }
        return HStack(spacing: 8) {
            // The label keeps its width; the field gives way and truncates.
            Text("Forecast for").foregroundStyle(Theme.secondaryText).lineLimit(1).fixedSize()
            Button { showPlaces = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: icon).font(.caption)
                    // Hugs its text; a long name stops at the screen's edge and truncates.
                    Text(name).lineLimit(1).truncationMode(.tail)
                    Image(systemName: "chevron.down").font(.caption2.weight(.bold)).foregroundStyle(Theme.secondaryText)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(Theme.secondaryText.opacity(0.14)))
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Forecast for \(name). Change place")
        }
        .font(.subheadline.weight(.medium))
    }

    /// "3336 Salena St," → "3336 Salena St".
    static func clean(_ name: String) -> String {
        name.trimmingCharacters(in: CharacterSet(charactersIn: ", ").union(.whitespaces))
    }

    /// The one sentence for a time, with its color once felt air has learned. Never a percent, never
    /// "attack", never a cause. Green: like your okay days. Yellow: a bit like your rescue days.
    /// Red: matches the days you reached for your rescue.
    /// The air's level as the verdict's colours: green clear, yellow hazy, red heavy.
    /// How heavy the air was, 0 … 1, for the rail's single ink.
    private func airTint(_ w: WeaveSpec) -> Double? {
        w.levels[.air].map { Double($0.rawValue) / 2 }
    }

    /// The verdict as a strength for the rail (nil while still learning).
    private func verdictStrength(_ tint: Color?) -> Double? {
        switch tint {
        case Verdict.green?: 0
        case Verdict.yellow?: 0.5
        case Verdict.red?: 1
        default: nil
        }
    }

    private func outlook(at t: Date) -> (text: String, tint: Color?) {
        let learned = forced == .learned || (forced == .auto && (model.progress?.isMet ?? false))
        // The demo event is the presentation's story: with the demo person learned, now matches their flare days.
        if learned, demoEvent != .none, abs(t.timeIntervalSince(now)) < 30 * 60 { return ("Matches your flare days", Self.red) }
        if learned {
            if forced == .learned, !(model.progress?.isMet ?? false) {
                // Demo: a rough afternoon, so every color can be seen on the track.
                let h = Calendar.current.component(.hour, from: t)
                if (14...17).contains(h) { return ("Matches your flare days", Self.red) }
                if (11...13).contains(h) || (18...19).contains(h) { return ("A bit like your flare days", Self.yellow) }
                return ("Looks like your baseline days", Self.green)
            }
            if let w = model.days.flatMap(\.windows).first(where: { $0.start <= t && t < $0.end }) {
                // A window's peak is a summed log likelihood ratio; past 1 it's clearly a rescue-day pattern.
                return w.peakScore >= 1 ? ("Matches your flare days", Self.red)
                                        : ("A bit like your flare days", Self.yellow)
            }
            if let day = model.days.first(where: { Calendar.current.isDate($0.day, inSameDayAs: t) }), day.isPersonal {
                return day.band == .elevated ? ("A bit like your flare days", Self.yellow) : ("Looks like your baseline days", Self.green)
            }
            return ("Looks like your baseline days", Self.green)
        }
        return (sentence, nil)
    }

    private static let green = Verdict.green, yellow = Verdict.yellow, red = Verdict.red

    /// Before felt air has learned: how far along it is.
    private var sentence: String {
        if let p = model.progress, !p.isMet {
            let needRescue = max(0, p.minAttacks - p.attacks), needCalm = max(0, p.minBaselines - p.baselines)
            // "Learning: 1 rescue and 14 baseline moments to go"
            var parts: [String] = []
            if needRescue > 0 { parts.append("\(needRescue) rescue") }
            if needCalm > 0 { parts.append("\(needCalm) baseline") }
            let total = needRescue + needCalm
            return "Learning: " + parts.joined(separator: " and ") + (total == 1 ? " moment to go" : " moments to go")
        }
        return "Learning your days"
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
                let air = liveAir
                NowSky(conditions: air.conditions, weave: air.weave, date: now,
                       pollen: air.pollen, probing: $probing,
                       mapID: "here", coordinate: here.map { ($0.lat, $0.lon) }, onPin: { pinDetails = liveSnapshot() },
                       event: liveEvent)
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
                   mapID: mapID, coordinate: forecastCoordinate, sketch: true)
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

    /// "54°, humid, clear air": the conditions as one plain line under the verdict.
    static func short(_ weave: WeaveSpec, _ conditions: Conditions?) -> String {
        let temp = conditions?.best(.temperature).map { "\(Int($0.value.rounded()))°" }
        // Facts, not feelings: "humid" or "dry" when it is, never "comfortable" (it may not have been for you).
        let feel = weave.words[.humidity].flatMap { ["humid", "dry", "very humid", "very dry"].contains($0) ? $0 : nil }
        let air = weave.levels[.air].map { ["clear air", "a little haze", "haze"][$0.rawValue] }
        let parts = [temp, feel, air].compactMap { $0 }
        return parts.isEmpty ? "No air reading" : parts.joined(separator: ", ")
    }

    /// "It was 51° and comfortable. The air was a bit hazy." / "It's… The air is…" / "It will be… The air will be…"
    static func sentence(tense: Tense, weave: WeaveSpec, conditions: Conditions?) -> String {
        let verb = switch tense { case .past: "was"; case .present: "is"; case .future: "will be"; case .carried: "should be" }
        let it = switch tense { case .past: "It was"; case .present: "It's"; case .future, .carried: "It will be" }
        let temp = conditions?.best(.temperature).map { "\(Int($0.value.rounded()))°" }
        // Facts, not feelings: "humid" or "dry" when it is, never "comfortable" (it may not have been for you).
        let feel = weave.words[.humidity].flatMap { ["humid", "dry", "very humid", "very dry"].contains($0) ? $0 : nil }
        let weather = [temp, feel].compactMap { $0 }.joined(separator: " and ")
        let air = weave.levels[.air].map { ["clear", "a little hazy", "hazy"][$0.rawValue] }
        // One sentence, two clauses: "It's 54° and humid, and the air is clear."
        let theAir = "the air \(verb)"
        switch (weather.isEmpty, air) {
        case (false, let air?): return "\(it) \(weather), and \(theAir) \(air)."
        case (false, nil): return "\(it) \(weather)."
        case (true, let air?): return "The air \(verb) \(air)."
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
        guard let all = try? await WeatherProvider().hourly(latitude: latitude, longitude: longitude, hours: 48,
                                                            pastHours: Int(TempDrop.windowHours)) else { return [] }
        let temps = all.map(\.tempPoint)
        let hours = all.filter { $0.date > Date().addingTimeInterval(-3600) }
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
            var conditions = Conditions(observations: obs, fetchedAt: .now)
            conditions.tempFallF = TempDrop.degreesFallen(at: h.date, in: temps)
            return NowHour(date: h.date, conditions: conditions, airCarried: airCarried)
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
    /// A forecast: drawn as a sketch of itself. Hollow particles, a paler map, no pin, since you aren't
    /// there yet.
    var sketch = false
    /// An air event changes the whole field, never a spot: a storm darkens it and breaks the pollen apart,
    /// smoke lays a warm veil over the map, a temperature drop cools the top of the sky.
    var event: AirEvent? = nil
    @State private var flash = 0.0
    @Environment(\.colorScheme) private var scheme
    private var light: Bool { scheme == .light }
    /// False while the timeline is moving.
    @Environment(\.skySettled) private var settled

    private func ripple() { rippleInk = captureInk ?? .white; rippleAt = .now }
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
                    PlaceMap(id: light ? mapID + "-light" : mapID, latitude: lat, longitude: lon, dark: !light)
                        .frame(width: size.width, height: size.height)
                        .modifier(MapZoomSource(id: mapID, namespace: mapNamespace))
                        .saturation(0)
                        .blendMode(light ? .multiply : .screen)
                        .opacity(sketch ? 0.7 : 1)
                        .frame(width: size.width, height: size.height)
                        .clipped()
                        .allowsHitTesting(false)
                    // You are here: the map is centred on the place. Not in a forecast: you aren't there yet.
                    if !sketch {
                        Circle().fill(Color.white.opacity(0.9)).frame(width: 7, height: 7)
                            .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 1.2).frame(width: 13, height: 13))
                            .shadow(color: .black.opacity(0.25), radius: 2)
                    }
                }
                if event == .smoke {
                    Color(red: 0.62, green: 0.46, blue: 0.32).opacity(0.32).allowsHitTesting(false)
                }
                if event == .tempDrop {
                    LinearGradient(colors: [Color(red: 0.55, green: 0.75, blue: 1).opacity(0.38), .clear], startPoint: .top, endPoint: .center)
                        .allowsHitTesting(false)
                }
                if event == .storm {
                    Color.black.opacity(0.28).allowsHitTesting(false)
                    Color.white.opacity(flash).allowsHitTesting(false)
                }
                ParticleField(particles: stack.map { ($0.color, $0.empty ? 0 : (Double($0.level.rawValue) + max(0, min(1, $0.fraction))) / 3) },
                              fragments: stack.map { event == .storm && $0.name.hasSuffix("pollen") },
                              selected: row.flatMap { $0 > 0 ? $0 - 1 : nil },
                              animated: texture == .dots,
                              rippleAt: rippleAt, inviting: !touched && rippleInk == .white,
                              rippleInk: rippleInk, scan: true, hollow: sketch)
            }
            .frame(width: size.width, height: size.height)
            .drawingGroup()
            // A sky ripples once you've landed on it, not while the timeline is moving past it.
            .onAppear { if settled { ripple() } }
            .onChange(of: date) { _, _ in if settled { ripple() } }
            .onChange(of: settled) { _, s in if s { ripple() } }
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
                StrataScale(layers: layers, probe: probe, height: size.height, weatherSymbol: SkyExplorer.weatherIcon(conditions))
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
        // A storm: now and then, a soft flash of lightning across the whole field.
        .task(id: event) {
            guard event == .storm, !reduceMotionEnv else { return }
            while !Task.isCancelled {
                // More often, and sharper: a quick double strike, then a short fade.
                try? await Task.sleep(for: .seconds(Double.random(in: 1.6...3.4)))
                withAnimation(.linear(duration: 0.04)) { flash = 0.42 }
                try? await Task.sleep(for: .milliseconds(60))
                withAnimation(.linear(duration: 0.05)) { flash = 0.08 }
                try? await Task.sleep(for: .milliseconds(70))
                withAnimation(.linear(duration: 0.04)) { flash = 0.3 }
                try? await Task.sleep(for: .milliseconds(50))
                withAnimation(.easeOut(duration: 0.28)) { flash = 0 }
            }
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotionEnv

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
    /// Layers drawn broken up into fragments (pollen in a storm): three tiny dots instead of one.
    var fragments: [Bool] = []
    var selected: Int? = nil
    var animated = true
    var rippleAt: Date? = nil
    var inviting = true
    var rippleInk: Color = .white
    /// A scan: the ring runs out from the pin in the inhaler's ink and the particles exist only where it
    /// has already passed. Before it, the map alone.
    var scan = false
    /// A sketch: particles drawn as rings, not dots. The forecast's look.
    var hollow = false
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
        // A log's scan takes a little longer than an ordinary refresh.
        let seconds = rippleInk == .white ? rippleSeconds : 2.2
        let wave = (animated && !reduceMotion && age < seconds) ? age / seconds : nil
        // Every new sky is revealed by its first ripple: no particles until the ring has passed. Later
        // "touch me" ripples run over a sky that's already there.
        let firstPass = rippleAt.map { time.timeIntervalSince($0) < seconds } ?? false

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
            let fade = wave.map { scan && firstPass ? 1 : 1 - $0 } ?? 0
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
                    // The ring runs ahead over bare grain; inside it, the air fills in, growing up just behind the front.
                    var emerge = 1.0
                    if scan, firstPass, k != nil, let radius {
                        let behind = Double(radius - dist)
                        if behind < 0 { continue }
                        let t = min(1, behind / 70)
                        emerge = 1 - pow(1 - t, 3)
                    }
                    var r: CGFloat, color: Color
                    if let k {
                        let amount = CGFloat(particles[k].1)
                        r = 0.8 + 2.6 * amount
                        let dim = selected != nil && selected != k
                        color = particles[k].0.opacity(dim ? 0.15 : 0.9)
                        if selected == k { r *= 1.6 }
                        r *= CGFloat(emerge)
                        color = color.opacity(emerge)
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
                    if let k, k < fragments.count, fragments[k] {
                        let f = max(0.6, r * 0.45)
                        for (dx, dy) in [(-2.2, -1.4), (2.0, -0.8), (0.2, 2.2)] as [(CGFloat, CGFloat)] {
                            ctx.fill(Path(ellipseIn: CGRect(x: x + dx * r * 0.6 - f, y: y + dy * r * 0.6 - f, width: 2 * f, height: 2 * f)), with: .color(color))
                        }
                        continue
                    }
                    let dot = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
                    if hollow, k != nil, r > 1.4 {
                        ctx.stroke(dot, with: .color(color), lineWidth: 1)
                    } else {
                        ctx.fill(dot, with: .color(color))
                    }
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

/// The home's header: where, then what (the serif sentence), then the verdict as a pill. Each row keeps
/// its height, so nothing jumps while you scrub.
struct VerdictHeader: View {
    var tag: MomentKind? = nil
    let place: AnyView
    let title: String
    let verdict: String?
    let tint: Color?
    var onVerdict: (() -> Void)? = nil
    /// A moment's date and time, on the line where the verdict would be: "Monday, Oct 12, 8:15 AM".
    var when: String? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.skySettled) private var settled

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let tag { MomentTag(moment: tag) }
                place
            }
            .frame(minHeight: 30, alignment: .leading)
            // Instant while scrubbing; one short crossfade in place when you land. No roll, scale or blur.
            Text(title)
                .font(Theme.serifTitle).kerning(Theme.serifKerning)
                .lineLimit(2)
                .contentTransition(.opacity)
                .animation(settled ? .easeInOut(duration: 0.22) : nil, value: title)
            let ink = tint ?? Theme.secondaryText
            Button { onVerdict?() } label: {
                HStack(spacing: 7) {
                    Circle().fill(ink).frame(width: 7, height: 7)
                    Text(verdict ?? " ").lineLimit(1)
                        .contentTransition(.opacity)
                        .animation(settled ? .easeInOut(duration: 0.22) : nil, value: verdict)
                    if onVerdict != nil { Image(systemName: "chevron.right").font(.caption2.weight(.bold)).opacity(0.6) }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(ink.opacity(0.16)))
            }
            .buttonStyle(PressStyle())
            .disabled(onVerdict == nil)
            .opacity(verdict == nil ? 0 : 1)
            .contentTransition(.opacity)
            .overlay(alignment: .leading) {
                if verdict == nil, let when {
                    // Sized to its own text, not the hidden pill's (which is one space wide).
                    Label(when, systemImage: "clock")
                        .font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .animation(settled ? .easeInOut(duration: 0.22) : nil, value: tint)
    }
}

private struct SkySettledKey: EnvironmentKey { static let defaultValue = true }
extension EnvironmentValues {
    /// Whether the timeline has come to rest (skies ripple only then).
    var skySettled: Bool {
        get { self[SkySettledKey.self] }
        set { self[SkySettledKey.self] = newValue }
    }
}

/// Weather that changes the air. Shown across the whole field, with a chip in the header.
enum AirEvent: Equatable {
    case storm, smoke, tempDrop

    var icon: String {
        switch self {
        case .storm: "cloud.bolt.rain.fill"
        case .smoke: "smoke.fill"
        case .tempDrop: "thermometer.low"
        }
    }

    var label: String {
        switch self {
        case .storm: "Storm and pollen"
        case .smoke: "Wildfire smoke"
        case .tempDrop: "Temperature drop"
        }
    }

    /// Plain facts, never a cause: "A thunderstorm while pollen is high."
    func sentence(temperature: Double?, fallF: Double?) -> String {
        let t = temperature.map { "It's \(Int($0.rounded()))°" }
        switch self {
        case .storm: return "A thunderstorm while pollen is high."
        case .smoke: return [t, "and there's wildfire smoke in the air."].compactMap { $0 }.joined(separator: ", ")
        case .tempDrop:
            let fall = fallF.map { "\(Int($0.rounded()))° colder than three hours ago." } ?? "and getting colder fast."
            return [t, fall].compactMap { $0 }.joined(separator: ", ")
        }
    }
}

/// The event's chip, the tag's size and shape, with its symbol. "Demo" when it comes from the switch.
struct EventChip: View {
    let event: AirEvent
    var demo = false

    var body: some View {
        Label(event.label + (demo ? " · Demo" : ""), systemImage: event.icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.primary.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color.primary.opacity(0.3), lineWidth: 0.8))
    }
}
