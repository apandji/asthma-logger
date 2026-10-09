import Foundation
import Testing
@testable import AsthmaCore

@Suite struct LiftTests {
    @Test func formatLift() {
        #expect(Lift.format(.infinity) == "∞")
        #expect(Lift.format(12.4) == "12")
        #expect(Lift.format(2.25) == "2.3")
        #expect(Lift.format(1.0) == "1.0")
    }

    @Test func v2BinsAddRowsOnlyWhenPresent() {
        var frames = DemoData.frames()
        let before = Lift.compute(frames, gate: .demo).rows.count
        for i in frames.indices where frames[i].kind == .attack && i % 2 == 0 {
            frames[i].tags = [.exercise]
            frames[i].place = .work
        }
        let rows = Lift.compute(frames, gate: .demo).rows
        #expect(rows.count == before + 2)  // tag_exercise:yes, place:work
        #expect(rows.contains { $0.id == "tag_exercise:yes" })
    }
}

@Suite struct ForecastTests {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    @Test func rateTableFavorsInhalerConditions() {
        let table = RateTable(frames: DemoData.frames(), gate: .demo)
        #expect(table.isPersonal)
        #expect(table.entries["ozone:high"]!.logLR > 1)
        #expect(table.entries["ozone:low"]!.logLR < 0)
    }

    @Test func elevatedAfternoonBecomesAWindow() {
        let frames = DemoData.frames()
        let table = RateTable(frames: frames, gate: .demo)
        let bander = RiskBander(table: table, baselineFrames: frames)
        let day = cal.date(from: DateComponents(year: 2026, month: 8, day: 3))!
        let hours = (0..<24).map { h -> ForecastHour in
            let hot = (13...17).contains(h)
            let f = FeatureFrame(id: "f\(h)", kind: .baseline, hourOfDay: h, season: .summer,
                                 tempBand: hot ? .hot : .mild, humidityBand: .ok,
                                 pm25Band: .low, ozoneBand: hot ? .high : .low, pollenWeed: hot ? .moderate : .none)
            return ForecastHour(start: day.addingTimeInterval(Double(h) * 3600), frame: f)
        }
        let days = Outlook.days(hours: hours, table: table, bander: bander, now: day, calendar: cal)
        #expect(days.count == 1)
        #expect(days[0].band == .elevated)
        let w = try! #require(days[0].windows.first)
        #expect(cal.component(.hour, from: w.start) == 13)
        // Demo inhaler logs run into the evening and no usual day does, so 6–10p stays elevated too.
        #expect(cal.component(.hour, from: w.end) == 22)
        #expect(w.drivers.first?.id == "ozone:high")
    }

    @Test func coldStartUsesGenericHazards() {
        let few = Array(DemoData.frames().prefix(3))
        let table = RateTable(frames: few)
        #expect(!table.isPersonal)
        let bander = RiskBander(table: table, baselineFrames: few)
        let f = FeatureFrame(id: "x", kind: .baseline, hourOfDay: 15, season: .summer, ozoneBand: .high, heatAlert: true)
        let days = Outlook.days(hours: [ForecastHour(start: Date(timeIntervalSince1970: 0), frame: f)],
                                table: table, bander: bander, calendar: cal)
        #expect(days[0].genericHazards == ["a heat alert", "high ozone"])
        #expect(OutlookCopy.coldStart(days[0].genericHazards) ==
            "The forecast shows a heat alert and high ozone. That's a general heads-up, not your pattern yet.")
        #expect(days[0].windows.isEmpty)
    }
}

@Suite struct NarratorTests {
    let input = NarratorInput(report: Lift.compute(DemoData.frames(), gate: .demo), styleScore: 80)

