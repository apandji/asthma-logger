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

/// The Lock Screen recorder in the app's look (April, Nov 20): light paper, Figtree, black ink, the + button's
/// black circle, Home's black moment tag and the journal's grey chips. The Dynamic Island stays dark (it's
/// the system's), in the same type.
struct QuickRecordLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: QuickRecordAttributes.self) { context in
            QuickRecordLockView(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Ink.paper)
                .activitySystemActionForegroundColor(.black)
                .widgetURL(Copy.url(context.state))
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    KindTag(state: s, dark: true).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    MainButton(state: s, size: 44, dark: true)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Copy.title(s.phase)).font(Ink.figtree(18, .medium)).foregroundStyle(.white)
                        Copy.detail(s).font(Ink.figtree(13)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: s.phase == .recording ? "waveform" : "mic.fill")
                    .foregroundStyle(s.phase == .standby ? Color.white.opacity(0.4) : Color.white)
            } compactTrailing: {
                if s.phase == .standby {
                    EmptyView()
                } else if s.phase == .recording, let start = s.startedAt {
                    Text(timerInterval: start...start.addingTimeInterval(QuickRecordAttributes.maxSeconds), countsDown: false)
                        .monospacedDigit().frame(width: 40).foregroundStyle(.white)
                } else {
                    Text(s.kind ?? "").font(Ink.figtree(13, .medium)).foregroundStyle(.white)
                }
            } minimal: {
                Image(systemName: "mic.fill").foregroundStyle(s.phase == .standby ? Color.white.opacity(0.4) : Color.white)
            }
            .widgetURL(Copy.url(s))
            .keylineTint(.white)
        }
    }
}

struct QuickRecordLockView: View {
    let state: QuickRecordAttributes.ContentState
    let isStale: Bool

    var body: some View {
        // A Lock Screen Live Activity is at most 160 pt tall: everything is sized to fit that.
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if state.phase == .standby {
                    Text("felt air").font(Ink.figtree(13, .medium)).foregroundStyle(Ink.secondary)
                } else {
                    KindTag(state: state, dark: false)
                }
                Text(state.whenAndWhere ?? "").font(Ink.figtree(13, .medium)).foregroundStyle(Ink.secondary).lineLimit(1)
                Spacer(minLength: 0)
                if state.phase != .saved {
                    Button(intent: QuickRecordDismissIntent()) {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Ink.secondary)
                            .frame(width: 24, height: 24).background(Circle().fill(.black.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Not now")
                }
            }
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(isStale && state.phase == .ready ? "Still want to add to your journal?" : Copy.title(state.phase))
                        .font(Ink.figtree(20, .medium)).foregroundStyle(.black).lineLimit(1).minimumScaleFactor(0.75)
                    Copy.detail(state).font(Ink.figtree(13)).foregroundStyle(Ink.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                MainButton(state: state, size: 48, dark: false)
            }
            if state.phase == .ready || state.phase == .review || state.phase == .needsMic {
                Chips(state: state)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

/// Record / stop / save: the one control, the + button's black circle.
private struct MainButton: View {
    let state: QuickRecordAttributes.ContentState
    let size: CGFloat
    /// In the Dynamic Island (dark): white circle, black symbol.
    let dark: Bool

    var body: some View {
        switch state.phase {
        case .standby:
            // Logs a rescue (or uses one from the last 10 minutes) and listens.
            Button(intent: QuickRecordStartIntent(momentID: nil)) { circle("mic.fill") }
                .buttonStyle(.plain).accessibilityLabel("Log a rescue and record a voice note")
        case .ready, .needsMic:
            Button(intent: QuickRecordStartIntent(momentID: state.momentID)) { circle("mic.fill") }
                .buttonStyle(.plain).accessibilityLabel("Record a voice note")
        case .recording:
            Button(intent: QuickRecordStopIntent()) { circle("stop.fill") }
                .buttonStyle(.plain).accessibilityLabel("Stop")
        case .writing:
            ProgressView().tint(dark ? .white : .black).frame(width: size, height: size)
        case .review:
            Button(intent: QuickRecordSaveIntent()) {
                Text("Save").font(Ink.figtree(15, .medium)).foregroundStyle(dark ? .black : .white)
                    .frame(width: size + 16, height: size * 0.72).background(Capsule().fill(dark ? .white : .black))
            }
            .buttonStyle(.plain)
        case .saved:
            circle("checkmark")
        }
    }

    private func circle(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.38, weight: .medium))
            .foregroundStyle(dark ? .black : .white)
            .frame(width: size, height: size)
            .background(Circle().fill(dark ? .white : .black))
    }
}

/// Quick tags, as the journal's chips: grey, black when chosen. After the note, the suggested ones first.
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
                    Text(t.label).font(Ink.figtree(13, .medium)).lineLimit(1)
                        .foregroundStyle(on ? .white : .black)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(Capsule().fill(on ? AnyShapeStyle(.black) : AnyShapeStyle(.black.opacity(0.07))))
                        .overlay {
                            if suggested.contains(t) && !on {
                                Capsule().strokeBorder(.black.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

/// Home's moment tag: a black pill with the inhaler symbol (white in the dark island).
private struct KindTag: View {
    let state: QuickRecordAttributes.ContentState
    let dark: Bool
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state.isRescue ? "inhaler" : "circle.dashed").font(.system(size: 11, weight: .semibold))
            Text(state.kind ?? "").font(Ink.figtree(13, .medium))
        }
        .foregroundStyle(dark ? .black : .white)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Capsule().fill(dark ? .white : .black))
    }
}

private enum Copy {
    static func title(_ p: QuickRecordAttributes.Phase) -> String {
        switch p {
        case .standby: "Here if you need it."
        case .ready: "What was going on?"
        case .recording: "Listening…"
        case .writing: "Writing it down…"
        case .review: "Anything else?"
        case .saved: "In your journal."
        case .needsMic: "Microphone is off"
        }
    }

