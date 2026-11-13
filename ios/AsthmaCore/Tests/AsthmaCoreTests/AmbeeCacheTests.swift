import Foundation
import Testing
@testable import AsthmaCore

/// Counts what reaches "Ambee" and remembers where it was asked.
private actor Counting: AmbeeSource {
    nonisolated let sourceName = Ambee.source
    var calls: [String] = []
    var points: [String] = []
    /// History hours Ambee doesn't have.
    var gaps: Set<Date> = []
    var delay: Duration = .zero

    func setGaps(_ g: Set<Date>) { gaps = g }
    func setDelay(_ d: Duration) { delay = d }

    func latest(latitude: Double, longitude: Double, at date: Date) async throws -> AmbeeHour {
        calls.append("latest"); points.append(String(format: "%.4f,%.4f", latitude, longitude))
        try await Task.sleep(for: delay)
        return AmbeeHour(date: date, pm25: 5, weedPollen: 18)
    }
    func history(latitude: Double, longitude: Double, from: Date, to: Date) async throws -> [AmbeeHour] {
        calls.append("history")
        return stride(from: from.timeIntervalSince1970, through: to.timeIntervalSince1970, by: 3600)
            .map { Date(timeIntervalSince1970: $0) }.filter { !gaps.contains($0) }.map { AmbeeHour(date: $0, pm25: 7) }
    }
    func forecast(latitude: Double, longitude: Double, from: Date, hours: Int) async throws -> [AmbeeHour] {
        calls.append("forecast")
        return (0..<hours).map { AmbeeHour(date: from.addingTimeInterval(Double($0) * 3600), ozone: 40, isForecast: true) }
    }
}

/// A clock the test moves.
private final class Clock: @unchecked Sendable {
    var date: Date
    init(_ d: Date) { date = d }
}

@Suite struct AmbeeCacheTests {
    let start = ISO8601DateFormatter().date(from: "2026-11-13T16:20:00Z")!

    @Test func cellsAreAbout500m() {
        let a = CachedAmbee.cell(37.7712, -122.4188), b = CachedAmbee.cell(37.7731, -122.4152)
        #expect(a == b)
        #expect(a.key == "37.7725,-122.4175")
        #expect(CachedAmbee.cell(37.7760, -122.4188) != a)   // ~550 m north
    }

    @Test func latestOncePerCellPerHour() async throws {
        let fake = Counting(), clock = Clock(start)
        let cache = CachedAmbee(fake, now: { clock.date })
        _ = try await cache.latest(latitude: 37.7712, longitude: -122.4188, at: start)
        let again = try await cache.latest(latitude: 37.7731, longitude: -122.4152, at: start.addingTimeInterval(600))
        #expect(again.date == start.addingTimeInterval(600))
        #expect(again.weedPollen == 18)
        #expect(await fake.calls.count == 1)
        #expect(await fake.points == ["37.7725,-122.4175"])   // the cell's centre, not the exact pin
        clock.date = start.addingTimeInterval(3600)
        _ = try await cache.latest(latitude: 37.7712, longitude: -122.4188, at: clock.date)
        #expect(await fake.calls.count == 2)
    }

    @Test func simultaneousAsksShareOneCall() async throws {
        let fake = Counting(); await fake.setDelay(.milliseconds(50))
        let cache = CachedAmbee(fake, now: { [start] in start })
        async let a = cache.latest(latitude: 37.77, longitude: -122.42, at: start)
        async let b = cache.latest(latitude: 37.77, longitude: -122.42, at: start)
        _ = try await (a, b)
        #expect(await fake.calls.count == 1)
    }

    @Test func pastHoursAreKeptAndOnlyGapsFetched() async throws {
        let fake = Counting(), clock = Clock(start)
        let cache = CachedAmbee(fake, now: { clock.date })
        let from = start.addingTimeInterval(-48 * 3600), to = start.addingTimeInterval(-24 * 3600)
        let first = try await cache.history(latitude: 37.77, longitude: -122.42, from: from, to: to)
        #expect(first.count == 25)
        clock.date = start.addingTimeInterval(5 * 3600)
        _ = try await cache.history(latitude: 37.77, longitude: -122.42, from: from, to: to)
        #expect(await fake.calls == ["history"])
        // A wider range fetches only what's new.
        let wider = try await cache.history(latitude: 37.77, longitude: -122.42, from: from, to: start)
        #expect(wider.count == 49)
        #expect(await fake.calls.count == 2)
    }

    @Test func settledGapsAreNotAskedForAgain() async throws {
        let fake = Counting(), clock = Clock(start)
        let gap = CachedAmbee.slot(start.addingTimeInterval(-30 * 3600))
        await fake.setGaps([gap])
        let cache = CachedAmbee(fake, now: { clock.date })
        let from = start.addingTimeInterval(-48 * 3600), to = start.addingTimeInterval(-24 * 3600)
        _ = try await cache.history(latitude: 37.77, longitude: -122.42, from: from, to: to)
        clock.date = start.addingTimeInterval(2 * 3600)
        let again = try await cache.history(latitude: 37.77, longitude: -122.42, from: from, to: to)
        #expect(again.count == 24)
        #expect(await fake.calls.count == 1)
    }

    @Test func recentHistoryIsRetriedHourly() async throws {
        let fake = Counting(), clock = Clock(start)
        // Ambee lags: the last hour isn't there yet.
        await fake.setGaps([CachedAmbee.slot(start)])
        let cache = CachedAmbee(fake, now: { clock.date })
        _ = try await cache.history(latitude: 37.77, longitude: -122.42, from: start.addingTimeInterval(-3600), to: start)
        _ = try await cache.history(latitude: 37.77, longitude: -122.42, from: start.addingTimeInterval(-3600), to: start)
        #expect(await fake.calls.count == 1)
        await fake.setGaps([])
        clock.date = start.addingTimeInterval(3600)
        let later = try await cache.history(latitude: 37.77, longitude: -122.42, from: start.addingTimeInterval(-3600), to: start)
        #expect(later.count == 2)
        #expect(await fake.calls.count == 2)
    }

    @Test func forecastReusedForThreeHours() async throws {
        let fake = Counting(), clock = Clock(start)
        let cache = CachedAmbee(fake, now: { clock.date })
        let a = try await cache.forecast(latitude: 37.77, longitude: -122.42, from: start, hours: 24)
        #expect(a.count == 24)
        clock.date = start.addingTimeInterval(2 * 3600)
        let b = try await cache.forecast(latitude: 37.77, longitude: -122.42, from: clock.date, hours: 24)
        #expect(b.first.map { $0.date >= clock.date.addingTimeInterval(-3600) } == true)
        #expect(await fake.calls.count == 1)
        clock.date = start.addingTimeInterval(3 * 3600 + 60)
        _ = try await cache.forecast(latitude: 37.77, longitude: -122.42, from: clock.date, hours: 24)
        #expect(await fake.calls.count == 2)
    }

    @Test func survivesARelaunch() async throws {
        let fake = Counting(), clock = Clock(start)
        let saved = Saved()
        let cache = CachedAmbee(fake, now: { clock.date }, save: { saved.data = $0 })
        _ = try await cache.latest(latitude: 37.77, longitude: -122.42, at: start)
        let relaunched = CachedAmbee(fake, saved: saved.data, now: { clock.date })
        _ = try await relaunched.latest(latitude: 37.77, longitude: -122.42, at: start)
        #expect(await fake.calls.count == 1)
    }
}

private final class Saved: @unchecked Sendable { var data: Data? }