    // Golden fixtures cover "never happened" and too-few-samples; this covers a nonzero usual count.
    @Test func templateReadsPlainly() {
        var i = input
        i.season = nil
        i.rows = [NarratorRow(bin: "humidity", level: "humid", attacksWith: 8, baselinesWith: 6,
                              attackRate: 0.8, baselineRate: 0.25, lift: 3.2, gated: true)]
        i.nAttacks = 10
        i.nBaselines = 24
        #expect(Narrator.template(i).headline ==
            "8 of the 10 times you used your inhaler, it was humid. On usual days, that only happened 6 of 24 times.")
        #expect(Narrator.clause("hour", "evening") == "it was evening")
        #expect(Narrator.clause("indoor_outdoor", "outdoor") == "you were likely outdoors")
        #expect(Narrator.clause("tag_coldAir", "yes") == "you noted cold air")
    }

    @Test func styleBands() {
        #expect(NarratorStyle(score: 0) == .clinical)
        #expect(NarratorStyle(score: 33) == .clinical)
        #expect(NarratorStyle(score: 50) == .plain)
        #expect(NarratorStyle(score: 67) == .poetic)
    }

    @Test func promptCarriesTableNotDiary() {
        let p = Narrator.prompt(input)
        #expect(p.instructions.contains("POETIC"))
        #expect(p.prompt.contains("\"ozone\""))
        #expect(!p.prompt.contains("latitude"))
    }

    @Test func guardAcceptsHonestSentence() {
        let out = NarrationGuard.accept(
            headline: "Here's what stands out: ozone was high on 8 of the 10 times you used your inhaler, and on 0 of 24 usual days.",
            caveat: "Outdoor air only.", drivers: ["ozone:high", "made:up"], input: input)
        #expect(out.source == .onDevice)
        #expect(out.drivers == ["ozone:high"])
    }

    @Test func guardRejectsInventedNumbersAndPredictions() {
        #expect(NarrationGuard.problems(headline: "Ozone was high on 9 of 10 days.", input: input)
            .contains(.unknownNumber("9")))
        #expect(!NarrationGuard.problems(headline: "You will have an attack on Thursday.", input: input).isEmpty)
        #expect(!NarrationGuard.problems(headline: "Ozone causes 80% of your attacks.", input: input).isEmpty)
        #expect(NarrationGuard.problems(headline: "PM2.5 was moderate on 8 of 10.", input: input).isEmpty)
        // Plain-language rules: no "attacks", no ratios.
        #expect(!NarrationGuard.problems(headline: "Ozone was high on 8 of 10 attacks.", input: input).isEmpty)
        #expect(!NarrationGuard.problems(headline: "Ozone was high 8 of 10 times (~99×).", input: input).isEmpty)
        #expect(!NarrationGuard.problems(headline: "Ozone was high twice as often on 8 of 10.", input: input).isEmpty)
        let out = NarrationGuard.accept(headline: "You will have an attack.", caveat: "", drivers: [], input: input)
        #expect(out.source == .template)
    }
}

@Suite struct JournalTests {
    @Test func sanitizeDropsUnknown() {
        #expect(TagExtraction.sanitize(["pets", "aliens", "exercise", "pets"]) == [.exercise, .pets])
    }

    @Test func keywordGuess() {
        let tags = TagExtraction.keywordGuess("Went running with the dog, then a campfire. Catching a cold?")
        #expect(tags.contains(.exercise))
        #expect(tags.contains(.pets))
        #expect(tags.contains(.smoke))
        #expect(!tags.contains(.coldAir))
    }
}

