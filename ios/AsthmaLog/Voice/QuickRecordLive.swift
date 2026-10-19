import ActivityKit
import AsthmaCore
import Foundation
import OSLog
import SwiftData

/// The app side of the Lock Screen recorder. One card lives on the Lock Screen while felt air is ready:
/// - **Standby**, started whenever the app is open (iOS only allows *starting* a Live Activity from the
///   foreground). Its mic logs a rescue and listens, so a note during an attack is one tap, phone locked.
/// - A press on the felt button or the watch arrives in the background, where iOS still allows *updating* the
///   card: it turns into "Rescue logged · What's going on?" and lights the screen with a sound.
/// - Its buttons (record, stop, tags, save) are App Intents that run here. After Save it goes back to standby.
/// Live Activities last up to 8 hours, so standby is refreshed each time the app comes forward.
/// Same recorder, transcriber and tagger as the in-app Quick Record. Nothing leaves the phone.
@MainActor
final class QuickRecordLive {
    static let shared = QuickRecordLive()

    typealias Live = Activity<QuickRecordAttributes>
    typealias State = QuickRecordAttributes.ContentState

    private var container: ModelContainer?
    /// Starts logging a rescue with this id (LogService: stamps the air, writes Health per Settings).
    private var logRescue: ((UUID) -> Void)?
    private var autoStop: Task<Void, Never>?
    private var idle: Task<Void, Never>?
    private let log = Logger(subsystem: "felt-air", category: "QuickRecordLive")

    /// Called from the app's init, so the intents work when the Lock Screen wakes the app in the background.
    func install(container: ModelContainer, logRescue: @escaping (UUID) -> Void) {
        self.container = container
        self.logRescue = logRescue
        QuickRecordBridge.handle = { [weak self] command in await self?.handle(command) }
    }

    /// Settings › "Keep felt air on the Lock Screen".
    var standbyOn: Bool {
        QuickRecordCenter.shared.enabled && (UserDefaults.standard.object(forKey: Prefs.lockScreenReady) as? Bool ?? true)
    }

    private var current: Live? {
        Live.activities.first { $0.activityState == .active || $0.activityState == .stale }
    }

    // MARK: Standby

    /// The app is in the foreground: make sure a fresh card is waiting (or none, if that's switched off).
    func standby() {
        guard standbyOn, ActivityAuthorizationInfo().areActivitiesEnabled else {
            if !standbyOn, current?.content.state.phase == .standby { endAll() }
            return
        }
        if let c = current {
            let s = c.content.state
            let busy = [.recording, .writing].contains(s.phase)
            // A note waiting on an old moment: after an hour it's no longer "while it's fresh".
            if !busy, s.phase != .standby, let e = event(s.momentID), Date().timeIntervalSince(e.loggedAt) > 3600 {
                let id = c.id, standby = content(State(phase: .standby))
                Task { await Self.update(id, standby, alert: nil) }
            }
            // Keep a card younger than 4 hours; restart an older one so the 8-hour limit stays far away.
            let age = Date().timeIntervalSince(UserDefaults.standard.object(forKey: Self.startedKey) as? Date ?? .distantPast)
            if busy || age < 4 * 3600 { return }
        }
        endAll()
        _ = request(State(phase: .standby))
    }

