import AsthmaCore
import SwiftData
import SwiftUI

/// The bottom of the Journal: the + capture control, with Insights beside it (a ring button by default;
/// the peek strip and edge tab are crit variants).
struct CaptureBar: View {
    @Binding var showInsights: Bool
    @Environment(LogService.self) private var services
    @Environment(\.modelContext) private var context
    @AppStorage(Prefs.writeToHealth) private var writeToHealth = true
    @State private var toast: LogEvent?
    @AppStorage(Crit.InsightsEntry.key) private var insightsEntry = Crit.InsightsEntry.ringButton

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            switch insightsEntry {
            case .bottomStrip: InsightPeek(open: { showInsights = true })
            case .ringButton:
                Spacer()
                InsightsRingButton(open: { showInsights = true })
            case .edgeTab: Spacer()
            }
            CaptureControl { moment in
                Task {
                    let e: LogEvent = await services.log(moment, in: context, writeToHealth: writeToHealth)
                    withAnimation(.snappy) { toast = e }
                    try? await Task.sleep(for: .seconds(4))
                    if toast?.id == e.id { withAnimation(.snappy) { toast = nil } }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .overlay(alignment: .top) {
            if let e = toast {
                HStack(spacing: 12) {
                    MomentDot(moment: e.moment, size: 9)
                    Text("\(e.moment == .rescue ? "Rescue" : "Standard") logged").font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("Undo") {
                        withAnimation(.snappy) { toast = nil }
                        Task { await services.delete(e, in: context) }
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .glassEffect(.regular, in: .capsule)
                .padding(.horizontal, 16)
                .offset(y: -64)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
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
            model.rebuild(events: events, demo: demo)
            await model.narrate(styleScore: 50, useModel: false)
        }
    }

    private var line: String {
        if let p = model.progress, !p.isMet {
            return "Learning your pattern: \(p.attacks) of \(p.minAttacks) inhaler uses, \(p.baselines) of \(p.minBaselines) calm moments."
        }
        return model.narration?.headline ?? "Swipe up for Insights"
    }
}

/// The + button. Press and drag up: past the first line is Rescue (orange, quick), keep going to the
/// top for Standard (blue). Let go in a zone to log it; let go below the first line to cancel.
struct CaptureControl: View {
    let onLog: (MomentKind) -> Void

    enum Zone: Int { case none, near, far }

    @State private var active = false
    @State private var lift: CGFloat = 0
    @State private var logged = 0
    @AppStorage(Crit.CaptureOrder.key) private var order = Crit.CaptureOrder.rescueFirst

    /// What the near zone and the far zone log, per the crit setting.
    private var near: MomentKind { order == .rescueFirst ? .rescue : .maintenance }
    private var far: MomentKind { order == .rescueFirst ? .maintenance : .rescue }
    private func color(_ m: MomentKind) -> Color { m == .rescue ? Theme.rescue : Theme.standard }
    private func name(_ m: MomentKind) -> String { m == .rescue ? "Rescue" : "Standard" }

    private let size: CGFloat = 64
    private let rescueAt: CGFloat = 70
    private let standardAt: CGFloat = 230
    private let trackHeight: CGFloat = 300

    private var zone: Zone { lift >= standardAt ? .far : lift >= rescueAt ? .near : .none }
    private var zoneColor: Color { zone == .far ? color(far) : zone == .near ? color(near) : .white.opacity(0.5) }

    var body: some View {
        ZStack(alignment: .bottom) {
            if active { track.transition(.scale(scale: 0.2, anchor: .bottom).combined(with: .opacity)) }
            knob
        }
        .frame(width: size, height: size, alignment: .bottom)
        .sensoryFeedback(trigger: zone) { _, new in
            switch new {
            case .near: .impact(weight: .medium, intensity: 0.8)
            case .far: .impact(weight: .heavy, intensity: 1)
            case .none: .selection
            }
        }
        .sensoryFeedback(.success, trigger: logged)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if !active { withAnimation(.spring(duration: 0.3, bounce: 0.35)) { active = true } }
                    lift = max(0, min(trackHeight, -v.translation.height))
                }
                .onEnded { _ in
                    let z = zone
                    if z != .none {
                        logged += 1
                        onLog(z == .near ? near : far)
                    }
                    withAnimation(.spring(duration: 0.4, bounce: 0.3)) { active = false; lift = 0 }
                }
        )
        .accessibilityElement()
        .accessibilityLabel("Log a moment")
        .accessibilityHint("Drag up a little for \(name(near).lowercased()), all the way up for \(name(far).lowercased())")
        .accessibilityAction(named: "Log rescue") { logged += 1; onLog(.rescue) }
        .accessibilityAction(named: "Log standard") { logged += 1; onLog(.maintenance) }
    }

    /// The + that becomes a bead riding up the track with your finger, coloured by the zone it's in.
    private var knob: some View {
        ZStack {
            // A liquid level: a little at rest (there's something to pull up), rising with your finger.
            ZStack(alignment: .bottom) {
                Color.clear
                Rectangle()
                    .fill(active ? zoneColor : Color.primary.opacity(0.12))
                    .frame(height: size * (active ? max(0.35, min(1, 0.35 + lift / standardAt)) : 0.22))
            }
            .clipShape(Circle())
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .rotationEffect(.degrees(active ? 45 * Double(min(1, lift / rescueAt)) : 0))
                .foregroundStyle(active && zone != .none ? .white : .primary)
        }
        .frame(width: size, height: size)
        .glassEffect(.regular.interactive(), in: .circle)
        .overlay(alignment: .top) {
            if !active {
                Image(systemName: "chevron.up").font(.caption2.weight(.bold)).foregroundStyle(Theme.secondaryText)
                    .offset(y: -14)
                    .phaseAnimator([0.0, -5.0, 0.0]) { v, y in v.offset(y: y) } animation: { _ in .easeInOut(duration: 1.4) }
            }
        }
        .scaleEffect(active ? 1 + 0.12 * min(1, lift / standardAt) : 1)
        .offset(y: -lift)
        .animation(.interactiveSpring(duration: 0.18), value: lift)
        .animation(.snappy, value: zone)
    }

    /// The track above the button: Rescue starts close (one short pull), Standard sits at the top.
    private var track: some View {
        ZStack(alignment: .bottom) {
            Capsule().fill(.ultraThinMaterial)
            // Fill rises with the finger.
            Capsule().fill(zoneColor.opacity(0.35))
                .frame(height: min(trackHeight + size, lift + size))
            VStack(spacing: 0) {
                label(name(far), color(far), on: zone == .far)
                Spacer()
                label(name(near), color(near), on: zone == .near)
                    .padding(.bottom, rescueAt + size * 0.2)
            }
            .padding(.top, 18)
        }
        .frame(width: size + 10, height: trackHeight + size)
        .overlay(alignment: .bottom) {
            // Lines where each zone begins.
            VStack(spacing: 0) {
                Capsule().fill(color(far).opacity(0.7)).frame(width: 28, height: 2)
                    .padding(.bottom, standardAt - rescueAt - 2)
                Capsule().fill(color(near).opacity(0.7)).frame(width: 28, height: 2)
            }
            .padding(.bottom, rescueAt + size / 2)
        }
        .offset(y: 0)
    }

    private func label(_ text: String, _ color: Color, on: Bool) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(on ? color : .secondary)
            .scaleEffect(on ? 1.15 : 1)
            .fixedSize()
            .rotationEffect(.degrees(-90))
            .frame(width: 20, height: 70)
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

    private let size: CGFloat = 56

    var body: some View {
        Button(action: { bubbleDismissed = true; open() }) {
            ZStack {
                Circle().stroke(Theme.secondaryText.opacity(0.18), lineWidth: 3)
                Circle().trim(from: 0, to: progress)
                    .stroke(learned ? Color.primary : Theme.secondaryText, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 1), value: progress)
                Image(systemName: learned ? "sparkles" : "sparkle")
                    .font(.body.weight(.semibold))
                    .symbolEffect(.pulse, isActive: learned && !bubbleDismissed)
            }
            .padding(5)
            .frame(width: size, height: size)
            .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if learned && !bubbleDismissed {
                bubble
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 230, alignment: .trailing)
                    .offset(x: 70, y: -size - 26)
                    .transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity))
                    .onTapGesture { bubbleDismissed = true; open() }
            }
        }
        .animation(.spring(duration: 0.45, bounce: 0.3), value: learned)
        .accessibilityLabel(learned ? "Insights: a pattern is ready" : "Insights: still learning, \(Int(progress * 100)) percent")
        .task(id: events.count) {
            model.rebuild(events: events, demo: demo)
            await model.narrate(styleScore: 50, useModel: false)
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("felt air noticed something").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            Text(model.narration?.headline ?? "Your inhaler days have something in common. Take a look.")
                .font(.subheadline).lineLimit(3)
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .overlay(alignment: .bottomTrailing) {
            // The bubble's tail points at the button.
            Image(systemName: "triangle.fill").font(.caption).rotationEffect(.degrees(180))
                .foregroundStyle(.ultraThinMaterial).offset(x: -86, y: 9)
        }
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