@Suite struct PlaceTests {
    @Test func findsHomeAndWork() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let monday = cal.date(from: DateComponents(year: 2026, month: 9, day: 7))!
        let home = (38.6270, -90.1994), work = (38.6488, -90.3108), gym = (38.6000, -90.2500)
        var visits: [Visit] = []
        for d in 0..<5 {
            let day = monday.addingTimeInterval(Double(d) * 86400)
            visits.append(Visit(latitude: home.0, longitude: home.1, arrival: day.addingTimeInterval(-5 * 3600), departure: day.addingTimeInterval(8 * 3600)))
            visits.append(Visit(latitude: work.0 + 0.0003, longitude: work.1, arrival: day.addingTimeInterval(9 * 3600), departure: day.addingTimeInterval(17 * 3600)))
            if d % 2 == 0 {
                visits.append(Visit(latitude: gym.0, longitude: gym.1, arrival: day.addingTimeInterval(18 * 3600), departure: day.addingTimeInterval(19 * 3600)))
            }
        }
        let places = Places.cluster(visits, calendar: cal)
        #expect(places.count == 3)
        #expect(places.first { $0.suggestion == .home }.map { abs($0.latitude - home.0) < 0.001 } == true)
        #expect(places.first { $0.suggestion == .work }.map { abs($0.latitude - work.0) < 0.001 } == true)
        #expect(places.contains { $0.suggestion == .frequent })
        #expect(Places.match(latitude: home.0, longitude: home.1 + 0.0005,
                             places: [(.home, home.0, home.1), (.work, work.0, work.1)]) == .home)
    }

    @Test func indoorOutdoorGuess() {
        #expect(IndoorOutdoorGuesser.guess(IndoorSignals(horizontalAccuracyM: 50, atPlace: .home, motion: .stationary)).value == .indoor)
        #expect(IndoorOutdoorGuesser.guess(IndoorSignals(horizontalAccuracyM: 5, motion: .running)).value == .outdoor)
        #expect(IndoorOutdoorGuesser.guess(IndoorSignals()).value == .unknown)
    }
}

