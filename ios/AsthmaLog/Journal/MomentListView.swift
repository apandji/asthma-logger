import AsthmaCore
import SwiftData
import SwiftUI

/// Every moment as a plain list, newest first. Pushed from the Journal; swipe to delete.
struct MomentListView: View {
    @Environment(\.modelContext) private var context
    @Environment(LogService.self) private var services
    @Query(sort: \LogEvent.loggedAt, order: .reverse) private var events: [LogEvent]

    var body: some View {
            List {
                if let error = services.lastError {
                    Text(error).font(Theme.caption).foregroundStyle(.orange)
                }

                if events.isEmpty {
                    ContentUnavailableView(
                        "No logs yet",
                        systemImage: "wind",
                        description: Text("Tap Rescue or Standard below, or press a button on Apple Watch. felt air notes where you were and what the outdoor air was like.")
                    )
                    .listRowBackground(Color.clear)
                }

                ForEach(days, id: \.day) { group in
                    Section(group.day.formatted(.dateTime.weekday(.wide).month().day())) {
                        ForEach(group.events) { event in
                            NavigationLink(value: event) {
                                EventRow(event: event)
                            }
                        }
                        .onDelete { offsets in
                            let doomed = offsets.map { group.events[$0] }
                            Task {
                                for e in doomed { await services.delete(e, in: context) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("All moments")
            .navigationBarTitleDisplayMode(.inline)
    }

    private var days: [(day: Date, events: [LogEvent])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: events) { cal.startOfDay(for: $0.loggedAt) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0]!) }
    }
}

struct EventRow: View {
    let event: LogEvent

    var body: some View {
        HStack(alignment: .top, spacing: Theme.spacing) {
            MomentDot(moment: event.moment).frame(width: 24, height: 20)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.moment.title)
                    Spacer()
                    Text(event.loggedAt.formatted(date: .omitted, time: .shortened))
                        .font(Theme.number)
                        .foregroundStyle(Theme.secondaryText)
                }
                summary
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var summary: some View {
        switch event.envStatus {
        case .pending:
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("Stamping outdoor conditions…")
            }
            .font(Theme.caption).foregroundStyle(Theme.secondaryText)
        case .failed:
            Text("Couldn't get conditions").font(Theme.caption).foregroundStyle(.orange)
        case .ready, .partial:
            HStack(spacing: 6) {
                if let io = event.indoorOutdoor, io != .unknown {
                    Chip(text: io == .indoor ? "Indoors" : "Outdoors")
                }
                ForEach(chips, id: \.self) { Chip(text: $0) }
            }
        }
    }

    private var chips: [String] {
        guard let c = event.conditions else { return [] }
        var out: [String] = []
        if let t = c.best(.temperature) { out.append("\(Int(t.value.rounded()))°F") }
        if let pm = c.best(.pm25) { out.append("PM2.5 \(Int(pm.value.rounded()))") }
        else if let aqi = c.best(.aqi) { out.append("AQI \(Int(aqi.value))") }
        if let o3 = c.best(.ozone) { out.append("O₃ \(Int(o3.value.rounded()))") }
        if !c.alerts.isEmpty { out.append("Alert") }
        return out
    }
}
