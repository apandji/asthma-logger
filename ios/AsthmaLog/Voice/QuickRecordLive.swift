import ActivityKit
import AsthmaCore
import Foundation
import OSLog
import SwiftData

/// The app side of the Lock Screen recorder: starts the Live Activity after a moment, and carries out its
/// buttons (record, stop, tags, save). Same recorder, transcriber and tagger as the in-app Quick Record.
/// Nothing leaves the phone.
@MainActor
final class QuickRecordLive {
    static let shared = QuickRecordLive()

    private var container: ModelContainer?
    private var autoStop: Task<Void, Never>?
    private var autoEnd: Task<Void, Never>?

    typealias Live = Activity<QuickRecordAttributes>

    /// Called from the app's init, so the intents work even when the Lock Screen wakes the app in the background.
    func install(container: ModelContainer) {
        self.container = container
        QuickRecordBridge.handle = { [weak self] command in await self?.handle(command) }
        // A note left waiting from an earlier run: after an hour it's no longer "while it's fresh".
        for a in Live.activities where a.content.state.phase != .recording {
            if let e = event(a.attributes.momentID), Date().timeIntervalSince(e.loggedAt) > 3600 {
                let id = a.id; Task { await Self.end(id, nil, .immediate) }
            }
        }
    }

    private var current: Live? {
        Live.activities.first { $0.activityState == .active || $0.activityState == .stale }
    }

    /// After a rescue or standard moment. Returns false when the Live Activity can't start (Live Activities
    /// off, or the app is in the background, where iOS doesn't allow it); the caller sends the notification.
    @discardableResult
    func begin(for e: LogEvent) -> Bool {
        guard QuickRecordCenter.shared.enabled, e.moment != .okay,
              ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        endAll(except: nil)
        do {
            _ = try Live.request(attributes: attributes(e),
                                 content: content(.init(phase: .ready, selected: e.tags.map(\.rawValue))),
                                 pushType: nil)
            scheduleEnd(after: 30 * 60)
            return true
        } catch {
            return false
        }
    }

    // MARK: Buttons

    private let log = Logger(subsystem: "felt-air", category: "QuickRecordLive")

    func handle(_ command: QuickRecordCommand) async {
        log.info("handle \(String(describing: command), privacy: .public); activities \(Live.activities.count)")
        switch command {
        case .start(let id): await start(id)
        case .stop: await stop()
        case .toggle(let tag): await toggle(tag)
        case .save: await save()
        case .dismiss:
            if VoiceNotes.shared.recordingID != nil { VoiceNotes.shared.stopRecording() }
            autoStop?.cancel()
            endAll(except: nil)
        }
    }

    private func start(_ id: String?) async {
        guard let e = event(id ?? current?.attributes.momentID) ?? latestMoment() else { log.error("start: no moment"); return }
        // The Lock Screen control can start a note for a moment with no Live Activity yet.
        var live = current
        if live?.attributes.momentID != e.id.uuidString {
            endAll(except: nil)
            live = try? Live.request(attributes: attributes(e), content: content(.init(phase: .ready)), pushType: nil)
        }
        guard let live else { log.error("start: no activity"); return }
        autoEnd?.cancel()
        var state = live.content.state
        guard await VoiceNotes.shared.startRecording(for: e) else {
            log.error("start: recorder refused")
            state.phase = .needsMic
            await Self.update(live.id, content(state))
            return
        }
        try? container?.mainContext.save()
        state.phase = .recording
        state.startedAt = .now
        await Self.update(live.id, content(state))
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
        await Self.update(live.id, content(state))

        let e = event(live.attributes.momentID)
        if let e, let file = e.voiceNoteFile, let text = await NoteTranscriber.transcribe(VoiceNotes.shared.url(file)) {
            // The words are the person's own, so they're kept now; tags only count once they press Save.
            e.voiceTranscript = text
            try? container?.mainContext.save()
            let result = await VoiceNoteTagger.suggest(transcript: text, using: ModelTagProposer())
            state.words = String(text.prefix(140))
            state.suggested = result.suggestions.map(\.tag.rawValue)
            state.selected = Array(Set(state.selected).union(state.suggested))
        }
        state.phase = .review
        await Self.update(live.id, content(state))
        scheduleEnd(after: 30 * 60)
    }