@Suite struct ConditionsTests {
    @Test func honestCopy() {
        let o = EnvObservation(signal: .pm25, value: 27.4, unit: "µg/m³", asOf: Date(timeIntervalSince1970: 16 * 3600),
                            source: "OpenAQ", spatialScale: .station, distanceKm: 17.6, stationName: "Denver-CAMP")
        #expect(ObservationCopy.line(o, timeZone: TimeZone(identifier: "UTC")!) ==
            "Regional outdoor PM2.5 27 µg/m³ · 11 mi from Denver-CAMP · 4:00 PM · OpenAQ")
        let uv = EnvObservation(signal: .uvIndex, value: 0, unit: "UV", asOf: Date(timeIntervalSince1970: 16 * 3600),
                                source: "Apple Weather", spatialScale: .modelGrid)
        #expect(ObservationCopy.line(uv, timeZone: TimeZone(identifier: "UTC")!) ==
            "Modeled outdoor UV index 0 · 4:00 PM · Apple Weather")
    }

    @Test func conditionsFeedFrames() {
        let now = Date()
        let c = Conditions(observations: [
            EnvObservation(signal: .temperature, value: 96, unit: "°F", asOf: now, source: "Apple Weather", spatialScale: .modelGrid),
            EnvObservation(signal: .ozone, value: 72, unit: "ppb", asOf: now, source: "OpenAQ", spatialScale: .station),
            EnvObservation(signal: .ozone, value: 40, unit: "ppb", asOf: now, source: "AirNow", spatialScale: .region),
        ])
        let f = FrameBuilder.frame(id: "a", kind: .attack, hourOfDay: 15, month: 7, conditions: c.input)
        #expect(f.tempBand == .hot)
        #expect(f.heatAlert)  // ≥95°F counts as extreme
        #expect(f.ozoneBand == .high)  // first provider wins
    }

    @Test func openAQPrefersNearMonitor() throws {
        let json = """
        {"results":[
          {"id":1,"name":"Sensor","isMobile":false,"isMonitor":false,"coordinates":{"latitude":38.63,"longitude":-90.20},
           "sensors":[{"id":11,"parameter":{"id":2,"name":"pm25","units":"µg/m³"}}]},
          {"id":2,"name":"Blair St","isMobile":false,"isMonitor":true,"coordinates":{"latitude":38.66,"longitude":-90.20},
           "sensors":[{"id":21,"parameter":{"id":10,"name":"o3","units":"ppm"}},{"id":22,"parameter":{"id":2,"name":"pm25","units":"µg/m³"}}]}
        ]}
        """
        let locs = try JSONDecoder().decode(OpenAQ.Results<OpenAQ.Location>.self, from: Data(json.utf8)).results!
        let pm = OpenAQ.nearest(locs, lat: 38.627, lon: -90.199) { $0.measuresPM25 }
        #expect(pm?.id == 2)
        let latest = [OpenAQ.Latest(datetime: .init(utc: ISO8601DateFormatter().string(from: Date()), local: nil), value: 0.061, sensorsId: 21)]
        let o3 = OpenAQ.reading(at: pm!, latest: latest, lat: 38.627, lon: -90.199) { $0.measuresOzone }
        #expect(o3.map { abs($0.value - 61) < 1e-9 } == true)
    }

    // Shapes from the 2026 AirNow services (observation/current/ziplatLong, forecast/current).
    @Test func airNowDecodesCurrentServices() throws {
        let observed = """
        [{"dateObserved":"2026-10-01","hourObserved":"19:00","localTimeZone":"CDT","reportingAreaName":"Saint Louis",
          "siteID":"295100085","siteName":"Blair Street","parameterName":"PM2.5","nowcastAQI":16,"aqiCategoryName":"Good"},
         {"dateObserved":"2026-10-01","hourObserved":"19:00","localTimeZone":"CDT","reportingAreaName":"Saint Louis",
          "siteID":"295100085","siteName":"Blair Street","parameterName":"OZONE","nowcastAQI":38,"aqiCategoryName":"Good"}]
        """
        let rows = try JSONDecoder().decode([AirNow.Observed].self, from: Data(observed.utf8))
        let o = try #require(AirNow.aqiObservation(rows, fetchedAt: Date()))
        #expect(o.value == 38 && o.source == "AirNow" && o.spatialScale == .region)
        // Stamped with the hour AirNow observed (19:00 CDT = 00:00 UTC), not the fetch time.
        #expect(o.asOf == ISO8601DateFormatter().date(from: "2026-10-02T00:00:00Z"))
        #expect(ObservationCopy.line(o, timeZone: TimeZone(identifier: "UTC")!) ==
            "Regional outdoor AQI 38 · Good · ozone · Saint Louis · 12:00 AM · AirNow")

        let forecast = """
        [{"dateIssue":"2026-10-01","dateValid":"2026-10-01","reportingArea":"Saint Louis","parameterName":"OZONE",
          "aqi":-1,"categoryNumber":1,"categoryName":"Good","actionDay":false,"discussion":""},
         {"dateIssue":"2026-10-01","dateValid":"2026-10-02","reportingArea":"Saint Louis","parameterName":"OZONE",
          "aqi":-1,"categoryNumber":3,"categoryName":"Unhealthy for Sensitive Groups","actionDay":true,"discussion":""},
         {"dateIssue":"2026-10-01","dateValid":"2026-10-02","reportingArea":"Saint Louis","parameterName":"PM2.5",
          "aqi":-1,"categoryNumber":2,"categoryName":"Moderate","actionDay":false,"discussion":""}]
        """
        let days = AirNow.categoriesByDay(try JSONDecoder().decode([AirNow.Forecast].self, from: Data(forecast.utf8)))
        #expect(days["2026-10-01"]?.ozone == 1 && days["2026-10-01"]?.pm25 == nil)
        #expect(days["2026-10-02"]?.ozone == 3 && days["2026-10-02"]?.pm25 == 2)
    }
}

@Suite struct ForecastFrameTests {
    @Test func gateProgress() {
        let p = GateProgress(nAttacks: 5, nBaselines: 2, gate: .default)
        #expect(!p.isMet && p.minAttacks == 8 && p.minBaselines == 20)
        #expect(GateProgress(nAttacks: 8, nBaselines: 20, gate: .default).isMet)
    }