    /// After a rescue or standard moment. True when the card now shows it; false when there's no card and iOS
    /// won't start one (background), so the caller sends the notification.
    @discardableResult
    func begin(for e: LogEvent) -> Bool {
        guard QuickRecordCenter.shared.enabled, e.moment != .okay else { return false }
        let state = momentState(e, phase: .ready)
        if let c = current {
            if [.recording, .writing].contains(c.content.state.phase) { return true }
            let alert = AlertConfiguration(title: "\(e.moment.title) logged", body: "What's going on? Tap the mic to say.", sound: .default)
            let id = c.id, next = content(state)
            Task { await Self.update(id, next, alert: alert) }
            returnToStandby(after: 30 * 60)
            return true
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled, request(state) else { return false }
        returnToStandby(after: 30 * 60)
        return true
    }

    // MARK: Buttons

    func handle(_ command: QuickRecordCommand) async {
        log.info("handle \(String(describing: command), privacy: .public)")
        switch command {
        case .start(let id): await start(id)
        case .logRescue:
            // Same as a felt button press: a rescue (merging puffs), then the card asks what's going on.
            guard let logRescue else { log.error("logRescue: no logger"); return }
            let id = UUID()
            logRescue(id)
            for _ in 0..<40 {
                if let e = event(id.uuidString) ?? latestMoment(within: 30) { _ = begin(for: e); return }
                try? await Task.sleep(for: .milliseconds(25))
            }
        case .stop: await stop()
        case .toggle(let tag): await toggle(tag)
        case .save: await save()
        case .dismiss:
            if VoiceNotes.shared.recordingID != nil { VoiceNotes.shared.stopRecording() }
            autoStop?.cancel()
            // The ✕ on standby hides the card until the app is next opened; on a note it goes back to standby.
            if current?.content.state.phase == .standby || !standbyOn { endAll() } else { await backToStandby() }
        }
    }

    private func start(_ id: String?) async {
        guard let e = await moment(for: id ?? current?.content.state.momentID) else { log.error("start: no moment"); return }
        idle?.cancel()
        var state = momentState(e, phase: .ready, keeping: current?.content.state)
        guard await VoiceNotes.shared.startRecording(for: e) else {
            log.error("start: recorder refused")
            state.phase = .needsMic
            await show(state)
            return
        }
        try? container?.mainContext.save()
        state.phase = .recording
        state.startedAt = .now
        await show(state)
        autoStop?.cancel()
        autoStop = Task { [weak self] in
            try? await Task.sleep(for: .seconds(QuickRecordAttributes.maxSeconds))
            guard !Task.isCancelled else { return }
            await self?.stop()
        }
    }

    private func stop() async {
        autoStop?.cancel()
        guard let live = current, live.content.state.phase == .recording else { return }
        VoiceNotes.shared.stopRecording()
        var state = live.content.state
        state.phase = .writing
        await Self.update(live.id, content(state), alert: nil)

        if let e = event(state.momentID), let file = e.voiceNoteFile,
           let text = await NoteTranscriber.transcribe(VoiceNotes.shared.url(file)) {
            // The words are the person's own, so they're kept now; tags only count once they press Save.
            e.addNote(file: file, transcript: text, source: "lock_screen")
            try? container?.mainContext.save()
            let result = await VoiceNoteTagger.suggest(transcript: text, using: ModelTagProposer())
            state.words = String(text.prefix(140))
            state.suggested = result.suggestions.map(\.tag.rawValue)
            state.selected = Array(Set(state.selected).union(state.suggested))
        }
        state.phase = .review
        await Self.update(live.id, content(state), alert: nil)
        returnToStandby(after: 30 * 60)
    }

    private func toggle(_ tag: String) async {
        guard let live = current, JournalTag(rawValue: tag) != nil else { return }
        var state = live.content.state
        if let i = state.selected.firstIndex(of: tag) { state.selected.remove(at: i) } else { state.selected.append(tag) }
        // A tag from the first screen counts as an answer: show Save.
        if state.phase == .ready || state.phase == .needsMic { state.phase = .review }
        await Self.update(live.id, content(state), alert: nil)
    }

    private func save() async {
        guard let live = current else { return }
        var state = live.content.state
        if let e = event(state.momentID) {
            e.tags = Set(state.selected.compactMap(JournalTag.init(rawValue:)))
            e.tagsReviewed = true
            try? container?.mainContext.save()
            QuickRecordCenter.shared.scheduleEvening()
        }
        state.phase = .saved
        await Self.update(live.id, content(state), alert: nil)
        try? await Task.sleep(for: .seconds(2.5))
        await backToStandby()
    }

    /// When the in-app recorder saves a note, the Lock Screen card for that moment goes back to standby.
    func finished(momentID: UUID) {
        guard current?.content.state.momentID == momentID.uuidString else { return }
        Task { await backToStandby() }
    }

    // MARK: Helpers

    /// The moment a note is for: the one given, else one logged in the last 10 minutes (a felt button press
    /// just before), else a new rescue. Logging starts in the background so recording isn't kept waiting.
    private func moment(for id: String?) async -> LogEvent? {
        if let e = event(id) { return e }
        if let e = latestMoment(within: 10 * 60) { return e }
        guard let logRescue else { return nil }
        let newID = UUID()
        logRescue(newID)
        for _ in 0..<40 {
            if let e = event(newID.uuidString) { return e }
            try? await Task.sleep(for: .milliseconds(25))
        }
        return nil
    }

    private func backToStandby() async {
        idle?.cancel()
        guard let live = current else { return }
        if standbyOn {
            await Self.update(live.id, content(State(phase: .standby)), alert: nil)
        } else {
            await Self.end(live.id, nil, .immediate)
        }
    }

    /// A note nobody answered goes back to standby. Only runs while the app is awake; `standby()` catches the rest.
    private func returnToStandby(after seconds: TimeInterval) {
        idle?.cancel()
        idle = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self, let live = self.current,
                  ![.recording, .writing, .standby].contains(live.content.state.phase) else { return }
            await self.backToStandby()
        }
    }

