import SwiftUI

/// Menus look, Moments tab (owner, Nov 13): your inhaler use by Day, Month or Year. One ink throughout, the
/// timeline's marks: rescue filled, standard an outline. Simple for now; other logs can join later.
struct MenusMomentsView: View {
    let events: [LogEvent]
    let now: Date
    /// Every moment with air, baselines included, for Year's air blanket.
    var air: [LogEvent] = []

    enum Mode: String, CaseIterable, Identifiable {
        case day = "Day", month = "Month", year = "Year"
        var id: String { rawValue }
    }
    @State private var mode: Mode = .day
    private let cal = Calendar.current

    /// Inhaler use by day: how many rescue and standard.
    /// A moment with symptoms but no inhaler (April, Nov 20): it counts as a day in Moments too.
    static func isSymptoms(_ e: LogEvent) -> Bool {
        e.moment == .note && e.tags.contains { $0.kind == .symptom }
    }

    /// What led the air each day, in the air blanket's inks (April, Nov 20: Day and Month carry Year's colours).
    private var leads: [Date: AirBlanket.Day] { AirBlanket.days(air.isEmpty ? events : air) }

    /// Days with a symptoms moment.
    private var symptomDays: Set<Date> { Set(events.filter(Self.isSymptoms).map { cal.startOfDay(for: $0.loggedAt) }) }

    private var byDay: [Date: (rescue: Int, standard: Int)] {
        var out: [Date: (rescue: Int, standard: Int)] = [:]
        for e in events where Self.isSymptoms(e) { out[cal.startOfDay(for: e.loggedAt)] = out[cal.startOfDay(for: e.loggedAt)] ?? (0, 0) }
        for e in events where e.moment == .rescue || e.moment == .maintenance {
            let d = cal.startOfDay(for: e.loggedAt)
            var c = out[d] ?? (0, 0)
            if e.moment == .rescue { c.rescue += 1 } else { c.standard += 1 }
            out[d] = c
        }
        return out
    }

    /// From the first moment (a month back at least) to today.
    private var firstDay: Date {
        let first = events.map(\.loggedAt).min() ?? now
        return cal.startOfDay(for: min(first, cal.date(byAdding: .day, value: -30, to: now)!))
    }

    var body: some View {
        // A moment's row opens its editor (owner, Nov 20), pushed like Settings. Its own stack: a destination
        // inside a tab isn't seen by Home's.
        NavigationStack {
            page
                .toolbarVisibility(.hidden, for: .navigationBar)
                .navigationDestination(for: UUID.self) { id in
                    if let e = events.first(where: { $0.id == id }) {
                        MomentEditor(event: e)
                            // Light, on the app's paper, like every other screen on this look.
                            .environment(\.colorScheme, .light)
                            .preferredColorScheme(.light)
                            .toolbarColorScheme(.light, for: .navigationBar)
                    }
                }
        }
    }

    private var page: some View {
        let counts = byDay
        return VStack(spacing: 0) {
            Picker("View", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 8)

            switch mode {
            case .day: dayList(counts)
            case .month:
                // The weekdays stay put above the scrolling months.
                weekdayHeader.padding(.horizontal, 16).padding(.bottom, 6)
                Divider().padding(.horizontal, 16)
                monthList(counts)
            case .year: yearList(counts)
            }
        }
        .sensoryFeedback(.selection, trigger: mode)
    }

    // MARK: Day

    private var dayLeads: [Date: AirBlanket.Day] { leads }

