import AsthmaCore
import Charts
import SwiftData
import SwiftUI

/// The Journal's Data mode: temperature, humidity and air as three stacked line charts that scroll
/// together through the last three days, hour by hour. Inhaler moments are drawn across all three at
/// their time (orange rescue, blue standard), so you can read what the air was doing around each one.
/// Lines come from hourly history (Apple Weather, nearest OpenAQ monitor) where you last logged;
/// without it, only the readings captured at your moments are plotted.
struct AirChartsView: View {
    /// Sideways: three slim charts filling the screen, a full day visible at once.
    var wide = false
    @Environment(LogService.self) private var services
    @Query(sort: \LogEvent.loggedAt) private var events: [LogEvent]
    @State private var history: HourlyHistory?
    @State private var loading = false
    @State private var scrollX = Date.now.addingTimeInterval(-12 * 3600)
    @State private var place: String?

    private let hoursBack: Double = 72
    private var visibleHours: Double { wide ? 24 : 12 }

    enum Metric: CaseIterable, Identifiable {
        case temperature, humidity, air
        var id: Self { self }
        var title: String { switch self { case .temperature: "Temperature"; case .humidity: "Humidity"; case .air: "Air (PM2.5)" } }
        var unit: String { switch self { case .temperature: "°F"; case .humidity: "%"; case .air: "µg/m³" } }
        var factor: WeaveSpec.Factor { switch self { case .temperature: .temperature; case .humidity: .humidity; case .air: .air } }
    }

    private var start: Date { Date.now.addingTimeInterval(-hoursBack * 3600) }

    var body: some View {
        if wide { wideBody } else { tallBody }
    }

