import AsthmaCore
import SwiftData
import SwiftUI
import TipKit

/// The bottom of the Journal: the + capture control, with Insights beside it (a ring button by default;
/// the peek strip and edge tab are crit variants).
struct CaptureBar: View {
    @Binding var showInsights: Bool
    var tip: PullToLogTip? = nil
    var spot: SpotlightFrames? = nil
    @Environment(LogService.self) private var services
    @Environment(\.modelContext) private var context
    @AppStorage(Prefs.writeToHealth) private var writeToHealth = true
    /// The "logged" toast, owned by the Journal so it can drop in from the top over everything.
    @Binding var toast: LogEvent?
    @AppStorage(Crit.InsightsEntry.key) private var insightsEntry = Crit.InsightsEntry.topBar
    @AppStorage(Prefs.logButtons) private var useButtons = false
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The + follows the rail to the hand's side.
    @AppStorage(Prefs.railLeft) private var railLeft = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if railLeft { logControl; Spacer() }
            switch insightsEntry {
            case .bottomStrip: InsightPeek(open: { showInsights = true })
            case .ringButton:
                Spacer()
                InsightsRingButton(open: { showInsights = true })
            case .edgeTab, .topBar: if !railLeft { Spacer() }
            }
            if !railLeft { logControl }
        }
        .padding(railLeft ? .trailing : .leading, 16)
        .padding(railLeft ? .leading : .trailing, NowHomeView.column - 28)  // the 56pt + on the hand's column
        .padding(.bottom, 6)
        .animation(.snappy, value: useButtons)
    }

    @ViewBuilder private var logControl: some View {
            if useButtons || typeSize.isAccessibilitySize {
                // Two labelled buttons: chosen in Settings (or from the tip), and always at accessibility text sizes.
                HStack(spacing: 8) {
                    logButton(.rescue, "Rescue", Theme.rescue)
                    logButton(.maintenance, "Standard", Theme.standard)
                }
            } else {
                CaptureControl { moment in
                    PullToLogTip().invalidate(reason: .actionPerformed)
                    log(moment)
                }
                .modifier(SpotIf(id: "plus", spot: spot))
                .popoverTip(tip, arrowEdge: .bottom) { action in
                    if action.id == "buttons" { useButtons = true; tip?.invalidate(reason: .actionPerformed) }
                }
                .tint(.primary)   // the tip's button in the app's ink, not system blue
            }
    }
}

extension CaptureBar {
    fileprivate func log(_ moment: MomentKind) {
        Task {
            // Presses within 2 minutes add a puff to the same use (docs/data-model.md).
            let e: LogEvent = moment == .okay ? await services.log(moment, in: context, writeToHealth: writeToHealth)
                : await services.press(moment, device: .phone, in: context).event
            withAnimation(.snappy) { toast = e }
            Sounds.play(.log)
            // So the question is waiting on the Lock Screen when the phone goes back in the pocket.
            if e.moment != .okay, QuickRecordCenter.shared.enabled { QuickRecordLive.shared.begin(for: e) }
            // Undo stays on the capture card for a while, then goes quietly.
            try? await Task.sleep(for: .seconds(10))
            if toast?.id == e.id { withAnimation(.snappy) { toast = nil } }
        }
    }

    fileprivate func logButton(_ moment: MomentKind, _ title: String, _ color: Color) -> some View {
        Button { log(moment) } label: {
            Label(title, systemImage: "plus")
                .font(.headline)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityHint("Logs a \(title.lowercased()) inhaler moment now")
    }
}

/// One quiet line of insight. Swipe up (or tap) for the full Insights; it comes down as a sheet.
struct InsightPeek: View {
    let open: () -> Void
    @Query(sort: \LogEvent.loggedAt) private var events: [LogEvent]
    @AppStorage(Prefs.useDemoData) private var demo = false
    @State private var model = InsightsModel()
    @State private var drag: CGFloat = 0

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles").foregroundStyle(Theme.secondaryText)
            Text(line)
                .font(.subheadline)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.up").font(.caption.weight(.bold)).foregroundStyle(Theme.secondaryText)
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        .offset(y: min(0, drag) * 0.35)
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { drag = $0.translation.height }
                .onEnded { v in
                    withAnimation(.snappy) { drag = 0 }
                    if v.translation.height < -30 || v.predictedEndTranslation.height < -80 { open() }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens Insights")
        .accessibilityAddTraits(.isButton)
        .task(id: events.count) {
            // Wait out the log animation (and any burst of logs) before recomputing patterns.
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            model.rebuild(events: events, demo: demo)
            model.narrate()
        }
    }

