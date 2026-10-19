import ActivityKit
import AppIntents
import AsthmaCore
import SwiftUI
import UIKit
import WidgetKit

@main
struct AsthmaLogWidgets: WidgetBundle {
    var body: some Widget {
        QuickRecordLiveActivity()
        QuickRecordControl()
        LogRescueControl()
    }
}

/// The Lock Screen recorder, in the app's language: black page, riso dots, the Recursive question,
/// the moment's tag, glass-white controls. Colour only on the dots (the inhaler's pastel).
struct QuickRecordLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: QuickRecordAttributes.self) { context in
            QuickRecordLockView(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(Copy.url(context.state))
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    KindTag(state: s).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    MainButton(state: s, size: 44)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Copy.title(s.phase)).font(Ink.sentence(20)).foregroundStyle(.white)
                        Copy.detail(s).font(.caption).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                // On standby the island stays quiet: a small grey mic.
                Image(systemName: s.phase == .recording ? "waveform" : "mic.fill")
                    .foregroundStyle(s.phase == .standby ? Color.white.opacity(0.4) : Ink.pastel(s))
            } compactTrailing: {
                if s.phase == .standby {
                    EmptyView()
                } else if s.phase == .recording, let start = s.startedAt {
                    Text(timerInterval: start...start.addingTimeInterval(QuickRecordAttributes.maxSeconds), countsDown: false)
                        .monospacedDigit().frame(width: 40).foregroundStyle(Ink.pastel(s))
                } else {
                    Text(s.kind ?? "").foregroundStyle(Ink.pastel(s))
                }
            } minimal: {
                Image(systemName: "mic.fill").foregroundStyle(s.phase == .standby ? Color.white.opacity(0.4) : Ink.pastel(s))
            }
            .widgetURL(Copy.url(s))
            .keylineTint(Ink.pastel(s))
        }
    }
}

struct QuickRecordLockView: View {
    let state: QuickRecordAttributes.ContentState
    let isStale: Bool

    var body: some View {
        // A Lock Screen Live Activity is at most 160 pt tall: everything is sized to fit that.
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if state.phase == .standby {
                    Text("felt air").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.6))
                } else {
                    KindTag(state: state)
                }
                Text(state.whenAndWhere ?? "").font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                Spacer(minLength: 0)
                if state.phase != .saved {
                    Button(intent: QuickRecordDismissIntent()) {
                        Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.6))
                            .frame(width: 24, height: 24).background(Circle().fill(.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Not now")
                }
            }
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isStale && state.phase == .ready ? "Still want to add a note?" : Copy.title(state.phase))
                        .font(Ink.sentence(22)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.75)
                    Copy.detail(state).font(.footnote).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                }
                Spacer(minLength: 0)
                ZStack {
                    // Standby is a waiting card: grey, barely a ring. Colour arrives with a moment.
                    DotRing(ink: state.phase == .standby ? .white : Ink.pastel(state),
                            strength: state.phase == .recording ? 1 : state.phase == .writing ? 0.6 : state.phase == .standby ? 0.06 : 0.35)
                        .frame(width: 68, height: 68)
                    MainButton(state: state, size: 46)
                }
            }
            if state.phase == .ready || state.phase == .review || state.phase == .needsMic {
                Chips(state: state)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

/// Record / stop / save: the one big control. White when it's the next step.
private struct MainButton: View {
    let state: QuickRecordAttributes.ContentState
    let size: CGFloat

    var body: some View {
        switch state.phase {
        case .standby:
            // Logs a rescue (or uses one from the last 10 minutes) and listens.
            Button(intent: QuickRecordStartIntent(momentID: nil)) { circle("mic.fill", filled: false) }
                .buttonStyle(.plain).accessibilityLabel("Log a rescue and record a voice note")
        case .ready, .needsMic:
            Button(intent: QuickRecordStartIntent(momentID: state.momentID)) {
                circle("mic.fill", filled: false)
            }
            .buttonStyle(.plain).accessibilityLabel("Record a voice note")
        case .recording:
            Button(intent: QuickRecordStopIntent()) { circle("stop.fill", filled: true) }
                .buttonStyle(.plain).accessibilityLabel("Stop")
        case .writing:
            ProgressView().tint(.white).frame(width: size, height: size)
        case .review:
            Button(intent: QuickRecordSaveIntent()) {
                Text("Save").font(.subheadline.weight(.semibold)).foregroundStyle(.black)
                    .frame(width: size + 12, height: size * 0.7).background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
        case .saved:
            Image(systemName: "checkmark").font(.title3.weight(.semibold)).foregroundStyle(.black)
                .frame(width: size, height: size).background(Circle().fill(Ink.pastel(state)))
        }
    }

    private func circle(_ symbol: String, filled: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(filled ? .black : .white)
            .frame(width: size, height: size)
            .background(Circle().fill(filled ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.16))))
            .overlay(Circle().strokeBorder(.white.opacity(filled ? 0 : 0.25), lineWidth: 1))
    }
}

/// Quick tags on the first screen; after the note, the suggested ones first.
private struct Chips: View {
    let state: QuickRecordAttributes.ContentState
    static let quick: [JournalTag] = [.exercise, .coldAir, .pets, .smoke]

