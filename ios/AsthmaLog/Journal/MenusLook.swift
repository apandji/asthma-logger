import AsthmaCore
import SwiftUI

// Design crit › App look › Menus (April's Oct 30 sketch): an information-architecture study on top of the
// Apple Health look. A side menu (≡) for Settings, sign-in and extras; a scale menu (Timeline / Month / Year)
// at the top right; the Apple Health look's header; Moments | Insights at the bottom with the +, which
// asks "Felt something?". The visual in the middle is the Health look's sky (the sketch's flower is a
// placeholder).

/// The scale menu at the top right.
enum MenusScale: String, CaseIterable, Identifiable {
    case timeline, month, year
    var id: String { rawValue }
    var title: String {
        switch self {
        case .timeline: "Timeline"
        case .month: "Month"
        case .year: "Year"
        }
    }
}

/// The bottom switch: the moments (this page at the chosen scale) or Insights, in place.
enum MenusTab: Hashable { case moments, insights }

// MARK: Top bar

/// ≡ on the left opens the side menu; the scale menu on the right.
struct MenusTopBar: View {
    @Binding var scale: MenusScale
    let openMenu: () -> Void

    var body: some View {
        HStack {
            Button(action: openMenu) {
                Image(systemName: "line.3.horizontal").font(.subheadline.weight(.semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Menu")
            Spacer()
            Menu {
                Picker("Scale", selection: $scale) {
                    ForEach(MenusScale.allCases) { Text($0.title).tag($0) }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(scale.title)
                    Image(systemName: "chevron.down").font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            .accessibilityLabel("Scale, \(scale.title)")
        }
        .padding(.horizontal, 20)
    }
}

// MARK: Month and Year

/// Month: the month's name, then a row of ticks per week (a tick every 6 hours, taller at each day's start).
/// Moments sit on their row as small pills in the timeline's colours; NOW is a tall line with its label.
struct MenusMonthView: View {
    let moments: [LogEvent]
    let now: Date
    private let cal = Calendar.current

    private var weeks: [Date] {
        guard let month = cal.dateInterval(of: .month, for: now),
              var start = cal.dateInterval(of: .weekOfYear, for: month.start)?.start else { return [] }
        var out: [Date] = []
        while start < month.end { out.append(start); start = cal.date(byAdding: .weekOfYear, value: 1, to: start)! }
        return out
    }

    var body: some View {
        let month = cal.dateInterval(of: .month, for: now)
        VStack(spacing: 30) {
            Text(now.formatted(.dateTime.month(.wide)))
                .font(.title2.weight(.bold))
                .padding(.top, 36)
            ForEach(weeks, id: \.self) { week in
                TickRow(start: week, end: cal.date(byAdding: .day, value: 7, to: week)!, slot: 6 * 3600,
                        major: { cal.component(.hour, from: $0) == 0 },
                        within: month, moments: moments, now: now)
                    .frame(height: 40)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
    }
}

/// Year: the year, then a row per month with a tick per day (taller on Sundays), moments and NOW as in Month.
struct MenusYearView: View {
    let moments: [LogEvent]
    let now: Date
    private let cal = Calendar.current

    var body: some View {
        let year = cal.dateInterval(of: .year, for: now)!
        let months = (0..<12).compactMap { cal.date(byAdding: .month, value: $0, to: year.start) }
        VStack(spacing: 10) {
            Text(now.formatted(.dateTime.year()))
                .font(.title2.weight(.bold))
                .padding(.top, 20).padding(.bottom, 14)
            ForEach(months, id: \.self) { m in
                HStack(spacing: 10) {
                    Text(m.formatted(.dateTime.month(.narrow)))
                        .font(.caption2.weight(.semibold)).foregroundStyle(.secondary).frame(width: 12)
                    TickRow(start: m, end: cal.date(byAdding: .month, value: 1, to: m)!, slot: 86_400,
                            major: { cal.component(.weekday, from: $0) == cal.firstWeekday },
                            within: nil, moments: moments, now: now, wholeDays: true)
                }
                .frame(height: 30)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
    }
}

/// One row of ticks from `start` to `end`, a tick per `slot`. Past ticks dark, ahead faint, outside `within`
/// none. Moments are pills (rescue orange, standard pale blue); with `wholeDays` a day with any moment gets one
/// pill, orange if any was a rescue. NOW, when it falls in the row, is a tall line with "NOW" above it.
private struct TickRow: View {
    let start: Date
    let end: Date
    let slot: TimeInterval
    let major: (Date) -> Bool
    let within: DateInterval?
    let moments: [LogEvent]
    let now: Date
    var wholeDays = false

    var body: some View {
        Canvas { ctx, size in
            let span = end.timeIntervalSince(start)
            let x = { (d: Date) in CGFloat(d.timeIntervalSince(start) / span) * size.width }
            let mid = size.height - 10
            var t = start
            while t < end {
                if within.map({ $0.contains(t) }) ?? true {
                    let h: CGFloat = major(t) ? 14 : 8
                    var p = Path()
                    p.move(to: CGPoint(x: x(t), y: mid - h / 2)); p.addLine(to: CGPoint(x: x(t), y: mid + h / 2))
                    ctx.stroke(p, with: .color(Color.primary.opacity(t > now ? 0.2 : 0.55)), lineWidth: 1)
                }
                t = t.addingTimeInterval(slot)
            }
            let inRow = moments.filter { $0.loggedAt >= start && $0.loggedAt < end }
            func pill(_ at: CGFloat, _ c: Color) {
                ctx.fill(Path(roundedRect: CGRect(x: at - 2.5, y: mid - 8, width: 5, height: 16), cornerRadius: 2.5), with: .color(c))
            }
            if wholeDays {
                let byDay = Dictionary(grouping: inRow) { Calendar.current.startOfDay(for: $0.loggedAt) }
                for (day, ms) in byDay {
                    pill(x(day), ms.contains { $0.moment == .rescue } ? Theme.rescue : Theme.standardSoft)
                }
            } else {
                for m in inRow where m.moment == .rescue || m.moment == .maintenance {
                    pill(x(m.loggedAt), m.moment == .rescue ? Theme.rescue : Theme.standardSoft)
                }
            }
            if now >= start, now < end {
                let nx = x(now)
                var line = Path()
                line.move(to: CGPoint(x: nx, y: mid - 14)); line.addLine(to: CGPoint(x: nx, y: mid + 8))
                ctx.stroke(line, with: .color(.primary), lineWidth: 1.5)
                ctx.draw(Text("Now").font(.caption2.weight(.semibold)), at: CGPoint(x: nx, y: mid - 22))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: Bottom

/// Moments | Insights on the left (the first segment names the page: Moments on the timeline, Timeline on
/// Month and Year, as in the sketch); the + on the right, which opens "Felt something?" and turns into ×.
struct MenusBottomBar: View {
    @Binding var tab: MenusTab
    let firstLabel: String
    /// `true`: voice memo (log a rescue and listen); `false`: log symptoms (log a rescue and write).
    let felt: (Bool) -> Void
    @State private var open = false

    var body: some View {
        HStack(alignment: .bottom) {
            HStack(spacing: 0) {
                segment(firstLabel, firstLabel == "Moments" ? "list.bullet" : "chart.bar.xaxis", .moments)
                segment("Insights", "sparkles", .insights)
            }
            .padding(.horizontal, 6)
            .glassEffect(.regular, in: .capsule)
            Spacer()
            Button { withAnimation(Theme.snap) { open.toggle() } } label: {
                Image(systemName: open ? "xmark" : "plus").font(.title2.weight(.semibold))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 56, height: 56)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .foregroundStyle(.primary)
            .accessibilityLabel(open ? "Close" : "Log")
            .overlay(alignment: .bottomTrailing) {
                if open {
                    feltCard
                        .offset(y: -68)
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomTrailing)))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .sensoryFeedback(.selection, trigger: tab)
    }

    private func segment(_ label: String, _ symbol: String, _ t: MenusTab) -> some View {
        Button { withAnimation(Theme.snap) { tab = t } } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 22, weight: .semibold)).frame(height: 28)
                Text(label).font(.caption2.weight(.semibold))
            }
            .foregroundStyle(tab == t ? Color.primary : Color.secondary)
            .frame(width: 96, height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(tab == t ? .isSelected : [])
    }

    private var feltCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Felt something?").font(.subheadline.weight(.semibold))
            option("Voice memo", "mic") { felt(true) }
            option("Log symptoms", "square.and.pencil") { felt(false) }
        }
        .padding(16)
        .frame(width: 210, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private func option(_ label: String, _ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Theme.snap) { open = false }
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol).foregroundStyle(Theme.rescue).frame(width: 20)
                Text(label)
            }
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
    }
}

// MARK: Side menu

/// Slides in from the left over the page: Settings, sign-in (not built yet) and the extras.
struct MenusSideMenu: View {
    let close: () -> Void
    let settings: () -> Void
    let doctor: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("felt air").font(.title2.weight(.bold))
                Spacer()
                Button(action: close) { Image(systemName: "xmark").font(.body.weight(.semibold)).frame(width: 44, height: 44) }
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Close menu")
            }
            .padding(.bottom, 16)
            row("person.crop.circle", "Sign in", note: "Not available yet", action: nil)
            Divider().padding(.vertical, 8)
            row("gearshape", "Settings", action: { close(); settings() })
            row("tablecells", "Table for your doctor", action: { close(); doctor() })
            Spacer()
            Text("felt air is a diary, not a medical device.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 60).padding(.bottom, 40)
        .frame(width: 300, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(uiColor: .systemGroupedBackground))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 4)
    }

    private func row(_ symbol: String, _ title: String, note: String? = nil, action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.body).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body)
                    if let note { Text(note).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
            }
            .padding(.vertical, 12).padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(uiColor: .secondarySystemGroupedBackground)))
            .contentShape(Rectangle())
        }
        .foregroundStyle(action == nil ? Color.secondary : Color.primary)
        .disabled(action == nil)
    }
}