    /// Updates the card, or starts one (allowed in the foreground and from the card's own intents).
    private func show(_ state: State) async {
        if let live = current { await Self.update(live.id, content(state), alert: nil) } else { _ = request(state) }
    }

    private static let startedKey = "quickRecordCardStarted"

    private func request(_ state: State) -> Bool {
        do {
            _ = try Live.request(attributes: QuickRecordAttributes(), content: content(state), pushType: nil)
            UserDefaults.standard.set(Date.now, forKey: Self.startedKey)
            return true
        } catch {
            log.info("request refused: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Ends every card (also used by Fresh start).
    func endAll() {
        for a in Live.activities {
            let id = a.id
            Task { await Self.end(id, nil, .immediate) }
        }
    }

    // ActivityKit's update and end are nonisolated; each looks the activity up by id so nothing non-Sendable
    // crosses from the main actor.
    private nonisolated static func update(_ id: String, _ c: ActivityContent<State>, alert: AlertConfiguration?) async {
        await Live.activities.first { $0.id == id }?.update(c, alertConfiguration: alert)
    }

    private nonisolated static func end(_ id: String, _ c: ActivityContent<State>?, _ policy: ActivityUIDismissalPolicy) async {
        await Live.activities.first { $0.id == id }?.end(c, dismissalPolicy: policy)
    }

    private func content(_ state: State) -> ActivityContent<State> {
        // Standby never goes stale; a note does after 30 minutes. Standby sits low among Live Activities.
        ActivityContent(state: state, staleDate: state.phase == .standby ? nil : .now.addingTimeInterval(30 * 60),
                        relevanceScore: state.phase == .standby ? 0 : 50)
    }

    private func momentState(_ e: LogEvent, phase: QuickRecordAttributes.Phase, keeping old: State? = nil) -> State {
        var s = State(phase: phase, momentID: e.id.uuidString, kind: e.moment.title, isRescue: e.moment == .rescue,
                      whenAndWhere: e.whenAndWhere)
        let same = old?.momentID == e.id.uuidString
        s.selected = same ? old?.selected ?? [] : e.tags.map(\.rawValue)
        s.suggested = same ? old?.suggested ?? [] : []
        return s
    }

    private func event(_ id: String?) -> LogEvent? {
        guard let id, let uuid = UUID(uuidString: id), let ctx = container?.mainContext else { return nil }
        return try? ctx.fetch(FetchDescriptor<LogEvent>(predicate: #Predicate { $0.id == uuid })).first
    }

    private func latestMoment(within seconds: TimeInterval) -> LogEvent? {
        guard let ctx = container?.mainContext else { return nil }
        let since = Date().addingTimeInterval(-seconds)
        let baseline = MomentKind.okay.rawValue
        var d = FetchDescriptor<LogEvent>(predicate: #Predicate { $0.loggedAt >= since && $0.kindRaw != baseline },
                                          sortBy: [SortDescriptor(\.loggedAt, order: .reverse)])
        d.fetchLimit = 1
        return try? ctx.fetch(d).first
    }
}
