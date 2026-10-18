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
    @AppStorage(Prefs.statementTypeface) private var statementTypeface = Theme.Typeface.recursive.rawValue
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
    /// Quick Record: the moment whose recorder is open (from a notification, or the toast's Note button).
    @State private var recording: LogEvent?
    @State private var quick = QuickRecordCenter.shared

    /// The air where the phone is. Now is always here.
    @State private var here: NowReading?
    /// The forecast's place when you've picked one (Home, Work, an address); nil means here.
    @State private var away: NowReading?
    @State private var hours: [NowHour] = [] {
        // Only for where you are, not a forecast place you picked.
        didSet { if !hours.isEmpty, chosen == nil { scheduleMorningBrief() } }
    }
    @State private var model = InsightsModel()
    /// Where the playhead is. Nil means now.
    @State private var focusTime: Date?
    @State private var showInsights = false
    /// One column on the hand's side, this far from the screen edge to the centre: Insights and Settings at the
    /// top, the rail's icons, the + at the bottom, all on the same line.
    static let column: CGFloat = 36
    private let sparkleTip = SparkleTip()
    /// Counts up each time a sentence with a sparkle lands: the sparkle button nods in sympathy.
    @State private var noticed = 0
    @Namespace private var hero
    /// The rail is open (held or pinned): the pill above it steps aside.
    @State private var railOpen = false
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Prefs.railLeft) private var railLeft = false
    @State private var showSettings = false
    @State private var openDay: Date?
    @State private var toast: LogEvent?
    @State private var probing = false
    @AppStorage(Prefs.didOnboard) private var didOnboard = false
    /// The timeline is moving: skies change without their ripple until it settles.
    @State private var scrubbing = false
    /// A sideways drag on the sky: where it started in time, and the finger.
    @State private var skyDrag: (start: Date, point: CGPoint)?
    @State private var skyPress: CGFloat = 0
    /// The clock. Ticks so "now" creeps along the track while you watch.
    @State private var now = Date()
    /// Active wildfires near here, while smoke is the event (Ambee, demo until the key arrives).
    @State private var fires: WildfiresNearby?
    @Namespace private var mapZoom
    @State private var tips = TipGroup(.ordered) { PullToLogTip() }

    /// Inhaler moments only; baseline moments stay in the comparison, not on the track.
    private var moments: [LogEvent] { events.filter { $0.moment != .okay } }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .opacity(probing ? 0.4 : 1)
                    .animation(Theme.smooth, value: probing)
                // Once, the first time a sentence carries the sparkle: what it means.
                if didOnboard, hasMark {
                    TipView(sparkleTip)
                    .tint(.primary)
                    .padding(.horizontal, 16).padding(.top, 10)
                }
                // The cards: what to do or see at this time. Several can be true at once, so they stack and you
                // swipe through them, most important first (docs/design/header-ia.md).
                let deck = cards
                if !deck.isEmpty {
                    CardStack(cards: deck) { card($0) }
                        .id(focusKey)
                        .padding(.top, 10)
                        .opacity(probing ? 0.4 : 1)
                        .transition(.opacity)
                }
                // One sky at a time; the next settles in with a breath, not a cut. Self slides the map away.
                ZStack { sky.id(scrubbing ? "scrub" : focusKey).transition(.opacity) }
                    .animation(scrubbing ? nil : .easeInOut(duration: 0.25), value: focusKey)
                    // Swiping the sky sideways scrubs time, and the surface dents under the finger as it goes.
                    // The dent is drawn by the sky itself (NowSky), so what sits on top (Self's glass cards) isn't
                    // flattened into the shader.
                    .environment(\.skyDent, skyDrag != nil && !reduceMotion ? SkyDent(point: skyDrag!.point, press: skyPress) : nil)
                    .gesture(skyScrub)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // Insights and Settings head the rail's column: one strip on the hand's side, top to bottom.
                    // They step aside while the rail is held open (it grows up into this space).
                    .overlay(alignment: railLeft ? .topLeading : .topTrailing) {
                        learningButton
                            .padding(.horizontal, NowHomeView.column - 22).padding(.top, 10)  // the 44pt pill on the column
                            .opacity(probing || railOpen ? 0 : 1)
                            .allowsHitTesting(!(probing || railOpen))
                            .animation(Theme.smooth, value: probing || railOpen)
                    }
                    .padding(.top, 4)
                // Baselines are the engine's, not the journal's: no ticks for them (owner, Oct 17).
                NowTimeline(moments: moments, baselines: [],
                            tint: { airTint($0.weave) },
                            forecastTints: hours.map { ($0.date, verdictStrength(outlook(at: $0.date).tint)) },
                            hours: hours, now: now, focusTime: $focusTime, scrubbing: $scrubbing, onPastEnd: { showInsights = true })
                    .frame(height: 104)
                    // Full width; the + floats over its end, which fades out beneath it. The other end just softens.
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: railLeft ? 0.2 : 0.08),
                                                 .init(color: .black, location: railLeft ? 0.92 : 0.8), .init(color: .clear, location: 1)],
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
            .fullScreenCover(item: $recording) { e in QuickRecordView(event: e) }
            #if DEBUG
            // Recordings: `-quickRecord` opens the recorder on the latest moment (unstructured, so the first
            // layout pass can't cancel it).
            .onAppear {
                if ProcessInfo.processInfo.arguments.contains("-liveRecord") {
                    // The Lock Screen card turns to the latest moment after 8 s, as a background press would
                    // (go Home or lock the device first to see it update there).
                    Task {
                        try? await Task.sleep(for: .seconds(8))
                        let all = (try? context.fetch(FetchDescriptor<LogEvent>(sortBy: [SortDescriptor(\.loggedAt)]))) ?? []
                        if let e = all.last(where: { $0.moment != .okay }) { QuickRecordLive.shared.begin(for: e) }
                    }
                }
                guard ProcessInfo.processInfo.arguments.contains("-quickRecord") else { return }
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    let all = (try? context.fetch(FetchDescriptor<LogEvent>(sortBy: [SortDescriptor(\.loggedAt)]))) ?? []
                    quick.pending = (all.last { $0.moment != .okay } ?? all.last)?.id
                }
            }
            #endif
            // Tapping the Lock Screen recorder (feltair://record/<moment id>) opens the in-app recorder.
            .onOpenURL { url in
                guard url.scheme == "feltair", url.host() == "record", let id = UUID(uuidString: url.lastPathComponent) else { return }
                quick.pending = id
            }
            .onChange(of: quick.pending) { _, id in
                // Fetched by id from the store: a notification can arrive before this view's list has loaded.
                guard let id, let e = try? context.fetch(FetchDescriptor<LogEvent>(predicate: #Predicate { $0.id == id })).first else { return }
                quick.pending = nil
                recording = e
            }
            .sheet(item: $pinDetails) { e in
                NavigationStack { MomentDetailsView(event: e) }
                    .presentationDragIndicator(.visible)
            }
            .overlay(alignment: .bottom) {
                // No tips until onboarding is done: they'd pop over the first-run screens.
                CaptureBar(showInsights: $showInsights, tip: didOnboard ? tips.currentTip as? PullToLogTip : nil, toast: $toast)
            }
            .sheet(isPresented: $showInsights) {
                // The sparkle grows into the page (a zoom from the button), and the page starts in this sky's colour
                // before its own bloom comes through: the same page, turned.
                InsightsView(skyColor: skyColorNow)
                    .navigationTransition(.zoom(sourceID: "insights", in: hero))
                    .presentationDragIndicator(.visible).presentationBackground(Theme.paper(paper)).presentationCornerRadius(32)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .onChange(of: focusKey) { _, _ in if !scrubbing, hasMark { noticed += 1 } }
            .onChange(of: scrubbing) { _, s in if !s, hasMark { noticed += 1 } }
            // Refresh the big statement when Settings › Type flips; do not remount (sheet would dismiss).
            .animation(nil, value: statementTypeface)
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
            // Back in the foreground with no place yet (the first fix timed out): try again.
            .onChange(of: scenePhase) { _, p in if p == .active, here == nil { Task { await load() } } }
            // Re-runs when the location arrives, not only when the event changes.
            .task(id: "\(liveEvent == .smoke)-\(here?.lat ?? 0)") {
                guard liveEvent == .smoke, let p = here else { fires = nil; return }
                fires = await AmbeeClient.wildfires(latitude: p.lat, longitude: p.lon)
            }
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
                model.narrate()
                if let p = away ?? here { await model.loadForecast(latitude: p.lat, longitude: p.lon, placeLabel: p.place ?? "here") }
            }
            // A new moment brings the playhead back to now.
            .environment(\.skySettled, !scrubbing)
            .sensoryFeedback(.impact(weight: .medium, intensity: 0.9), trigger: inFuture)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: inPast)
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
        Sounds.play(.log)
        Task {
            try? await Task.sleep(for: .seconds(10))
            if toast?.id == e.id { withAnimation(Theme.smooth) { toast = nil } }
        }
    }

    /// A moment logged in the last couple of minutes: Now shows it, not the live reading.
    private var justNow: LogEvent? {
        guard let m = moments.last(where: { $0.moment != .note }), now.timeIntervalSince(m.loggedAt) < 120 else { return nil }
        return m
    }

    // MARK: What the playhead is on

    private enum Focus { case now, moment(LogEvent), hour(NowHour) }

    /// Whether the playhead is on a past moment. Crossing back from Now gives a softer tick.
    private var inPast: Bool { if case .moment = focus { true } else { false } }

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
        case .mold: return .mold
        case .none: break
        }
        guard let c = here?.conditions else { return nil }
        if Self.isMold(c) { return .mold }
        let stormy = (c.weatherCondition ?? "").localizedCaseInsensitiveContains("thunder")
        let pollenHigh = DemoPollen.sample(at: now, season: pollenSeason)?.kinds.contains { $0.level == .high } ?? false
        if stormy && pollenHigh { return .storm }
        if TempDrop.band(c.tempFallF) == .sharp { return .tempDrop }
        return nil
    }

    /// The live air, with the demo event's readings added so the particles show it too.
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
        case .mold:
            c?.weatherCondition = "Rain"
            c?.observations.append(EnvObservation(signal: .humidity, value: 88, unit: "%", asOf: now, source: "Demo",
                                                  spatialScale: .region, confidence: .low))
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
            case .mold: return Color(red: 0.27, green: 0.36, blue: 0.3)
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

    /// The header's sentence carries a sparkle mark (a pattern). Arms the one-time SparkleTip.
    private var hasMark: Bool {
        let title: String? = switch focus {
        case .now: justNow == nil && here != nil ? nowRead : nil
        case .moment(let m): backRead(m)
        case .hour(let h): aheadRead(h)
        }
        let marked = title.map { s in TheRead.Mark.allCases.contains { s.contains($0.rawValue) } } ?? false
        return marked
    }

    /// Insights and Settings as one upright glass pill at the head of the rail's column, the sparkle on top.
    /// Settings left the bottom corner, where it sat on the timeline.
    private var learningButton: some View {
        VStack(spacing: 2) {
            // No bubble: it would cover the sky. Learning breathes; learned bounces once.
            InsightsRingButton(open: { showInsights = true }, size: 36, bubbleBelow: true, leading: railLeft, showsBubble: false, glass: false, nod: noticed)
                .matchedTransitionSource(id: "insights", in: hero)
            settingsButton
        }
        .padding(4)
        .glassEffect(.regular, in: .capsule)   // not .interactive(): on a container it takes the buttons' taps
        .padding(.top, 1)
    }

    private var settingsButton: some View {
        Button { showSettings = true } label: {
            Image(systemName: "gearshape").font(.body.weight(.semibold)).frame(width: 36, height: 36).contentShape(Circle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Settings")
    }

    /// Top to bottom: where (a plain line, or a field you can change in the forecast), what the air is (the
    /// serif sentence), how it compares (the verdict pill). The inhaler tag sits with the place on moments.
    private var header: some View {
        Group {
            switch focus {
            case .now:
                if let j = justNow {
                    // Just logged: Now is taken over by the capture. No verdict while it's happening.
                    VerdictHeader(tag: j.moment, place: AnyView(placeLabel(j.latitude, j.longitude, j.placeName ?? here?.place)),
                                  title: TheRead.justLogged(j.moment.title), verdict: nil, tint: nil)
                } else {
                    VerdictHeader(place: AnyView(placeLabel(here?.lat, here?.lon, here?.place, current: true)),
                                  title: here == nil ? "Checking the air near you…" : nowRead,
                                  verdict: outlook(at: now).text, tint: outlook(at: now).tint, onVerdict: { showInsights = true })
                }
            case .moment(let m):
                VerdictHeader(tag: m.moment, place: AnyView(placeLabel(m.latitude, m.longitude, m.placeName)),
                              title: backRead(m), verdict: nil, tint: nil,
                              when: m.loggedAt.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()))
            case .hour(let h):
                VerdictHeader(place: AnyView(placeField), title: aheadRead(h),
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
            // No "Forecast for": the read names the time, and the verdict sits beside this on the context line.
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
    /// Never say "attack", never a cause. Green: like your baseline. Yellow / red: like your flare days.
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

    /// Before felt air has learned. Not a countdown: you're not a number (owner, Oct 17).
    private var sentence: String { "Still learning" }

    private static func when(_ d: Date) -> String {
        let cal = Calendar.current
        let day = cal.isDateInToday(d) ? "This" : cal.isDateInTomorrow(d) ? "Tomorrow" : d.formatted(.dateTime.weekday(.wide))
        let h = cal.component(.hour, from: d)
        let part = h < 12 ? "morning" : h < 17 ? "afternoon" : "evening"
        return cal.isDateInToday(d) ? "This \(part)" : "\(day) \(part)"
    }

    // MARK: Sky

    /// One NowSky for every time, built from the playhead's focus, so its identity holds while you scrub and
    /// the colour flows from moment to moment instead of cutting (docs/design/polish-pass.md §2). Landed, it
    /// takes the moment's id again, so arriving somewhere new still crossfades.
    private var sky: some View {
        let s = skyInputs
        return NowSky(conditions: s.conditions, weave: s.weave, date: s.date, pollen: s.pollen, probing: $probing,
                      mapID: s.mapID, coordinate: s.coordinate, mapNamespace: s.mapNamespace, captureInk: s.captureInk,
                      onPin: s.onPin, sketch: s.sketch, event: s.event, showsSelf: s.showsSelf, selfEvent: s.selfEvent,
                      onRecord: { recording = $0 }, makeNote: s.makeNote,
                      scrubTemperature: scrubbing ? focusTime.flatMap(temperature(at:)) : nil,
                      onRailOpen: { railOpen = $0 })
            .onTapGesture { s.onTap() }
    }

    private struct SkyInputs {
        var conditions: Conditions?
        var weave: WeaveSpec
        var date: Date
        var pollen: PollenSample?
        var mapID: String
        var coordinate: (Double, Double)?
        var mapNamespace: Namespace.ID? = nil
        var captureInk: Color? = nil
        var onPin: (() -> Void)? = nil
        var sketch = false
        var event: AirEvent? = nil
        var showsSelf = false
        var selfEvent: LogEvent? = nil
        var makeNote: (() async -> LogEvent?)? = nil
        var onTap: () -> Void = {}
    }

    private var skyInputs: SkyInputs {
        switch focus {
        case .now:
            if let j = justNow {
                // Just logged: the map alone first, then a scan from the pin in the inhaler's ink, and the
                // particles appear where it has passed.
                return SkyInputs(conditions: j.conditions ?? here?.conditions, weave: j.weave.isEmpty ? (here?.weave ?? WeaveSpec()) : j.weave, date: j.loggedAt,
                                 pollen: DemoPollen.sample(at: j.loggedAt, season: pollenSeason),
                                 mapID: j.latitude == nil ? "here" : j.id.uuidString,
                                 coordinate: j.latitude.flatMap { lat in j.longitude.map { (lat, $0) } } ?? here.map { ($0.lat, $0.lon) },
                                 captureInk: j.moment == .rescue ? Theme.rescueSoft : Theme.standardSoft, onPin: { pinDetails = j },
                                 showsSelf: true, selfEvent: j, onTap: { pinDetails = j })
            }
            let air = liveAir
            return SkyInputs(conditions: air.conditions, weave: air.weave, date: now, pollen: air.pollen,
                             mapID: "here", coordinate: here.map { ($0.lat, $0.lon) }, onPin: { pinDetails = liveSnapshot() },
                             event: liveEvent, showsSelf: true, selfEvent: recentInhalerMoment,
                             makeNote: { await services.log(.note, in: context, writeToHealth: false) },
                             onTap: { openDay = Calendar.current.startOfDay(for: now) })
        case .moment(let m):
            return SkyInputs(conditions: m.conditions, weave: m.weave, date: m.loggedAt,
                             pollen: DemoPollen.sample(at: m.loggedAt, season: pollenSeason),
                             mapID: m.id.uuidString, coordinate: m.latitude.flatMap { lat in m.longitude.map { (lat, $0) } },
                             mapNamespace: mapZoom, onPin: { pinDetails = m }, showsSelf: true, selfEvent: m, onTap: { pinDetails = m })
        case .hour(let h):
            return SkyInputs(conditions: h.conditions, weave: h.weave, date: h.date,
                             pollen: DemoPollen.sample(at: h.date, season: pollenSeason),
                             mapID: mapID, coordinate: forecastCoordinate, sketch: true)
        }
    }

    /// The sky's base colour at the playhead, for Insights to start from.
    private var skyColorNow: Color {
        let s = skyInputs
        let t = s.conditions?.best(.temperature)?.value ?? WeatherColor.fallbackTemp(s.weave)
        return WeatherColor.light(WeatherColor.temperature(t), at: s.date)
    }

    /// The temperature at any time on the track, between the readings either side of it (moments, now, the
    /// forecast), so the sky's hue flows under the playhead instead of stepping.
    private func temperature(at t: Date) -> Double? {
        var pts: [(Date, Double)] = moments.compactMap { m in m.conditions?.best(.temperature).map { (m.loggedAt, $0.value) } }
        if let v = here?.conditions.best(.temperature)?.value { pts.append((now, v)) }
        pts += hours.compactMap { h in h.conditions.best(.temperature).map { (h.date, $0.value) } }
        pts.sort { $0.0 < $1.0 }
        guard let after = pts.first(where: { $0.0 >= t }) else { return pts.last?.1 }
        guard let before = pts.last(where: { $0.0 <= t }) else { return after.1 }
        let span = after.0.timeIntervalSince(before.0)
        guard span > 0 else { return before.1 }
        return before.1 + (after.1 - before.1) * t.timeIntervalSince(before.0) / span
    }

    /// On Now, Voice and Body are about a rescue or Standard logged in the last 30 minutes, if there is one: a
    /// note during a rescue goes into that moment. Otherwise saving a voice note makes a Note.
    private var recentInhalerMoment: LogEvent? {
        moments.last { ($0.moment == .rescue || $0.moment == .maintenance) && now.timeIntervalSince($0.loggedAt) < 30 * 60 }
    }

    private var mapID: String { chosen.map { "place-\($0.lat)-\($0.lon)" } ?? "here" }



    /// What stood out at a rescue moment, from the data model: the bins of its frame that are gated
    /// patterns (more common on flare days than baseline), named in plain words. Never a cause, never a
    /// percent: "Weed pollen was high and it was humid, as on most of your flare days." Nil when the moment
    /// isn't rescue, the gate isn't met, or nothing in it is a pattern; the weather sentence then stands.
    /// A flare moment's line, led by the event that was going on (facts only: AirAdvice.afterFlare).
    private func standsOut(_ m: LogEvent) -> String? {
        guard let line = standsOutBody(m) else { return nil }
        guard let c = m.conditions, let e = Self.event(in: c) else { return line }
        // A drop now and the day before are one story: said once, as a change.
        let dayBefore = e == .tempDrop && c.lookBack?.tempDropLevel == .earlier
        var fact = AirAdvice.afterFlare(e.advice, fallF: c.tempFallF, dayBefore: dayBefore)
        var rest = line.replacingOccurrences(of: "Nothing outdoors stood out this time.", with: "")
            .replacingOccurrences(of: dayBefore ? Self.dayBeforeDrop : "\u{0}", with: "")
        // The event already says the drop: when the pattern is the drop too, its sparkle joins the fact
        // instead of saying it again ("…fallen 19° in three hours. ✦").
        let dropPattern = TheRead.noun("temp_drop", "yes") + " was there."
        if e == .tempDrop, let r = rest.range(of: dropPattern) {
            let after = rest[r.upperBound...]
            if let mark = after.first(where: { TheRead.Mark(rawValue: String($0)) != nil }) {
                fact += "\u{00A0}" + String(mark)
                rest = String(after.drop { $0 == "\u{00A0}" || $0 == " " }.dropFirst())
            } else {
                rest = String(after)
            }
        }
        return [fact, rest].joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    /// An event the moment's own readings show (no demo data: these lines are facts about a real moment).
    static func event(in c: Conditions) -> AirEvent? {
        if TempDrop.band(c.tempFallF) == .sharp { return .tempDrop }
        if isMold(c) { return .mold }
        return nil
    }

    static func isMold(_ c: Conditions) -> Bool {
        AirAdvice.isMoldWeather(condition: c.weatherCondition, humidity: c.best(.humidity)?.value,
                                temperatureF: c.best(.temperature)?.value)
    }

    // MARK: The read and the cards (docs/design/header-ia.md)

    private var isLearned: Bool { forced == .learned || (forced == .auto && (model.progress?.isMet ?? false)) }

    /// Gated rows to compare against: yours, or the demo person's while Design crit forces "learned".
    private var gatedRows: [LiftRow] {
        if forced == .learned, !(model.progress?.isMet ?? false) { return AirProfile.demoPerson.axes.compactMap(\.lead).filter(\.gated) }
        return model.report?.gatedRows ?? []
    }

    private func shared(_ c: Conditions?, at d: Date) -> [LiftRow] {
        guard let c, c.input.hasAnyValue else { return [] }
        return TheRead.shared(FrameBuilder.frame(id: "read", kind: .baseline, date: d, conditions: c.input), rows: gatedRows)
    }

    /// What's at a high level, most first, as a clause: "weed pollen is high" (or "looks high", ahead).
    private func notable(_ c: Conditions?, weave: WeaveSpec, pollen: PollenSample?, ahead: Bool) -> [(factor: AirAdvice.Factor, clause: String)] {
        let names: [String: (AirAdvice.Factor, String)] = [
            "PM2.5": (.pm25, "fine particles"), "PM10": (.pm10, "coarse dust"), "NO₂": (.no2, "traffic pollution"),
            "Ozone": (.ozone, "ozone"), "Tree pollen": (.treePollen, "tree pollen"), "Grass pollen": (.grassPollen, "grass pollen"),
            "Weed pollen": (.weedPollen, "weed pollen"),
        ]
        return AirLayers(conditions: c, weave: weave, pollen: pollen).all
            .filter { $0.level == .high }
            .sorted { $0.fraction > $1.fraction }
            .compactMap { l in names[l.name].map { ($0.0, "\($0.1) \(ahead ? "looks" : "is") high") } }
    }

    /// Now: the event, then what you share with your flare days (counts), or what's high, never the weather.
    private var nowRead: String {
        let air = liveAir
        // No reading (every source failed, or offline): say so, never "nothing stands out".
        guard air.conditions?.input.hasAnyValue == true || liveEvent != nil else { return TheRead.noReading(.now) }
        return TheRead.sentence(time: .now, learned: isLearned, event: liveEvent?.advice, fallF: air.conditions?.tempFallF,
                                fires: fires, shared: shared(air.conditions, at: now),
                                notable: notable(air.conditions, weave: air.weave, pollen: air.pollen, ahead: false).map(\.clause))
    }

    /// An event the forecast shows (a sharp drop, mold weather).
    private func aheadEvent(_ h: NowHour) -> AirEvent? {
        if TempDrop.band(h.conditions.tempFallF) == .sharp { return .tempDrop }
        return Self.isMold(h.conditions) ? .mold : nil
    }

    /// `label` names the time ("Thursday afternoon"); the morning brief says "This afternoon" instead.
    private func aheadRead(_ h: NowHour, label: String? = nil) -> String {
        let tint = outlook(at: h.date).tint
        return TheRead.sentence(time: .ahead(label ?? Self.when(h.date)), learned: isLearned, event: aheadEvent(h)?.advice,
                                fallF: h.conditions.tempFallF, shared: shared(h.conditions, at: h.date),
                                notable: notable(h.conditions, weave: h.weave, pollen: DemoPollen.sample(at: h.date, season: pollenSeason), ahead: true).map(\.clause),
                                looksLikeFlare: tint == Self.red || tint == Self.yellow)
    }

    private var atHome: Bool { Self.knownPlace(here?.lat, here?.lon)?.name == "Home" }

    /// Tomorrow's look-ahead for the 8 am notification: the waking hour that looks most like your flare days,
    /// worded for that morning ("This afternoon…").
    private func scheduleMorningBrief() {
        let cal = Calendar.current
        let tomorrow = hours.filter { cal.isDateInTomorrow($0.date) && (7...22).contains(cal.component(.hour, from: $0.date)) }
        guard let pick = tomorrow.max(by: { (verdictStrength(outlook(at: $0.date).tint) ?? 0) < (verdictStrength(outlook(at: $1.date).tint) ?? 0) }) else {
            MorningBrief.schedule(title: nil, body: nil)
            return
        }
        let h = cal.component(.hour, from: pick.date)
        let part = h < 12 ? "This morning" : h < 17 ? "This afternoon" : "This evening"
        let verdict = outlook(at: pick.date).text
        let title = isLearned ? "Today: \(verdict.prefix(1).lowercased() + verdict.dropFirst())" : "Today's air"
        MorningBrief.schedule(title: title, body: TheRead.spoken(aheadRead(pick, label: part)))
    }

    /// Ahead, the advice follows the forecast's place, not where you are.
    private var forecastAtHome: Bool {
        guard let chosen else { return atHome }
        return chosen == SavedPlace.load(SavedPlace.homeKey)
    }

    /// The deck for the playhead's time, most important first.
    private var cards: [HeaderCard] {
        switch focus {
        case .now:
            if let j = justNow {
                var deck: [HeaderCard] = [.capture(j)]
                if let e = liveEvent { deck.append(.advice(AirAdvice.warning(e.advice, fallF: liveAir.conditions?.tempFallF), icon: e.icon, title: e.label, home: atHome, ahead: false)) }
                return deck
            }
            let air = liveAir
            return adviceDeck(event: liveEvent, fallF: air.conditions?.tempFallF,
                              notable: notable(air.conditions, weave: air.weave, pollen: air.pollen, ahead: false), home: atHome, ahead: false)
        case .moment:
            // No note card: Voice on the rail is where you say what was going on.
            return []
        case .hour(let h):
            return adviceDeck(event: aheadEvent(h), fallF: h.conditions.tempFallF,
                              notable: notable(h.conditions, weave: h.weave, pollen: DemoPollen.sample(at: h.date, season: pollenSeason), ahead: true),
                              home: forecastAtHome, ahead: true)
        }
    }

    private func adviceDeck(event: AirEvent?, fallF: Double?, notable: [(factor: AirAdvice.Factor, clause: String)],
                            home: Bool, ahead: Bool) -> [HeaderCard] {
        var deck: [HeaderCard] = []
        if let event { deck.append(.advice(AirAdvice.warning(event.advice, fallF: fallF), icon: event.icon, title: event.label, home: home, ahead: ahead)) }
        for n in notable.prefix(3) {
            let w = AirAdvice.warning(n.factor)
            deck.append(.advice(w, icon: Icons.factor(n.factor),
                                title: w.headline.replacingOccurrences(of: " today.", with: "").replacingOccurrences(of: ".", with: ""),
                                home: home, ahead: ahead))
        }
        return deck
    }

    @ViewBuilder private func card(_ c: HeaderCard) -> some View {
        switch c {
        case .advice(let w, let icon, let title, let home, let ahead):
            AdviceCard(warning: w, icon: icon, title: title, home: home, ahead: ahead)
        case .capture(let e):
            // The header already says "Rescue logged": no toast. Undo sits on the card for a bit (docs/design/polish-pass.md).
            CaptureCard(event: e, record: { recording = e }, undo: toast?.id == e.id ? {
                withAnimation(.snappy) { toast = nil }
                Task { await services.undoPress(e, in: context) }
            } : nil)
        }
    }

    /// Back: Standard is routine; a Note leads with its words; no reading says so (with the reason when known).
    private func backRead(_ m: LogEvent) -> String {
        if m.moment == .maintenance { return TheRead.standard }
        if m.moment == .note { return TheRead.note(m.voiceTranscript, tags: m.tags.sorted()) }
        guard m.conditions?.input.hasAnyValue == true else {
            return TheRead.noReading(.back, checking: m.envStatus == .pending, reason: m.envError)
        }
        return standsOut(m) ?? m.pastStatement
    }

    private func standsOutBody(_ m: LogEvent) -> String? {
        guard m.moment == .rescue else { return nil }
        let learned = forced == .learned || (model.progress?.isMet ?? false)
        // What was in the air in the two days before (the look-back, docs/air-outlook.md): a flare often
        // trails the air, so a high the day before is worth a clause even when the moment itself was clean.
        let before = Self.before(m.conditions?.lookBack)
        // On a flare, the weather sentence alone would judge the air ("the air was clear") and discount what
        // happened. So: the facts, then what we saw, or didn't: outdoor air is the only thing felt air can see.
        let weather = AirWords.weatherOnly(tense: .past, weave: m.weave, conditions: m.conditions)
        let nothing = "Nothing outdoors stood out this time."
        guard learned else { return [weather, before ?? nothing].compactMap { $0 }.joined(separator: " ") }
        if forced == .learned, !(model.progress?.isMet ?? false) {
            // The demo person's story, for moments without a real pattern behind them.
            return [TheRead.marked("High weed pollen", time: .back, mark: .often), before].compactMap { $0 }.joined(separator: " ")
        }
        guard let frame = m.frame(), let rows = model.report?.gatedRows, !rows.isEmpty else {
            return [weather, before ?? nothing].compactMap { $0 }.joined(separator: " ")
        }
        let hits = Bins.all.compactMap { def -> (String, Double)? in
            guard let level = def.levelOf(frame),
                  let row = rows.first(where: { $0.bin == def.bin && $0.level == level && $0.lift > 1.25 }) else { return nil }
            return (Self.phrase(def.bin, level), row.lift)
        }
        .sorted { $0.1 > $1.1 }
        guard !hits.isEmpty else { return [weather, before ?? nothing].compactMap { $0 }.joined(separator: " ") }
        // Raw counts, not "as on most of your flare days".
        let top = TheRead.shared(frame, rows: rows).first.map { TheRead.pattern($0, past: true) }
        return [top, before].compactMap { $0 }.joined(separator: " ")
    }

    static let dayBeforeDrop = "The temperature dropped fast the day before."

    /// "Fine particles were high in the two days before." Only signals whose two windows were read well
    /// enough count; a window that wasn't read is missing, not clean. High *now* is already in the frame.
    private static func before(_ lb: LookBack?) -> String? {
        guard let lb else { return nil }
        var names: [String] = []
        if lb.pm25Level == .earlier { names.append("fine particles") }
        if lb.ozoneLevel == .earlier { names.append("ozone") }
        var parts: [String] = []
        if !names.isEmpty {
            let joined = names.count == 1 ? names[0] : "\(names[0]) and \(names[1])"
            parts.append(joined.prefix(1).uppercased() + joined.dropFirst() + (names.count == 1 && names[0] == "ozone" ? " was" : " were") + " high the two days before.")
        }
        if lb.tempDropLevel == .earlier { parts.append(dayBeforeDrop) }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// A bin and level as a short past-tense clause.
    private static func phrase(_ bin: String, _ level: String) -> String {
        switch (bin, level) {
        case ("pm25", "high"): "fine particles were high"
        case ("pm25", "moderate"): "fine particles were up"
        case ("ozone", "high"): "ozone was high"
        case ("ozone", "moderate"): "ozone was up"
        case ("pollen_weed", "high"): "weed pollen was high"
        case ("pollen_weed", "moderate"): "weed pollen was up"
        case ("temp", "hot"): "it was hot"
        case ("temp", "cold"): "it was cold"
        case ("humidity", "humid"): "it was humid"
        case ("humidity", "dry"): "the air was dry"
        case ("smoke_at_point", "yes"): "there was smoke"
        case ("heat_alert", "yes"): "there was a heat alert"
        case ("temp_drop", "yes"): "the temperature had dropped fast"
        case ("hour", let part): "it was \(part)"
        case ("indoor_outdoor", let io): "you were \(io == "indoor" ? "indoors" : "outdoors")"
        case (let b, let l) where b.hasPrefix("tag_"): "\(Bins.label(b).lowercased()) was noted\(l == "yes" ? "" : "")"
        case (let b, let l): "\(Bins.label(b).lowercased()) was \(l)"
        }
    }

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

    // MARK: Data

    private func load() async {
        // A fix can take a while indoors: three tries, so Now isn't stuck on "Checking the air near you…".
        var fix: CLLocation?
        for _ in 0..<3 where fix == nil {
            fix = try? await services.location.currentLocation(timeout: .seconds(6))
        }
        guard let fix else { return }
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

    /// "It was 58° and humid." The weather alone, no judgement of the air: for flare moments.
    static func weatherOnly(tense: Tense, weave: WeaveSpec, conditions: Conditions?) -> String? {
        let it = switch tense { case .past: "It was"; case .present: "It's"; case .future, .carried: "It will be" }
        let temp = conditions?.best(.temperature).map { "\(Int($0.value.rounded()))°" }
        let feel = weave.words[.humidity].flatMap { ["humid", "dry", "very humid", "very dry"].contains($0) ? $0 : nil }
        let weather = [temp, feel].compactMap { $0 }.joined(separator: " and ")
        return weather.isEmpty ? nil : "\(it) \(weather)."
    }

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
    /// Self, the rail's last stop: false for a forecast (there's no "you" there yet).
    var showsSelf = false
    /// The moment Self is about (nil for Now with nothing logged), and how to record a note for it.
    var selfEvent: LogEvent? = nil
    var onRecord: ((LogEvent) -> Void)? = nil
    /// Saving a voice note on Now with nothing logged makes a Note moment (never in patterns).
    var makeNote: (() async -> LogEvent?)? = nil
    /// While scrubbing: the temperature between readings, for a hue that flows with the playhead.
    var scrubTemperature: Double? = nil
    /// Told when the rail opens or closes (held, or pinned on Voice / Body), so what sits above it can step aside.
    var onRailOpen: ((Bool) -> Void)? = nil
    @State private var voice = VoiceSession()
    @Environment(\.modelContext) private var modelContext
    /// Let go on a Self row and its panel stays, the rail open beside it.
    @State private var pinned: RailRow?
    @Environment(\.skyDent) private var dent
    /// Settings › Rail: left for left hands (the panels read on the other side of the thumb).
    @AppStorage(Prefs.railLeft) private var railLeft = false
    @State private var flash = 0.0
    @State private var pinPulse = false
    /// Past: a moment more than 20 minutes ago (not a forecast, not a fresh log).
    private var isPast: Bool { !sketch && captureInk == nil && date < Date().addingTimeInterval(-20 * 60) }
    /// 0 at now … 1 two days out.
    private var farness: CGFloat { sketch ? CGFloat(min(1, max(0, date.timeIntervalSinceNow / (48 * 3600)))) : 0 }
    @Environment(\.colorScheme) private var scheme
    private var light: Bool { scheme == .light }
    /// False while the timeline is moving.
    @Environment(\.skySettled) private var settled

    private func ripple() { rippleInk = captureInk ?? .white; rippleAt = .now }
    @AppStorage(Crit.Paper.key) private var paper = Crit.Paper.black
    @AppStorage(Crit.SkyTexture.key) private var texture = Crit.SkyTexture.dots
    @State private var probe: SkyProbe?
    /// The 48 hours before this sky's time, for the label's lines. Loaded once per sky.
    @State private var history: HourlyHistory?
    /// The rail row being read, and whether the rail is held open (groups with their items).
    @State private var row: RailRow?
    @State private var expanded = false
    @State private var pulse: Task<Void, Never>?
    /// The thumb's height on the rail while it's held: the stop under it grows, its neighbours ease away.
    @State private var railFinger: CGFloat?
    /// When the rail opens, everything would slide to make room. This keeps the stop you pressed where it
    /// was (the rail grows around your thumb), clamped so the rail stays on the sky.
    @State private var railShift: CGFloat = 0
    @State private var rippleAt: Date?
    @State private var rippleInk: Color = .white
    @AppStorage("sky.touched") private var touched = false

    private var temperature: Double? { scrubTemperature ?? conditions?.best(.temperature)?.value }
    private var layers: AirLayers { AirLayers(conditions: conditions, weave: weave, pollen: pollen, smooth: true) }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let stack = SkyExplorer.stack(layers)
            let rows = RailRow.rows(expanded: expanded, layers: layers, includesSelf: showsSelf)
            let mids = RailRow.mids(rows).map { CGFloat($0) * size.height + (expanded ? railShift : 0) }
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
                            // Now is live: the pin breathes like a live location. The past's pin stays still.
                            .background {
                                if !isPast {
                                    Circle().stroke(.white.opacity(pinPulse ? 0 : 0.6), lineWidth: 1.5)
                                        .frame(width: pinPulse ? 34 : 13, height: pinPulse ? 34 : 13)
                                }
                            }
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
                              selected: selectedLayer(stack),
                              animated: texture == .dots,
                              rippleAt: rippleAt, inviting: !touched && rippleInk == .white,
                              rippleInk: rippleInk, scan: true, hollow: sketch,
                              breathes: !isPast, drift: sketch ? 1 + 2 * farness : 0,
                              reveal: sketch ? .soft : isPast ? .inward : .outward)
            }
            .frame(width: size.width, height: size.height)
            // The past is a print, a touch faded. The future softens the further out it is.
            .saturation(isPast ? 0.82 : 1)
            .blur(radius: sketch && !reduceMotionEnv ? 2.5 * farness : 0)
            .drawingGroup()
            // Swiping the sky sideways dents the surface under the finger (set by NowHomeView).
            .distortionEffect(ShaderLibrary.dent(.float2(dent?.point ?? .zero), .float(170), .float(dent?.press ?? 0)),
                              maxSampleOffset: CGSize(width: 24, height: 24), isEnabled: dent != nil)
            // A sky ripples once you've landed on it, not while the timeline is moving past it.
            .onAppear { if settled { ripple() } }
            .onChange(of: expanded, initial: true) { _, open in onRailOpen?(open) }
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
                // Beside the thumb, at the row's height: an item's (or Weather's) full reading, or for a group,
                // the list of everything it tracks. Each names itself, so the thumb never hides what you're on.
                // A Self panel left open: tapping the open sky around it closes it (under the panel, so its
                // buttons still work).
                if pinned != nil && row == nil {
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture {
                            if voice.phase != .idle { voice.discard() }
                            withAnimation(Theme.smooth) { pinned = nil; expanded = false }
                        }
                }
                if let shown = row ?? pinned, let i = rows.firstIndex(of: shown) {
                    let x = railLeft ? 64 + 130 : size.width - 64 - 130, y = min(max(mids[i], 110), size.height - 110)
                    switch shown {
                    case .header(let g) where !g.items.isEmpty:
                        GroupSummary(group: g, layers: layers)
                            .frame(width: 224)
                            .position(x: railLeft ? 64 + 118 : size.width - 64 - 118, y: min(max(mids[i], 90), size.height - 90))
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    case .voice:
                        VoicePanel(event: selfEvent, session: voice, interactive: !probing, save: {
                            Task {
                                await voice.save(into: selfEvent, makeNote: { await makeNote?() }, context: modelContext)
                                withAnimation(Theme.smooth) { pinned = nil; expanded = false }
                            }
                        })
                        .frame(width: 260).position(x: x, y: y).transition(.opacity)
                    case .body:
                        BodyPanel(date: selfEvent?.loggedAt ?? date, interactive: !probing)
                            .frame(width: 248).position(x: x, y: y).transition(.opacity)
                    default:
                        if let probe {
                            SkyProbeOverlay(point: CGPoint(x: railLeft ? 64 + 118 : size.width - 64 - 118, y: mids[i]), probe: probe, width: size.width,
                                            showsGlow: false, beside: true)
                                .transition(.opacity)
                        }
                    }
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
            .overlay(alignment: railLeft ? .leading : .trailing) {
                GroupRail(layers: layers, rows: rows, mids: mids, selected: row ?? pinned, weatherSymbol: SkyExplorer.weatherIcon(conditions),
                         voiceBadge: selfEvent?.wantsNote ?? false, fingerY: railFinger)
                    // The stops sit in one glass well, the same material as the controls above and the + below.
                    .background {
                        if let first = mids.first, let last = mids.last {
                            Capsule().fill(.clear)
                                .glassEffect(.regular, in: .capsule)
                                .frame(width: 44, height: last - first + 52)
                                .position(x: 0, y: (first + last) / 2)
                                .animation(Theme.smooth, value: mids.count)
                        }
                    }
                    .padding(railLeft ? .leading : .trailing, NowHomeView.column - 8)  // the sky sits 8pt in from the screen
                    .frame(width: 64, height: size.height, alignment: railLeft ? .leading : .trailing)
                    .contentShape(Rectangle())
                    .gesture(scrub(size))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Weather, particles and gases, biologics" + (showsSelf ? ", your voice and your body" : ""))
                    .accessibilityAdjustableAction { dir in
                        let all = RailRow.rows(expanded: true, layers: layers, includesSelf: showsSelf)
                        let i = row.flatMap { all.firstIndex(of: $0) } ?? -1
                        select(all[dir == .increment ? min(all.count - 1, i + 1) : max(0, i - 1)])
                    }
            }
        }
        .padding(.horizontal, 8)
        .onDisappear { stopPulse() }
        .task(id: "\(mapID)-\(date.timeIntervalSinceReferenceDate)") {
            guard let (lat, lon) = coordinate else { return }
            history = await HourlyHistory.load(latitude: lat, longitude: lon, from: date.addingTimeInterval(-48 * 3600), to: date)
        }
        .onAppear {
            #if DEBUG
            // `-railOpen`: the rail held open on weed pollen, for screenshots.
            if ProcessInfo.processInfo.arguments.contains("-railOpen"), !sketch {
                expanded = true
                // `-railOpen particles` / `body` / `voice`: open on that row instead.
                let args = ProcessInfo.processInfo.arguments
                let next = args.firstIndex(of: "-railOpen").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
                let target: RailRow = switch next {
                case "particles": .header(.particles)
                case "body": .body
                case "voice": .voice
                default: .item("Weed pollen")
                }
                Task { try? await Task.sleep(for: .seconds(1.5)); select(target); if target.isSelf { pinned = target; row = nil } }
            }
            #endif
            guard !isPast, !sketch, !reduceMotionEnv else { return }
            withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) { pinPulse = true }
        }
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

    /// Hold the rail: it opens (every group with its items' dots) and stays put while you slide; let go and it
    /// folds. Letting go on Self opens your words and activity.
    private func scrub(_ size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                if !probing {
                    probing = true; touched = true; startPulse()
                    if !expanded {
                        // Which stop is under the thumb now, and where it will be once the rail opens.
                        let closed = RailRow.rows(expanded: false, layers: layers, includesSelf: showsSelf)
                        let cm = RailRow.mids(closed).map { CGFloat($0) * size.height }
                        let i = cm.enumerated().min { abs($0.element - drag.location.y) < abs($1.element - drag.location.y) }?.offset ?? 0
                        let opened = RailRow.rows(expanded: true, layers: layers, includesSelf: showsSelf)
                        let om = RailRow.mids(opened).map { CGFloat($0) * size.height }
                        if let j = opened.firstIndex(of: closed[i]), let first = om.first, let last = om.last {
                            let wanted = cm[i] - om[j]
                            railShift = min(max(wanted, 44 - first), size.height - 44 - last)
                        }
                    }
                    withAnimation(.snappy(duration: 0.25)) { expanded = true }
                }
                railFinger = drag.location.y
                // How far the thumb has slid off the rail toward the sky (the rail column is 64 pt wide).
                let inward = railLeft ? drag.location.x - 32 : 32 - drag.location.x
                // On Voice, slide sideways into its panel to record; slide back out to cancel.
                if row == .voice || voice.phase == .recording {
                    if voice.phase == .idle && inward > 72 {
                        stopPulse()
                        Task { await voice.start() }
                        return
                    }
                    if voice.phase == .recording {
                        if inward < 28 { voice.cancel(); UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                        return   // recording: the rail holds still on Voice
                    }
                }
                let rows = RailRow.rows(expanded: true, layers: layers, includesSelf: showsSelf)
                let mids = RailRow.mids(rows).map { CGFloat($0) * size.height + railShift }
                // Slid off the bottom (past Body): nothing is read, and letting go puts the rail back as it was.
                if let last = mids.last, drag.location.y > last + 40 {
                    if row != nil { row = nil; probe = nil; UISelectionFeedbackGenerator().selectionChanged() }
                    return
                }
                let nearest = mids.enumerated().min { abs($0.element - drag.location.y) < abs($1.element - drag.location.y) }?.offset ?? 0
                if rows[nearest] != row { select(rows[nearest]) }
            }
            .onEnded { _ in
                stopPulse()
                railFinger = nil
                // Lift while recording: stop, write it down, review.
                if voice.phase == .recording { Task { await voice.finish() } }
                // Voice and Body stay open where you let go, the rail with them; the air's close.
                let keep = (row?.isSelf ?? false) ? row : nil
                withAnimation(.easeOut(duration: 0.25)) { probe = nil; row = nil; pinned = keep; expanded = keep != nil; if keep == nil { railShift = 0 } }
                probing = false
            }
    }

    /// The layer the particle field lights: the item read, or a group's strongest item.
    private func selectedLayer(_ stack: [AirLayers.Layer]) -> Int? {
        let name: String? = switch row {
        case .item(let n)?: n
        case .header(let g)?: worstItem(g)
        default: nil
        }
        return name.flatMap { n in stack.firstIndex { ($0.name == "Air" ? "PM2.5" : $0.name) == n } }
    }

    private func worstItem(_ g: RailGroup) -> String? {
        let present = layers.readable.filter { g.items.contains($0.name == "Air" ? "PM2.5" : $0.name) && !$0.empty }
        return present.max { (Double($0.level.rawValue) + $0.fraction) < (Double($1.level.rawValue) + $1.fraction) }
            .map { $0.name == "Air" ? "PM2.5" : $0.name }
    }

    private func select(_ r: RailRow) {
        UISelectionFeedbackGenerator().selectionChanged()
        var p: SkyProbe?
        switch r {
        case .header(.weather):
            p = SkyExplorer.strata(at: 0, layers: layers, conditions: conditions, weave: weave, temperatureF: temperature, pollen: pollen)?.probe
        case .header(let g):
            // A group reads as its strongest item, named as the group.
            if let n = worstItem(g) ?? g.items.first, var q = SkyExplorer.layerProbe(n, layers: layers, conditions: conditions, pollen: pollen) {
                q.kind = "\(g.title) · most now: \(n)"
                p = q
            }
        case .item(let n):
            p = SkyExplorer.layerProbe(n, layers: layers, conditions: conditions, pollen: pollen)
        case .voice, .body:
            p = nil   // Self's panels read themselves.
        }
        if var probe = p, let h = history {
            switch probe.name {
            case "Weather":
                probe.lines = [SparkSeries(name: "Temperature", unit: "°", points: h.temperature, ink: .white),
                               SparkSeries(name: "Humidity", unit: "%", points: h.humidity, ink: Color(red: 0.55, green: 0.7, blue: 0.95))]
                    .filter { $0.points.count > 1 }
            case "PM2.5", "Air":
                probe.lines = h.pm25.count > 1 ? [SparkSeries(name: "PM2.5", unit: "", points: h.pm25, ink: WeatherColor.pm25)] : []
            default: break
            }
            p = probe
        }
        withAnimation(.snappy(duration: 0.2)) { row = r; probe = p }
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
    /// Now breathes; the past is still.
    var breathes = true
    /// The future drifts, more the further out: 0 still … 3 restless.
    var drift: CGFloat = 0
    /// How the reveal moves: the past closes in onto the pin (it happened, it settles), now rings out from
    /// it, the future washes in wide and soft (not yet known).
    enum Reveal { case inward, outward, soft }
    var reveal: Reveal = .outward
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
        let seconds = rippleInk != .white ? 2.2 : reveal == .soft ? 2.6 : reveal == .inward ? 1.4 : rippleSeconds
        let wave = (animated && !reduceMotion && age < seconds) ? age / seconds : nil
        // Every new sky is revealed by its first ripple: no particles until the ring has passed. Later
        // "touch me" ripples run over a sky that's already there.
        let firstPass = rippleAt.map { time.timeIntervalSince($0) < seconds } ?? false

        let clock = (animated && !reduceMotion) ? time.timeIntervalSinceReferenceDate : 0
        let breath = breathes ? clock : 0
        // Odds per layer: a floor so any present layer shows, rising with amount; capped so the map shows.
        var weights = particles.map { $0.1 > 0 ? 0.012 + 0.09 * $0.1 : 0 }
        let total = weights.reduce(0, +)
        if total > 0.3 { weights = weights.map { $0 * 0.3 / total } }
        let cumulative = weights.reduce(into: [Double]()) { $0.append(($0.last ?? 0) + $1) }
        return Canvas(rendersAsynchronously: true) { ctx, size in
            // Every ripple starts at the pin: the place, then the air around it.
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let reach = hypot(size.width, size.height) * 0.6
            let radius = wave.map { reveal == .inward ? reach * (1 - CGFloat($0)) : CGFloat($0) * reach }
            let fade = wave.map { scan && firstPass ? 1 : 1 - $0 } ?? 0
            let cols = Int(size.width / spacing) + 1, rows = Int(size.height / spacing) + 1
            for i in 0..<cols {
                for j in 0..<rows {
                    var h = UInt32(truncatingIfNeeded: i &* 73856093 ^ j &* 19349663)
                    h = (h ^ (h >> 13)) &* 1274126177
                    let u = Double(h & 0xFFFF) / 65535, jx = Double((h >> 16) & 0xFF) / 255, jy = Double((h >> 24) & 0xFF) / 255
                    var x = (CGFloat(i) + 0.2 + 0.6 * jx) * spacing, y = (CGFloat(j) + 0.2 + 0.6 * jy) * spacing
                    if drift > 0, clock > 0 {
                        // Not yet settled: each dot wanders on its own slow path.
                        x += drift * 1.6 * CGFloat(sin(clock * 0.5 + jx * 6.3))
                        y += drift * 1.6 * CGFloat(cos(clock * 0.43 + jy * 6.3))
                    }
                    let k = cumulative.firstIndex { u < $0 }
                    let dist = hypot(x - centre.x, y - centre.y)
                    // The scan: nothing exists ahead of the ring yet.
                    // The ring runs ahead over bare grain; inside it, the air fills in, growing up just behind the front.
                    var emerge = 1.0
                    if scan, firstPass, k != nil, let radius {
                        // Behind the front: inside it when it rings out, outside it when it closes in.
                        let behind = reveal == .inward ? Double(dist - radius) : Double(radius - dist) * (reveal == .soft ? 0.5 : 1)
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
                        let width = reveal == .soft ? 110.0 : scan ? 44.0 : 36.0
                        if d < width {
                            let t = (1 - d / width) * fade * (reveal == .soft ? 0.45 : 1)
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
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Room kept at one end of the top line for controls floating over that corner.
    @Environment(\.cornerInset) private var corner
    /// Tapping a sentence with a sparkle opens the key (the one-time tip, again on demand).
    @State private var showKey = false
    @State private var breath = false
    private var hasMark: Bool { TheRead.Mark.allCases.contains { title.contains($0.rawValue) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // The context line: tag, place, and the verdict (the place gives way first).
            HStack(spacing: 8) {
                if let tag { MomentTag(moment: tag) }
                place.layoutPriority(0)
                if verdict != nil { verdictPill.layoutPriority(1) }
            }
            .frame(minHeight: 30, alignment: .leading)
            .padding(Edge.Set(corner.0), max(0, corner.1 - 20))
            // Instant while scrubbing; one short crossfade in place when you land. No roll, scale or blur.
            // Never cut: the sentence takes the lines it needs and the sky gives up the room.
            // Blurs between readings instead of cutting (the same as ScaleHeader), once the playhead has landed.
            // Three lines at most: a long sentence sets a step smaller (26 → 23 → 20) rather than running on.
            // A step smaller again at accessibility sizes.
            let plain = TheRead.spoken(title).count
            let size: CGFloat = plain > 100 ? 20 : plain > 78 ? 23 : 26
            let font = Theme.Typeface.sentence(size: typeSize.isAccessibilitySize ? size - 4 : size)
            ZStack(alignment: .topLeading) {
                Group {
                    if hasMark {
                        // The sparkle is its own view, so the key's arrow points at it.
                        MarkedSentence(text: title, font: font, showKey: $showKey)
                    } else {
                        Text(title).font(font).kerning(Theme.serifKerning)
                            .lineLimit(3).minimumScaleFactor(0.85)
                    }
                }
                    .fixedSize(horizontal: false, vertical: true)
                    .shimmer(title.hasSuffix("…"))
                    .id(title)
                    .transition(reduceMotion || !settled ? AnyTransition.opacity : AnyTransition(.blurReplace))
            }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(TheRead.spoken(title))
                .animation(settled ? .easeInOut(duration: 0.26) : nil, value: title)
            if let when {
                Label(when, systemImage: "clock")
                    .font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .animation(settled ? .easeInOut(duration: 0.22) : nil, value: tint)
    }
}

/// A sentence that ends in felt air's sparkle, laid out word by word so the sparkle is a view of its own:
/// tap it for the key, and the popover's arrow points at it. A word joined to the mark by a non-breaking
/// space stays on the mark's line.
struct MarkedSentence: View {
    let text: String
    let font: Font
    @Binding var showKey: Bool

    var body: some View {
        let tokens = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        FlowLayout(spacing: 7, lineSpacing: -2) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, tok in
                if let (word, mark) = Self.split(tok) {
                    HStack(spacing: 7) {
                        if !word.isEmpty { Text(word).font(font).kerning(Theme.serifKerning) }
                        Image(systemName: mark == .often ? "sparkles" : "sparkle")
                            .font(.title3).foregroundStyle(.secondary)
                            .padding(6).contentShape(Rectangle())
                            .onTapGesture { SparkleTip().invalidate(reason: .actionPerformed); showKey = true }
                            .popover(isPresented: $showKey, arrowEdge: .top) { SparkleKey() }
                            .accessibilityLabel(mark.words)
                            .accessibilityAddTraits(.isButton)
                    }
                } else {
                    Text(tok).font(font).kerning(Theme.serifKerning)
                }
            }
        }
    }

    /// "there.\u{00A0}✦" → ("there.", .sometimes); nil for a plain word.
    static func split(_ tok: String) -> (String, TheRead.Mark)? {
        for m in TheRead.Mark.allCases where tok.contains(m.rawValue) {
            let word = tok.replacingOccurrences(of: m.rawValue, with: "").replacingOccurrences(of: "\u{00A0}", with: "")
            return (word, m)
        }
        return nil
    }
}

/// The key to the sparkle, as a popover: the marks and what they stand for.
struct SparkleKey: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Shows up on your flare days", systemImage: "sparkles").font(Theme.Typeface.sentence(size: 17))
            SparkleTip.key.font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 300, alignment: .leading)
        .presentationCompactAdaptation(.popover)
    }
}

extension VerdictHeader {
    /// The sentence with felt air's marks drawn as sparkles: two for "often shows up on your flare days",
    /// one for "sometimes". Quieter than the words, so the fact leads.
    static func marked(_ s: String) -> Text {
        var out = Text(verbatim: "")
        var run = ""
        for ch in s {
            if let mark = TheRead.Mark(rawValue: String(ch)) {
                let icon = Text(Image(systemName: mark == .often ? "sparkles" : "sparkle")).font(.title3).foregroundStyle(.secondary)
                out = Text("\(out)\(Text(verbatim: run))\(icon)")
                run = ""
            } else {
                run.append(ch)
            }
        }
        return Text("\(out)\(Text(verbatim: run))")
    }

    /// How this time compares with your days, as a pill; tap for Insights.
    var verdictPill: some View {
        let ink = tint ?? Theme.secondaryText
        return Button { onVerdict?() } label: {
            HStack(spacing: 6) {
                // The one state that asks for attention gets the only motion on the line: a slow breath.
                let matches = tint == Verdict.red
                Circle().fill(ink).frame(width: 7, height: 7)
                    .scaleEffect(matches && breath ? 1.35 : 1)
                    .animation(matches && !reduceMotion ? .easeInOut(duration: 1.6).repeatForever(autoreverses: true) : .default, value: breath)
                    .onChange(of: matches, initial: true) { _, m in breath = m && !reduceMotion }
                Text(verdict ?? " ").lineLimit(1).fixedSize()
                    .contentTransition(.opacity)
                    .animation(settled ? .easeInOut(duration: 0.22) : nil, value: verdict)
                if onVerdict != nil { Image(systemName: "chevron.right").font(.caption2.weight(.bold)).opacity(0.6) }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(ink.opacity(0.16)))
        }
        .buttonStyle(PressStyle())
        .disabled(onVerdict == nil)
    }
}

/// Where the finger dents the sky while you swipe it.
struct SkyDent: Equatable { var point: CGPoint; var press: CGFloat }
private struct SkyDentKey: EnvironmentKey { static let defaultValue: SkyDent? = nil }
private struct SkySettledKey: EnvironmentKey { static let defaultValue = true }
private struct CornerInsetKey: EnvironmentKey { static let defaultValue: (Edge, CGFloat) = (.trailing, 0) }
extension EnvironmentValues {
    var cornerInset: (Edge, CGFloat) {
        get { self[CornerInsetKey.self] }
        set { self[CornerInsetKey.self] = newValue }
    }
}

extension EnvironmentValues {
    var skyDent: SkyDent? {
        get { self[SkyDentKey.self] }
        set { self[SkyDentKey.self] = newValue }
    }

    /// Whether the timeline has come to rest (skies ripple only then).
    var skySettled: Bool {
        get { self[SkySettledKey.self] }
        set { self[SkySettledKey.self] = newValue }
    }
}

/// Weather that changes the air. Shown across the whole field, with a chip in the header.
enum AirEvent: Equatable {
    case storm, smoke, tempDrop, mold

    /// The same event in the advice copy (AsthmaCore/Conditions/AirAdvice.swift).
    var advice: AirAdvice.Event {
        switch self {
        case .storm: .stormPollen
        case .smoke: .smoke
        case .tempDrop: .tempDrop
        case .mold: .mold
        }
    }

    var icon: String {
        switch self {
        case .storm: Icons.storm
        case .smoke: Icons.smoke
        case .tempDrop: Icons.tempDrop
        case .mold: Icons.mold
        }
    }

    var label: String {
        switch self {
        case .storm: "Storm and pollen"
        case .smoke: "Wildfire smoke"
        case .tempDrop: "Temperature drop"
        case .mold: "Damp air"
        }
    }

    /// Plain facts, never a cause: "A thunderstorm while pollen is high."
    func sentence(temperature: Double?, fallF: Double?) -> String {
        let t = temperature.map { "It's \(Int($0.rounded()))°" }
        switch self {
        case .storm: return "A thunderstorm while pollen is high."
        case .smoke: return [t, "and there's wildfire smoke in the air."].compactMap { $0 }.joined(separator: ", ")
        case .tempDrop:
            let fall = fallF.map { "down \(Int($0.rounded()))° in three hours." } ?? "and getting colder fast."
            return [t, fall].compactMap { $0 }.joined(separator: ", ")
        case .mold: return [t, "rainy and humid."].compactMap { $0 }.joined(separator: ", ")
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

/// What sits under the header at each time (docs/design/header-ia.md).
enum HeaderCard: Identifiable {
    /// Advice for Now or Ahead: staying put or going out.
    case advice(AirAdvice.Warning, icon: String, title: String, home: Bool, ahead: Bool)
    /// Just logged: say what's going on.
    case capture(LogEvent)

    var id: String {
        switch self {
        case .advice(_, _, let title, _, _): "advice-\(title)"
        case .capture(let e): "capture-\(e.id)"
        }
    }
}

/// Several cards true at once: a row you swipe through, the next one peeking in, with page dots.
/// The cards as a stack, like the Watch's: the one that matters most in front, the next peeking out above
/// it, all the same height (the stack is as tall as its tallest card). Swipe up to bring the next one forward,
/// down to go back, or tap the peek. One card: just the card.
struct CardStack<Content: View>: View {
    let cards: [HeaderCard]
    @ViewBuilder let content: (HeaderCard) -> Content
    @State private var front = 0
    @State private var drag: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let n = cards.count
        VStack(spacing: 8) {
            ZStack(alignment: .top) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { i, c in
                    // 0 = in front, 1 = next, 2 = the one behind that.
                    let k = (i - front + n) % n
                    let depth = min(k, 2)
                    content(c)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .scaleEffect(1 - 0.05 * CGFloat(depth), anchor: .top)
                        .offset(y: -10 * CGFloat(depth) + (k == 0 ? drag * 0.3 : 0))
                        .opacity(depth == 0 ? 1 : depth == 1 ? 0.55 : 0.3)
                        .zIndex(Double(n - k))
                        .allowsHitTesting(k == 0)
                        .accessibilityHidden(k != 0)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, n > 1 ? 18 : 0)   // room for the peeks
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
            .gesture(n > 1 ? swipe : nil)
            .animation(reduceMotion ? nil : Theme.lift, value: front)
            .animation(reduceMotion ? nil : Theme.snap, value: drag)
            .sensoryFeedback(.selection, trigger: front)
            if n > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<n, id: \.self) { i in
                        Circle().fill(Color.primary.opacity(i == front ? 0.9 : 0.25)).frame(width: 6, height: 6)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel("\(n) cards, \(front + 1) in front")
                .accessibilityAdjustableAction { dir in step(dir == .increment ? 1 : -1) }
            }
        }
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { drag = $0.translation.height }
            .onEnded { v in
                drag = 0
                if v.translation.height < -30 || v.predictedEndTranslation.height < -80 { step(1) }
                else if v.translation.height > 30 || v.predictedEndTranslation.height > 80 { step(-1) }
            }
    }

    private func step(_ by: Int) {
        let n = cards.count
        front = ((front + by) % n + n) % n
    }
}

/// What to do about the air, for where you are: staying put at Home, going out anywhere else (tap to see the
/// other). Ahead, it's for planning. The advice is a provocation for provider conversations
/// (docs/air-advice.md); the "i" says it isn't medical advice.
struct AdviceCard: View {
    let warning: AirAdvice.Warning
    let icon: String
    let title: String
    let home: Bool
    var ahead = false
    @State private var picked: AirAdvice.Context?
    @State private var showNote = false

    var body: some View {
        let context = picked ?? .at(home: home)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Label(ahead ? "Planning ahead · \(title)" : title, systemImage: icon)
                    .font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer(minLength: 4)
                Button { withAnimation(Theme.snap) { showNote.toggle() } } label: {
                    Image(systemName: "info.circle").font(.subheadline).foregroundStyle(Theme.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("About this suggestion")
            }
            HStack(spacing: 6) {
                ForEach(AirAdvice.Context.allCases, id: \.self) { c in
                    Button { withAnimation(Theme.snap) { picked = c } } label: {
                        Text(c.label).font(.caption.weight(.semibold))
                            .foregroundStyle(c == context ? Color.black : .primary)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(c == context ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.primary.opacity(0.12))))
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityAddTraits(c == context ? .isSelected : [])
                }
            }
            Text(warning.advice(context)).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
            if showNote {
                Text(AirAdvice.disclaimer).font(.caption2).foregroundStyle(Theme.secondaryText).transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Fills the height it's given, so cards in a stack are all one height.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}

/// Just logged, on Now: say what's going on, or tap what fits. The same choices as the Lock Screen card.
struct CaptureCard: View {
    let event: LogEvent
    let record: () -> Void
    /// Just logged: one quiet Undo, for a few seconds.
    var undo: (() -> Void)? = nil
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("Say it or tap it").font(.subheadline.weight(.semibold))
                    if let undo {
                        Button("Undo", action: undo)
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                            .buttonStyle(PressStyle())
                            .transition(.opacity)
                    }
                }
                .animation(Theme.smooth, value: undo == nil)
                FlowLayout(spacing: 6) {
                    ForEach([JournalTag.exercise, .coldAir, .pets, .smoke], id: \.self) { t in
                        let on = event.tags.contains(t)
                        Button { toggle(t) } label: {
                            Text(t.label).font(.caption.weight(.semibold))
                                .foregroundStyle(on ? Color.black : .primary)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Capsule().fill(on ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.primary.opacity(0.12))))
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
            Spacer(minLength: 0)
            Button(action: record) {
                Image(systemName: "mic.fill").font(.title3.weight(.semibold))
                    .frame(width: 56, height: 56)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Record a voice note")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Fills the height it's given, so cards in a stack are all one height.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private func toggle(_ t: JournalTag) {
        if event.tags.contains(t) { event.tags.remove(t) } else { event.tags.insert(t) }
        event.tagsReviewed = true
        try? context.save()
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

