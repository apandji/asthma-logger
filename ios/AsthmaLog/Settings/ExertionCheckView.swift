#if DEBUG
import AsthmaCore
import SwiftData
import SwiftUI

/// Settings › Demo and development › Exertion check. For the latest real moments (and right now): what
/// Health and Motion return for the time before, the decision, and what the moment has stored. Numbers are
/// fine here: it's a debugging page, not the app. Debug builds only.
struct ExertionCheckView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \LogEvent.loggedAt, order: .reverse) private var events: [LogEvent]
    @State private var results: [Date: ExertionReader.Result] = [:]
    @State private var now: (Date, ExertionReader.Result)?
    @State private var restampNote: String?
    @State private var busy = false

    private var recent: [LogEvent] { Array(events.lazy.filter { !$0.isDemo }.prefix(6)) }

    var body: some View {
        Form {
            Section {
                if let (date, r) = now {
                    resultRows(r, at: date)
                } else {
                    Text("Reading…").foregroundStyle(Theme.secondaryText)
                }
                Button("Read again") { Task { await readNow() } }
            } header: {
                Text("Right now")
            } footer: {
                Text("The 30 minutes before now (Motion, steps) and the hour before (workouts). Go for a brisk walk of 15 minutes or more, come back and read again.")
            }

            Section {
                if recent.isEmpty { Text("No real moments yet.").foregroundStyle(Theme.secondaryText) }
                ForEach(recent) { e in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(e.moment.title) · \(e.loggedAt.formatted(.dateTime.weekday(.abbreviated).month().day().hour().minute()))")
                            .font(.subheadline.weight(.semibold))
                        Text("Stored: \(stored(e))").font(.caption.monospaced())
                        if let r = results[e.loggedAt] {
                            resultRows(r, at: e.loggedAt)
                        } else {
                            Text("Reading…").font(.caption).foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Latest moments")
            } footer: {
                Text("Stored is what the moment saved when it was logged. Read is what Health and Motion say now for the same window. Motion keeps about a week.")
            }

            Section {
                Button(busy ? "Re-stamping…" : "Re-stamp moments without it") {
                    Task {
                        busy = true
                        let n = await ExertionReader.restampIfNeeded(in: context, force: true)
                        busy = false
                        restampNote = "Filled in \(n) moment\(n == 1 ? "" : "s")."
                        await readMoments()
                    }
                }
                .disabled(busy)
            } footer: {
                Text(restampNote ?? "Fills in active / not active for real moments that have nothing stored, from Health and Motion history. It runs once by itself after Health is connected.")
            }
        }
        .navigationTitle("Exertion check")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await readNow()
            await readMoments()
        }
    }

    @ViewBuilder private func resultRows(_ r: ExertionReader.Result, at date: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            row("Health", r.healthNote)
            row("Motion", r.motionNote)
            row("Decision", decision(r.decision))
            if let line = Exertion.line(active: r.decision.active) {
                Text([line, Exertion.detail(r.decision.source)].compactMap { $0 }.joined(separator: " "))
                    .font(.caption).italic()
            }
        }
    }

    private func row(_ name: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(name).font(.caption.weight(.medium)).foregroundStyle(Theme.secondaryText).frame(width: 60, alignment: .leading)
            Text(text).font(.caption)
        }
    }

    private func decision(_ d: Exertion.Decision) -> String {
        switch d.active {
        case true?: "active (\(d.source?.rawValue ?? "?"))"
        case false?: "not active"
        case nil: "unknown (missing, not counted)"
        }
    }

    private func stored(_ e: LogEvent) -> String {
        switch e.exerted {
        case true?: "active, \(e.exertedByRaw ?? "no source kept")"
        case false?: "not active"
        case nil: "nothing (unknown)"
        }
    }

    private func readNow() async {
        let date = Date.now
        now = (date, await ExertionReader.read(before: date))
    }

    private func readMoments() async {
        for e in recent { results[e.loggedAt] = await ExertionReader.read(before: e.loggedAt) }
    }
}
#endif
