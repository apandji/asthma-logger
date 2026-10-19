import ActivityKit
import AppIntents
import Foundation

/// Quick Record on the Lock Screen. While felt air is ready, a small card waits on the Lock Screen (iOS only lets
/// an app *start* a Live Activity from the foreground, but it can *update* one from the background, which is
/// where a felt button press arrives). A press turns the card into "Rescue logged · What's going on?"; its mic
/// on standby logs a rescue and listens. Record, stop, tag and save all happen without unlocking.
/// Compiled into the app and the widget extension; the intents always run in the app's process.
nonisolated struct QuickRecordAttributes: ActivityAttributes {
    /// Fixed for the card's life; the moment it's about changes, so it lives in the state.
    var app = "felt air"

    struct ContentState: Codable, Hashable {
        var phase: Phase
        /// The moment this note is for (nil on standby).
        var momentID: String?
        /// "Rescue" or "Standard".
        var kind: String?
        var isRescue = true
        /// "Today, 6:12 PM · Tower Grove South".
        var whenAndWhere: String?
        var startedAt: Date?
        /// The first words of the transcript (the full text is on the moment).
        var words: String?
        /// Tags (JournalTag raw values) the words suggested, and the ones switched on.
        var suggested: [String] = []
        var selected: [String] = []
    }

    enum Phase: String, Codable, Hashable {
        /// Waiting for a moment: the mic logs a rescue and listens.
        case standby
        case ready, recording, writing, review, saved
        /// The microphone isn't allowed yet; that can only be asked in the app.
        case needsMic
    }

    /// Longest note from the Lock Screen; it stops itself after this.
    static let maxSeconds: TimeInterval = 60
}

/// What the Lock Screen buttons ask the app to do.
nonisolated enum QuickRecordCommand: Sendable {
    case start(momentID: String?)
    /// Log a rescue now (Control Center, the Action button, Lock Screen): one tap, the same as the felt button.
    case logRescue
    case stop
    case toggle(tag: String)
    case save
    case dismiss
}

/// Set by the app at launch. Empty in the widget extension, which never performs these intents.
@MainActor enum QuickRecordBridge {
    static var handle: ((QuickRecordCommand) async -> Void)?
}

/// Starts a voice note for the moment on the card. With no moment (standby card, Lock Screen control, Action
/// button): attaches to a moment logged in the last 10 minutes, otherwise logs a rescue first.
struct QuickRecordStartIntent: AudioRecordingIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Rescue voice note"
    static let description = IntentDescription("Logs a rescue (unless you just logged one) and records what's going on.")
    static let openAppWhenRun = false

    @Parameter(title: "Moment") var momentID: String?

    init() {}
    init(momentID: String?) { self.momentID = momentID }

    @MainActor func perform() async throws -> some IntentResult {
        await QuickRecordBridge.handle?(.start(momentID: momentID))
        return .result()
    }
}

/// One tap logs a rescue, from Control Center, the Lock Screen or the Action button: the same moment a felt
/// button press makes (air stamped, Health written when that's on, puffs merged within two minutes).
struct LogRescueIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Log a rescue"
    static let description = IntentDescription("Logs a rescue inhaler use now, with the air around you.")
    static let openAppWhenRun = false

    @MainActor func perform() async throws -> some IntentResult {
        await QuickRecordBridge.handle?(.logRescue)
        return .result()
    }
}

struct QuickRecordStopIntent: AudioRecordingIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop the voice note"
    static let isDiscoverable = false

    @MainActor func perform() async throws -> some IntentResult {
        await QuickRecordBridge.handle?(.stop)
        return .result()
    }
}

struct QuickRecordTagIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Switch a tag"
    static let isDiscoverable = false

    @Parameter(title: "Tag") var tag: String

    init() {}
    init(tag: String) { self.tag = tag }

    @MainActor func perform() async throws -> some IntentResult {
        await QuickRecordBridge.handle?(.toggle(tag: tag))
        return .result()
    }
}

struct QuickRecordSaveIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Save the note"
    static let isDiscoverable = false

    @MainActor func perform() async throws -> some IntentResult {
        await QuickRecordBridge.handle?(.save)
        return .result()
    }
}

struct QuickRecordDismissIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Not now"
    static let isDiscoverable = false

    @MainActor func perform() async throws -> some IntentResult {
        await QuickRecordBridge.handle?(.dismiss)
        return .result()
    }
}
