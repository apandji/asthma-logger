import AsthmaCore
import CoreMotion
import SwiftUI

/// Voice and Body: stops on the rail like the air's, reading beside the thumb. Let go on either and it stays
/// open. In words, never numbers.

/// The shared panel look: the same glass label as a reading on the rail.
private struct RailPanel<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.subheadline.weight(.semibold))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

/// A grey label and its value on one line, one size throughout.
private struct BodyLine: View {
    let name: String
    let text: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(name).font(.caption.weight(.medium)).foregroundStyle(Theme.secondaryText).frame(width: 64, alignment: .leading)
            Text(text).font(.subheadline)
        }
    }
}

/// Voice, a stop on the rail. Slide into this panel to record (lift to stop), or tap Record once you've let go.
/// Then a light review: your words (fix them if they came out wrong), the tags they suggest, Save or Redo.
struct VoicePanel: View {
    let event: LogEvent?
    let session: VoiceSession
    /// False while the thumb is still on the rail.
    let interactive: Bool
    let save: () -> Void

    var body: some View {
        RailPanel(title: "Your voice", icon: Icons.voice) {
            switch session.phase {
            case .idle: idle
            case .recording: recording
            case .writing:
                HStack(spacing: 8) { ProgressView(); Text("Writing it down…").font(.subheadline) }
            case .review: review
            }
        }
    }

    @ViewBuilder private var idle: some View {
        let text = (event?.voiceTranscript ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            Text("“\(text)”").font(.subheadline).italic().lineLimit(4)
        }
        if let tags = event?.tags, !tags.isEmpty {
            Text(tags.sorted().map(\.label).joined(separator: " · ")).font(.caption.weight(.semibold))
        }
        if session.denied {
            Text("The microphone is off for felt air. Turn it on in Settings › felt air.").font(.caption).foregroundStyle(Theme.secondaryText)
        } else if interactive {
            Button { Task { await session.start() } } label: {
                Label(text.isEmpty ? "Record" : "Add more", systemImage: "mic.fill")
                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 8)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
            .buttonStyle(PressStyle())
        } else {
            Label("Slide in to record", systemImage: "mic").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.secondaryText)
        }
        if event == nil && !interactive {
            Text("Saved as a note, with the air right now.").font(.caption).foregroundStyle(Theme.secondaryText)
        }
    }

    @ViewBuilder private var recording: some View {
        VoiceGrain(level: Double(VoiceNotes.shared.level), listening: true,
                   ink: event?.moment == .rescue || event == nil ? Theme.rescueSoft : Theme.standardSoft)
            .frame(height: 96)
        HStack {
            Text("Listening…").font(.subheadline.weight(.semibold))
            Spacer()
            if let start = session.startedAt {
                TimelineView(.periodic(from: .now, by: 1)) { tl in
                    Text(Duration.seconds(tl.date.timeIntervalSince(start)).formatted(.time(pattern: .minuteSecond)))
                        .font(.subheadline.monospacedDigit()).foregroundStyle(Theme.secondaryText)
                }
            }
        }
        if interactive {
            Button { Task { await session.finish() } } label: {
                Label("Stop", systemImage: "stop.fill").font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
            .buttonStyle(PressStyle())
        } else {
            Text("Lift to stop. Slide back out to cancel.").font(.caption).foregroundStyle(Theme.secondaryText)
        }
    }

    @ViewBuilder private var review: some View {
        @Bindable var session = session
        TextField("No words came through. Type a few if you like.", text: $session.words, axis: .vertical)
            .font(.subheadline).lineLimit(2...5)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.08)))
        FlowLayout(spacing: 6) {
            let quick: [JournalTag] = [.exercise, .coldAir, .pets, .smoke]
            ForEach(session.suggested + quick.filter { !session.suggested.contains($0) }, id: \.self) { t in
                let on = session.chosen.contains(t)
                Button {
                    if on { session.chosen.remove(t) } else { session.chosen.insert(t) }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Text(t.label).font(.caption.weight(.semibold))
                        .foregroundStyle(on ? Color.black : .primary)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(on ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.primary.opacity(0.12))))
                }
                .buttonStyle(PressStyle())
            }
        }
        HStack(spacing: 12) {
            Button("Redo") { session.discard() }
                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            Spacer()
            Button(action: save) {
                Text("Save").font(.subheadline.weight(.semibold)).foregroundStyle(.black)
                    .padding(.horizontal, 22).padding(.vertical, 8)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(PressStyle())
        }
    }
}

/// Your body: activity (motion sensor) and Apple Health (sleep, heart, breathing), in words.
struct BodyPanel: View {
    let date: Date
    let interactive: Bool
    @State private var activity: String?
    @State private var health: HealthReader.Words?
    @State private var askHealth = false

    var body: some View {
        RailPanel(title: "Your body", icon: Icons.body) {
            BodyLine(name: "Activity", text: activity ?? "…")
            if let h = health {
                if let v = h.sleep { BodyLine(name: "Sleep", text: v) }
                if let v = h.heart { BodyLine(name: "Heart", text: v) }
                if let v = h.breathing { BodyLine(name: "Breathing", text: v) }
            }
            if askHealth {
                Button { Task { await HealthReader.shared.ask(); await load() } } label: {
                    Label("Connect Apple Health", systemImage: "heart.fill")
                        .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 8)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(PressStyle())
                .disabled(!interactive)
                .opacity(interactive ? 1 : 0.5)
                Text("Adds sleep, heart and breathing, in words.").font(.caption).foregroundStyle(Theme.secondaryText)
            }
        }
        .task(id: date) { await load() }
    }

    private func load() async {
        askHealth = await HealthReader.shared.shouldAsk()
        activity = await ActivityWords.before(date)
        health = askHealth ? nil : await HealthReader.shared.words(before: date)
    }
}

/// Steps in the two hours before a time, as words. iOS keeps a week of pedometer data; older than that, or
/// without Motion & Fitness, there's nothing to say.
enum ActivityWords {
    nonisolated static func before(_ date: Date) async -> String {
        guard CMPedometer.isStepCountingAvailable() else { return "Not available on this iPhone." }
        guard date > Date().addingTimeInterval(-7 * 86_400) else { return "Too long ago: iOS keeps a week of activity." }
        let from = date.addingTimeInterval(-2 * 3600)
        let pedometer = CMPedometer()   // held until it answers (freed early, it never replies)
        let steps: Int? = await withCheckedContinuation { c in
            pedometer.queryPedometerData(from: from, to: min(date, .now)) { @Sendable data, _ in
                c.resume(returning: data?.numberOfSteps.intValue)
            }
        }
        _ = pedometer
        guard let steps else { return "No activity recorded." }
        switch steps {
        case ..<300: return "Mostly still."
        case ..<1500: return "Some walking."
        case ..<4000: return "A fair bit of walking."
        default: return "A lot of walking."
        }
    }
}
