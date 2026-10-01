import AsthmaCore
import Foundation
import SwiftData

enum EnvStatus: String {
    case pending, ready, partial, failed
}

/// One log: an inhaler puff (`attack`) or a usual-day sample (`baseline`).
/// Mirrors EVENT in docs/data-architecture.md; conditions are stored as JSON with full provenance.
@Model
final class LogEvent {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var loggedAt: Date

    var latitude: Double?
    var longitude: Double?
    var horizontalAccuracy: Double?
    var floorLevel: Int?

    var envStatusRaw: String
    var envError: String?
    var conditionsData: Data?

    var indoorGuessRaw: String?
    var indoorGuessConfidenceRaw: String?
    var indoorGuessReasons: [String] = []
    /// The user's correction wins over the guess.
    var indoorConfirmedRaw: String?

    var healthSampleID: UUID?
    var tagsRaw: [String] = []
    var note: String?

    init(kind: FrameKind, loggedAt: Date = .now) {
        id = UUID()
        kindRaw = kind.rawValue
        self.loggedAt = loggedAt
        envStatusRaw = EnvStatus.pending.rawValue
    }

    var kind: FrameKind {
        FrameKind(rawValue: kindRaw) ?? .attack
    }

    var envStatus: EnvStatus {
        get { EnvStatus(rawValue: envStatusRaw) ?? .pending }
        set { envStatusRaw = newValue.rawValue }
    }

    var conditions: Conditions? {
        get { conditionsData.flatMap { try? JSONDecoder().decode(Conditions.self, from: $0) } }
        set { conditionsData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    var indoorGuess: IndoorOutdoor? {
        indoorGuessRaw.flatMap(IndoorOutdoor.init(rawValue:))
    }

    var indoorOutdoor: IndoorOutdoor? {
        indoorConfirmedRaw.flatMap(IndoorOutdoor.init(rawValue:)) ?? indoorGuess
    }

    var tags: Set<JournalTag> {
        get { Set(TagExtraction.sanitize(tagsRaw)) }
        set { tagsRaw = newValue.sorted().map(\.rawValue) }
    }

    func apply(_ guess: IndoorGuess) {
        indoorGuessRaw = guess.value.rawValue
        indoorGuessConfidenceRaw = guess.confidence.rawValue
        indoorGuessReasons = guess.reasons
    }

    /// Feature frame for insights, or nil when no outdoor value was stamped (same rule as the web prototype).
    func frame(calendar: Calendar = .current) -> FeatureFrame? {
        guard let c = conditions, c.input.hasAnyValue else { return nil }
        return FrameBuilder.frame(
            id: id.uuidString, kind: kind, date: loggedAt, calendar: calendar, conditions: c.input,
            place: nil, indoorOutdoor: indoorOutdoor, tags: tags
        )
    }
}