    private var line: String {
        if let p = model.progress, !p.isMet {
            return "Learning your pattern: \(p.attacks) of \(p.minAttacks) rescue and \(p.baselines) of \(p.minBaselines) baseline moments."
        }
        return model.narration?.headline ?? "Swipe up for Insights"
    }
}

/// The +: the glass well (`PullToLog`) by default, the system menu as the crit fallback. VoiceOver always
/// gets the menu.
struct CaptureControl: View {
    let onLog: (MomentKind) -> Void
    @AppStorage(Crit.LogStyle.key) private var style = Crit.LogStyle.pull
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    var body: some View {
        if style == .pull && !voiceOver { PullToLog(onLog: onLog) } else { CaptureMenu(onLog: onLog) }
    }
}

/// Variant: Insights as sideways text on the right edge, with a small grip. Pull left or tap to open.
struct InsightEdgeTab: View {
    let open: () -> Void
    @State private var drag: CGFloat = 0

    var body: some View {
        HStack(spacing: 6) {
            Capsule().fill(Theme.secondaryText.opacity(0.5)).frame(width: 3, height: 28)
            Text("INSIGHTS")
                .font(.caption2.weight(.semibold)).tracking(2)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize()
                .rotationEffect(.degrees(-90))
                .frame(width: 14, height: 80)
        }
        .padding(.vertical, 14).padding(.leading, 8).padding(.trailing, 4)
        .glassEffect(.regular.interactive(), in: UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14))
        .offset(x: max(-24, min(0, drag)))
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { drag = $0.translation.width }
                .onEnded { v in
                    withAnimation(.snappy) { drag = 0 }
                    if v.translation.width < -20 { open() }
                }
        )
        .accessibilityLabel("Insights")
        .accessibilityAddTraits(.isButton)
    }
}

/// Sideways: temperature, humidity and air across the full width, a day at a glance.
struct LandscapeDataView: View {
    var body: some View {
        AirChartsView(wide: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.stage.ignoresSafeArea())
    }
}

/// Insights as a round button next to the +. While felt air is still learning, a ring fills toward the
/// first pattern. Once there's a pattern, a speech bubble offers it; tap to open Insights.
struct InsightsRingButton: View {
    let open: () -> Void
    @Query(sort: \LogEvent.loggedAt) private var events: [LogEvent]
    @AppStorage(Prefs.useDemoData) private var demo = false
    @AppStorage(Crit.InsightsState.key) private var forced = Crit.InsightsState.auto
    @State private var model = InsightsModel()
    @State private var bubbleDismissed = false
    @State private var shown = false

