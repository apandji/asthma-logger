import AsthmaCore
import SwiftData
import SwiftUI

/// All moments: a month calendar with a dot per moment, and the full list below (tap a day to
/// filter it). Opened by pinching in on the Journal; Settings lives here too. Swipe a row to delete.
struct MomentListView: View {
    @State private var day: Date?
    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)!.start
    @Environment(\.modelContext) private var context
    @Environment(LogService.self) private var services
    @Query(sort: \LogEvent.loggedAt, order: .reverse) private var events: [LogEvent]

    var body: some View {
            List {
                Section {
                    MonthCalendar(month: $month, events: Array(events), selected: $day)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                } footer: {
                    if day != nil {
                        Button("Show all days") { withAnimation { day = nil } }.font(.footnote.weight(.semibold))
                    }
                }

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
            .toolbar(.visible, for: .navigationBar)
            .settingsToolbar()
    }

    private var days: [(day: Date, events: [LogEvent])] {
        let cal = Calendar.current
        let shown = day.map { d in events.filter { cal.isDate($0.loggedAt, inSameDayAs: d) } } ?? Array(events)
        let grouped = Dictionary(grouping: shown) { cal.startOfDay(for: $0.loggedAt) }
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

/// A month of days; each day shows up to three dots (orange rescue, blue standard). Tap a day to filter.
struct MonthCalendar: View {
    @Binding var month: Date
    let events: [LogEvent]
    @Binding var selected: Date?
    /// When set, each dot shares its id with the moment's card on the Journal, so cards shrink into dots.
    var namespace: Namespace.ID? = nil
    /// The zoom anchor: the current moment's day square.
    var anchorStore: AnchorFrames? = nil
    var anchorHidden = false
    var anchorDay: Date? = nil
    /// The moment whose sky fills the anchor square.
    var anchorMoment: LogEvent? = nil

    private let cal = Calendar.current

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(month.formatted(.dateTime.month(.wide).year())).font(.headline)
                Spacer()
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                Button { shift(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(cal.isDate(month, equalTo: .now, toGranularity: .month))
            }
            .buttonStyle(.borderless)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 6) {
                ForEach(Array(cal.veryShortWeekdaySymbols.enumerated()), id: \.offset) { _, s in
                    Text(s).font(.caption2).foregroundStyle(Theme.secondaryText)
                }
                ForEach(0..<leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 40) }
                ForEach(days, id: \.self) { d in dayCell(d) }
            }
        }
    }

    private func dayCell(_ d: Date) -> some View {
        let ms = events.filter { cal.isDate($0.loggedAt, inSameDayAs: d) && $0.moment != .okay }
        let isSel = selected.map { cal.isDate($0, inSameDayAs: d) } ?? false
        return Button {
            withAnimation(.snappy) { selected = isSel ? nil : d }
        } label: {
            VStack(spacing: 4) {
                Text("\(cal.component(.day, from: d))")
                    .font(.subheadline.weight(cal.isDateInToday(d) ? .bold : .regular))
                    .foregroundStyle(d > .now ? Theme.secondaryText : .primary)
                HStack(spacing: 2) {
                    ForEach(Array(ms.prefix(3))) { m in
                        dot(m)
                    }
                }
                .frame(height: 9)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(isSel ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 10))
            .background {
                if let anchorDay, cal.isDate(anchorDay, inSameDayAs: d) {
                    Group {
                        if let m = anchorMoment {
                            AmbientField(weave: m.weave, temperatureF: m.conditions?.best(.temperature)?.value,
                                         date: m.loggedAt, conditions: m.conditions)
                        } else {
                            Color.white.opacity(0.16)
                        }
                    }
                    .clipShape(.rect(cornerRadius: 10, style: .continuous))
                    .modifier(AnchorReport(key: "month", store: anchorStore, hidden: anchorHidden))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(d > .now)
        .accessibilityLabel("\(d.formatted(date: .complete, time: .omitted)), \(ms.count) inhaler moments")
    }

    @ViewBuilder private func dot(_ m: LogEvent) -> some View {
        let c = MomentSwatch(event: m, size: 9, ringWidth: 1.5)
        if let namespace { c.matchedGeometryEffect(id: m.id, in: namespace) } else { c }
    }

    private var days: [Date] {
        let range = cal.range(of: .day, in: .month, for: month)!
        return range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: month) }
    }

    private var leadingBlanks: Int {
        (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
    }

    private func shift(_ n: Int) {
        if let m = cal.date(byAdding: .month, value: n, to: month) { withAnimation { month = m } }
    }
}

/// All moments, in place on the Journal: the month with a dot per moment (the cards shrink into them)
/// and every moment listed below. Tap one to go back to it; pinch out or Done to return.
struct MomentsOverview: View {
    let events: [LogEvent]
    let namespace: Namespace.ID
    var anchorStore: AnchorFrames? = nil
    var anchorHidden = false
    var anchorDay: Date? = nil
    var anchorMoment: LogEvent? = nil
    let open: (LogEvent) -> Void
    let close: () -> Void

    /// Opens on the anchor's month, so its square exists for the zoom to land in.
    @State private var month: Date
    @State private var day: Date?

    init(events: [LogEvent], namespace: Namespace.ID, anchorStore: AnchorFrames? = nil, anchorHidden: Bool = false,
         anchorDay: Date? = nil, anchorMoment: LogEvent? = nil,
         open: @escaping (LogEvent) -> Void, close: @escaping () -> Void) {
        self.events = events
        self.namespace = namespace
        self.anchorStore = anchorStore
        self.anchorHidden = anchorHidden
        self.anchorDay = anchorDay
        self.anchorMoment = anchorMoment
        self.open = open
        self.close = close
        _month = State(initialValue: Calendar.current.dateInterval(of: .month, for: anchorDay ?? .now)!.start)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text("All moments").font(.system(.title, design: .serif, weight: .medium))
                    Spacer()
                    Button("Done", action: close).font(.subheadline.weight(.semibold))
                }
                HStack(spacing: 14) {
                    stat(.rescue, "Rescue")
                    stat(.maintenance, "Standard")
                    Text("this month").foregroundStyle(Theme.secondaryText)
                }
                .font(.subheadline)

                MonthCalendar(month: $month, events: events, selected: $day, namespace: namespace,
                              anchorStore: anchorStore, anchorHidden: anchorHidden, anchorDay: anchorDay, anchorMoment: anchorMoment)
                    .padding(14)
                    .frostedCard()

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { e in
                        Button { open(e) } label: {
                            HStack(spacing: 12) {
                                MomentDot(moment: e.moment, size: 9)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(e.loggedAt.formatted(.dateTime.weekday(.abbreviated).month().day().hour().minute()))
                                        .font(.subheadline.weight(.medium))
                                    Text(e.weave.isEmpty ? "No air reading" : e.airLine)
                                        .font(.caption).foregroundStyle(Theme.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 4)
                .frostedCard()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)  // clear the + bar
        }
        .scrollIndicators(.hidden)
    }

    private var rows: [LogEvent] {
        let cal = Calendar.current
        let inhaler = events.filter { $0.moment != .okay }.reversed()
        if let day { return inhaler.filter { cal.isDate($0.loggedAt, inSameDayAs: day) } }
        return Array(inhaler)
    }

    private func stat(_ kind: MomentKind, _ label: String) -> some View {
        let n = events.filter { $0.moment == kind && Calendar.current.isDate($0.loggedAt, equalTo: month, toGranularity: .month) }.count
        return HStack(spacing: 6) {
            MomentDot(moment: kind, size: 8)
            Text("\(n) \(label)").monospacedDigit()
        }
    }
}