    @Test func lookAheadReadsPlainly() {
        let evening = RateTable.Entry(bin: "hour", level: "evening", attacksWith: 4, baselinesWith: 0, logLR: 1.2, gated: true)
        let ozone = RateTable.Entry(bin: "ozone", level: "high", attacksWith: 8, baselinesWith: 2, logLR: 0.9, gated: true)
        let w = RiskWindow(start: Date(), end: Date(), peakScore: 2, drivers: [evening, ozone], isPartial: true,
                           nAttacks: 10, nBaselines: 24)
        #expect(OutlookCopy.headline(w, timeRange: "8 PM–10 PM") ==
            "8 PM–10 PM looks more like the times you used your inhaler: evening and high ozone.")
        #expect(OutlookCopy.evidence(w) == [
            "Evening: 4 of your 10 inhaler times, 0 of 24 usual days.",
            "High ozone: 8 of your 10 inhaler times, 2 of 24 usual days.",
            "No air-quality forecast for these hours, so this is weather only.",
        ])
    }

    @Test func categoriesBecomeBands() {
        let f = FrameBuilder.forecastFrame(id: "h", hourOfDay: 15, month: 7,
                                           ForecastConditions(temperatureF: 91, humidityPct: 70, pm25Category: 1, ozoneCategory: 3))
        #expect(f.tempBand == .hot && f.humidityBand == .humid)
        #expect(f.pm25Band == .low && f.ozoneBand == .high)
        #expect(f.smokeAtPoint)
        #expect(f.pollenWeed == .unknown)
        #expect(ForecastConditions(temperatureF: 70).isPartial)
    }
}

@Suite struct MomentTests {
    @Test func kindsKeepStoredValuesAndOnlyRescueAndOkayFeedPatterns() {
        #expect(MomentKind(rawValue: "attack") == .rescue)
        #expect(MomentKind(rawValue: "baseline") == .okay)
        #expect(MomentKind.rescue.frameKind == .attack)
        #expect(MomentKind.okay.frameKind == .baseline)
        #expect(MomentKind.maintenance.frameKind == nil)
    }

    @Test func weaveUsesV1BandsWithDirectionWords() {
        let w = WeaveSpec(ConditionsInput(pm25: 20, ozonePpb: 40, temperatureF: 93, humidityPct: 80))
        #expect(w.levels[.air] == .medium)          // PM2.5 moderate beats ozone low
        #expect(w.levels[.temperature] == .high && w.words[.temperature] == "hot")
        #expect(w.levels[.humidity] == .high && w.words[.humidity] == "humid")
        #expect(w.levels[.pollen] == nil)           // no pollen source: absent, not low
        #expect(w.summary == "Air moderate · humid · hot")
    }

    @Test func weaveFallsBackToAQIAndStaysEmptyWithoutReadings() {
        #expect(WeaveSpec(ConditionsInput(aqi: 120)).levels[.air] == .high)
        #expect(WeaveSpec(ConditionsInput()).isEmpty)
        let mild = WeaveSpec(ConditionsInput(temperatureF: 70, humidityPct: 50))
        #expect(mild.levels[.temperature] == .low && mild.levels[.humidity] == .low)
    }
}

@Suite struct DemoWeekTests {
    @Test func demoWeekIsLabelledAndStopsAtNow() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 9))!
        let week = DemoWeek.moments(endingAt: now, calendar: cal)
        #expect(!week.isEmpty && week.allSatisfy { $0.at <= now })
        #expect(week.allSatisfy { $0.conditions.observations.allSatisfy { $0.source == DemoWeek.source } })
        #expect(week.contains { $0.kind == .rescue } && week.contains { $0.kind == .maintenance } && week.contains { $0.kind == .okay })
        #expect(week.contains { !WeaveSpec($0.conditions.input).isEmpty })
    }
}