    private var wideBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 14) {
                Text(rangeTitle).font(.headline)
                Text("Swipe to go back in time").font(.caption).foregroundStyle(Theme.secondaryText)
                Spacer()
                legend(Theme.rescue, "Rescue")
                legend(Theme.standard, "Standard")
                if loading { ProgressView().controlSize(.small) }
            }
            .font(.caption).foregroundStyle(Theme.secondaryText)
            ForEach(Metric.allCases) { m in card(m) }
        }
        .task { await load() }
    }

    private var tallBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(rangeTitle).font(Theme.headlineSerif)
                Text("Swipe sideways to go back in time. Lines show the air outside, hour by hour; marks are when you used an inhaler.")
                    .font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
            .padding(.horizontal, 4)

            ForEach(Metric.allCases) { m in
                card(m)
            }

            HStack(spacing: 14) {
                legend(Theme.rescue, "Rescue")
                legend(Theme.standard, "Standard")
                if loading { ProgressView().controlSize(.small) }
            }
            .font(.caption).foregroundStyle(Theme.secondaryText)
            .padding(.horizontal, 4)

            Text(footnote)
                .font(.caption2).foregroundStyle(Theme.secondaryText)
                .padding(.horizontal, 4)
            WeatherAttributionView().padding(.horizontal, 4)
        }
        .task { await load() }
    }

    // MARK: Chart

    private func card(_ m: Metric) -> some View {
        let line = series(m)
        let ink = WeaveSwatch.ink(m.factor)
        return VStack(alignment: .leading, spacing: wide ? 2 : 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(m.title).font(wide ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                Spacer()
                if let last = line.last {
                    Text("\(Int(last.value.rounded())) \(m.unit)").font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            if line.count < 2 {
                Text(loading ? "Loading…" : "No hourly readings here yet.")
                    .font(.footnote).foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: wide ? 40 : 110)
            } else {
                Chart {
                    ForEach(line) { p in
                        AreaMark(x: .value("Time", p.date), yStart: .value("Base", baseline(line)), yEnd: .value(m.title, p.value))
                            .foregroundStyle(LinearGradient(colors: [ink.opacity(0.28), ink.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.monotone)
                        LineMark(x: .value("Time", p.date), y: .value(m.title, p.value))
                            .foregroundStyle(ink)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.monotone)
                    }
                    ForEach(inhalerMoments) { e in
                        RuleMark(x: .value("Moment", e.loggedAt))
                            .foregroundStyle(color(e).opacity(0.55))
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            .annotation(position: .top, spacing: 2) {
                                Circle().fill(color(e)).frame(width: 8, height: 8)
                            }
                    }
                }
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: visibleHours * 3600)
                .chartScrollPosition(x: $scrollX)
                .chartXScale(domain: start...Date.now)
                .chartYScale(domain: yDomain(line))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                        AxisGridLine().foregroundStyle(Theme.secondaryText.opacity(0.15))
                        if let d = value.as(Date.self) {
                            AxisValueLabel {
                                Text(Calendar.current.component(.hour, from: d) == 0
                                     ? d.formatted(.dateTime.weekday(.abbreviated))
                                     : d.formatted(.dateTime.hour()))
                                    .fontWeight(Calendar.current.component(.hour, from: d) == 0 ? .semibold : .regular)
                            }
                        }
                    }
                }
                .chartYAxis { AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) }
                .frame(height: wide ? nil : 140)
                .frame(maxHeight: wide ? .infinity : nil)
                .accessibilityLabel("\(m.title) over the last three days")
            }
        }
        .padding(wide ? 8 : 14)
        .frostedCard()
    }

    /// Fit the axis to the data with a little room, so changes are visible (not squashed against 0).
    private func yDomain(_ line: [HourPoint]) -> ClosedRange<Double> {
        let lo = line.map(\.value).min() ?? 0
        let hi = line.map(\.value).max() ?? 1
        let pad = max((hi - lo) * 0.2, 2)
        return (baseline(line) - pad * 0.2)...(hi + pad)
    }

    private func baseline(_ line: [HourPoint]) -> Double {
        let lo = line.map(\.value).min() ?? 0
        let hi = line.map(\.value).max() ?? 1
        return lo - (hi - lo) * 0.15
    }

    // MARK: Data

    private var inhalerMoments: [LogEvent] {
        events.filter { $0.loggedAt >= start && $0.moment != .okay && !$0.isDemo }
    }

    /// Hourly history when it loaded; otherwise the readings captured at your moments.
    private func series(_ m: Metric) -> [HourPoint] {
        if let h = history {
            let s = switch m { case .temperature: h.temperature; case .humidity: h.humidity; case .air: h.pm25 }
            if s.count >= 2 { return s }
        }
        return events.filter { $0.loggedAt >= start && !$0.isDemo }.compactMap { e in
            guard let c = e.conditions else { return nil }
            let v = switch m {
            case .temperature: c.best(.temperature)?.value
            case .humidity: c.best(.humidity)?.value
            case .air: c.best(.pm25)?.value
            }
            return v.map { HourPoint(date: e.loggedAt, value: $0) }
        }
    }

    private func load() async {
        guard history == nil, !loading else { return }
        loading = true
        defer { loading = false }
        // Where you last logged in this window; else where you are now.
        var lat: Double?, lon: Double?
        if let e = events.last(where: { $0.loggedAt >= start && $0.latitude != nil && !$0.isDemo }) {
            lat = e.latitude; lon = e.longitude
            place = "where you last logged"
        } else if let fix = try? await services.location.currentLocation(timeout: .seconds(6)) {
            lat = fix.coordinate.latitude; lon = fix.coordinate.longitude
            place = "where you are"
        }
        guard let lat, let lon else { return }
        history = await HourlyHistory.load(latitude: lat, longitude: lon, from: start, to: .now)
    }

    private var rangeTitle: String {
        let end = scrollX.addingTimeInterval(visibleHours * 3600)
        let cal = Calendar.current
        if cal.isDateInToday(end) && cal.isDateInToday(scrollX) { return "Today" }
        if cal.isDateInToday(end) { return "Since yesterday" }
        return end.formatted(.dateTime.weekday(.wide))
    }

    private var footnote: String {
        var parts = ["Outdoor air \(place ?? "near you")."]
        if let h = history {
            if !h.temperature.isEmpty { parts.append("Temperature and humidity: Apple Weather.") }
            if let s = h.pm25Station { parts.append("PM2.5: OpenAQ, \(s).") }
            if h.pm25.isEmpty || h.temperature.isEmpty { parts.append("Where hourly data is missing, only readings taken at your moments are shown.") }
        }
        return parts.joined(separator: " ")
    }

    private func color(_ e: LogEvent) -> Color { e.moment == .rescue ? Theme.rescue : Theme.standard }

    private func legend(_ c: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1).fill(c).frame(width: 2, height: 12)
            Circle().fill(c).frame(width: 7, height: 7)
            Text(label)
        }
    }
}
