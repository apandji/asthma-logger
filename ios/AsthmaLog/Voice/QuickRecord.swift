import AsthmaCore
import Foundation
import Observation
import Speech
import SwiftData
import SwiftUI
import UserNotifications

/// Quick Record (FigJam "On Quick Record"): a press on the felt button (or the watch) logs the moment, then a
/// notification offers to add what was going on while it's fresh. **Add a voice note** opens the recorder;
/// the quick tags log a tag without opening the app. At 6 pm, if today's rescue moments have no note, one
/// nudge. Nothing leaves the phone: audio and transcript stay on it, transcription is on-device when the phone
/// supports it.
@MainActor @Observable
final class QuickRecordCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = QuickRecordCenter()

    /// The moment to open the recorder for (set by a notification tap or the toast's Note button).
    var pending: UUID?
    @ObservationIgnored var container: ModelContainer?

    static let category = "quickRecord"
    static let evening = "eveningSummary"
    enum Action: String { case record, exercise, coldAir, pets }

    /// Registers the notification actions. Asks nothing.
    func start(container: ModelContainer) {
        self.container = container
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let record = UNNotificationAction(identifier: Action.record.rawValue, title: "Add a voice note",
                                          options: [.foreground], icon: UNNotificationActionIcon(systemImageName: "mic.fill"))
        // Quick tags log without opening the app. "Not sure" is just dismissing the notification.
        let tags = [(Action.exercise, JournalTag.exercise), (.coldAir, .coldAir), (.pets, .pets)].map { a, t in
            UNNotificationAction(identifier: a.rawValue, title: t.label, options: [])
        }
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.category, actions: [record] + tags, intentIdentifiers: []),
        ])
    }

    /// The notifications prompt. Asked from onboarding's permissions step or Settings, never on its own.
    func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    var enabled: Bool { UserDefaults.standard.object(forKey: Prefs.quickRecord) as? Bool ?? true }

    /// After a press from the button or the watch: "Rescue logged · Add what was going on, while it's fresh."
    func notify(for event: LogEvent) {
        guard enabled, event.moment != .okay else { return }
        let c = UNMutableNotificationContent()
        c.title = "\(event.moment == .rescue ? "Rescue" : "Standard") logged"
        c.subtitle = event.placeName ?? ""
        c.body = "Add what was going on, while it's fresh."
        c.sound = .default
        c.categoryIdentifier = Self.category
        c.userInfo = ["moment": event.id.uuidString]
        c.threadIdentifier = "moments"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: event.id.uuidString, content: c, trigger: nil))
        scheduleEvening()
    }

    /// One nudge at 6 pm for today's rescue moments that have no note or reviewed tags.
    func scheduleEvening() {
        guard enabled, let ctx = container?.mainContext else { return }
        let start = Calendar.current.startOfDay(for: .now)
        let rescue = MomentKind.rescue.rawValue
        let today = (try? ctx.fetch(FetchDescriptor<LogEvent>(predicate: #Predicate { $0.loggedAt >= start && $0.kindRaw == rescue }))) ?? []
        let open = today.filter { !$0.isDemo && !$0.tagsReviewed && ($0.voiceTranscript ?? "").isEmpty }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.evening])
        guard let first = open.first,
              let six = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: .now), six > .now else { return }
        let c = UNMutableNotificationContent()
        c.title = open.count == 1 ? "One moment today" : "\(open.count) moments today"
        c.body = "Add what was going on, so felt air can learn what your flare days share."
        c.sound = .default
        c.categoryIdentifier = Self.category
        c.userInfo = ["moment": first.id.uuidString]
        let when = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: six)
        center.add(UNNotificationRequest(identifier: Self.evening, content: c,
                                         trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false)))
    }

    // MARK: UNUserNotificationCenterDelegate

    /// In the app the toast already says it; no banner on top of it.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        []
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let idString = response.notification.request.content.userInfo["moment"] as? String
        let action = response.actionIdentifier
        await MainActor.run {
            guard let idString, let id = UUID(uuidString: idString) else { return }
            switch Action(rawValue: action) {
            case .record?: pending = id
            case .exercise?: tag(id, .exercise)
            case .coldAir?: tag(id, .coldAir)
            case .pets?: tag(id, .pets)
            case nil:
                // A plain tap on the notification opens the recorder too.
                if action == UNNotificationDefaultActionIdentifier { pending = id }
            }
        }
    }

    private func tag(_ id: UUID, _ t: JournalTag) {
        guard let ctx = container?.mainContext,
              let e = try? ctx.fetch(FetchDescriptor<LogEvent>(predicate: #Predicate { $0.id == id })).first else { return }
        e.tags.insert(t)
        e.tagsReviewed = true
        try? ctx.save()
        scheduleEvening()
    }
}

/// On-device speech to text for a recorded note. Fails open: no permission or no recognizer → no transcript.
/// `nonisolated`: Speech calls back on its own queues, and a main-actor closure there traps (the stop crash).
nonisolated enum NoteTranscriber {
    /// Asks for speech recognition once (before recording, so the prompt doesn't land mid-transcript).
    static func authorize() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() != .notDetermined { return SFSpeechRecognizer.authorizationStatus() == .authorized }
        let status = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { @Sendable s in c.resume(returning: s) }
        }
        return status == .authorized
    }

    static func transcribe(_ url: URL) async -> String? {
        guard await authorize(), let r = SFSpeechRecognizer(), r.isAvailable else { return nil }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = r.supportsOnDeviceRecognition
        request.shouldReportPartialResults = false
        return await withCheckedContinuation { (c: CheckedContinuation<String?, Never>) in
            let once = Once()
            r.recognitionTask(with: request) { @Sendable result, error in
                if let result, result.isFinal {
                    let text = result.bestTranscription.formattedString
                    once.run { c.resume(returning: text) }
                } else if error != nil {
                    once.run { c.resume(returning: nil) }
                }
            }
        }
    }

    /// Resumes the continuation exactly once, whichever callback comes first.
    private final class Once: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func run(_ body: () -> Void) {
            lock.lock(); defer { lock.unlock() }
            guard !done else { return }
            done = true
            body()
        }
    }
}

