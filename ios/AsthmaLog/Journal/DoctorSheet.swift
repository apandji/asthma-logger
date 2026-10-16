import AsthmaCore
import SwiftUI

/// What you take to the doctor: a table of every inhaler moment with the outdoor air at the time, on
/// screen and as a CSV to share. Raw readings with their sources; demo moments are marked and demo
/// pollen says so. No judgement, no percentages, nothing invented.
struct DoctorSheet: View {
    let events: [LogEvent]
    @AppStorage(DemoPollen.Season.key) private var pollenSeason = DemoPollen.Season.off
    @Environment(\.dismiss) private var dismiss

    private var rows: [LogEvent] { events.filter { $0.moment != .okay }.reversed() }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Every inhaler moment with the outdoor air at the time, from the nearest monitors and Apple Weather. Readings are regional, not at your location. Not medical advice.")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                }
                Section("\(rows.count) moments") {
                    ForEach(rows) { e in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                MomentDot(moment: e.moment, size: 8)
                                Text(e.loggedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                                    .font(.subheadline.weight(.medium))
                                if e.isDemo { Text("Demo").font(.caption2.weight(.semibold)).foregroundStyle(Theme.secondaryText) }
                            }
                            Text(line(e)).font(.caption).foregroundStyle(Theme.secondaryText)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("For your doctor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(item: csvFile(), preview: SharePreview("felt air moments.csv")) { Label("Share table", systemImage: "square.and.arrow.up") }
                }
            }
        }
    }

    private func line(_ e: LogEvent) -> String {
        var parts: [String] = []
        if let t = e.conditions?.best(.temperature) { parts.append("\(Int(t.value.rounded()))°") }
        if let h = e.conditions?.best(.humidity) { parts.append("\(Int(h.value.rounded()))% humidity") }
        if let p = e.conditions?.best(.pm25) { parts.append("PM2.5 \(fmt(p.value)) \(p.unit)") }
        if let o = e.conditions?.best(.ozone) { parts.append("ozone \(fmt(o.value)) \(o.unit)") }
        if let a = e.conditions?.best(.aqi) { parts.append("AQI \(Int(a.value))") }
        if let place = e.placeName { parts.append(place) }
        return parts.isEmpty ? "No outdoor reading." : parts.joined(separator: " · ")
    }

    private func fmt(_ v: Double) -> String { v >= 10 || v == v.rounded() ? String(Int(v.rounded())) : String(format: "%.1f", v) }

    /// One row per moment, one column per reading, sources in their own columns.
    private func csvFile() -> URL {
        var lines = ["date,time,inhaler,place,indoor_outdoor,temperature_f,humidity_pct,weather,pm25_ugm3,pm25_source,ozone_ppb,ozone_source,aqi,aqi_source,pm10_ugm3,no2_ppb,tree_pollen,grass_pollen,weed_pollen,pollen_source,note,demo"]
        let day = Date.FormatStyle().year().month(.twoDigits).day(.twoDigits)
        for e in rows.reversed() {
            let c = e.conditions
            func v(_ s: Signal) -> String { c?.best(s).map { fmt($0.value) } ?? "" }
            func src(_ s: Signal) -> String { c?.best(s)?.source ?? "" }
            let pollen = DemoPollen.sample(at: e.loggedAt, season: pollenSeason)
            let fields: [String] = [
                e.loggedAt.formatted(day), e.loggedAt.formatted(date: .omitted, time: .shortened),
                e.moment == .rescue ? "rescue" : "standard",
                e.placeName ?? "", e.indoorOutdoor?.rawValue ?? "",
                v(.temperature), v(.humidity), c?.weatherCondition ?? "",
                v(.pm25), src(.pm25), v(.ozone), src(.ozone), v(.aqi), src(.aqi), v(.pm10), v(.no2),
                pollen.map { "\($0.tree.count)" } ?? "", pollen.map { "\($0.grass.count)" } ?? "", pollen.map { "\($0.weed.count)" } ?? "",
                pollen == nil ? "" : "Demo (not real)",
                e.note ?? "", e.isDemo ? "yes" : "",
            ]
            lines.append(fields.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ","))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("felt air moments.csv")
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