    private func toggle(_ tag: String) async {
        guard let live = current, JournalTag(rawValue: tag) != nil else { return }
        var state = live.content.state
        if let i = state.selected.firstIndex(of: tag) { state.selected.remove(at: i) } else { state.selected.append(tag) }
        // A tag from the first screen counts as an answer: show Save.
        if state.phase == .ready || state.phase == .needsMic { state.phase = .review }
        await Self.update(live.id, content(state))
    }

    private func save() async {
        guard let live = current else { return }
        var state = live.content.state
        if let e = event(live.attributes.momentID) {
            e.tags = Set(state.selected.compactMap(JournalTag.init(rawValue:)))
            e.tagsReviewed = true
            try? container?.mainContext.save()
            QuickRecordCenter.shared.scheduleEvening()
        }
        state.phase = .saved
        await Self.end(live.id, content(state), .after(.now.addingTimeInterval(4)))
    }

    /// When the in-app recorder saves a note, the Lock Screen one for that moment goes away.
    func finished(momentID: UUID) {
        for a in Live.activities where a.attributes.momentID == momentID.uuidString {
            let id = a.id; Task { await Self.end(id, nil, .immediate) }
        }
    }

    // MARK: Helpers

    private func endAll(except id: String?) {
        for a in Live.activities where a.attributes.momentID != id {
            let id = a.id; Task { await Self.end(id, nil, .immediate) }
        }
    }

    /// Ends a note that's still waiting; only runs while the app is awake, the stale date covers the rest.
    private func scheduleEnd(after seconds: TimeInterval) {
        autoEnd?.cancel()
        autoEnd = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self, let live = self.current, live.content.state.phase != .recording else { return }
            await Self.end(live.id, nil, .immediate)
        }
    }

    // ActivityKit's update and end are nonisolated; each looks the activity up by id so nothing non-Sendable
    // crosses from the main actor.
    private nonisolated static func update(_ id: String, _ c: ActivityContent<QuickRecordAttributes.ContentState>) async {
        await Live.activities.first { $0.id == id }?.update(c)
    }

    private nonisolated static func end(_ id: String, _ c: ActivityContent<QuickRecordAttributes.ContentState>?,
                                        _ policy: ActivityUIDismissalPolicy) async {
        await Live.activities.first { $0.id == id }?.end(c, dismissalPolicy: policy)
    }

    private func content(_ state: QuickRecordAttributes.ContentState) -> ActivityContent<QuickRecordAttributes.ContentState> {
        ActivityContent(state: state, staleDate: .now.addingTimeInterval(30 * 60))
    }

    private func attributes(_ e: LogEvent) -> QuickRecordAttributes {
        QuickRecordAttributes(momentID: e.id.uuidString, kind: e.moment.title, isRescue: e.moment == .rescue,
                              whenAndWhere: e.whenAndWhere)
    }

    private func event(_ id: String?) -> LogEvent? {
        guard let id, let uuid = UUID(uuidString: id), let ctx = container?.mainContext else { return nil }
        return try? ctx.fetch(FetchDescriptor<LogEvent>(predicate: #Predicate { $0.id == uuid })).first
    }

    /// The Lock Screen control's moment: the latest rescue or standard moment in the last 6 hours.
    private func latestMoment() -> LogEvent? {
        guard let ctx = container?.mainContext else { return nil }
        let since = Date().addingTimeInterval(-6 * 3600)
        let baseline = MomentKind.okay.rawValue
        var d = FetchDescriptor<LogEvent>(predicate: #Predicate { $0.loggedAt >= since && $0.kindRaw != baseline },
                                          sortBy: [SortDescriptor(\.loggedAt, order: .reverse)])
        d.fetchLimit = 1
        return try? ctx.fetch(d).first
    }
}
