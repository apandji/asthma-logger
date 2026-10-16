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

    @State private var here: NowReading?
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
                sky
                    .frame(maxHeight: .infinity)
                    .padding(.top, 4)
                NowTimeline(moments: moments, hours: hours, focusTime: $focusTime)
                    .frame(height: 104)
                    .padding(.bottom, 84)  // clear the +
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.black.ignoresSafeArea())
            .overlay(alignment: .bottom) {
                CaptureBar(showInsights: $showInsights, tip: tips.currentTip as? PullToLogTip, toast: $toast)
            }
            .overlay(alignment: .topTrailing) { rail }
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
            .task(id: events.count) {
                try? await Task.sleep(for: .seconds(1.2))
                guard !Task.isCancelled else { return }
                model.rebuild(events: events, demo: demo)
                await model.narrate(styleScore: 50, useModel: false)
                if let here { await model.loadForecast(latitude: here.lat, longitude: here.lon, placeLabel: here.place ?? "here") }
            }
            // A new moment brings the playhead back to now.
            .onChange(of: events.last?.id) { _, _ in withAnimation(.smooth(duration: 0.6)) { focusTime = nil } }
        }
    }

    // MARK: What the playhead is on

    private enum Focus { case now, moment(LogEvent), hour(NowHour), gap(Date) }

    private var focus: Focus {
        guard let t = focusTime else { return .now }
        if let m = moments.min(by: { abs($0.loggedAt.timeIntervalSince(t)) < abs($1.loggedAt.timeIntervalSince(t)) }),
           abs(m.loggedAt.timeIntervalSince(t)) < 20 * 60 { return .moment(m) }
        if t > .now, let h = hours.min(by: { abs($0.date.timeIntervalSince(t)) < abs($1.date.timeIntervalSince(t)) }) { return .hour(h) }
        if abs(t.timeIntervalSinceNow) < 30 * 60 { return .now }
        return .gap(t)
    }

    // MARK: Header

    private var header: some View {
        Group {
            switch focus {
            case .now:
                ScaleHeader(title: sentence, reserveTwoLines: true) {
                    Circle().fill(.white).frame(width: 8, height: 8)
                    Text(["Now", here?.place].compactMap { $0 }.joined(separator: " · "))
                }
                .onTapGesture { showInsights = true }
            case .moment(let m):
                ScaleHeader(title: m.statement, reserveTwoLines: true) {
                    MomentDot(moment: m.moment, size: 8)
                    Text(m.detailsLine)
                }
            case .hour(let h):
                ScaleHeader(title: h.statement, reserveTwoLines: true) {
                    Image(systemName: "arrow.right").font(.caption2.weight(.bold))
                    Text("Forecast · \(h.date.formatted(.dateTime.weekday(.abbreviated).hour()))\(here?.place.map { " · \($0)" } ?? "")")
                }
            case .gap(let t):
                ScaleHeader(title: "Nothing logged.", reserveTwoLines: true) {
                    Text(t.formatted(.dateTime.weekday(.abbreviated).hour()))
                    Text("· no reading for this hour")
                }
            }
        }
        .padding(.top, 2)
        .animation(.easeInOut(duration: 0.25), value: focusTime)
    }

    /// The one sentence. Never a percent, never "attack", never a cause.
    private var sentence: String {
        if let window = model.days.flatMap(\.windows).first(where: { $0.end > .now && $0.start < Date.now.addingTimeInterval(48 * 3600) }) {
            return "\(Self.when(window.start)) looks more like your rescue days than your usual ones."
        }
        if let today = model.days.first, today.isPersonal {
            switch today.band {
            case .quiet: return "Today looks quieter than your usual days."
            case .usual, .elevated: return "Today looks like your usual days."
            }
        }
        if let p = model.progress, !p.isMet {
            let needRescue = max(0, p.minAttacks - p.attacks), needCalm = max(0, p.minBaselines - p.baselines)
            var parts: [String] = []
            if needRescue > 0 { parts.append("\(needRescue) more rescue moment\(needRescue == 1 ? "" : "s")") }
            if needCalm > 0 { parts.append("\(needCalm) more calm day\(needCalm == 1 ? "" : "s")") }
            return parts.joined(separator: " and ").prefix(1).uppercased() + parts.joined(separator: " and ").dropFirst() + " before felt air can compare."
        }
        if let here { return here.statement }
        return "Checking the air near you…"
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
            NowSky(conditions: here?.conditions, weave: here?.weave ?? WeaveSpec(), date: .now,
                   pollen: DemoPollen.sample(at: .now, season: pollenSeason), probing: $probing)
                .onTapGesture { openDay = Calendar.current.startOfDay(for: .now) }
        case .moment(let m):
            NowSky(conditions: m.conditions, weave: m.weave, date: m.loggedAt,
                   pollen: DemoPollen.sample(at: m.loggedAt, season: pollenSeason), probing: $probing)
                .id(m.id)
                .onTapGesture { openDay = Calendar.current.startOfDay(for: m.loggedAt) }
        case .hour(let h):
            NowSky(conditions: h.conditions, weave: h.weave, date: h.date,
                   pollen: DemoPollen.sample(at: h.date, season: pollenSeason), probing: $probing)
                .id(h.date)
        case .gap(let t):
            NowSky(conditions: nil, weave: WeaveSpec(), date: t, pollen: nil, probing: $probing)
                .opacity(0.35)
                .onTapGesture { openDay = Calendar.current.startOfDay(for: t) }
        }
    }

    // MARK: Right edge

    private var rail: some View {
        VStack(spacing: 10) {
            Button { showMonth = true } label: { railIcon("calendar") }.accessibilityLabel("Month")
            Button { showSettings = true } label: { railIcon("gearshape") }.accessibilityLabel("Settings")
        }
        .buttonStyle(.plain)
        .padding(.trailing, JournalView.railAxis - 22)
        .padding(.top, 2)
    }

    private func railIcon(_ name: String) -> some View {
        Image(systemName: name).font(.body.weight(.semibold)).frame(width: 44, height: 44)
            .glassEffect(.regular.interactive(), in: .circle)
    }

    // MARK: Data

    private func load() async {
        guard let fix = try? await services.location.currentLocation(timeout: .seconds(6)) else { return }
        let lat = fix.coordinate.latitude, lon = fix.coordinate.longitude
        async let c = services.conditions.conditions(latitude: lat, longitude: lon)
        async let marks = try? CLGeocoder().reverseGeocodeLocation(fix)
        let place = await marks?.first.map { [$0.locality ?? $0.subAdministrativeArea, $0.administrativeArea].compactMap { $0 }.joined(separator: ", ") }
        here = NowReading(lat: lat, lon: lon, place: place, conditions: await c)
        hours = await NowHour.forecast(latitude: lat, longitude: lon)
        await model.loadForecast(latitude: lat, longitude: lon, placeLabel: place ?? "here")
    }
}

