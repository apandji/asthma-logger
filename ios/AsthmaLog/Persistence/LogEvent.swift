import AsthmaCore
import Foundation
import SwiftData

enum EnvStatus: String {
    case pending, ready, partial, failed
}

/// One moment: a rescue inhaler use (`attack`), a standard inhaler dose (`maintenance`) or a usual-moment
/// sample (`baseline`). See `MomentKind`.
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
    /// Made-up moment from Settings → Demo moments. Its own field, so a user note (voice notes) never
    /// turns a demo moment real or the other way round.
    var isDemoMoment: Bool = false

    init(moment: MomentKind, loggedAt: Date = .now, id: UUID = UUID()) {
        self.id = id
        kindRaw = moment.rawValue
        self.loggedAt = loggedAt
        envStatusRaw = EnvStatus.pending.rawValue
    }

    var moment: MomentKind {
        MomentKind(rawValue: kindRaw) ?? .rescue
    }

    /// Insights kind. Standard (maintenance) doses aren't part of patterns; `frame()` skips them.
    var kind: FrameKind {
        moment.frameKind ?? .baseline
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

    /// How demo moments were marked before `isDemoMoment`: this exact `note`. Still read so older demo
    /// weeks are recognised and removed.
    static let legacyDemoNote = "felt-air-demo"

    var isDemo: Bool { isDemoMoment || note == Self.legacyDemoNote }

    /// Feature frame for insights, or nil when no outdoor value was stamped (same rule as the web prototype).
    func frame(calendar: Calendar = .current) -> FeatureFrame? {
        guard !isDemo, moment.frameKind != nil, let c = conditions, c.input.hasAnyValue else { return nil }
        return FrameBuilder.frame(
            id: id.uuidString, kind: kind, date: loggedAt, calendar: calendar, conditions: c.input,
            place: nil, indoorOutdoor: indoorOutdoor, tags: tags
        )
    }
}