    /// 56 by the +; 44 in the top bar, matching •••.
    var size: CGFloat = 56
    /// In the top bar the bubble hangs below the button instead of above it.
    var bubbleBelow = false
    /// On the left (the rail is on the left): the bubble opens to the right.
    var leading = false
    var showsBubble = true
    /// Its own glass circle; off when it sits in a group that has the glass (Now's top controls).
    var glass = true
    /// Bumps when a sentence with a sparkle lands on the home: the button nods once.
    var nod = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: { bubbleDismissed = true; open() }) {
            ZStack {
                // Learning, as a ring of riso dots that builds as felt air learns (Insights' LearningRing, small).
                // It draws itself in from empty when it appears, so you see it building.
                let dots = size < 50 ? 20 : 28
                let big: CGFloat = size < 50 ? 1.6 : 2.3
                DotRing(fill: 1, dots: dots, on: 0.9, inset: big + 1).fill(Theme.secondaryText.opacity(0.4))
                DotRing(fill: shown ? progress : 0, dots: dots, on: big, inset: big + 1)
                    .fill(Color.primary.opacity(learned ? 1 : 0.8))
                    .animation(reduceMotion ? nil : .smooth(duration: 1.4), value: shown ? progress : 0)
                // SF Symbols' own animation: a slow breath while learning; one sparkle becomes two, with a
                // bounce, once it has learned.
                Image(systemName: learned ? "sparkles" : "sparkle")
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
                    .symbolEffect(.breathe.pulse.byLayer, options: .repeat(.continuous), isActive: !learned && !reduceMotion)
                    .symbolEffect(.bounce, value: learned)
                    .symbolEffect(.bounce.down, value: nod)
            }
            .onAppear { shown = true }
            .padding(size < 50 ? 4 : 5)
            .frame(width: size, height: size)
            .glassEffect(glass ? .regular.interactive() : .identity, in: .circle)
        }
        .buttonStyle(.plain)
        .overlay(alignment: leading ? .topLeading : .topTrailing) {
            if showsBubble && learned && !bubbleDismissed {
                bubble
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 230, alignment: leading ? .leading : .trailing)
                    .offset(x: bubbleBelow ? 0 : 70, y: bubbleBelow ? size + 10 : -size - 26)
                    .transition(.scale(scale: 0.6, anchor: bubbleBelow ? (leading ? .topLeading : .topTrailing) : .bottomTrailing).combined(with: .opacity))
                    .onTapGesture { bubbleDismissed = true; open() }
            }
        }
        .animation(.spring(duration: 0.45, bounce: 0.3), value: learned)
        .onChange(of: learned) { was, now in if !was && now { Sounds.play(.learned) } }
        .accessibilityLabel(learned ? "Insights: learned" : "Insights: still learning")
        .task(id: events.count) {
            // Wait out the log animation (and any burst of logs) before recomputing patterns.
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            model.rebuild(events: events, demo: demo)
            model.narrate()
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Learned").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            // Words only (the template headline carries counts): no numbers on screen.
            Text("Your flare days have something in common. Tap to see what.")
                .font(.subheadline).lineLimit(3)
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private var learned: Bool {
        switch forced {
        case .learned: true
        case .learning: false
        case .auto: model.progress?.isMet ?? false
        }
    }

    private var progress: Double {
        switch forced {
        case .learned: return 1
        case .learning: return 0.62
        case .auto:
            guard let p = model.progress else { return 0 }
            let a = min(1, Double(p.attacks) / Double(max(1, p.minAttacks)))
            let b = min(1, Double(p.baselines) / Double(max(1, p.minBaselines)))
            return (a + b) / 2
        }
    }
}

/// Dots around a circle, the first `fill` of them (clockwise from the top). Animatable, so the ring builds.
nonisolated struct DotRing: Shape {
    var fill: Double
    var dots: Int
    /// Radius of a dot that's on. Dots past `fill` are left out; the one at the edge grows in as `fill` passes it.
    var on: CGFloat
    /// How far the dots' centres sit inside the edge: the same for every ring drawn together, so they line up.
    var inset: CGFloat

    var animatableData: Double {
        get { fill }
        set { fill = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY), radius = min(rect.width, rect.height) / 2 - inset
        for i in 0..<dots {
            // 0 before this dot's turn, 1 once fill has passed it: the ring builds one dot at a time, smoothly.
            let grown = min(1, max(0, fill * Double(dots) - Double(i)))
            let r = on * CGFloat(grown)
            guard r > 0.05 else { continue }
            let a = Double(i) / Double(dots) * 2 * .pi - .pi / 2
            let pt = CGPoint(x: c.x + radius * cos(a), y: c.y + radius * sin(a))
            p.addEllipse(in: CGRect(x: pt.x - r, y: pt.y - r, width: 2 * r, height: 2 * r))
        }
        return p
    }
}

/// "Rescue logged · Undo", dropping in from the top edge.
struct LoggedToast: View {
    let event: LogEvent
    let undo: () -> Void
    /// Quick Record from inside the app: add a voice note or tags to this moment.
    var note: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            MomentDot(moment: event.moment, size: 9)
            Text("\(event.moment == .rescue ? "Rescue" : "Standard") logged").font(.subheadline.weight(.semibold))
            Spacer()
            if let note {
                Button(action: note) { Label("Note", systemImage: "mic.fill") }.font(.subheadline.weight(.semibold))
            }
            Button("Undo", action: undo).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.secondaryText)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
