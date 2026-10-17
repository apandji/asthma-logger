import Foundation

/// One hourly value (PM2.5 µg/m³, ozone ppb, …) at the start of its hour.
public struct HourValue: Codable, Sendable, Equatable {
    public var date: Date
    public var value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

/// The worst value inside one window of hours, and how many hourly readings it saw.
public struct WindowPeak: Codable, Sendable, Equatable {
    /// Highest value in the window; nil when no hour had a reading.
    public var worst: Double?
    /// Hours with a reading. A window counts only when at least half its hours were read.
    public var hours: Int

    public init(worst: Double? = nil, hours: Int = 0) {
        self.worst = worst
        self.hours = hours
    }
}

/// Which of the three look-back levels a moment falls in for one signal. Exclusive: a moment is in
/// exactly one, so a smoky week is never counted twice (docs/air-outlook.md › Looking back).
public enum LookBackLevel: String, Codable, Sendable, CaseIterable {
    /// High in the 6 hours up to the moment.
    case now
    /// High 6–48 hours before, but not now.
    case earlier
    /// Not high anywhere in the 48 hours.
    case neither
}

/// The outdoor air in the 48 hours before a moment, in two windows: "now" (the 6 hours up to it) and
/// "earlier" (6–48 hours before). Stored on every moment so look-back bins can be added later without
/// refetching. Not in frames or Insights yet.
public struct LookBack: Codable, Sendable, Equatable {
    public static let nowHours: Double = 6
    public static let spanHours: Double = 48

    public var pm25Now: WindowPeak
    public var pm25Earlier: WindowPeak
    public var ozoneNow: WindowPeak
    public var ozoneEarlier: WindowPeak
    /// Largest 3-hour temperature fall (°F, `TempDrop`) ending inside each window.
    public var tempFallNow: WindowPeak
    public var tempFallEarlier: WindowPeak
    /// OpenAQ station names the hours came from, for the details view.
    public var pm25Station: String?
    public var ozoneStation: String?
    /// When the hours were fetched (at log time, or later by backfill).
    public var fetchedAt: Date

    public init(pm25Now: WindowPeak = .init(), pm25Earlier: WindowPeak = .init(),
                ozoneNow: WindowPeak = .init(), ozoneEarlier: WindowPeak = .init(),
                tempFallNow: WindowPeak = .init(), tempFallEarlier: WindowPeak = .init(),
                pm25Station: String? = nil, ozoneStation: String? = nil, fetchedAt: Date = Date()) {
        self.pm25Now = pm25Now
        self.pm25Earlier = pm25Earlier
        self.ozoneNow = ozoneNow
        self.ozoneEarlier = ozoneEarlier
        self.tempFallNow = tempFallNow
        self.tempFallEarlier = tempFallEarlier
        self.pm25Station = pm25Station
        self.ozoneStation = ozoneStation
        self.fetchedAt = fetchedAt
    }

    /// The two windows ending at `date`: now = [date − 6 h, date], earlier = [date − 48 h, date − 6 h).
    public static func windows(at date: Date) -> (now: ClosedRange<Date>, earlier: Range<Date>) {
        let cut = date.addingTimeInterval(-nowHours * 3600)
        return (cut...date, date.addingTimeInterval(-spanHours * 3600)..<cut)
    }

    public static func compute(at date: Date, pm25: [HourValue], ozone: [HourValue], temps: [TempPoint],
                               pm25Station: String? = nil, ozoneStation: String? = nil,
                               fetchedAt: Date = Date()) -> LookBack {
        let w = windows(at: date)
        // Each hour's 3-hour fall, so a drop yesterday afternoon lands in "earlier".
        let falls = temps.compactMap { p in TempDrop.degreesFallen(at: p.date, in: temps).map { HourValue(date: p.date, value: $0) } }
        return LookBack(
            pm25Now: peak(pm25, w.now.contains), pm25Earlier: peak(pm25, w.earlier.contains),
            ozoneNow: peak(ozone, w.now.contains), ozoneEarlier: peak(ozone, w.earlier.contains),
            tempFallNow: peak(falls, w.now.contains), tempFallEarlier: peak(falls, w.earlier.contains),
            pm25Station: pm25Station, ozoneStation: ozoneStation, fetchedAt: fetchedAt
        )
    }

    static func peak(_ values: [HourValue], _ inWindow: (Date) -> Bool) -> WindowPeak {
        let inside = values.filter { inWindow($0.date) && $0.value.isFinite }
        return WindowPeak(worst: inside.map(\.value).max(), hours: inside.count)
    }

    /// A window is read when at least half its hours have a reading. Otherwise it's unknown.
    public static func isCovered(_ p: WindowPeak, windowHours: Double) -> Bool {
        p.worst != nil && Double(p.hours) >= windowHours / 2
    }

    /// The look-back level for one signal, or nil when either window wasn't read well enough
    /// (missing, not "neither"). `isHigh` is the signal's own cut-off, e.g. PM2.5 band high.
    public static func level(now: WindowPeak, earlier: WindowPeak, isHigh: (Double) -> Bool) -> LookBackLevel? {
        guard isCovered(now, windowHours: nowHours), isCovered(earlier, windowHours: spanHours - nowHours),
              let n = now.worst, let e = earlier.worst else { return nil }
        if isHigh(n) { return .now }
        if isHigh(e) { return .earlier }
        return .neither
    }

    public var pm25Level: LookBackLevel? {
        Self.level(now: pm25Now, earlier: pm25Earlier) { Banding.pm25($0) == .high }
    }

    public var ozoneLevel: LookBackLevel? {
        Self.level(now: ozoneNow, earlier: ozoneEarlier) { Banding.ozone(ppb: $0) == .high }
    }

    public var tempDropLevel: LookBackLevel? {
        Self.level(now: tempFallNow, earlier: tempFallEarlier) { TempDrop.band($0) == .sharp }
    }
}

extension OpenAQ {
    /// One row of `/sensors/{id}/hours`.
    public struct SensorHour: Codable, Sendable {
        public struct Period: Codable, Sendable { public var datetimeFrom: DateTimePair? }
        public var value: Double?
        public var period: Period?
    }

    /// Hour rows → values, oldest first. Converts ppm → ppb (ozone, NO₂) like `reading` does.
    public static func hourValues(_ rows: [SensorHour], units: String?) -> [HourValue] {
        let ppm = (units ?? "").lowercased().contains("ppm")
        return rows.compactMap { r -> HourValue? in
            guard let v = r.value, v.isFinite, v >= 0, let d = parseDate(r.period?.datetimeFrom?.utc) else { return nil }
            return HourValue(date: d, value: ppm ? v * 1000 : v)
        }.sorted { $0.date < $1.date }
    }
}
