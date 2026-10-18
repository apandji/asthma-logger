import AsthmaCore
import SwiftUI

/// What you take to the doctor: every inhaler moment with the outdoor air at the time, on screen, and
/// everything the engine runs on to share (`EngineExport`: every moment with full provenance, and the pattern
/// table). The screen stays simple; the files carry every number. No judgement, nothing invented.
struct DoctorSheet: View {
    let events: [LogEvent]
    @Environment(\.dismiss) private var dismiss

    private var rows: [LogEvent] { events.filter { $0.moment != .okay }.reversed() }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Every inhaler moment with the outdoor air at the time, from the nearest monitors and Apple Weather. Readings are regional, not at your location. Share gives two files: every moment with every reading and where it came from, and the pattern table felt air learns from. Not medical advice.")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                }
                Section("\(rows.count) moments") {
                    ForEach(rows) { e in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                MomentDot(moment: e.moment, size: 8)
                                Text(e.loggedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                                    .font(.subheadline.weight(.medium))
                            }
                            Text(line(e)).font(.caption).foregroundStyle(Theme.secondaryText)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Moments table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(items: EngineExport.files(events: events)) { Label("Share", systemImage: "square.and.arrow.up") }
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
}
