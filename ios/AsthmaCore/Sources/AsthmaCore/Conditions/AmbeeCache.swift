import Foundation

/// Ambee behind a per-phone cache, so the POC stays inside its daily call budget (docs/ambee/poc-estimate.md).
///
/// Places are snapped to a ~500 m cell (Ambee's own resolution for history and forecasts) and the cell's
/// centre is what Ambee is asked for, so every moment in a cell shares one answer. Rules:
/// - **Latest**: one answer per cell per clock hour.
/// - **History**: past hours never change, so they're kept (60 days) and a range is only fetched when an
///   hour in it is missing. Ambee's history runs an hour or two behind; those recent hours are asked for at
///   most once an hour. The POC key only reaches back two days ("Only past 2 days data available!", a 400 for
///   the whole request, seen Nov 13, 2026), so older missing hours are never asked for: what's kept is what
///   was fetched in time.
/// - **Forecast**: reused for `forecastTTL` (3 h by default).
/// Two requests for the same thing at the same time share one call. Every failure falls through to the
/// caller, which fails open as before.
public actor CachedAmbee: AmbeeSource {
    public nonisolated let sourceName: String
    private let inner: any AmbeeSource
    private let now: @Sendable () -> Date
    private let save: (@Sendable (Data) -> Void)?
    private let forecastTTL: TimeInterval
    private let historyReach: TimeInterval
    private var store: Store
    private var inFlight: [String: Task<[AmbeeHour], Error>] = [:]

    /// Calls actually sent to the inner source, for tests and the Data sources screen.
    public private(set) var calls = 0

    /// `saved` is a previous `save` (nil or unreadable → empty). `save` is called after each change.
    public init(_ inner: any AmbeeSource, saved: Data? = nil, forecastTTL: TimeInterval = 3 * 3600,
                historyReach: TimeInterval = 47 * 3600,
                now: @escaping @Sendable () -> Date = { Date() }, save: (@Sendable (Data) -> Void)? = nil) {
        self.inner = inner
        self.sourceName = inner.sourceName
        self.now = now
        self.save = save
        self.forecastTTL = forecastTTL
        self.historyReach = historyReach
        self.store = saved.flatMap { try? JSONDecoder().decode(Store.self, from: $0) } ?? Store()
    }

    // MARK: Cells

    /// ~500 m: 0.005° of latitude is 555 m; of longitude, 440 m at 37° N.
    public static let cellDegrees = 0.005

    public struct Cell: Hashable, Sendable {
        public let latitude: Double
        public let longitude: Double
        public var key: String { String(format: "%.4f,%.4f", latitude, longitude) }
    }

    /// The centre of the cell a point falls in.
    public static func cell(_ latitude: Double, _ longitude: Double) -> Cell {
        func snap(_ d: Double) -> Double { ((d / cellDegrees).rounded(.down) + 0.5) * cellDegrees }
        return Cell(latitude: snap(latitude), longitude: snap(longitude))
    }

    static func slot(_ d: Date) -> Date { Date(timeIntervalSince1970: (d.timeIntervalSince1970 / 3600).rounded(.down) * 3600) }

    // MARK: AmbeeSource

    public func latest(latitude: Double, longitude: Double, at date: Date) async throws -> AmbeeHour {
        let c = Self.cell(latitude, longitude)
        let hour = Self.slot(now())
        var entry = store.cells[c.key] ?? CellStore()
        if let cached = entry.latest, Self.slot(cached.fetchedAt) == hour {
            var h = cached.hour; h.date = date; return h
        }
        let fetched = try await once("latest|\(c.key)|\(hour.timeIntervalSince1970)") { [inner] in
            [try await inner.latest(latitude: c.latitude, longitude: c.longitude, at: date)]
        }
        guard var h = fetched.first else { throw URLError(.zeroByteResource) }
        entry = store.cells[c.key] ?? CellStore()
        entry.latest = .init(hour: h, fetchedAt: now())
        store.cells[c.key] = entry
        persist()
        h.date = date
        return h
    }

    public func history(latitude: Double, longitude: Double, from: Date, to: Date) async throws -> [AmbeeHour] {
        let c = Self.cell(latitude, longitude)
        let entry = store.cells[c.key] ?? CellStore()
        let wanted = stride(from: Self.slot(from).timeIntervalSince1970, through: Self.slot(to).timeIntervalSince1970, by: 3600)
            .map { Date(timeIntervalSince1970: $0) }
        // Hours inside Ambee's lag may not exist yet: missing ones there count only if we haven't asked this hour.
        let settled = now().addingTimeInterval(-3 * 3600)
        let askedThisHour = entry.historyAskedAt.map { Self.slot($0) == Self.slot(now()) } ?? false
        let reachable = now().addingTimeInterval(-historyReach)
        let missing = wanted.filter { d in
            d >= reachable && entry.history[key(d)] == nil && !entry.noData.contains(key(d)) && (d < settled || !askedThisHour)
        }
        if !missing.isEmpty {
            let range = "\(missing.first!.timeIntervalSince1970)-\(missing.last!.timeIntervalSince1970)"
            let fetched = try await once("history|\(c.key)|\(range)") { [inner] in
                try await inner.history(latitude: c.latitude, longitude: c.longitude, from: missing.first!, to: missing.last!)
            }
            var e = store.cells[c.key] ?? CellStore()
            for h in fetched { e.history[key(h.date)] = h }
            // Settled hours Ambee skipped inside what it returned: don't ask again. Only between the first and
            // last hour it sent, so a short or empty answer (a failed request upstream) never blacks out a range.
            if let first = fetched.map(\.date).min(), let last = fetched.map(\.date).max() {
                for d in missing where d < settled && d > first && d < last && e.history[key(d)] == nil { e.noData.insert(key(d)) }
            }
            e.historyAskedAt = now()
            store.cells[c.key] = e
            prune()
            persist()
        }
        let e = store.cells[c.key] ?? CellStore()
        return wanted.compactMap { e.history[key($0)] }
    }

    public func forecast(latitude: Double, longitude: Double, from: Date, hours: Int) async throws -> [AmbeeHour] {
        let c = Self.cell(latitude, longitude)
        let entry = store.cells[c.key] ?? CellStore()
        let all: [AmbeeHour]
        if let f = entry.forecast, now().timeIntervalSince(f.fetchedAt) < forecastTTL {
            all = f.hours
        } else {
            // Ask from the start of this hour for the full 48, then trim per caller.
            let start = Self.slot(now())
            all = try await once("forecast|\(c.key)|\(start.timeIntervalSince1970)") { [inner] in
                try await inner.forecast(latitude: c.latitude, longitude: c.longitude, from: start, hours: 48)
            }
            var e = store.cells[c.key] ?? CellStore()
            e.forecast = .init(hours: all, fetchedAt: now())
            store.cells[c.key] = e
            persist()
        }
        return Array(all.filter { $0.date >= from.addingTimeInterval(-3600) }.prefix(hours))
    }

    // MARK: Plumbing

    /// One call per key at a time: a second asker waits for the first.
    private func once(_ key: String, _ work: @escaping @Sendable () async throws -> [AmbeeHour]) async throws -> [AmbeeHour] {
        if let t = inFlight[key] { return try await t.value }
        calls += 1
        let t = Task { try await work() }
        inFlight[key] = t
        defer { inFlight[key] = nil }
        return try await t.value
    }

    private func key(_ d: Date) -> Int { Int(Self.slot(d).timeIntervalSince1970) }

    /// History older than 60 days (the baseline backfill's reach) and cells untouched for as long are dropped.
    private func prune() {
        let cutoff = now().addingTimeInterval(-60 * 86_400)
        for (k, var e) in store.cells {
            e.history = e.history.filter { Double($0.key) >= cutoff.timeIntervalSince1970 }
            e.noData = e.noData.filter { Double($0) >= cutoff.timeIntervalSince1970 }
            let touched = [e.latest?.fetchedAt, e.forecast?.fetchedAt, e.historyAskedAt].compactMap { $0 }.max()
            store.cells[k] = e.history.isEmpty && (touched ?? .distantPast) < cutoff ? nil : e
        }
    }

    private func persist() {
        guard let save, let data = try? JSONEncoder().encode(store) else { return }
        save(data)
    }

    struct Store: Codable, Sendable { var cells: [String: CellStore] = [:] }

    struct CellStore: Codable, Sendable {
        var latest: Stamped?
        var history: [Int: AmbeeHour] = [:]
        var historyAskedAt: Date?
        var noData: Set<Int> = []
        var forecast: Forecast?

        struct Stamped: Codable, Sendable { var hour: AmbeeHour; var fetchedAt: Date }
        struct Forecast: Codable, Sendable { var hours: [AmbeeHour]; var fetchedAt: Date }
    }
}
