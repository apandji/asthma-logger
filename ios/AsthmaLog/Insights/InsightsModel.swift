import AsthmaCore
import Foundation

/// Builds the lift table, narration and look-ahead. All math is AsthmaCore; this only gathers inputs.
@Observable
final class InsightsModel {
    private(set) var report: LiftReport?
    private(set) var narration: NarratorOutput?
    private(set) var days: [DayOutlook] = []
    private(set) var forecastNote: String?
    private(set) var isLoadingForecast = false
    private(set) var usingDemo = false
    private(set) var frameCount = (attacks: 0, baselines: 0, skipped: 0)

    private var table: RateTable?
    private var bander: RiskBander?

    func rebuild(events: [LogEvent], demo: Bool) {
        usingDemo = demo
        let frames: [FeatureFrame]
        let gate: LiftGate
        if demo {
            frames = DemoData.frames()
            gate = .demo
            frameCount = (10, 24, 0)
        } else {
            frames = events.compactMap { $0.frame() }
            gate = .default
            frameCount = (frames.filter { $0.kind == .attack }.count,
                          frames.filter { $0.kind == .baseline }.count,
                          events.count - frames.count)
        }
        let report = Lift.compute(frames, gate: gate)
        self.report = report
        let table = RateTable(frames: frames, gate: gate)
        self.table = table
        bander = RiskBander(table: table, baselineFrames: frames)
    }

    func narrate(styleScore: Int, useModel: Bool) async {
        guard let report else { return }
        let input = NarratorInput(report: report, styleScore: styleScore)
        narration = Narrator.template(input)
        if useModel && !report.gatedRows.isEmpty {
            narration = await OnDeviceModel.narrate(input)
        }
    }

    /// Next ~3 days at `latitude/longitude`: WeatherKit hourly + AirNow daily AQ categories.
    func loadForecast(latitude: Double, longitude: Double, placeLabel: String) async {
        guard let table, let bander else { return }
        isLoadingForecast = true
        defer { isLoadingForecast = false }
        do {
            let hours = try await WeatherProvider().hourly(latitude: latitude, longitude: longitude, hours: 72)
            var aq: [String: (pm25: Int?, ozone: Int?)] = [:]
            var notes = ["Forecast for \(placeLabel)."]
            if let key = Secrets.airNow {
                do { aq = try await AirNowProvider(key: key).forecast(latitude: latitude, longitude: longitude) }
                catch { notes.append("Air-quality forecast unavailable.") }
            } else {
                notes.append("No AirNow key — air quality not in the forecast.")
            }
            notes.append("Pollen not included yet.")

            let cal = Calendar.current
            let forecast = hours.map { h -> ForecastHour in
                let day = aq[AirNowProvider.dayString(h.date)]
                let conditions = ForecastConditions(temperatureF: h.temperatureF, humidityPct: h.humidityPct,
                                                    pm25Category: day?.pm25, ozoneCategory: day?.ozone)
                let parts = cal.dateComponents([.hour, .month], from: h.date)
                let frame = FrameBuilder.forecastFrame(id: h.date.ISO8601Format(), hourOfDay: parts.hour ?? 0,
                                                       month: parts.month ?? 1, conditions)
                return ForecastHour(start: h.date, frame: frame, isPartial: conditions.isPartial)
            }
            days = Outlook.days(hours: forecast, table: table, bander: bander, calendar: cal)
            forecastNote = notes.joined(separator: " ")
        } catch {
            days = []
            forecastNote = "Couldn't load the forecast: \(error.localizedDescription)"
        }
    }
}
