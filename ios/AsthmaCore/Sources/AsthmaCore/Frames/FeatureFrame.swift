import Foundation

/// Bin edges version. v1 = the web prototype's bins; v2 adds place, indoor/outdoor and journal tags;
/// v3 reads journal tags as missing (not "no") on frames without a reviewed note;
/// v4 adds `temp_drop` (a fall of 10°F or more in the 3 hours before, `TempDrop`);
/// v5 adds `exertion` (active in the hour before: a workout, running or cycling, or a burst of steps; `Exertion`).
/// v6 adds `ili` (flu-like illness around that day, `Infection`; missing until stamped).
/// Bump when any edge changes and regenerate `fixtures/` (fixtures cover the v1 bins only).
public enum BinSpec {
    public static let version = 6
}

public enum FrameKind: String, Codable, Sendable, CaseIterable {
    /// An inhaler puff.
    case attack
    /// A usual-day sample: no puff logged.
    case baseline
}

public enum Season: String, Codable, Sendable, CaseIterable {
    case winter, spring, summer, fall
}

public enum TempBand: String, Codable, Sendable, CaseIterable {
    case cold, mild, hot, unknown
}

public enum HumidityBand: String, Codable, Sendable, CaseIterable {
    case dry, ok, humid, unknown
}

public enum PollutantBand: String, Codable, Sendable, CaseIterable {
    case low, moderate, high, unknown
}

public enum PollenLevel: String, Codable, Sendable, CaseIterable {
    case none, low, moderate, high, unknown
}

public enum PlaceKind: String, Codable, Sendable, CaseIterable {
    case home, work, frequent, other
}

public enum IndoorOutdoor: String, Codable, Sendable, CaseIterable {
    case indoor, outdoor, unknown
}

/// One hour at one place, binned. Past logs and forecast hours both become frames,
/// so the Journal patterns and the Insights look-ahead read the same table.
public struct FeatureFrame: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var kind: FrameKind
    /// Local hour 0–23.
    public var hourOfDay: Int
    public var season: Season
    public var tempBand: TempBand
    public var humidityBand: HumidityBand
    public var pm25Band: PollutantBand
    public var ozoneBand: PollutantBand
    public var pollenWeed: PollenLevel
    public var smokeAtPoint: Bool
    public var heatAlert: Bool

    /// v4 (iOS only). Unknown when there were no hourly temperatures around the frame.
    public var tempDrop: TempDropBand

    // v2 (iOS only). Absent → the bin contributes no rows.
    public var place: PlaceKind?
    public var indoorOutdoor: IndoorOutdoor?
    /// Confirmed journal tags only. Suggestions never land here until the user confirms them.
    public var tags: Set<JournalTag>
    /// The user reviewed this moment's note and its tag chips (`TagReview.isReviewed`), so a tag not in
    /// `tags` reads "no". Without a review the tag bins are missing for this frame, not "no".
    public var tagsReviewed: Bool
    /// v5 (iOS only): active in the hour before (Health workouts, Motion, steps). Nil when neither Health nor
    /// Motion could say: missing, not "no".
    public var exerted: Bool?
    /// v6 (`Infection`): flu-like illness around that day. Nil = not stamped: missing, not "low". Real moments
    /// aren't stamped until `Infection.isEnabled` (later, not MVP); data sets carry it.
    public var infection: InfectionLevel?

    /// Whether the journal-tag bins have data for this frame. A confirmed tag implies a review.
    public var tagsSampled: Bool { tagsReviewed || !tags.isEmpty }

    public init(
        id: String,
        kind: FrameKind,
        hourOfDay: Int,
        season: Season,
        tempBand: TempBand = .unknown,
        humidityBand: HumidityBand = .unknown,
        pm25Band: PollutantBand = .unknown,
        ozoneBand: PollutantBand = .unknown,
        pollenWeed: PollenLevel = .unknown,
        smokeAtPoint: Bool = false,
        heatAlert: Bool = false,
        tempDrop: TempDropBand = .unknown,
        place: PlaceKind? = nil,
        indoorOutdoor: IndoorOutdoor? = nil,
        tags: Set<JournalTag> = [],
        tagsReviewed: Bool = false,
        exerted: Bool? = nil,
        infection: InfectionLevel? = nil
    ) {
        self.id = id
        self.kind = kind
        self.hourOfDay = hourOfDay
        self.season = season
        self.tempBand = tempBand
        self.humidityBand = humidityBand
        self.pm25Band = pm25Band
        self.ozoneBand = ozoneBand
        self.pollenWeed = pollenWeed
        self.smokeAtPoint = smokeAtPoint
        self.heatAlert = heatAlert
        self.tempDrop = tempDrop
        self.place = place
        self.indoorOutdoor = indoorOutdoor
        self.tags = tags
        self.tagsReviewed = tagsReviewed
        self.exerted = exerted
        self.infection = infection
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, hourOfDay, season, tempBand, humidityBand, pm25Band, ozoneBand, pollenWeed
        case smokeAtPoint, heatAlert, tempDrop, place, indoorOutdoor, tags, tagsReviewed, exerted, infection
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = try c.decode(FrameKind.self, forKey: .kind)
        hourOfDay = try c.decode(Int.self, forKey: .hourOfDay)
        season = try c.decode(Season.self, forKey: .season)
        tempBand = try c.decode(TempBand.self, forKey: .tempBand)
        humidityBand = try c.decode(HumidityBand.self, forKey: .humidityBand)
        pm25Band = try c.decode(PollutantBand.self, forKey: .pm25Band)
        ozoneBand = try c.decode(PollutantBand.self, forKey: .ozoneBand)
        pollenWeed = try c.decode(PollenLevel.self, forKey: .pollenWeed)
        smokeAtPoint = try c.decode(Bool.self, forKey: .smokeAtPoint)
        heatAlert = try c.decode(Bool.self, forKey: .heatAlert)
        tempDrop = try c.decodeIfPresent(TempDropBand.self, forKey: .tempDrop) ?? .unknown
        place = try c.decodeIfPresent(PlaceKind.self, forKey: .place)
        indoorOutdoor = try c.decodeIfPresent(IndoorOutdoor.self, forKey: .indoorOutdoor)
        tags = try c.decodeIfPresent(Set<JournalTag>.self, forKey: .tags) ?? []
        tagsReviewed = try c.decodeIfPresent(Bool.self, forKey: .tagsReviewed) ?? false
        exerted = try c.decodeIfPresent(Bool.self, forKey: .exerted)
        infection = try c.decodeIfPresent(InfectionLevel.self, forKey: .infection)
    }
}
