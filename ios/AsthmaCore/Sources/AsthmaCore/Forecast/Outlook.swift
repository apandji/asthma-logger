import Foundation

/// One forecast hour, already binned with the same edges as past logs.
public struct ForecastHour: Sendable {
    public var start: Date
    public var frame: FeatureFrame
    /// Some providers failed for this hour; the score uses what we have.
    public var isPartial: Bool

    public init(start: Date, frame: FeatureFrame, isPartial: Bool = false) {
        self.start = start
        self.frame = frame
        self.isPartial = isPartial
    }
}

public struct RiskWindow: Sendable, Identifiable {
    public var start: Date
    /// Exclusive.
    public var end: Date
    public var peakScore: Double
    /// Top two drivers by log-LR (positive only).
    public var drivers: [RateTable.Entry]
    public var isPartial: Bool
    /// Totals behind the driver counts, so copy can say "4 of your 10".
    public var nAttacks: Int
    public var nBaselines: Int
    public var id: Date { start }
}

public struct DayOutlook: Sendable, Identifiable {
    public var day: Date
    public var band: RiskBand
    public var windows: [RiskWindow]
    /// Cold start only: hazards from the forecast itself, not this person's pattern.
    public var genericHazards: [String]
    /// Hours ahead of now when the day starts; later days are less certain.
    public var leadHours: Int
    /// False before the sample gate: the band only reflects general hazards, not this person's pattern.
    public var isPersonal: Bool = true
    public var id: Date { day }
}

public enum Outlook {
    /// Elevated windows per day. Before the sample gate, falls back to generic hazards (§6 cold start).
    public static func days(
        hours: [ForecastHour], table: RateTable, bander: RiskBander,
        now: Date = Date(), calendar: Calendar = .current
    ) -> [DayOutlook] {
        let byDay = Dictionary(grouping: hours.sorted { $0.start < $1.start }) { calendar.startOfDay(for: $0.start) }
        return byDay.keys.sorted().map { day in
            let dayHours = byDay[day]!
            let lead = max(0, Int(day.timeIntervalSince(now) / 3600))
            guard table.isPersonal else {
                let hazards = Array(Set(dayHours.flatMap { GenericHazards.list($0.frame) })).sorted()
                return DayOutlook(day: day, band: hazards.isEmpty ? .usual : .elevated, windows: [],
                                  genericHazards: hazards, leadHours: lead, isPersonal: false)
            }
            let windows = Array(elevatedWindows(dayHours, table: table, bander: bander)
                .sorted { $0.peakScore > $1.peakScore }.prefix(2)).sorted { $0.start < $1.start }
            let band: RiskBand
            if !windows.isEmpty {
                band = .elevated
            } else if dayHours.allSatisfy({ bander.band(table.score($0.frame).score) == .quiet }) {
                band = .quiet
            } else {
                band = .usual
            }
            return DayOutlook(day: day, band: band, windows: windows, genericHazards: [], leadHours: lead)
        }
    }

    /// Merge consecutive elevated hours; drop single hours unless extreme (heat alert, smoke).
    static func elevatedWindows(_ hours: [ForecastHour], table: RateTable, bander: RiskBander) -> [RiskWindow] {
        var out: [RiskWindow] = []
        var run: [(ForecastHour, Double, [RateTable.Entry])] = []

        func flush() {
            defer { run = [] }
            guard let first = run.first, let last = run.last else { return }
            let extreme = run.contains { $0.0.frame.heatAlert || $0.0.frame.smokeAtPoint }
            if run.count < 2 && !extreme { return }
            var best: [String: RateTable.Entry] = [:]
            for (_, _, entries) in run {
                for e in entries where e.logLR > 0 { best[e.id] = e }
            }
            let drivers = Array(best.values.sorted { $0.logLR > $1.logLR }.prefix(2))
            out.append(RiskWindow(start: first.0.start, end: last.0.start.addingTimeInterval(3600),
                                  peakScore: run.map(\.1).max() ?? 0, drivers: drivers,
                                  isPartial: run.contains { $0.0.isPartial },
                                  nAttacks: table.nAttacks, nBaselines: table.nBaselines))
        }

        for h in hours {
            let (score, entries) = table.score(h.frame)
            let contiguous = run.last.map { h.start.timeIntervalSince($0.0.start) == 3600 } ?? true
            if bander.band(score) == .elevated {
                if !contiguous { flush() }
                run.append((h, score, entries))
            } else {
                flush()
            }
        }
        flush()
        return out
    }
}

/// Outdoor hazards anyone would want to know about. Used before we know this person's pattern.
/// Phrased to sit mid-sentence ("high ozone", "a heat alert"); `OutlookCopy.coldStart` builds the line.
public enum GenericHazards {
    public static func list(_ f: FeatureFrame) -> [String] {
        var out: [String] = []
        if f.pm25Band == .high { out.append("high PM2.5") }
        if f.ozoneBand == .high { out.append("high ozone") }
        if f.pollenWeed == .high { out.append("high weed pollen") }
        if f.heatAlert { out.append("a heat alert") }
        if f.tempBand == .cold { out.append("freezing air") }
        if f.smokeAtPoint && f.pm25Band == .high { out.append("smoke-like air") }
        return out
    }
}