/// The on-device model as a tag proposer for `VoiceNoteTagger` (keyword rules still run without it).
struct ModelTagProposer: TagProposer {
    func proposeTags(for transcript: String, instructions: String) async throws -> [String] {
        await OnDeviceModel.suggestTags(for: transcript).map(\.rawValue)
    }
}

/// The recorder, in the home's language: the moment's tag and place, the serif question, a field of riso
/// grain that gathers into a ring and swells with your voice, one glass button. Then the words, suggested
/// tags to confirm, and Save.
struct QuickRecordView: View {
    let event: LogEvent
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var notes = VoiceNotes.shared
    @State private var phase = Phase.ready
    @State private var started: Date?
    @State private var transcript = ""
    @State private var suggested: [JournalTag] = []
    @State private var confirmed: Set<JournalTag> = []

    enum Phase { case ready, recording, transcribing, review }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VerdictHeader(tag: event.moment,
                          place: AnyView(Text(event.whenAndWhere).font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondaryText).lineLimit(1)),
                          title: title, verdict: nil, tint: nil)
            if phase == .review {
                review.transition(.opacity)
            } else {
                VoiceGrain(level: phase == .recording ? Double(notes.level) : 0, listening: phase == .recording,
                           ink: event.moment == .rescue ? Theme.rescueSoft : Theme.standardSoft)
                    .frame(maxHeight: .infinity)
                    .overlay(alignment: .bottom) {
                        if phase == .recording, let started {
                            TimelineView(.periodic(from: .now, by: 1)) { tl in
                                Text(Duration.seconds(tl.date.timeIntervalSince(started)).formatted(.time(pattern: .minuteSecond)))
                                    .font(.subheadline.monospacedDigit()).foregroundStyle(Theme.secondaryText)
                            }
                            .padding(.bottom, 8)
                        }
                    }
                controls
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            ZStack { Color.black; SkyGrain(responds: false).opacity(0.5) }.ignoresSafeArea()
        }
        .environment(\.colorScheme, .dark)
        .animation(Theme.smooth, value: phase)
        .onAppear { confirmed = event.tags; transcript = event.voiceTranscript ?? "" }
        .onDisappear { if phase == .recording { notes.stopRecording() } }
    }

    private var title: String {
        switch phase {
        case .ready: "What's going on?"
        case .recording: "Listening…"
        case .transcribing: "Writing it down…"
        case .review: "Anything else that counts?"
        }
    }

    // MARK: Record

    private var controls: some View {
        VStack(spacing: 14) {
            Button(action: toggle) {
                Image(systemName: phase == .recording ? "stop.fill" : "mic.fill")
                    .font(.title2.weight(.semibold))
                    .frame(width: 76, height: 76)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(PressStyle())
            .disabled(phase == .transcribing)
            .accessibilityLabel(phase == .recording ? "Stop" : "Record a voice note")
            if notes.denied {
                Text("The microphone is off for felt air. Turn it on in Settings › felt air, or tap a tag below.")
                    .font(.footnote).foregroundStyle(Theme.secondaryText).multilineTextAlignment(.center)
            } else {
                Text(phase == .recording ? "Tap to finish." : "Say where you were and what you were doing.")
                    .font(.footnote).foregroundStyle(Theme.secondaryText)
            }
            quickTags
            HStack {
                Button("Not now") { dismiss() }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                Spacer()
                if !confirmed.isEmpty {
                    Button("Save tags") { save() }.font(.subheadline.weight(.semibold))
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 16)
    }

    private func toggle() {
        if phase == .recording {
            notes.stopRecording()
            phase = .transcribing
            Task {
                if let file = event.voiceNoteFile, let text = await NoteTranscriber.transcribe(notes.url(file)) {
                    transcript = text
                    let result = await VoiceNoteTagger.suggest(transcript: text, using: ModelTagProposer())
                    suggested = result.suggestions.map(\.tag)
                    confirmed.formUnion(suggested)
                }
                phase = .review
            }
        } else {
            Task {
                _ = await NoteTranscriber.authorize()
                if await notes.startRecording(for: event) {
                    started = .now
                    phase = .recording
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        }
    }

    // MARK: Review

    private var review: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your words").font(.caption).foregroundStyle(Theme.secondaryText)
                    TextField("No words came through. Type a few if you like.", text: $transcript, axis: .vertical)
                        .font(.body).lineLimit(2...6)
                        .padding(14)
                        .glassEffect(.regular, in: .rect(cornerRadius: 18))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(suggested.isEmpty ? "Tags" : "Tags (suggested from your words; tap to change)")
                        .font(.caption).foregroundStyle(Theme.secondaryText)
                    TagGrid(all: JournalTag.allCases, selected: $confirmed, highlighted: Set(suggested))
                }
                Button(action: save) {
                    Text("Save").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .foregroundStyle(.black).background(Capsule().fill(.white))
                }
                .buttonStyle(PressStyle())
                Text("Your note and words stay on this iPhone.").font(.caption).foregroundStyle(Theme.secondaryText)
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }

    private var quickTags: some View {
        HStack(spacing: 8) {
            ForEach([JournalTag.exercise, .coldAir, .pets, .smoke], id: \.self) { t in
                TagChip(tag: t, on: confirmed.contains(t)) { toggle(t) }
            }
        }
    }

    private func toggle(_ t: JournalTag) {
        if confirmed.contains(t) { confirmed.remove(t) } else { confirmed.insert(t) }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func save() {
        event.tags = confirmed
        event.tagsReviewed = true
        let words = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        event.voiceTranscript = words.isEmpty ? nil : words
        try? context.save()
        QuickRecordCenter.shared.scheduleEvening()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

/// A tag you can tap: glass when off, white when on.
struct TagChip: View {
    let tag: JournalTag
    let on: Bool
    var highlighted = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tag.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(on ? Color.black : .primary)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background { if on { Capsule().fill(.white) } }
                .glassEffect(on ? .identity : .regular.interactive(), in: .capsule)
                .overlay { if highlighted && !on { Capsule().strokeBorder(.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 3])) } }
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct TagGrid: View {
    let all: [JournalTag]
    @Binding var selected: Set<JournalTag>
    var highlighted: Set<JournalTag> = []

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(all, id: \.self) { t in
                TagChip(tag: t, on: selected.contains(t), highlighted: highlighted.contains(t)) {
                    if selected.contains(t) { selected.remove(t) } else { selected.insert(t) }
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
        }
    }
}

/// Wraps chips onto as many lines as they need.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width, x > 0 { x = 0; y += row + spacing; row = 0 }
            x += s.width + spacing; row = max(row, s.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += row + spacing; row = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; row = max(row, s.height)
        }
    }
}

/// The voice, drawn in the app's riso grain: at rest the dots scatter faintly; while you talk they gather into
/// a ring around the centre that swells with your voice, in the inhaler's pastel. Reduce Motion: a still ring.
struct VoiceGrain: View {
    let level: Double
    let listening: Bool
    let ink: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var smoothed = 0.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { frame in
            let t = reduceMotion ? 0 : frame.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let base = min(size.width, size.height) * 0.28
                let spacing: CGFloat = 9
                let n = Int(max(size.width, size.height) / spacing) + 2
                let lv = CGFloat(smoothed)
                for i in -n...n {
                    for j in -n...n {
                        let x = c.x + CGFloat(i) * spacing + CGFloat(j % 2) * spacing / 2
                        let y = c.y + CGFloat(j) * spacing * 0.866
                        let d = hypot(x - c.x, y - c.y)
                        // The ring breathes with the voice; a little wobble so it reads as sound, not a circle.
                        let angle = atan2(y - c.y, x - c.x)
                        let wobble = 6 * lv * CGFloat(sin(Double(angle) * 5 + t * 3)) + 3 * CGFloat(sin(t * 1.2))
                        let ring = base * (1 + 0.35 * lv) + wobble
                        let width = 18 + 30 * lv
                        let near = max(0, 1 - abs(d - ring) / width)
                        var r: CGFloat = 0.6
                        var color = Color.white.opacity(0.12)
                        if listening || near > 0.5 {
                            r += near * near * (2.6 + 3 * lv)
                            color = (near > 0.05 ? ink : .white).opacity(0.12 + 0.8 * Double(near))
                        } else if d < ring {
                            color = Color.white.opacity(0.16)
                        }
                        guard r > 0.2, x > -4, y > -4, x < size.width + 4, y < size.height + 4 else { continue }
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(color))
                    }
                }
            }
        }
        .onChange(of: level) { _, v in withAnimation(.easeOut(duration: 0.12)) { smoothed = v } }
        .accessibilityHidden(true)
    }
}
