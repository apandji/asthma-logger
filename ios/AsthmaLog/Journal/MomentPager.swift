import AsthmaCore
import SwiftUI
import UIKit

/// The Journal's moments: one contained sky (the moment you're on) above a history track. Drag the
/// track to move through time; the moment nearest the centre marker becomes current, with a haptic tick
/// as you pass each one, and it settles on the nearest moment when you let go. Tap a dot to jump.
/// Only one sky is drawn at a time (it cross-fades), which keeps it smooth.
struct MomentPager: View {
    let events: [LogEvent]
    @Binding var selectedID: UUID?
    let zoom: Namespace.ID
    let mapNamespace: Namespace.ID
    let pollenSeason: DemoPollen.Season
    let onOpen: (LogEvent) -> Void
    let onOverview: () -> Void
    @Binding var probing: Bool
    var spot: SpotlightFrames? = nil

    private var current: LogEvent? { events.first { $0.id == selectedID } ?? events.last }

    /// Snapshot the maps either side of the current moment, so scrubbing never waits on one.
    private func prefetchNeighbours() async {
        guard let i = events.firstIndex(where: { $0.id == current?.id }) else { return }
        let dark = true  // the Journal page is black
        for j in [i - 1, i + 1, i - 2, i + 2] where events.indices.contains(j) {
            _ = await MapSnapshots.image(for: events[j], size: CGSize(width: 520, height: 520), dark: dark)
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                if let e = current {
                    SkyPanel(event: e, pollen: DemoPollen.sample(at: e.loggedAt, season: pollenSeason),
                             zoom: zoom, mapNamespace: mapNamespace, probing: $probing, onOpen: { onOpen(e) }, onOverview: onOverview)
                        .id(e.id)
                        .transition(.opacity)
                }
            }
            .modifier(SpotIf(id: "sky", spot: spot))
            .animation(.easeInOut(duration: 0.35), value: current?.id)
            .task(id: current?.id) { await prefetchNeighbours() }

            TimelineTrack(events: events, selectedID: $selectedID)
                .frame(height: 104)
                .modifier(SpotIf(id: "track", spot: spot))
        }
    }
}

/// History as a scrubber, in the language of the Photos and Camera dials: ticks every 6 hours (taller at
/// midnight, day names beneath), moments as dots on the same axis, and a fixed playhead in the middle
/// with the current moment's time in a pill above it. The moment under the playhead is enlarged and ringed.
struct TimelineTrack: View {
    let events: [LogEvent]
    @Binding var selectedID: UUID?

    @State private var position = ScrollPosition(edge: .trailing)
    /// The track point under the playhead.
    @State private var centerX: CGFloat = 0
    /// The scroll view's visible width (from its own geometry, so the padding and playhead line up exactly).
    @State private var viewport: CGFloat = 0
    @State private var dragging = false

    private let dayWidth: CGFloat = 64
    private let axis: CGFloat = 46       // y of the shared axis for ticks and dots
    private let height: CGFloat = 86
    private let cal = Calendar.current