    var body: some View {
        let suggested = state.suggested.compactMap(JournalTag.init(rawValue:))
        let selected = state.selected.compactMap(JournalTag.init(rawValue:))
        // Stable order (a tapped chip doesn't jump): suggested, the quick four, then anything else switched on.
        let shown = Array((suggested + Self.quick + selected).uniqued().prefix(4))
        HStack(spacing: 6) {
            ForEach(shown, id: \.self) { t in
                let on = state.selected.contains(t.rawValue)
                Button(intent: QuickRecordTagIntent(tag: t.rawValue)) {
                    Text(t.label).font(.caption.weight(.semibold)).lineLimit(1)
                        .foregroundStyle(on ? .black : .white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(on ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.14))))
                        .overlay {
                            if suggested.contains(t) && !on {
                                Capsule().strokeBorder(.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

private struct KindTag: View {
    let state: QuickRecordAttributes.ContentState
    var body: some View {
        Text(state.kind ?? "").font(.caption.weight(.semibold)).foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.14)))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.2), lineWidth: 1))
    }
}

/// The app's riso grain gathered into a ring: a hex grid of dots, swollen and inked near the ring.
/// Still (Live Activities don't animate continuously); fuller while listening.
private struct DotRing: View {
    let ink: Color
    let strength: Double

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let ring = min(size.width, size.height) * 0.36
            let spacing: CGFloat = 5
            let n = Int(size.width / spacing) + 2
            for i in -n...n {
                for j in -n...n {
                    let x = c.x + CGFloat(i) * spacing + CGFloat(j % 2) * spacing / 2
                    let y = c.y + CGFloat(j) * spacing * 0.866
                    let d = hypot(x - c.x, y - c.y)
                    guard d < size.width / 2 else { continue }
                    let near = max(0, 1 - abs(d - ring) / (7 + 6 * strength))
                    let r = 0.45 + near * near * (1.1 + 1.0 * strength)
                    let color = near > 0.05 ? ink.opacity(0.15 + 0.85 * near * (0.5 + 0.5 * strength)) : .white.opacity(0.1)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(color))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private enum Copy {
    static func title(_ p: QuickRecordAttributes.Phase) -> String {
        switch p {
        case .standby: "Here if you need it."
        case .ready: "What's going on?"
        case .recording: "Listening…"
        case .writing: "Writing it down…"
        case .review: "Anything else?"
        case .saved: "Saved."
        case .needsMic: "Microphone is off"
        }
    }

    /// Tapping the card opens the in-app recorder for its moment (or just the app, on standby).
    static func url(_ s: QuickRecordAttributes.ContentState) -> URL? {
        URL(string: "feltair://record/\(s.momentID ?? "")")
    }

    @ViewBuilder static func detail(_ s: QuickRecordAttributes.ContentState) -> some View {
        switch s.phase {
        case .standby: Text("The mic logs a rescue and listens.")
        case .ready: Text("Where you were, what you were doing.")
        case .recording:
            if let start = s.startedAt {
                Text(timerInterval: start...start.addingTimeInterval(QuickRecordAttributes.maxSeconds), countsDown: false)
                    .monospacedDigit()
            }
        case .writing: Text("On this iPhone.")
        case .review:
            if let w = s.words { Text("“\(w)”").italic() } else { Text("Tap what counts, then Save.") }
        case .saved: Text("In your journal, on this iPhone.")
        case .needsMic: Text("Open felt air to allow it, or tap a tag.")
        }
    }
}

/// Widget-side copies of the few tokens the Lock Screen needs (the extension can't see the app's Theme).
enum Ink {
    /// Theme.rescueSoft / Theme.standardSoft, dark values.
    static func pastel(_ s: QuickRecordAttributes.ContentState) -> Color {
        s.isRescue ? Color(red: 1, green: 0xC9 / 255, blue: 0xA3 / 255) : Color(red: 0xB4 / 255, green: 0xDC / 255, blue: 0xF7 / 255)
    }

    /// Recursive at the "plain" voice (a little casual, no cursive), as the app's sentence. Falls back to New York.
    static func sentence(_ size: CGFloat) -> Font {
        guard let base = UIFont(name: "Recursive-SansLinearLight", size: size) else {
            return .system(size: size, weight: .regular, design: .serif)
        }
        func tag(_ s: String) -> UInt32 { s.utf8.reduce(0) { $0 << 8 | UInt32($1) } }
        let variations: [UInt32: CGFloat] = [tag("CASL"): 0.25, tag("MONO"): 0, tag("wght"): 400, tag("slnt"): 0, tag("CRSV"): 0]
        let key = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        return Font(UIFont(descriptor: base.fontDescriptor.addingAttributes([key: variations]), size: size) as CTFont)
    }
}

/// Lock Screen / Control Center / Action button: record a note for the latest moment.
struct QuickRecordControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "felt-air.voice-note") {
            ControlWidgetButton(action: QuickRecordStartIntent()) {
                Label("Voice note", systemImage: "mic.fill")
            }
        }
        .displayName("felt air voice note")
        .description("Say what was going on at your latest moment.")
    }
}

/// Control Center / Lock Screen / Action button: log a rescue in one tap.
struct LogRescueControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "felt-air.log-rescue") {
            ControlWidgetButton(action: LogRescueIntent()) {
                Label("Log rescue", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Log a rescue")
        .description("Logs a rescue inhaler use now, with the air around you.")
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
