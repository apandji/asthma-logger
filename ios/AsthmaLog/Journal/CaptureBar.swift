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

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            switch insightsEntry {
            case .bottomStrip: InsightPeek(open: { showInsights = true })
            case .ringButton:
                Spacer()
                InsightsRingButton(open: { showInsights = true })
            case .edgeTab, .topBar: Spacer()
            }
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
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, JournalView.railAxis - 28)  // the 56pt + centers on the rail axis
        .padding(.bottom, 6)
        .animation(.snappy, value: useButtons)
    }
}

extension CaptureBar {
    fileprivate func log(_ moment: MomentKind) {
        Task {
            // Presses within 2 minutes add a puff to the same use (docs/data-model.md).
            let e: LogEvent = moment == .okay ? await services.log(moment, in: context, writeToHealth: writeToHealth)
                : await services.press(moment, device: .phone, in: context).event
            withAnimation(.snappy) { toast = e }
            // So the question is waiting on the Lock Screen when the phone goes back in the pocket.
            if e.moment != .okay, QuickRecordCenter.shared.enabled { QuickRecordLive.shared.begin(for: e) }
            try? await Task.sleep(for: .seconds(4))
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
            await model.narrate(styleScore: 50, useModel: false)
        }
    }

    private var line: String {
        if let p = model.progress, !p.isMet {
            return "Learning your pattern: \(p.attacks) of \(p.minAttacks) rescue and \(p.baselines) of \(p.minBaselines) baseline moments."
        }
        return model.narration?.headline ?? "Swipe up for Insights"
    }
}

/// The + button. Press and drag up: past the first line is Rescue (orange, quick), keep going to the
/// top for Standard (blue). Let go in a zone to log it; let go below the first line to cancel.
struct CaptureControl: View {
    let onLog: (MomentKind) -> Void
    @State private var logged = 0

    /// The + is a system menu: press, slide onto Rescue or Standard, lift to log (or tap, then tap a choice).
    /// That's Apple's own press-and-slide, so it needs no custom track and works with VoiceOver as is.
    /// Rescue sits nearest the finger.
    var body: some View {
        Menu {
            Button { logged += 1; onLog(.rescue) } label: { Label("Rescue", systemImage: "lungs.fill") }
            Button { logged += 1; onLog(.maintenance) } label: { Label("Standard", systemImage: "lungs") }
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 56, height: 56)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .menuOrder(.priority)
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: logged)
        .accessibilityLabel("Log a moment")
        .accessibilityHint("Choose Rescue or Standard")
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

    /// 56 by the +; 44 in the top bar, matching •••.
    var size: CGFloat = 56
    /// In the top bar the bubble hangs below the button instead of above it.
    var bubbleBelow = false

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
            .padding(size < 50 ? 4 : 5)
            .frame(width: size, height: size)
            .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if learned && !bubbleDismissed {
                bubble
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 230, alignment: .trailing)
                    .offset(x: bubbleBelow ? 0 : 70, y: bubbleBelow ? size + 10 : -size - 26)
                    .transition(.scale(scale: 0.6, anchor: bubbleBelow ? .topTrailing : .bottomTrailing).combined(with: .opacity))
                    .onTapGesture { bubbleDismissed = true; open() }
            }
        }
        .animation(.spring(duration: 0.45, bounce: 0.3), value: learned)
        .accessibilityLabel(learned ? "Insights: a pattern is ready" : "Insights: still learning, \(Int(progress * 100)) percent")
        .task(id: events.count) {
            // Wait out the log animation (and any burst of logs) before recomputing patterns.
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            model.rebuild(events: events, demo: demo)
            await model.narrate(styleScore: 50, useModel: false)
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("New pattern").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            Text(model.narration?.headline ?? "Your inhaler days have something in common.")
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