    /// Tapping the card opens the in-app recorder for its moment (or just the app, on standby).
    static func url(_ s: QuickRecordAttributes.ContentState) -> URL? {
        URL(string: "feltair://record/\(s.momentID ?? "")")
    }

    @ViewBuilder static func detail(_ s: QuickRecordAttributes.ContentState) -> some View {
        switch s.phase {
        case .standby: Text("The mic logs a moment and listens.")
        case .ready: Text("Where you were, what you were doing.")
        case .recording:
            if let start = s.startedAt {
                Text(timerInterval: start...start.addingTimeInterval(QuickRecordAttributes.maxSeconds), countsDown: false)
                    .monospacedDigit()
            }
        case .writing: Text("On this iPhone.")
        case .review:
            if let w = s.words { Text("“\(w)”").italic() } else { Text("Tap what fits, then Save.") }
        case .saved: Text("Saved on this iPhone.")
        case .needsMic: Text("Open felt air to allow it, or tap what fits.")
        }
    }
}

/// Widget-side copies of the few tokens the Lock Screen needs (the extension can't see the app's Theme).
enum Ink {
    /// The app's paper (systemGroupedBackground, light).
    static let paper = Color(red: 0.949, green: 0.949, blue: 0.969)
    static let secondary = Color(red: 0.24, green: 0.24, blue: 0.26).opacity(0.6)

    /// Figtree, as the app sets it: the variable font's weight axis, medium the heaviest. Falls back to SF.
    static func figtree(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let w: CGFloat = weight == .medium || weight == .semibold || weight == .bold ? 500 : 400
        let desc = UIFontDescriptor(fontAttributes: [.family: "Figtree"])
            .addingAttributes([UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [0x77676874: w]])
        let font = UIFont(descriptor: desc, size: size)
        return font.familyName == "Figtree" ? Font(font) : .system(size: size, weight: weight)
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
