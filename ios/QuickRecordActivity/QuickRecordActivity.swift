import ActivityKit
import AppIntents
import Foundation

/// Quick Record on the Lock Screen: after a rescue or standard moment, a Live Activity asks what was going on.
/// Record, stop, tag and save all happen from the Lock Screen without unlocking. Compiled into the app and the
/// widget extension; the intents always run in the app's process (where the microphone and the journal are).
nonisolated struct QuickRecordAttributes: ActivityAttributes {
    /// The moment this note is for.
    var momentID: String
    /// "Rescue" or "Standard".
    var kind: String
    var isRescue: Bool
    /// "Today, 6:12 PM · Tower Grove South".
    var whenAndWhere: String

    struct ContentState: Codable, Hashable {
        var phase: Phase
        var startedAt: Date?
        /// The first words of the transcript (the full text is on the moment).
        var words: String?
        /// Tags (JournalTag raw values) the words suggested, and the ones switched on.
        var suggested: [String] = []
        var selected: [String] = []
    }

    enum Phase: String, Codable, Hashable {
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
    case stop
    case toggle(tag: String)
    case save
    case dismiss
}

/// Set by the app at launch. Empty in the widget extension, which never performs these intents.
@MainActor enum QuickRecordBridge {
    static var handle: ((QuickRecordCommand) async -> Void)?
}

/// Starts a voice note for the moment on the Lock Screen (or, from the Lock Screen control, the latest
/// rescue or standard moment in the last few hours).
struct QuickRecordStartIntent: AudioRecordingIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Record a voice note"
    static let description = IntentDescription("Say what was going on at your latest felt air moment.")
    static let openAppWhenRun = false

    @Parameter(title: "Moment") var momentID: String?

    init() {}
    init(momentID: String?) { self.momentID = momentID }

    @MainActor func perform() async throws -> some IntentResult {
        await QuickRecordBridge.handle?(.start(momentID: momentID))
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
