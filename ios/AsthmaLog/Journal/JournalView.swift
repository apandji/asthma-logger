import AsthmaCore
import CoreLocation
import SwiftData
import SwiftUI
import TipKit

/// The Journal: one moment at a time. The color field and the header follow the moment you're on
/// (swipe sideways between them; a new moment slides in as soon as it's logged, from the +, the felt
/// button or the watch). Pinch a moment open for everything about it; pinch in and the moments shrink
/// into dots on a calendar with the full list. Turn sideways for the Data view.
/// The ••• button top-right opens All moments and Settings.
struct JournalView: View {
    @Environment(LogService.self) private var services
    @Query(sort: \LogEvent.loggedAt) private var events: [LogEvent]
    @State private var selectedID: UUID?
    @State private var opened: LogEvent?
    @Namespace private var zoom
    @Namespace private var morph
    @Namespace private var mapZoom
    /// The zoom's anchor frames, and the flying copy of the sky that travels between them.
    @State private var anchorStore = AnchorFrames()
    @State private var flight: Flight?
    struct Flight: Equatable {
        let moment: LogEvent
        var rect: CGRect
        var radius: CGFloat
    }
    @State private var gaugeLabelVisible = false
    /// True while a finger is on the gauge: it widens and shows every level's name.
    @State private var gaugeActive = false
    /// The moment opened in place (panel style): the sky gives way to its map and details.
    @State private var expanded: LogEvent?
    @State private var overview = false
    /// The "days" scale of the zoom (gesture model B).
    @State private var showDays = ProcessInfo.processInfo.arguments.contains("-startDays")  // debug: open on Days
    @State private var zoomingIn = false
    @AppStorage(Crit.Gestures.key) private var gestures = Crit.Gestures.zoom
    /// First-use tips, one at a time: pull to log, then moments.
    @State private var tips = TipGroup(.ordered) { PullToLogTip(); MomentsTip(); SkyTip() }
    @State private var probePoint: CGPoint?
    @State private var probe: SkyProbe?
    @State private var fieldFrame: CGRect = .zero
    @State private var panelProbing = false
    @State private var spot = SpotlightFrames()
    @AppStorage(Crit.CardStyle.key) private var momentStyle = Crit.CardStyle.panel
    @State private var ambientFrame: CGRect = .zero
    @State private var showInsights = false
    @State private var showSettings = false
    @AppStorage(Crit.InsightsEntry.key) private var insightsEntry = Crit.InsightsEntry.ringButton
    @AppStorage(DemoPollen.Season.key) private var pollenSeason = DemoPollen.Season.off
    @AppStorage(Crit.Header.key) private var headerStyle = Crit.Header.moment

    private let days = 7