    private var start: Date { cal.startOfDay(for: events.first?.loggedAt ?? .now) }
    private var end: Date { cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now))! }
    private var contentWidth: CGFloat { CGFloat(end.timeIntervalSince(start) / 86_400) * dayWidth }
    private func x(_ d: Date) -> CGFloat { CGFloat(d.timeIntervalSince(start) / 86_400) * dayWidth }
    /// The moment under the playhead (the newest until you scrub).
    private var currentID: UUID? { selectedID ?? events.last?.id }
    private var selected: LogEvent? { events.first { $0.id == currentID } }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                // Half the viewport at each end, so any moment can sit under the playhead.
                Color.clear.frame(width: viewport / 2)
                ZStack(alignment: .topLeading) {
                    Canvas { ctx, size in
                        // Axis.
                        var line = Path()
                        line.move(to: CGPoint(x: 0, y: axis)); line.addLine(to: CGPoint(x: size.width, y: axis))
                        ctx.stroke(line, with: .color(.white.opacity(0.12)), lineWidth: 1)
                        // Ticks, centred on the axis.
                        var t = start
                        while t <= end {
                            let isDay = cal.component(.hour, from: t) == 0
                            let half: CGFloat = isDay ? 10 : 4
                            var p = Path()
                            p.move(to: CGPoint(x: x(t), y: axis - half)); p.addLine(to: CGPoint(x: x(t), y: axis + half))
                            ctx.stroke(p, with: .color(.white.opacity(isDay ? 0.4 : 0.18)), lineWidth: 1)
                            if isDay {
                                let label = cal.isDateInToday(t) ? "Today" : t.formatted(.dateTime.weekday(.abbreviated).day())
                                ctx.draw(Text(label).font(.caption2).foregroundStyle(.white.opacity(0.45)),
                                         at: CGPoint(x: x(t) + dayWidth / 2, y: axis + 26))
                            }
                            t = cal.date(byAdding: .hour, value: 6, to: t)!
                        }
                    }
                    .frame(width: contentWidth, height: height)

                    // Moments on the axis. The current one is enlarged and ringed.
                    ForEach(events) { e in
                        let on = e.id == currentID
                        Circle()
                            .fill(e.moment == .rescue ? Theme.rescue : Theme.standard)
                            .frame(width: on ? 14 : 8, height: on ? 14 : 8)
                            .overlay(Circle().strokeBorder(.black.opacity(0.6), lineWidth: on ? 0 : 1))
                            .background {
                                if on {
                                    Circle().fill(.white).frame(width: 22, height: 22)
                                        .shadow(color: (e.moment == .rescue ? Theme.rescue : Theme.standard).opacity(0.8), radius: 8)
                                }
                            }
                            .position(x: x(e.loggedAt), y: axis)
                            .animation(.snappy(duration: 0.2), value: on)
                            .onTapGesture { select(e, scroll: true) }
                    }
                }
                .frame(width: contentWidth, height: height)
                Color.clear.frame(width: viewport / 2)
            }
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGFloat.self) { $0.containerSize.width } action: { _, w in viewport = w }
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x } action: { _, cx in
            centerX = cx
            guard dragging, let nearest = nearest(to: cx), nearest.id != selectedID else { return }
            selectedID = nearest.id
        }
        .onScrollPhaseChange { old, phase in
            dragging = phase == .interacting || phase == .decelerating
            // Snap only after a real drag, not when the track settles at launch.
            if phase == .idle, old == .interacting || old == .decelerating, let n = nearest(to: centerX) { select(n, scroll: true) }
        }
        // The playhead: a bright capsule through the axis, the current moment's time in a pill above.
        .overlay(alignment: .top) {
            ZStack(alignment: .top) {
                Capsule().fill(.white).frame(width: 3, height: 34)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .offset(y: axis - 17)
                if let e = selected {
                    Text(e.loggedAt.formatted(.dateTime.weekday(.abbreviated).day().hour().minute()))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(.white, in: Capsule())
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.2), value: e.id)
                        .fixedSize()
                        .offset(y: axis - 17 - 30)
                }
            }
            .allowsHitTesting(false)
        }
        .padding(.top, 24)
        .sensoryFeedback(.selection, trigger: selectedID)
        .onChange(of: selectedID) { _, id in
            // Moved from elsewhere (a new log, the calendar): bring it under the playhead.
            if !dragging, let e = events.first(where: { $0.id == id }), abs(x(e.loggedAt) - centerX) > 1 {
                withAnimation(.smooth) { position.scrollTo(x: x(e.loggedAt)) }
            }
        }
        .task(id: viewport) {
            guard viewport > 0 else { return }
            try? await Task.sleep(for: .milliseconds(80))   // let the content lay out first
            if let e = events.first(where: { $0.id == selectedID }) ?? events.last { position.scrollTo(x: x(e.loggedAt)) }
        }
        .accessibilityElement()
        .accessibilityLabel("History")
        .accessibilityValue(selected.map { "\($0.moment.title), \($0.loggedAt.formatted(date: .abbreviated, time: .shortened))" } ?? "")
        .accessibilityAdjustableAction { dir in
            guard let i = events.firstIndex(where: { $0.id == selectedID }) ?? events.indices.last else { return }
            let j = dir == .increment ? min(events.count - 1, i + 1) : max(0, i - 1)
            select(events[j], scroll: true)
        }
    }

    private func nearest(to cx: CGFloat) -> LogEvent? {
        events.min { abs(x($0.loggedAt) - cx) < abs(x($1.loggedAt) - cx) }
    }

    private func select(_ e: LogEvent, scroll: Bool) {
        selectedID = e.id
        if scroll { withAnimation(.smooth(duration: 0.35)) { position.scrollTo(x: x(e.loggedAt)) } }
    }
}

/// One moment's sky.
struct SkyPanel: View {
    let event: LogEvent
    let pollen: PollenSample?
    let zoom: Namespace.ID
    let mapNamespace: Namespace.ID
    @Binding var probing: Bool
    let onOpen: () -> Void
    let onOverview: () -> Void

