import AsthmaCore
import CoreMotion
import SwiftUI

/// Voice and Body: stops on the rail like the air's, reading beside the thumb. Let go on either and it stays
/// open. In words, never numbers.

/// The shared panel look: the same glass label as a reading on the rail.
private struct RailPanel<Content: View>: View {
    let title: String
    let icon: String
    /// Recording: the glass takes the inhaler's ink, so the panel reads as live, not a card.
    var tint: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.subheadline.weight(.semibold))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassEffect(tint.map { .regular.tint($0.opacity(0.22)) } ?? .regular, in: .rect(cornerRadius: 16))
        .overlay {
            if let tint {
                RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(tint.opacity(0.7), lineWidth: 1.5)
            }
        }
        .animation(Theme.smooth, value: tint != nil)
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
        let ink = event?.moment == .rescue || event == nil ? Theme.rescueSoft : Theme.standardSoft
        RailPanel(title: session.phase == .recording ? "Recording" : "Your voice", icon: Icons.voice,
                  tint: session.phase == .recording ? ink : nil) {
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
            Label("Keep holding to record", systemImage: "mic").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.secondaryText)
        }
        if event == nil && !interactive {
            Text("Saved as a note, with the air right now.").font(.caption).foregroundStyle(Theme.secondaryText)
        }
    }

    @ViewBuilder private var recording: some View {
        let ink = event?.moment == .rescue || event == nil ? Theme.rescueSoft : Theme.standardSoft
        VoiceGrain(level: Double(VoiceNotes.shared.level), listening: true, ink: ink)
            .frame(height: 72)
        // Your words as you say them, and the ones felt air is picking up lit in the inhaler's ink: this is
        // data capture, not a voice memo. Older lines scroll off the top.
        LiveWords(text: VoiceNotes.shared.liveWords, ink: ink)
        // A past-tense prompt, rotating, so there's always something to answer; "keep going" once you've begun.
        Text(VoiceNotes.shared.liveWords.isEmpty ? VoicePrompts.first(for: event) : VoicePrompts.next(after: VoiceNotes.shared.liveWords))
            .font(.subheadline).foregroundStyle(Theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .contentTransition(.opacity)
            .animation(Theme.smooth, value: VoiceNotes.shared.liveWords.isEmpty)
        HStack {
            Label(VoiceNotes.shared.liveWords.isEmpty ? "Listening" : "Still listening", systemImage: "waveform")
                .font(.caption.weight(.semibold)).foregroundStyle(ink)
                .symbolEffect(.variableColor.iterative, options: .repeating)
            Spacer()
            if let start = session.startedAt {
                TimelineView(.periodic(from: .now, by: 1)) { tl in
                    Text(Duration.seconds(tl.date.timeIntervalSince(start)).formatted(.time(pattern: .minuteSecond)))
                        .font(.caption.monospacedDigit()).foregroundStyle(Theme.secondaryText)
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
            Text("Lift to stop.").font(.caption).foregroundStyle(Theme.secondaryText)
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

/// The transcript as it's being written: each new word slides in, the latest a touch brighter, and the text
/// keeps its tail (head truncation) so you always see what you just said.
struct LiveWords: View {
    let text: String
    var ink: Color = Theme.rescueSoft
    var font: Font = .subheadline
    var lineLimit: Int? = 3
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let words = text.split(separator: " ").map(String.init)
        Group {
            if words.isEmpty {
                Text(" ").font(.subheadline)
            } else {
                // One Text so it wraps as a paragraph. Words that match a tag rule light up in the ink
                // (not negated ones: "no smoke" stays plain); the newest word is brightest.
                let lit = Self.litWords(in: text)
                words.enumerated().reduce(Text(verbatim: "")) { acc, pair in
                    let (i, w) = pair
                    let clean = w.lowercased().trimmingCharacters(in: .punctuationCharacters)
                    let piece: Text
                    switch lit[clean] {
                    case .symptom?, .outcome?: piece = Text(w).foregroundStyle(Theme.symptom).fontWeight(.semibold)
                    case .trigger?: piece = Text(w).foregroundStyle(ink).fontWeight(.semibold)
                    case nil: piece = Text(w).foregroundStyle(.primary.opacity(i == words.count - 1 ? 1 : 0.75))
                    }
                    return acc + piece + Text(i == words.count - 1 ? "" : " ")
                }
                    .font(font)
                    .lineLimit(lineLimit)
                    .truncationMode(.head)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.interpolate)
                    .animation(reduceMotion ? nil : Theme.snap, value: words.count)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
    }

    /// The words of every positive tag mention in the text, with the kind of tag they named (symptoms and
    /// triggers light in different inks).
    static func litWords(in text: String) -> [String: JournalTag.Kind] {
        var out: [String: JournalTag.Kind] = [:]
        for m in KeywordTagger.scan(text).mentions where !m.negated {
            for w in m.phrase.lowercased().split(separator: " ") { out[String(w)] = m.tag.kind }
        }
        return out
    }
}

/// What to answer, in the past tense (a note often comes hours after the moment). The first prompt rotates
/// per note; after the first words, the one you haven't answered yet, then "keep going".
enum VoicePrompts {
    static let opening = ["What were you doing?", "Where were you?", "How did you feel?", "What was in the air?"]

    static func first(for event: LogEvent?) -> String {
        // Rotates with the moment, so the same person sees a different first question each time.
        let i = Int((event?.loggedAt ?? .now).timeIntervalSince1970 / 60) % opening.count
        return opening[i]
    }

    static func next(after words: String) -> String {
        let w = words.lowercased()
        let doing = ["was ", "were ", "went", "walk", "run", "ran", "clean", "cook", "sleep", "work", "play", "exercis", "gym", "stairs"].contains { w.contains($0) }
        let feeling = ["felt", "feel", "tight", "wheez", "cough", "breath", "chest", "bad", "fine", "worse", "better", "panick"].contains { w.contains($0) }
        let place = ["at ", "in ", "outside", "inside", "indoors", "outdoors", "home", "park", "car", "office", "school", "kitchen", "bed"].contains { w.contains($0) }
        if !feeling { return "How did you feel?" }
        if !doing { return "What were you doing?" }
        if !place { return "Where were you?" }
        return "Keep going…"
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
                if let v = h.workout { BodyLine(name: "Workout", text: v) }
                if let v = h.mind { BodyLine(name: "Mind", text: v) }
                // Asked, and nothing came back (not shared, or no data for the hours): say so rather than
                // dropping the row.
                if h.isEmpty { BodyLine(name: "Health", text: "Nothing to read yet.") }
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
                Text("Adds sleep, heart and breathing, workouts and State of Mind, in words. Stays on this iPhone.").font(.caption).foregroundStyle(Theme.secondaryText)
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