    var body: some View {
        NavigationStack {
            ambient
                // The + and Insights live on the home only, not on pushed pages.
                // The + and Insights stay put on every scale, over everything.
                .overlay(alignment: .bottom) {
                    CaptureBar(showInsights: $showInsights, tip: tips.currentTip as? PullToLogTip, spot: spot)
                }
                .overlay(alignment: .trailing) {
                    if insightsEntry == .edgeTab && !overview { InsightEdgeTab { showInsights = true } }
                }
                .overlay(alignment: .trailing) {
                    if gestures == .zoom && !cards.isEmpty { depthGauge }
                }
                // The flying sky: global coordinates, on top of everything, never part of layout.
                .overlay {
                    GeometryReader { _ in
                        if let f = flight {
                            AmbientField(weave: f.moment.weave, temperatureF: f.moment.conditions?.best(.temperature)?.value,
                                         date: f.moment.loggedAt, conditions: f.moment.conditions,
                                         pollen: DemoPollen.sample(at: f.moment.loggedAt, season: pollenSeason))
                                .frame(width: f.rect.width, height: f.rect.height)
                                .clipShape(.rect(cornerRadius: f.radius, style: .continuous))
                                .position(x: f.rect.midX, y: f.rect.midY)
                        }
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
                // Tutorial: dim everything the current tip isn't about.
                .overlay {
                    if expanded == nil && !overview && !showDays, let ids = spotlightIDs {
                        SpotlightDim(holes: ids.compactMap { spot.frames[$0] })
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: spotlightIDs)
                .sheet(isPresented: $showInsights) {
                    InsightsView()
                        .presentationDragIndicator(.visible)
                        .presentationBackground(.ultraThinMaterial)
                }
                .sheet(isPresented: $showSettings) { SettingsView() }
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: LogEvent.self) { EventDetailView(event: $0) }
                .navigationDestination(item: $opened) { e in
                    MomentDetailsView(event: e)
                        .navigationTransition(.zoom(sourceID: e.id, in: zoom))
                }
        }
        // A new moment (from anywhere) slides into view.
        .onChange(of: events.last?.id) { _, id in
            guard let id, let e = events.last, e.moment != .okay, Date().timeIntervalSince(e.loggedAt) < 120 else { return }
            withAnimation(.smooth(duration: 0.6)) {
                overview = false
                showDays = false
                selectedID = id
            }
        }
    }

    // MARK: Ambient

    private var ambient: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            Group {
                if overview {
                    MomentsOverview(events: Array(events), namespace: morph,
                                    anchorStore: gestures == .zoom ? anchorStore : nil, anchorHidden: flight != nil,
                                    anchorDay: selected?.loggedAt, anchorMoment: selected, open: { e in
                        withAnimation(.spring(duration: 0.55, bounce: 0.15)) { selectedID = e.id; overview = false; showDays = false }
                    }, close: { withAnimation(.spring(duration: 0.55, bounce: 0.15)) { overview = false } })
                } else if showDays {
                    DaysView(events: cards, selectedID: selected?.id, pollenSeason: pollenSeason,
                             anchorStore: gestures == .zoom ? anchorStore : nil, anchorHidden: flight != nil) { e in
                        zoomingIn = true
                        withAnimation(.spring(duration: 0.5, bounce: 0.12)) { selectedID = e.id; showDays = false }
                    }
                } else if let e = expanded {
                    MomentDetailsView(event: e, mapNamespace: mapZoom, onClose: collapse)
                } else {
                    momentLevel
                }
            }
            .id(levelKey)
            // Model B: the level follows the fingers (smaller and fainter pinching in, larger pinching out)
            // and the next one settles in from the opposite size.
            // Only the anchor moves between levels (shared geometry); everything else just fades.
            .transition(.opacity)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: levelKey)
            if let error = services.lastError {
                Text(error).font(.footnote).foregroundStyle(.orange).padding(.horizontal, 20).padding(.top, 8)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .simultaneousGesture(skyGesture, isEnabled: momentStyle != .panel)
        .overlay {
            if let probePoint, let probe {
                SkyProbeOverlay(point: CGPoint(x: probePoint.x - ambientFrame.minX, y: probePoint.y - ambientFrame.minY),
                                probe: probe, width: ambientFrame.width)
                    .transition(.opacity)
            }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { ambientFrame = $0 }
        .sensoryFeedback(.selection, trigger: probe?.name)
        .sensoryFeedback(.impact(weight: .light), trigger: probePoint == nil)

        .background {
            if momentStyle == .panel {
                // The sky lives in its panel; the page is black.
                Color.black.ignoresSafeArea()
            } else {
            // The room takes on the moment you're on.
            AmbientField(weave: fieldWeave,
                         temperatureF: selected?.conditions?.best(.temperature)?.value ?? now?.temp,
                         date: selected?.loggedAt ?? .now,
                         conditions: selected?.conditions,
                         pollen: DemoPollen.sample(at: selected?.loggedAt ?? .now, season: pollenSeason))
                .ignoresSafeArea()
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { fieldFrame = $0 }
                .animation(.easeInOut(duration: 0.8), value: selected?.id)
            }
        }
    }

    /// The moment scale: header, the moment's sky and the timeline.
    @ViewBuilder private var momentLevel: some View {
        VStack(alignment: .leading, spacing: 0) {
                header.transition(.opacity)
                    .opacity(probe == nil && !panelProbing ? 1 : 0.4)  // step aside while you explore the sky
                    .animation(.easeOut(duration: 0.2), value: probe == nil && !panelProbing)
                Spacer(minLength: 4)
                if cards.isEmpty {
                    emptyState.padding(.horizontal, 20)
                } else {
                    if momentStyle == .panel {
                        MomentPager(events: cards, selectedID: $selectedID, zoom: zoom, mapNamespace: mapZoom,
                                    pollenSeason: pollenSeason, onOpen: expand, onOverview: zoomOut, probing: $panelProbing,
                                    spot: spot, anchorStore: gestures == .zoom ? anchorStore : nil, anchorHidden: flight != nil,
                                    momentsTip: tips.currentTip as? MomentsTip, skyTip: tips.currentTip as? SkyTip)
                            .frame(maxHeight: 640)
                    } else {
                        MomentCarousel(events: cards, selectedID: $selectedID, namespace: zoom, morph: morph,
                                       onOverview: zoomOut) { opened = $0 }
                            .frame(height: 380)
                    }
                }
        }
        .padding(.bottom, 84)  // clear the + bar
    }

    private var levelKey: String {
        overview ? "month" : showDays ? "days" : expanded != nil ? "detail" : "moment"
    }

    /// Levels top to bottom on the gauge: widest view first.
    private static let levels = ["month", "days", "moment", "detail"]
    private static let levelNames = ["Month", "Days", "Moment", "Details"]
    private var levelIndex: Int { Self.levels.firstIndex(of: levelKey) ?? 2 }

    /// A depth gauge on the right: Month · Days · Moment · Details, top to bottom. Hold it and slide up
    /// or down to move through the levels (a haptic tick at each); tap a level to jump. Like the letter
    /// index at the side of Contacts.
    private var depthGauge: some View {
        let row: CGFloat = 34
        return VStack(alignment: .trailing, spacing: 0) {
            ForEach(0..<4, id: \.self) { i in
                let isCurrent = i == levelIndex
                HStack(spacing: 8) {
                    if gaugeActive || (gaugeLabelVisible && isCurrent) {
                        Text(Self.levelNames[i])
                            .font(.caption.weight(isCurrent ? .bold : .medium))
                            .foregroundStyle(isCurrent ? .black : .white.opacity(0.85))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(isCurrent ? AnyShapeStyle(.white) : AnyShapeStyle(.clear), in: Capsule())
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                    Circle()
                        .fill(.white.opacity(isCurrent ? 0.95 : 0.3))
                        .frame(width: isCurrent ? 10 : 6, height: isCurrent ? 10 : 6)
                        .frame(width: 18, height: row)
                }
                .frame(height: row)
                .accessibilityElement()
                .accessibilityLabel(Self.levelNames[i])
                .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
                .accessibilityAction { zoom(by: i - levelIndex) }
            }
        }
        .padding(.vertical, 8).padding(.leading, gaugeActive ? 10 : 6).padding(.trailing, 6)
        .background {
            if gaugeActive { Capsule().fill(.black.opacity(0.55)).overlay(Capsule().strokeBorder(.white.opacity(0.15))) }
        }
        .contentShape(Rectangle().inset(by: -16))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if !gaugeActive { withAnimation(.snappy(duration: 0.2)) { gaugeActive = true } }
                    let i = max(0, min(3, Int((v.location.y - 8) / row)))
                    if i != levelIndex { zoom(by: i - levelIndex) }
                }
                .onEnded { _ in withAnimation(.snappy(duration: 0.25)) { gaugeActive = false } }
        )
        .padding(.trailing, 8)
        .animation(.snappy(duration: 0.25), value: levelIndex)
        .animation(.easeOut(duration: 0.3), value: gaugeLabelVisible)
        .task(id: levelKey) {
            gaugeLabelVisible = true
            try? await Task.sleep(for: .seconds(1.2))
            gaugeLabelVisible = false
        }
    }

    /// Negative zooms out (detail → moment → days → month), positive zooms in; jumps several levels at once.
    /// Between Moment, Days and Month a copy of the current sky flies from the old anchor to the new one
    /// (drawn on top, so it never affects layout); Moment ⇄ Details uses the map's own zoom.
    private func zoom(by step: Int) {
        guard step != 0 else { return }
        zoomingIn = step > 0
        MomentsTip().invalidate(reason: .actionPerformed)
        let fromKey = levelKey
        let target = max(0, min(3, levelIndex + step))
        let toKey = Self.levels[target]
        let flies = gestures == .zoom && fromKey != "detail" && toKey != "detail"
        if flies, let m = selected, let from = anchorStore.frames[fromKey] {
            flight = Flight(moment: m, rect: from, radius: Self.anchorRadius(fromKey))
        }
        withAnimation(.smooth(duration: 0.45)) {
            overview = target == 0
            showDays = target == 1
            expanded = target == 3 ? selected : nil
        }
        guard flight != nil else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(50))   // let the new scale lay out and report its anchor
            if let to = anchorStore.frames[toKey] {
                withAnimation(.smooth(duration: 0.45)) {
                    flight?.rect = to
                    flight?.radius = Self.anchorRadius(toKey)
                }
                try? await Task.sleep(for: .milliseconds(470))
            }
            flight = nil
        }
    }

    private static func anchorRadius(_ key: String) -> CGFloat {
        switch key {
        case "moment": 36
        case "days": 20
        default: 10
        }
    }

    /// Touch and hold, then move: name whatever color is under the finger.
    private var skyGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                guard case .second(true, let drag?) = value, fieldFrame.width > 0 else { return }
                SkyTip().invalidate(reason: .actionPerformed)
                let unit = CGPoint(x: (drag.location.x - fieldFrame.minX) / fieldFrame.width,
                                   y: (drag.location.y - fieldFrame.minY) / fieldFrame.height)
                let pollen = DemoPollen.sample(at: selected?.loggedAt ?? .now, season: pollenSeason)
                let layers = AirLayers(conditions: selected?.conditions, weave: fieldWeave, pollen: pollen)
                withAnimation(.easeOut(duration: 0.15)) {
                    probePoint = drag.location
                    probe = SkyExplorer.probe(at: unit, layers: layers, conditions: selected?.conditions, weave: fieldWeave,
                                              temperatureF: selected?.conditions?.best(.temperature)?.value ?? now?.temp, pollen: pollen)
                }
            }
            .onEnded { _ in
                withAnimation(.easeOut(duration: 0.3)) { probePoint = nil; probe = nil }
            }
    }

    /// What the current tip points at (plus the inline tip itself, so it stays lit).
    private var spotlightIDs: [String]? {
        switch tips.currentTip {
        case is PullToLogTip: ["plus"]
        case is MomentsTip: ["track"]
        case is SkyTip: ["sky"]
        default: nil
        }
    }

    private func expand(_ e: LogEvent) {
        zoomingIn = true
        withAnimation(.spring(duration: 0.6, bounce: 0.12)) { expanded = e }
    }

    private func collapse() {
        zoomingIn = false
        withAnimation(.spring(duration: 0.55, bounce: 0.1)) { expanded = nil }
    }

    private func zoomOut() {
        MomentsTip().invalidate(reason: .actionPerformed)
        withAnimation(.spring(duration: 0.55, bounce: 0.15)) { overview = true }
    }

    /// A standard ••• menu, top right: All moments and Settings.
    private var topBar: some View {
        HStack {
            Spacer()
            Menu {
                Button(overview ? "Back to moments" : "All moments", systemImage: overview ? "rectangle.stack" : "calendar") {
                    overview ? withAnimation(.spring(duration: 0.55, bounce: 0.15)) { overview = false } : zoomOut()
                }
                Button("Settings", systemImage: "gearshape") { showSettings = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .accessibilityLabel("More")
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
    }

    private var fieldWeave: WeaveSpec {
        if headerStyle == .now || headerStyle == .nowWithCounts, selectedID == nil, let n = now { return n.weave }
        return selected.map { $0.weave.isEmpty ? todayWeave : $0.weave } ?? todayWeave
    }

    /// Every inhaler moment, oldest first (the newest starts in the middle). The row is your history;
    /// the calendar is for jumping around.
    private var cards: [LogEvent] {
        events.filter { $0.moment != .okay }
    }

    // MARK: Header

    @State private var now: (weave: WeaveSpec, temp: Double?, place: String?)?

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch headerStyle {
            case .moment:
                if let m = selected {
                    // The details line never moves: type, time and place on one line. The statement sits
                    // under it with two lines reserved, so a one- or two-line statement shifts nothing.
                    HStack(spacing: 7) {
                        MomentDot(moment: m.moment, size: 8)
                        Text([momentWhen(m), m.placeName].compactMap { $0 }.joined(separator: " · "))
                            .font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondaryText)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Text(m.weave.isEmpty ? "No air reading." : m.headline)
                        .font(.system(.title, design: .serif, weight: .medium))
                        .lineLimit(2, reservesSpace: true)
                        .minimumScaleFactor(0.85)
                        .contentTransition(.opacity)
                } else {
                    nowLines
                }
            case .now, .nowWithCounts:
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondaryText)
                nowLines
                if headerStyle == .nowWithCounts {
                    HStack(spacing: 10) {
                        stat(count(.rescue), "Rescue", Theme.rescue)
                        stat(count(.maintenance), "Standard", Theme.standard)
                    }
                    .padding(.top, 4)
                }
            case .lastMoment:
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondaryText)
                Text(lastSentence)
                    .font(.system(.title, design: .serif, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    stat(count(.rescue), "Rescue", Theme.rescue)
                    stat(count(.maintenance), "Standard", Theme.standard)
                }
            case .dateOnly:
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .animation(.easeInOut(duration: 0.35), value: selected?.id)
        // Only the "right now" headers need a live reading; don't spend launch on it otherwise.
        .task(id: headerStyle) { if headerStyle == .now || headerStyle == .nowWithCounts || cards.isEmpty { await loadNow() } }
    }

    @ViewBuilder private var nowLines: some View {
        if let now, let sentence = nowSentence(now.weave) {
            Text(sentence)
                .font(.system(.title, design: .serif, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
            if let detail = nowDetail(now) {
                Text(detail).font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
        }
    }

    /// "Rescue · Yesterday, 7:55 AM"
    private func momentWhen(_ m: LogEvent) -> String {
        let cal = Calendar.current
        let time = m.loggedAt.formatted(date: .omitted, time: .shortened)
        let day = cal.isDateInToday(m.loggedAt) ? "Today" : cal.isDateInYesterday(m.loggedAt) ? "Yesterday"
            : m.loggedAt.formatted(.dateTime.weekday(.abbreviated))
        let kind = m.moment == .rescue ? "Rescue" : m.moment == .maintenance ? "Standard" : "I'm okay"
        return "\(kind) · \(day), \(time)"
    }

    /// "The air is good right now." Present tense, outdoor, no number.
    private func nowSentence(_ w: WeaveSpec) -> String? {
        guard let air = w.levels[.air] else { return nil }
        return ["The air is good right now.", "The air is OK right now.", "The air isn't great right now."][air.rawValue]
    }

    /// "65° and comfortable · University City, MO"
    private func nowDetail(_ n: (weave: WeaveSpec, temp: Double?, place: String?)) -> String? {
        var parts: [String] = []
        var feel: [String] = []
        if let t = n.temp { feel.append("\(Int(t.rounded()))°") }
        if let h = n.weave.words[.humidity] { feel.append(h) }
        if !feel.isEmpty { parts.append(feel.joined(separator: " and ")) }
        if let p = n.place { parts.append(p) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The air where you are now, for the header only (nothing is saved).
    private func loadNow() async {
        guard now == nil, let fix = try? await services.location.currentLocation(timeout: .seconds(6)) else { return }
        let c = await services.conditions.conditions(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude)
        let marks = try? await CLGeocoder().reverseGeocodeLocation(fix)
        let place = marks?.first.map { [$0.locality ?? $0.subAdministrativeArea, $0.administrativeArea].compactMap { $0 }.joined(separator: ", ") }
        now = (WeaveSpec(c.input), c.best(.temperature)?.value, place)
    }

    /// The old header: the latest moment's air.
    private var lastSentence: String {
        guard let latest = events.last(where: { !$0.weave.isEmpty }) else { return "Nothing logged yet." }
        let line = latest.airLine
        return Calendar.current.isDateInToday(latest.loggedAt) ? line : "Last time: " + line.prefix(1).lowercased() + line.dropFirst()
    }

    /// Today's air for the ambient field: the latest moment today with a reading, else the latest one.
    private var todayWeave: WeaveSpec {
        let today = events.last { Calendar.current.isDateInToday($0.loggedAt) && !$0.weave.isEmpty }
        return (today ?? events.last { !$0.weave.isEmpty })?.weave ?? now?.weave ?? WeaveSpec()
    }

    private func count(_ kind: MomentKind) -> Int {
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: .now))!
        return events.filter { $0.loggedAt >= start && $0.moment == kind }.count
    }

    private func stat(_ n: Int, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(n)").font(.headline.monospacedDigit())
            Text(label).font(.subheadline).foregroundStyle(Theme.secondaryText)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(n) \(label.lowercased()) this week")
    }

    private var emptyState: some View {
        Text("Pull up on + to log. The felt button and Apple Watch work too.")
            .font(.subheadline)
            .foregroundStyle(Theme.secondaryText)
    }

    // MARK: Data

    private var selected: LogEvent? {
        if let id = selectedID, let e = events.first(where: { $0.id == id }) { return e }
        return cards.last ?? events.last { !$0.weave.isEmpty } ?? events.last
    }
}

/// Orange dot = rescue, blue dot = standard, open ring = I'm okay. Same colors as the watch.
struct MomentDot: View {
    let moment: MomentKind
    var size: CGFloat = 10
    @Environment(\.accessibilityDifferentiateWithoutColor) private var noColor

    var body: some View {
        switch moment {
        case .rescue: Circle().fill(Theme.rescue).frame(width: size, height: size)
        case .maintenance:
            // With Differentiate Without Color, standard doses are squares, not just blue.
            RoundedRectangle(cornerRadius: noColor ? size * 0.15 : size / 2).fill(Theme.standard).frame(width: size, height: size)
        case .okay: Circle().strokeBorder(Theme.secondaryText, lineWidth: max(1.5, size / 5)).frame(width: size, height: size)
        }
    }
}

// MARK: - Selected moment

/// The selected moment in plain iOS: kind, time, the weave in words, and every outdoor value with its source.
struct MomentCard: View {
    let event: LogEvent
    var showsChevron = true
    @AppStorage(LevelStyle.key) private var style = LevelStyle.signal

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        MomentDot(moment: event.moment, size: 9)
                        Text(event.moment.title).font(.headline)
                    }
                    Text(event.loggedAt.formatted(.dateTime.weekday(.wide).hour().minute()))
                        .font(.subheadline).foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                if showsChevron {
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
            }
            .padding(.bottom, 12)

            if let c = event.conditions, !c.observations.isEmpty {
                Divider()
                factorRow(.air, "Air quality", value: airValue(c))
                Divider().padding(.leading, 40)
                factorRow(.humidity, "Humidity", value: c.best(.humidity).map { "\(Int($0.value.rounded()))%" })
                Divider().padding(.leading, 40)
                factorRow(.temperature, "Temperature", value: c.best(.temperature).map { "\(Int($0.value.rounded()))°F" })
                Divider().padding(.leading, 40)
                factorRow(.pollen, "Pollen", value: nil)
                Divider()
                Text("Outdoors near you · \(sourceLine(c))")
                    .font(.caption).foregroundStyle(Theme.secondaryText)
                    .padding(.top, 12)
            } else if let err = event.envError {
                Divider()
                Text(err).font(.footnote).foregroundStyle(Theme.secondaryText).padding(.top, 12)
            } else if event.envStatus == .pending {
                Divider()
                Text("Checking the air…").font(.footnote).foregroundStyle(Theme.secondaryText).padding(.top, 12)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frostedCard()
        .contentShape(.rect(cornerRadius: 22))
    }

    /// One condition: its tier as a small graphic (style from Settings), the name, Good / OK / Not good,
    /// and the plain word with the reading underneath.
    private func factorRow(_ f: WeaveSpec.Factor, _ name: String, value: String?) -> some View {
        let level = event.weave.levels[f]
        // Air shows its plain word under the tier; weather shows just the reading.
        let detail = [Tier.isJudged(f) ? event.weave.words[f].map { $0.prefix(1).uppercased() + $0.dropFirst() } : nil, value]
            .compactMap { $0 }.joined(separator: " · ")
        return HStack(spacing: 12) {
            LevelIndicator(level: level, ink: WeaveSwatch.ink(f), style: style)
                .frame(minWidth: 30)
            Text(name)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                if style != .word || level == nil || !Tier.isJudged(f) {
                    Text(Tier.label(f, event.weave) ?? (f == .pollen ? "Not yet" : "No reading"))
                        .foregroundStyle(level == nil ? Theme.secondaryText : .primary)
                }
                if !detail.isEmpty {
                    Text(detail).font(.caption.monospacedDigit()).foregroundStyle(Theme.secondaryText)
                }
            }
        }
        .font(.subheadline)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }

    private func airValue(_ c: Conditions) -> String? {
        if let pm = c.best(.pm25) { return "PM2.5 \(Int(pm.value.rounded()))" }
        if let aqi = c.best(.aqi) { return "AQI \(Int(aqi.value))" }
        if let o3 = c.best(.ozone) { return "O₃ \(Int(o3.value.rounded()))" }
        return nil
    }

    /// "Apple Weather, OpenAQ (2–6 mi) ·": the full provenance is one tap away (Details).
    private func sourceLine(_ c: Conditions) -> String {
        let names = Array(Set(c.observations.map(\.source))).sorted()
        let miles = c.observations.compactMap(\.distanceKm).map { Int(($0 * 0.621371).rounded()) }
        var line = names.joined(separator: ", ")
        if let lo = miles.min(), let hi = miles.max() { line += lo == hi ? " (\(lo) mi)" : " (\(lo)–\(hi) mi)" }
        return line
    }
}

extension LogEvent {
    /// The Journal headline: leads with whatever stands out. Air first when it isn't good; otherwise
    /// the weather. "Moderate air, 88° and humid." / "Rain, 61° and humid." / "Mild and comfortable, 61°."
    var headline: String {
        let w = weave
        if let air = w.levels[.air], air != .low { return airLine }
        let temp = conditions?.best(.temperature).map { "\(Int($0.value.rounded()))°" }
        let humidity = w.words[.humidity]
        if let sky = conditions?.weatherCondition {
            return [sky, [temp, humidity].compactMap { $0 }.joined(separator: " and ")].filter { !$0.isEmpty }.joined(separator: ", ") + "."
        }
        let feel = [w.words[.temperature]?.capitalized, humidity].compactMap { $0 }.joined(separator: " and ")
        let line = [feel.isEmpty ? nil : feel, temp].compactMap { $0 }.joined(separator: ", ")
        return line.isEmpty ? airLine : line + "."
    }

    /// The air at this moment as a short phrase: "Good air, 63° and comfortable."
    var airLine: String {
        let w = weave
        var parts: [String] = []
        if let air = w.levels[.air] { parts.append(["Good air", "Moderate air", "Poor air"][air.rawValue]) }
        var tail: [String] = []
        if let t = conditions?.best(.temperature) { tail.append("\(Int(t.value.rounded()))°") }
        if let h = w.words[.humidity] { tail.append(h) }
        if !tail.isEmpty { parts.append(tail.joined(separator: " and ")) }
        return parts.isEmpty ? "No air reading." : parts.joined(separator: ", ") + "."
    }
}
