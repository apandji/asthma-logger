import AsthmaCore
import Charts
import SwiftData
import SwiftUI

/// How one outdoor factor changed over the days around a moment, from every captured moment
/// (rescue, standard and I'm okay). Only captured readings are plotted; the line joins them and
/// isn't continuous measurement. The selected moment is marked.
struct MomentTrendChart: View {
    let event: LogEvent
    @Query(sort: \LogEvent.loggedAt) private var all: [LogEvent]
    @State private var factor: Factor = .air

    enum Factor: String, CaseIterable, Identifiable {
        case air = "Air", humidity = "Humidity", temperature = "Temp"
        var id: String { rawValue }
        var weave: WeaveSpec.Factor {
            switch self { case .air: .air; case .humidity: .humidity; case .temperature: .temperature }
        }
    }

    struct Point: Identifiable {
        let id: UUID
        let at: Date
        let value: Double
        let moment: MomentKind
    }

    private let days = 7

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Factor", selection: $factor) {
                ForEach(Factor.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if points.count < 2 {
                Text("Not enough readings yet.")
                    .font(.footnote).foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                chart.frame(height: 200)
            }

            HStack(spacing: 14) {
                legend(Theme.rescue, "Rescue")
                legend(Theme.standard, "Standard")
                HStack(spacing: 4) {
                    Circle().strokeBorder(Theme.secondaryText, lineWidth: 1.5).frame(width: 8, height: 8)
                    Text("I'm okay")
                }
            }
            .font(.caption).foregroundStyle(Theme.secondaryText)

            Text("\(unitNote) The circled point is this moment. Dots are readings from the last \(days) days.")
                .font(.caption2).foregroundStyle(Theme.secondaryText)
        }
        .padding(.vertical, 4)
    }

    private var chart: some View {
        let ink = WeaveSwatch.ink(factor.weave)
        return Chart {
            ForEach(points) { p in
                LineMark(x: .value("Time", p.at), y: .value(factor.rawValue, p.value))
                    .foregroundStyle(ink.opacity(0.45))
                    .interpolationMethod(.monotone)
            }
            ForEach(points) { p in
                PointMark(x: .value("Time", p.at), y: .value(factor.rawValue, p.value))
                    .symbol {
                        switch p.moment {
                        case .rescue: Circle().fill(Theme.rescue).frame(width: 9, height: 9)
                        case .maintenance: Circle().fill(Theme.standard).frame(width: 9, height: 9)
                        case .okay: Circle().strokeBorder(Theme.secondaryText, lineWidth: 1.5).frame(width: 8, height: 8)
                        }
                    }
            }
            RuleMark(x: .value("This moment", event.loggedAt))
                .foregroundStyle(.primary.opacity(0.35))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            if let v = value(of: event) {
                PointMark(x: .value("Time", event.loggedAt), y: .value(factor.rawValue, v))
                    .symbolSize(220)
                    .foregroundStyle(.clear)
                    .symbol { Circle().strokeBorder(.primary, lineWidth: 2).frame(width: 16, height: 16) }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.weekday(.narrow))
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartYScale(domain: .automatic(includesZero: false))
        .animation(.smooth(duration: 0.45), value: factor)
    }

    /// The `days` days ending at the end of the moment's day (or now, if sooner).
    private var points: [Point] {
        let cal = Calendar.current
        let end = min(cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: event.loggedAt))!, .now.addingTimeInterval(60))
        let start = cal.date(byAdding: .day, value: -days, to: end)!
        // One line never mixes demo readings with real ones: plot the selected moment's kind only.
        return all.filter { $0.loggedAt >= start && $0.loggedAt <= end && $0.isDemo == event.isDemo }
            .compactMap { e in value(of: e).map { Point(id: e.id, at: e.loggedAt, value: $0, moment: e.moment) } }
    }

    private func value(of e: LogEvent) -> Double? {
        guard let c = e.conditions else { return nil }
        switch factor {
        case .air: return c.best(.pm25)?.value
        case .humidity: return c.best(.humidity)?.value
        case .temperature: return c.best(.temperature)?.value
        }
    }

    private var unitNote: String {
        switch factor {
        case .air: "Air: PM2.5 in µg/m³."
        case .humidity: "Humidity in %."
        case .temperature: "Temperature in °F."
        }
    }

    private func legend(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) { Circle().fill(color).frame(width: 8, height: 8); Text(label) }
    }
}
