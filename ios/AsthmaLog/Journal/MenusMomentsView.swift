import SwiftUI

/// Menus look, Moments tab (owner, Nov 13): your inhaler use by Day, Month or Year. One ink throughout, the
/// timeline's marks: rescue filled, standard an outline. Simple for now; other logs can join later.
struct MenusMomentsView: View {
    let events: [LogEvent]
    let now: Date

    enum Mode: String, CaseIterable, Identifiable {
        case day = "Day", month = "Month", year = "Year"
        var id: String { rawValue }
    }
    @State private var mode: Mode = .day
    private let cal = Calendar.current

    /// Inhaler use by day: how many rescue and standard.
    private var byDay: [Date: (rescue: Int, standard: Int)] {
        var out: [Date: (rescue: Int, standard: Int)] = [:]
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
        let counts = byDay
        VStack(spacing: 0) {
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

    private func dayList(_ counts: [Date: (rescue: Int, standard: Int)]) -> some View {
        let today = cal.startOfDay(for: now)
        let days = stride(from: 0, through: cal.dateComponents([.day], from: firstDay, to: today).day ?? 0, by: 1)
            .compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(days, id: \.self) { d in
                    let c = counts[d] ?? (0, 0)
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(d.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                                .font(Theme.Figtree.font(size: 22, weight: .medium))
                            Text(Self.summary(c))
                                .font(Theme.Figtree.font(size: 15))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        HStack(spacing: 4) {
                            ForEach(0..<min(c.rescue, 5), id: \.self) { _ in Self.pill(filled: true) }
                            ForEach(0..<min(c.standard, max(0, 5 - c.rescue)), id: \.self) { _ in Self.pill(filled: false) }
                        }
                    }
                    .padding(.horizontal, 24).padding(.vertical, 22)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(d.formatted(date: .complete, time: .omitted)), \(Self.summary(c))")
                    Divider().padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 120)
        }
    }

    static func summary(_ c: (rescue: Int, standard: Int)) -> String {
        switch (c.rescue, c.standard) {
        case (0, 0): "No inhaler use"
        case (let r, 0): "\(r) rescue"
        case (0, let s): "\(s) standard"
        case (let r, let s): "\(r) rescue · \(s) standard"
        }
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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 28) {
                    ForEach(months, id: \.self) { m in
                        VStack(spacing: 14) {
                            Text(m.formatted(.dateTime.month(.abbreviated).year()))
                                .font(Theme.Figtree.font(size: 22, weight: .medium))
                            monthGrid(m, counts, mini: false)
                        }
                        .id(m)
                        .padding(.horizontal, 16)
                    }
                }
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
    private func monthGrid(_ month: Date, _ counts: [Date: (rescue: Int, standard: Int)], mini: Bool) -> some View {
        let days = cal.range(of: .day, in: .month, for: month)!.count
        let lead = (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
        let today = cal.startOfDay(for: now)
        let cells: [Date?] = Array(repeating: nil, count: lead) + (0..<days).map { cal.date(byAdding: .day, value: $0, to: month) }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return LazyVGrid(columns: columns, spacing: mini ? 4 : 10) {
            ForEach(cells.indices, id: \.self) { i in
                if let d = cells[i] {
                    let c = counts[d] ?? (0, 0)
                    if mini { miniDay(d, c, today: today) } else { fullDay(d, c, today: today) }
                } else {
                    Color.clear.frame(height: mini ? 16 : 56)
                }
            }
        }
    }

    private func fullDay(_ d: Date, _ c: (rescue: Int, standard: Int), today: Date) -> some View {
        let future = d > today
        return VStack(spacing: 8) {
            ZStack {
                if c.rescue > 0 { Self.pill(filled: true) } else if c.standard > 0 { Self.pill(filled: false) }
            }
            .frame(height: 18)
            Text("\(cal.component(.day, from: d))")
                .font(Theme.Figtree.font(size: 17, weight: d == today ? .medium : .regular).monospacedDigit())
                .foregroundStyle(future ? Color.secondary : Color.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(.vertical, 4)
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
                    VStack(spacing: 18) {
                        Text(String(y)).font(Theme.Figtree.font(size: 22, weight: .medium))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: 3), alignment: .center, spacing: 22) {
                            ForEach(1...12, id: \.self) { mo in
                                let m = cal.date(from: DateComponents(year: y, month: mo, day: 1))!
                                VStack(spacing: 6) {
                                    Text(m.formatted(.dateTime.month(.wide)))
                                        .font(Theme.Figtree.font(size: 13, weight: .medium))
                                        .foregroundStyle(m > now ? Color.secondary : Color.primary)
                                    monthGrid(m, counts, mini: true)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }
            .padding(.bottom, 120)
        }
    }
}
