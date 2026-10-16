import AsthmaCore
import SwiftUI
import UIKit

/// The Journal's moments as pages, each its own contained sky on a black page: the colour field fades
/// to black at the top and the edges, the map sits inside it faint and inactive, and small dots below
/// show where you are. Swipe for other moments. Touch and hold the sky to explore it (paging pauses
/// while you do); pinch it open for the details, pinch it closed for the calendar.
struct MomentPager: View {
    let events: [LogEvent]
    @Binding var selectedID: UUID?
    let zoom: Namespace.ID
    let pollenSeason: DemoPollen.Season
    let onOpen: (LogEvent) -> Void
    let onOverview: () -> Void
    @Binding var probing: Bool

    var body: some View {
        VStack(spacing: 14) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(events) { e in
                        SkyPanel(event: e, pollen: DemoPollen.sample(at: e.loggedAt, season: pollenSeason),
                                 zoom: zoom, probing: $probing, onOpen: { onOpen(e) }, onOverview: onOverview)
                            .containerRelativeFrame(.horizontal)
                            .id(e.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $selectedID)
            .defaultScrollAnchor(.trailing)
            .scrollIndicators(.hidden)
            .scrollDisabled(probing)

            PageDots(count: events.count, index: events.firstIndex { $0.id == selectedID } ?? events.count - 1)
        }
    }
}

/// One moment's sky.
struct SkyPanel: View {
    let event: LogEvent
    let pollen: PollenSample?
    let zoom: Namespace.ID
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
                        .saturation(0)
                        .opacity(0.22)
                        .blendMode(.screen)
                        .mask(EllipticalGradient(colors: [.black, .clear], center: .center,
                                                 startRadiusFraction: 0.1, endRadiusFraction: 0.5))
                        .matchedTransitionSource(id: event.id, in: zoom) { $0.clipShape(RoundedRectangle(cornerRadius: 200)) }
                        .allowsHitTesting(false)
                } else {
                    Color.clear.frame(width: 1, height: 1)
                        .matchedTransitionSource(id: event.id, in: zoom)
                }
                if let point, let probe {
                    SkyProbeOverlay(point: point, probe: probe, width: size.width)
                        .transition(.opacity)
                }
            }
            .frame(width: size.width, height: size.height)
            // Self-contained: fades to black at the edges, and most of all toward the top.
            .mask {
                EllipticalGradient(colors: [.black, .black, .clear], center: UnitPoint(x: 0.5, y: 0.58),
                                   startRadiusFraction: 0, endRadiusFraction: 0.62)
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.38)],
                                         startPoint: .top, endPoint: .bottom))
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

/// Small page dots like iOS: a window of up to seven, the current one bright, the far ones smaller.
struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        let window = 7
        let start = max(0, min(index - window / 2, count - window))
        let range = start..<min(count, start + window)
        HStack(spacing: 7) {
            ForEach(Array(range), id: \.self) { i in
                let edge = (i == range.lowerBound && start > 0) || (i == range.upperBound - 1 && range.upperBound < count)
                Circle()
                    .fill(.white.opacity(i == index ? 0.95 : 0.3))
                    .frame(width: edge ? 4 : 7, height: edge ? 4 : 7)
            }
        }
        .animation(.snappy, value: index)
        .accessibilityElement()
        .accessibilityLabel("Moment \(index + 1) of \(count)")
    }
}