    private func dayList(_ counts: [Date: (rescue: Int, standard: Int)]) -> some View {
        let today = cal.startOfDay(for: now)
        let days = stride(from: 0, through: cal.dateComponents([.day], from: firstDay, to: today).day ?? 0, by: 1)
            .compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
            // Only days you used your inhaler (owner, Nov 19): no "No inhaler use" rows.
            .filter { counts[$0] != nil }
        return ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(days, id: \.self) { d in
                    let c = counts[d] ?? (0, 0)
                    // A card per day, in the app's one card and type (April, Nov 20: as Home and Insights).
                    Self.card {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(d.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                                    .font(Theme.Figtree.font(size: 17, weight: .medium))
                                Text(Self.summary(c, symptoms: momentsOn(d).filter(Self.isSymptoms).count)).font(Theme.Figtree.font(size: 13)).foregroundStyle(.secondary)
                                // The day's air, as on Year: its ink and what led.
                                if let lead = dayLeads[d], !lead.lead.isEmpty {
                                    HStack(spacing: 6) {
                                        RoundedRectangle(cornerRadius: 3).fill(AirBlanket.ink(lead.lead).opacity(0.45 + 0.55 * lead.strength))
                                            .frame(width: 18, height: 8)
                                        Text("\(ComingDays.word(lead.lead)) led the air").font(Theme.Figtree.font(size: 13)).foregroundStyle(.secondary)
                                    }
                                    .padding(.top, 2)
                                }
                            }
                            // No pills here (April, Nov 20): each moment row below already carries its own.
                            Spacer(minLength: 8)
                        }
                        .padding(.vertical, 15)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(d.formatted(date: .complete, time: .omitted)), \(Self.summary(c))")
                        // The day's moments, each one tap from its editor.
                        ForEach(momentsOn(d)) { e in
                            Divider()
                            momentRow(e)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
        .overlay {
            if days.isEmpty {
                Text("Days you use your inhaler show up here.")
                    .font(Theme.Figtree.font(size: 15)).foregroundStyle(.secondary)
            }
        }
    }

    /// Inhaler and manual moments on a day, latest first. Demo moments stay out (they aren't yours to edit).
    private func momentsOn(_ day: Date) -> [LogEvent] {
        events.filter { ($0.moment == .rescue || $0.moment == .maintenance || $0.moment == .note) && !$0.isDemo && cal.isDate($0.loggedAt, inSameDayAs: day) }
            .sorted { $0.loggedAt > $1.loggedAt }
    }

    /// Time, kind and puffs, the place under it, and a chevron: tap to edit.
    private func momentRow(_ e: LogEvent) -> some View {
        NavigationLink(value: e.id) {
            HStack(spacing: 12) {
                Group {
                    // Symptoms take the same lungs as Home's tag (April, Nov 20).
                    if Self.isSymptoms(e) { Self.symptomMark(size: 14) }
                    else if e.moment == .note { Capsule().strokeBorder(Color.primary.opacity(0.4), style: StrokeStyle(lineWidth: 1.3, dash: [2, 2])) }
                    else { Self.pill(filled: e.moment == .rescue, width: 7, height: 16) }
                }
                .frame(width: 20, height: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text([e.loggedAt.formatted(date: .omitted, time: .shortened), Self.isSymptoms(e) ? "Symptoms" : e.moment.title, e.puffs > 1 ? "\(e.puffs) puffs" : nil]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(Theme.Figtree.font(size: 16)).foregroundStyle(.primary)
                    // Symptoms said in words under the time; otherwise the place.
                    let felt = e.tags.filter { $0.kind == .symptom }.sorted().map(\.label)
                    if !felt.isEmpty {
                        Text(felt.joined(separator: ", ")).font(Theme.Figtree.font(size: 13)).foregroundStyle(.secondary).lineLimit(1)
                    } else if let place = e.placeName, !place.isEmpty {
                        Text(place).font(Theme.Figtree.font(size: 13)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }

    /// The app's card (Home, Insights): white on the paper, 22 pt corners, 16 pt sides.
    static func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(uiColor: .secondarySystemGroupedBackground)))
    }

    static func summary(_ c: (rescue: Int, standard: Int), symptoms: Int = 0) -> String {
        var parts: [String] = []
        if c.rescue > 0 { parts.append("\(c.rescue) inhaler") }
        if c.standard > 0 { parts.append("\(c.standard) standard") }
        if symptoms > 0 { parts.append(symptoms == 1 ? "symptoms" : "\(symptoms) with symptoms") }
        return parts.isEmpty ? "No inhaler use" : parts.joined(separator: " · ")
    }

    /// A symptoms moment's mark: the lungs, as on Home's tag.
    static func symptomMark(size: CGFloat) -> some View {
        Image(systemName: "lungs").font(.system(size: size, weight: .semibold)).foregroundStyle(Color.primary)
    }

    /// The timeline's mark: rescue filled, standard an outline.
    static func pill(filled: Bool, width: CGFloat = 8, height: CGFloat = 18) -> some View {
        Group {
            if filled { Capsule().fill(Color.primary) } else { Capsule().strokeBorder(Color.primary, lineWidth: 1.3) }
        }
        .frame(width: width, height: height)
    }

    // MARK: Month

    private var months: [Date] {
        let start = cal.dateInterval(of: .month, for: firstDay)!.start
        let end = cal.dateInterval(of: .month, for: now)!.start
        var out: [Date] = []
        var m = start
        while m <= end { out.append(m); m = cal.date(byAdding: .month, value: 1, to: m)! }
        return out
    }

    private func monthList(_ counts: [Date: (rescue: Int, standard: Int)]) -> some View {
        let tint = leads
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(months, id: \.self) { m in
                        Self.card {
                            Text(m.formatted(.dateTime.month(.wide).year()))
                                .font(Theme.Figtree.font(size: 17, weight: .medium))
                                .padding(.vertical, 15)
                            monthGrid(m, counts, mini: false, leads: tint).padding(.bottom, 12)
                        }
                        .id(m)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
            .onAppear { proxy.scrollTo(months.last, anchor: .bottom) }
        }
    }

    private var weekdayHeader: some View {
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let order = (0..<7).map { (cal.firstWeekday - 1 + $0) % 7 }
        return HStack(spacing: 0) {
            ForEach(order, id: \.self) { i in
                Text(cal.shortStandaloneWeekdaySymbols[i].uppercased())
                    .font(Theme.Figtree.font(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(symbols[i])
            }
        }
    }

    /// One month as a week grid. Full size: a pill above each day's number. Mini (Year): the number itself,
    /// in a filled circle for a rescue day and an outlined one for a standard-only day.
    private func monthGrid(_ month: Date, _ counts: [Date: (rescue: Int, standard: Int)], mini: Bool, leads: [Date: AirBlanket.Day] = [:]) -> some View {
        let days = cal.range(of: .day, in: .month, for: month)!.count
        let lead = (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
        let today = cal.startOfDay(for: now)
        let cells: [Date?] = Array(repeating: nil, count: lead) + (0..<days).map { cal.date(byAdding: .day, value: $0, to: month) }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return LazyVGrid(columns: columns, spacing: mini ? 4 : 10) {
            ForEach(cells.indices, id: \.self) { i in
                if let d = cells[i] {
                    let c = counts[d] ?? (0, 0)
                    if mini { miniDay(d, c, today: today) } else { fullDay(d, c, today: today, lead: leads[d]) }
                } else {
                    Color.clear.frame(height: mini ? 16 : 56)
                }
            }
        }
    }

    private func fullDay(_ d: Date, _ c: (rescue: Int, standard: Int), today: Date, lead: AirBlanket.Day? = nil) -> some View {
        let future = d > today
        return VStack(spacing: 8) {
            ZStack {
                HStack(spacing: 3) {
                    if c.rescue > 0 { Self.pill(filled: true) } else if c.standard > 0 { Self.pill(filled: false) }
                    // Symptoms that day (April, Nov 20): a dashed pill, as on the Day list, beside any inhaler pill.
                    if symptomDays.contains(d) { Self.symptomMark(size: 13) }
                }
            }
            .frame(height: 18)
            Text("\(cal.component(.day, from: d))")
                .font(Theme.Figtree.font(size: 17, weight: d == today ? .medium : .regular).monospacedDigit())
                .foregroundStyle(future ? Color.secondary : Color.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(.vertical, 4)
        // The day's air (April, Nov 20): a soft tile in the ink that led, as on Year's blanket.
        .background {
            if let lead, !lead.lead.isEmpty, !future {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AirBlanket.ink(lead.lead).opacity(0.18 + 0.32 * lead.strength))
                    .padding(.horizontal, 2)
            }
        }
        // Today: an outline round the day, like the timeline's playhead.
        .overlay {
            if d == today { Capsule().strokeBorder(Color.primary, lineWidth: 1.3).padding(.horizontal, 6) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(d.formatted(date: .abbreviated, time: .omitted)), \(Self.summary(c))")
    }

    private func miniDay(_ d: Date, _ c: (rescue: Int, standard: Int), today: Date) -> some View {
        let future = d > today
        return Text("\(cal.component(.day, from: d))")
            .font(Theme.Figtree.font(size: 10, weight: d == today ? .medium : .regular).monospacedDigit())
            .foregroundStyle(c.rescue > 0 ? Color(uiColor: .systemBackground) : future ? Color.secondary : Color.primary)
            .frame(width: 17, height: 17)
            .background {
                if c.rescue > 0 { Circle().fill(Color.primary) }
                else if c.standard > 0 { Circle().strokeBorder(Color.primary, lineWidth: 1) }
                else if symptomDays.contains(d) { Circle().strokeBorder(Color.primary.opacity(0.5), lineWidth: 1) }
                else if d == today { Circle().strokeBorder(Color.primary.opacity(0.4), lineWidth: 1) }
            }
            .frame(maxWidth: .infinity)
    }

    // MARK: Year

    private var years: [Int] {
        Array(cal.component(.year, from: firstDay)...cal.component(.year, from: now))
    }

    private func yearList(_ counts: [Date: (rescue: Int, standard: Int)]) -> some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(years.reversed(), id: \.self) { y in
                    // The air blanket (April, Nov 20): a stitch per day in the ink that led the air.
                    Self.card {
                        AirBlanket(year: y, events: air.isEmpty ? events : air, now: now)
                            .padding(.bottom, 16)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 120)
        }
    }
}