    @State private var point: CGPoint?
    @State private var probe: SkyProbe?
    @State private var pinch: CGFloat = 1
    @State private var pulse: Task<Void, Never>?
    @AppStorage(Crit.LayerStrength.key) private var strengthStyle = Crit.LayerStrength.smooth

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                AmbientField(weave: event.weave, temperatureF: temperature, date: event.loggedAt,
                             conditions: event.conditions, pollen: pollen)
                // The place, faint and inactive: it comes alive when you open the moment.
                if event.latitude != nil {
                    MomentMap(event: event)
                        .frame(width: size.width * 0.62, height: size.width * 0.62)
                        .matchedGeometryEffect(id: "map-\(event.id)", in: mapNamespace)
                        .saturation(0.35)
                        .opacity(0.5)
                        .mask(EllipticalGradient(colors: [.black, .clear], center: .center,
                                                 startRadiusFraction: 0.1, endRadiusFraction: 0.5))
                        .allowsHitTesting(false)
                }

                if let point, let probe {
                    // The glow belongs to the sky, so it fades with it.
                    SkyProbeOverlay(point: point, probe: probe, width: size.width, showsLabel: false)
                        .transition(.opacity)
                }
            }
            .frame(width: size.width, height: size.height)
            // One offscreen pass for the sky, map and glow, instead of a pass per mask.
            .drawingGroup()
            // Self-contained: fades to black at the edges, and most of all toward the top.
            .mask {
                EllipticalGradient(colors: [.black, .black, .clear], center: UnitPoint(x: 0.5, y: 0.55),
                                   startRadiusFraction: 0, endRadiusFraction: 0.7)
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.26)],
                                         startPoint: .top, endPoint: .bottom))
            }
            // The label sits above the fade, always fully legible.
            .overlay {
                if let point, let probe {
                    SkyProbeOverlay(point: point, probe: probe, width: size.width, showsGlow: false)
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .scaleEffect(pinch)
            .onTapGesture(perform: onOpen)
            .gesture(explore(size))
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { v in pinch = min(1.08, max(0.94, v.magnification)) }
                    .onEnded { v in
                        withAnimation(.snappy) { pinch = 1 }
                        if v.magnification > 1.08 { onOpen() } else if v.magnification < 0.85 { onOverview() }
                    }
            )
        }
        .padding(.horizontal, 8)
        .task { await PlaceNames.lookUp(event) }
        .onDisappear { stopPulse() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.moment.title), \(event.loggedAt.formatted(date: .abbreviated, time: .shortened)). \(event.airLine)")
        .accessibilityAction(named: "Open details", onOpen)
    }

    private var temperature: Double? { event.conditions?.best(.temperature)?.value }

    /// Touch and hold, then move: name what's under the finger, with a steady haptic pulse that
    /// quickens and strengthens as the reading nears high.
    private func explore(_ size: CGSize) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                if !probing { probing = true; SkyTip().invalidate(reason: .actionPerformed); startPulse() }
                let unit = CGPoint(x: drag.location.x / size.width, y: drag.location.y / size.height)
                let layers = AirLayers(conditions: event.conditions, weave: event.weave, pollen: pollen,
                                       smooth: strengthStyle == .smooth)
                withAnimation(.easeOut(duration: 0.12)) {
                    point = drag.location
                    probe = SkyExplorer.probe(at: unit, layers: layers, conditions: event.conditions, weave: event.weave,
                                              temperatureF: temperature, pollen: pollen)
                }
            }
            .onEnded { _ in
                stopPulse()
                withAnimation(.easeOut(duration: 0.25)) { point = nil; probe = nil }
                probing = false
            }
    }

    // MARK: Haptic pulse

    private func startPulse() {
        pulse?.cancel()
        pulse = Task { @MainActor in
            let soft = UIImpactFeedbackGenerator(style: .soft)
            let rigid = UIImpactFeedbackGenerator(style: .rigid)
            let heavy = UIImpactFeedbackGenerator(style: .heavy)
            soft.prepare(); rigid.prepare(); heavy.prepare()
            while !Task.isCancelled {
                let x = probe?.intensity ?? 0   // 0 clean … 1 high
                switch x {
                case ..<0.34: soft.impactOccurred(intensity: 0.55 + x)
                case ..<0.67: rigid.impactOccurred(intensity: 0.6 + x * 0.4)
                default: heavy.impactOccurred(intensity: min(1, 0.75 + x * 0.25))
                }
                // Slow and soft over clean air, quick and hard near high: 0.55 s → 0.12 s between taps.
                let interval = 0.55 - 0.43 * x
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    private func stopPulse() {
        pulse?.cancel()
        pulse = nil
    }
}

/// Marks a spotlight target when there's a store.
struct SpotIf: ViewModifier {
    let id: String
    let spot: SpotlightFrames?
    func body(content: Content) -> some View {
        if let spot { content.spotlightTarget(id, spot) } else { content }
    }
}