/// The air where you are, right now. Nothing is saved.
struct NowReading {
    let lat: Double, lon: Double
    let place: String?
    let conditions: Conditions
    var weave: WeaveSpec { WeaveSpec(conditions.input) }
    var statement: String {
        let temp = conditions.best(.temperature).map { "\(Int($0.value.rounded()))°" }
        let w = weave.words[.temperature]?.capitalized
        let air = weave.levels[.air].map { ["Good air", "OK air", "Not great air"][$0.rawValue] }
        return [[w, temp].compactMap { $0 }.joined(separator: ", "), air].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ") + "."
    }
}

/// One forecast hour, shown with the same sky as a logged moment. Apple Weather for temperature and
/// humidity; AirNow's daily category for PM2.5 and ozone, as a typical value for that category.
/// Every reading is labelled forecast and never enters a pattern.
struct NowHour: Identifiable, Sendable {
    let date: Date
    let conditions: Conditions
    var id: Date { date }
    var weave: WeaveSpec { WeaveSpec(conditions.input) }
    var statement: String {
        let temp = conditions.best(.temperature).map { "\(Int($0.value.rounded()))°" }
        let w = conditions.best(.humidity).map { $0.value >= 70 ? "humid" : $0.value <= 30 ? "dry" : "comfortable" }
        return [temp, w].compactMap { $0 }.joined(separator: " and ") + ", forecast."
    }

    static let source = "Forecast"
    /// Typical PM2.5 (µg/m³) and ozone (ppb) for each AirNow category, so the sky can color it.
    private static let pm25ByCategory: [Int: Double] = [1: 6, 2: 20, 3: 45, 4: 80, 5: 200, 6: 300]
    private static let ozoneByCategory: [Int: Double] = [1: 35, 2: 62, 3: 78, 4: 95, 5: 130, 6: 200]

    static func forecast(latitude: Double, longitude: Double) async -> [NowHour] {
        guard let hours = try? await WeatherProvider().hourly(latitude: latitude, longitude: longitude, hours: 48) else { return [] }
        var aq: [String: (pm25: Int?, ozone: Int?)] = [:]
        if let key = Secrets.airNow { aq = (try? await AirNowProvider(key: key).forecast(latitude: latitude, longitude: longitude)) ?? [:] }
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
            return NowHour(date: h.date, conditions: Conditions(observations: obs, fetchedAt: .now))
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
    @AppStorage(Crit.LayerStrength.key) private var strengthStyle = Crit.LayerStrength.smooth
    @State private var point: CGPoint?
    @State private var probe: SkyProbe?
    @State private var pulse: Task<Void, Never>?

    private var temperature: Double? { conditions?.best(.temperature)?.value }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                AmbientField(weave: weave, temperatureF: temperature, date: date, conditions: conditions, pollen: pollen)
                if let point, let probe {
                    SkyProbeOverlay(point: point, probe: probe, width: size.width, showsLabel: false).transition(.opacity)
                }
            }
            .frame(width: size.width, height: size.height)
            .drawingGroup()
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
                if !probing { probing = true; startPulse() }
                let unit = CGPoint(x: drag.location.x / size.width, y: drag.location.y / size.height)
                let layers = AirLayers(conditions: conditions, weave: weave, pollen: pollen, smooth: strengthStyle == .smooth)
                withAnimation(.easeOut(duration: 0.12)) {
                    point = drag.location
                    probe = SkyExplorer.probe(at: unit, layers: layers, conditions: conditions, weave: weave,
                                              temperatureF: temperature, pollen: pollen)
                }
            }
            .onEnded { _ in
                stopPulse()
                withAnimation(.easeOut(duration: 0.25)) { point = nil; probe = nil }
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
