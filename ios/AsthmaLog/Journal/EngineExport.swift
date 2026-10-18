import AsthmaCore
import Foundation

/// Everything the engine runs on, as two CSV files (owner, Oct 17: "complex, data-driven backend, simple
/// frontend"). The screen shows no counts; this is where every number lives, for a doctor, a researcher or
/// us. Nothing is summarised away and nothing is invented.
/// - **felt air moments.csv:** one row per moment (rescue, standard, baseline: live, filled in, first capture),
///   every reading with its full provenance, the look-back, and the bins the pattern maths used.
/// - **felt air patterns.csv:** the lift table (counts, rates, lift, gate), with each bin's category and word,
///   the gate and the archetype.
enum EngineExport {
    static let signals: [Signal] = [.temperature, .humidity, .dewpoint, .uvIndex, .windSpeed, .pm25, .pm10, .ozone, .no2,
                                    .aqi, .pollenTree, .pollenGrass, .pollenWeed]

    static func files(events: [LogEvent]) -> [URL] {
        [write("felt air moments.csv", moments(events)), write("felt air patterns.csv", patterns(events))]
    }

    // MARK: Moments

    static func moments(_ events: [LogEvent]) -> [[String]] {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        iso.timeZone = .current
        let readingCols = signals.flatMap { s in
            ["value", "unit", "source", "scale", "station", "distance_km", "confidence", "as_of", "category"].map { "\(s.rawValue)_\($0)" }
        }
        let binCols = Bins.all.map { "bin_\($0.bin)" }
        var rows: [[String]] = [[
            "id", "logged_at", "kind", "baseline_source", "demo", "latitude", "longitude", "accuracy_m", "place",
            "indoor_outdoor", "indoor_guess", "indoor_guess_confidence", "indoor_confirmed", "env_status", "env_error",
            "weather", "alerts", "temp_fall_f",
            "lookback_pm25_level", "lookback_pm25_now_worst", "lookback_pm25_earlier_worst",
            "lookback_ozone_level", "lookback_ozone_now_worst", "lookback_ozone_earlier_worst",
            "lookback_temp_drop_level", "lookback_pm25_station", "lookback_ozone_station",
        ] + readingCols + ["in_patterns", "bin_spec_version"] + binCols + [
            "tags", "tags_reviewed", "voice_transcript", "voice_note_file", "health_sample_id", "note",
        ]]
        for e in events.sorted(by: { $0.loggedAt < $1.loggedAt }) {
            let c = e.conditions
            let lb = c?.lookBack
            let baselineSource = e.moment != .okay ? "" : e.isFirstCapture ? "first_capture" : e.isBackfilled ? "filled_in" : "live"
            var row: [String] = [
                e.id.uuidString, iso.string(from: e.loggedAt), kind(e.moment), baselineSource, e.isDemo ? "yes" : "",
                num(e.latitude, 5), num(e.longitude, 5), num(e.horizontalAccuracy, 0), e.placeName ?? "",
                e.indoorOutdoor?.rawValue ?? "", e.indoorGuessRaw ?? "", e.indoorGuessConfidenceRaw ?? "", e.indoorConfirmedRaw ?? "",
                e.envStatusRaw, e.envError ?? "",
                c?.weatherCondition ?? "", (c?.alerts ?? []).map(\.name).joined(separator: "; "), num(c?.tempFallF, 1),
                lb?.pm25Level.map { "\($0)" } ?? "", num(lb?.pm25Now.worst, 1), num(lb?.pm25Earlier.worst, 1),
                lb?.ozoneLevel.map { "\($0)" } ?? "", num(lb?.ozoneNow.worst, 1), num(lb?.ozoneEarlier.worst, 1),
                lb?.tempDropLevel.map { "\($0)" } ?? "", lb?.pm25Station ?? "", lb?.ozoneStation ?? "",
            ]
            for s in signals {
                if let o = c?.best(s) {
                    row += [num(o.value, 2), o.unit, o.source, o.spatialScale.rawValue, o.stationName ?? "", num(o.distanceKm, 1),
                            o.confidence.rawValue, iso.string(from: o.asOf), o.category ?? ""]
                } else {
                    row += Array(repeating: "", count: 9)
                }
            }
            // The frame the pattern maths used (nil for Standard doses, demo moments and moments without air).
            let frame = e.frame()
            row += [frame == nil ? "no" : "yes", String(BinSpec.version)]
            row += Bins.all.map { def in frame.flatMap { def.levelOf($0) } ?? "" }
            row += [e.tags.sorted().map(\.rawValue).joined(separator: "; "), e.tagsReviewed ? "yes" : "no",
                    e.voiceTranscript ?? "", e.voiceNoteFile ?? "", e.healthSampleID?.uuidString ?? "", e.note ?? ""]
            rows.append(row)
        }
        return rows
    }

    // MARK: Patterns

    static func patterns(_ events: [LogEvent]) -> [[String]] {
        let frames = events.compactMap { $0.frame() }
        let gate = LiftGate.default
        let report = Lift.compute(frames, gate: gate)
        let profile = AirProfile(report: report)
        let learned = GateProgress(nAttacks: report.nAttacks, nBaselines: report.nBaselines, gate: gate).isMet
        let archetype = Archetype(profile: profile, learned: learned)
        var rows: [[String]] = [[
            "bin", "level", "category", "word", "attacks_with", "n_attacks", "baselines_with", "n_baselines",
            "attack_rate", "baseline_rate", "lift", "gated",
        ]]
        for r in report.rows {
            rows.append([
                r.bin, r.level, AirProfile.Category.of(bin: r.bin)?.title ?? (TheRead.personalBins.contains(r.bin) ? "When and where" : ""),
                AirProfile.Strength.of(r).word, String(r.attacksWith), String(r.nAttacks), String(r.baselinesWith), String(r.nBaselines),
                num(r.attackRate, 3), num(r.baselineRate, 3), r.lift.isFinite ? num(r.lift, 2) : "inf", r.gated ? "yes" : "no",
            ])
        }
        // Context, as rows a spreadsheet keeps next to the table.
        rows.append([])
        rows.append(["_summary", "rescue moments", String(report.nAttacks)])
        rows.append(["_summary", "baseline moments", String(report.nBaselines)])
        rows.append(["_summary", "gate", "\(gate.minAttacks) rescue, \(gate.minBaselines) baseline, \(gate.minAttacksInLevel) in the level, lift > 1.25"])
        rows.append(["_summary", "learned", learned ? "yes" : "no"])
        rows.append(["_summary", "archetype", archetype.name])
        for a in profile.axes { rows.append(["_summary", "category \(a.category.title)", a.status.word, num(a.strength, 3)]) }
        rows.append(["_summary", "bin spec version", String(BinSpec.version)])
        rows.append(["_summary", "exported", ISO8601DateFormatter().string(from: .now)])
        return rows
    }

    // MARK: Helpers

    private static func kind(_ m: MomentKind) -> String {
        switch m {
        case .rescue: "rescue"
        case .maintenance: "standard"
        case .okay: "baseline"
        }
    }

    private static func num(_ v: Double?, _ digits: Int) -> String {
        guard let v, v.isFinite else { return "" }
        return String(format: "%.\(digits)f", v)
    }

    private static func write(_ name: String, _ rows: [[String]]) -> URL {
        let text = rows.map { $0.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ",") }
            .joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appending(path: name)
        try? text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
