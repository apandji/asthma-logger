import AsthmaCore
import Charts
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

// MARK: Below the fold

/// The columns every row below Now shares, so the strip and each chart sit on one time axis: the page's 16 pt
/// margin, the card's 16 pt inset, a name column on the left and a value column on the right.
enum MenusColumns {
    static let page: CGFloat = 16
    static let card: CGFloat = 16
    static let name: CGFloat = 92
    static let value: CGFloat = 54
    static let gap: CGFloat = 8
}

/// The window of time on screen: its middle (the playhead) and how much it shows. Shared by the strip and
/// every chart, so panning or zooming one moves them all.
struct MenusWindow: Equatable {
    var center: Date
    var span: TimeInterval
    static let minSpan: TimeInterval = 6 * 3600
    static let maxSpan: TimeInterval = 30 * 86_400
    var start: Date { center.addingTimeInterval(-span / 2) }
    var end: Date { center.addingTimeInterval(span / 2) }
    var domain: ClosedRange<Date> { start...end }
    func x(_ d: Date, width: CGFloat) -> CGFloat { CGFloat(d.timeIntervalSince(start) / span) * width }
}

/// Pan (sideways drag) and zoom (pinch) on the shared window. `settle` runs when a gesture ends.
struct MenusWindowGestures: ViewModifier {
    @Binding var window: MenusWindow
    let width: CGFloat
    let limits: ClosedRange<Date>
    let settle: () -> Void
    @State private var panFrom: Date?
    @State private var zoomFrom: TimeInterval?

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { v in
                        guard panFrom != nil || abs(v.translation.width) > abs(v.translation.height) else { return }
                        let from = panFrom ?? window.center
                        panFrom = from
                        let t = from.addingTimeInterval(-Double(v.translation.width / max(width, 1)) * window.span)
                        window.center = min(max(t, limits.lowerBound), limits.upperBound)
                    }
                    .onEnded { _ in if panFrom != nil { panFrom = nil; settle() } }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { v in
                        let from = zoomFrom ?? window.span
                        zoomFrom = from
                        window.span = min(max(from / v.magnification, MenusWindow.minSpan), MenusWindow.maxSpan)
                    }
                    .onEnded { _ in zoomFrom = nil; settle() }
            )
    }
}

/// The sticky timeline: the playhead's day as a title with its time (and the verdict ahead), then the track on
/// the shared window, in the chart column: ticks that adapt to the zoom, your moments as pills, the forecast
/// as tinted slots, NOW, and the playhead in the middle. Pinch to zoom, drag to move, tap a moment to go to it.
struct MenusStrip: View {
    @Binding var window: MenusWindow
    let moments: [LogEvent]
    let forecast: [(Date, Double?)]
    let now: Date
    let verdict: String?
    let limits: ClosedRange<Date>
    let settle: () -> Void
    let backToNow: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var width: CGFloat = 1
    private let cal = Calendar.current
    private var atNow: Bool { abs(window.center.timeIntervalSince(now)) < window.span * 0.01 }

    var body: some View {
        VStack(spacing: 2) {
            Button(action: backToNow) {
                HStack(spacing: 6) {
                    Text(title).font(.title3.weight(.semibold))
                    if !atNow {
                        Image(systemName: window.center > now ? "arrow.uturn.backward" : "arrow.uturn.forward")
                            .font(.footnote.weight(.bold)).opacity(0.5)
                    }
                }
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            }
            .buttonStyle(PressStyle())
            .disabled(atNow)
            Text([atNow ? "Now" : window.center.formatted(.dateTime.hour().minute()), window.center >= now.addingTimeInterval(-60) ? verdict : nil]
                .compactMap { $0 }.joined(separator: " · "))
                .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                .monospacedDigit()
            HStack(spacing: MenusColumns.gap) {
                Text(spanLabel).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    .frame(width: MenusColumns.name, alignment: .leading)
                track
                Color.clear.frame(width: MenusColumns.value, height: 1)
            }
            .padding(.horizontal, MenusColumns.page + MenusColumns.card)
        }
        .padding(.top, 8).padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea(edges: .top))
        .sensoryFeedback(.selection, trigger: cal.startOfDay(for: window.center))
    }

    private var title: String {
        let d = window.center
        let day = cal.isDateInToday(d) ? "Today" : cal.isDateInYesterday(d) ? "Yesterday" : cal.isDateInTomorrow(d) ? "Tomorrow"
            : d.formatted(.dateTime.weekday(.wide))
        return "\(day), \(d.formatted(.dateTime.month(.wide).day()))"
    }

    /// How much is on screen: "12 h", "3 days", "2 weeks".
    private var spanLabel: String {
        let h = window.span / 3600
        if h < 36 { return "\(Int(h.rounded())) h" }
        let d = h / 24
        return d < 14 ? "\(Int(d.rounded())) days" : "\(Int((d / 7).rounded())) weeks"
    }

    private var track: some View {
        Canvas { ctx, size in
            let w = size.width, mid: CGFloat = 40
            let x = { (d: Date) in window.x(d, width: w) }
            let ink = Color.primary
            // Ticks: hours when zoomed in, days when out, weeks when far out; labels above the major ones.
            let (minor, major): (TimeInterval, TimeInterval) =
                window.span <= 36 * 3600 ? (3600, 6 * 3600) : window.span <= 10 * 86_400 ? (6 * 3600, 86_400) : (86_400, 7 * 86_400)
            var t = cal.dateInterval(of: .day, for: window.start)!.start
            while t <= window.end {
                if t >= window.start {
                    let isMajor = major == 7 * 86_400 ? cal.component(.weekday, from: t) == cal.firstWeekday && cal.component(.hour, from: t) == 0
                        : Int(t.timeIntervalSince(cal.startOfDay(for: t))) % Int(major) == 0
                    let h: CGFloat = isMajor ? 14 : 6
                    var p = Path(); p.move(to: CGPoint(x: x(t), y: mid - h / 2)); p.addLine(to: CGPoint(x: x(t), y: mid + h / 2))
                    ctx.stroke(p, with: .color(ink.opacity(t > now ? 0.18 : 0.4)), lineWidth: 1)
                    if isMajor {
                        let label = major < 86_400 ? t.formatted(.dateTime.hour())
                            : major == 86_400 ? t.formatted(.dateTime.weekday(.abbreviated).day())
                            : t.formatted(.dateTime.month(.abbreviated).day())
                        if abs(x(t) - w / 2) > 18 {
                            ctx.draw(Text(label).font(.caption2.weight(.medium)).foregroundStyle(ink.opacity(t > now ? 0.35 : 0.55)),
                                     at: CGPoint(x: x(t), y: 8))
                        }
                    }
                }
                t = t.addingTimeInterval(minor)
            }
            // The forecast ahead: a slot per hour in the verdict's colour.
            let slot = max(1, w * CGFloat(3600 / window.span))
            for (d, v) in forecast where d >= now && d <= window.end {
                let c: Color = v == nil ? ink.opacity(0.08) : (v! >= 1 ? Verdict.red : v! >= 0.5 ? Verdict.yellow : Verdict.green).opacity(0.7)
                ctx.fill(Path(CGRect(x: x(d), y: mid - 4, width: max(1, slot - 1), height: 8)), with: .color(c))
            }
            // Moments: pills, narrower as you zoom out.
            let pw: CGFloat = min(10, max(4, w * CGFloat(3 * 3600 / window.span)))
            for m in moments where m.loggedAt >= window.start && m.loggedAt <= window.end && (m.moment == .rescue || m.moment == .maintenance) {
                let r = CGRect(x: x(m.loggedAt) - pw / 2, y: mid - 11, width: pw, height: 22)
                ctx.fill(Path(roundedRect: r, cornerRadius: pw / 2), with: .color(m.moment == .rescue ? Theme.rescue : Theme.standardSoft))
            }
            // Now, and the playhead in the middle.
            if now >= window.start, now <= window.end {
                var n = Path(); n.move(to: CGPoint(x: x(now), y: mid - 16)); n.addLine(to: CGPoint(x: x(now), y: mid + 16))
                ctx.stroke(n, with: .color(ink.opacity(0.7)), lineWidth: 1.5)
            }
            var ph = Path(); ph.move(to: CGPoint(x: w / 2, y: mid - 18)); ph.addLine(to: CGPoint(x: w / 2, y: mid + 20))
            ctx.stroke(ph, with: .color(ink), lineWidth: 2)
            // Health's pointer, on the playhead.
            var tri = Path()
            tri.move(to: CGPoint(x: w / 2 - 5, y: mid - 26)); tri.addLine(to: CGPoint(x: w / 2 + 5, y: mid - 26))
            tri.addLine(to: CGPoint(x: w / 2, y: mid - 20)); tri.closeSubpath()
            ctx.fill(tri, with: .color(ink))
        }
        .frame(height: 60)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .contentShape(Rectangle())
        .onTapGesture { p in
            let t = window.start.addingTimeInterval(Double(p.x / max(width, 1)) * window.span)
            let tolerance = window.span * Double(14 / max(width, 1))
            if let m = moments.filter({ $0.moment == .rescue || $0.moment == .maintenance })
                .min(by: { abs($0.loggedAt.timeIntervalSince(t)) < abs($1.loggedAt.timeIntervalSince(t)) }),
               abs(m.loggedAt.timeIntervalSince(t)) < tolerance {
                withAnimation(Theme.smooth) { window.center = m.loggedAt }
                settle()
            }
        }
        .modifier(MenusWindowGestures(window: $window, width: width, limits: limits, settle: settle))
        .accessibilityElement()
        .accessibilityLabel("Timeline, \(spanLabel)")
        .accessibilityValue(title)
    }
}

/// Below the timeline: the conditions and your logs on the strip's window, every row in the same columns so
/// they line up with it and with each other. Environment: a small area chart per condition in the Health
/// look's category colours, rescue moments as faint orange rules, the playhead as a dark rule through all of
/// them. Body: inhaler use, what you noted, and what Apple Health will add. Pinch or drag here too.
/// Built from the readings stamped on your moments and baselines; a condition with none says so.
struct MenusDetails: View {
    @Binding var window: MenusWindow
    let events: [LogEvent]
    let now: Date
    let limits: ClosedRange<Date>
    let settle: () -> Void
    @State private var chartWidth: CGFloat = 1
    /// A little either side of the window, so lines run off the edges instead of stopping short.
    private var shown: [LogEvent] {
        let pad = window.span * 0.5
        return events.filter { $0.loggedAt >= window.start.addingTimeInterval(-pad) && $0.loggedAt <= window.end.addingTimeInterval(pad) }
    }
    private var rescues: [Date] { shown.filter { $0.moment == .rescue }.map(\.loggedAt) }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            section("Environment", "Outdoor, at your moments") {
                VStack(spacing: 0) {
                    row("Temperature", Theme.healthBlue, series(.temperature), unit: "°F")
                    row("Humidity", Theme.healthBlue, series(.humidity), unit: "%")
                    row("Wind", Theme.healthBlue, series(.windSpeed), unit: "mph")
                    row("Pressure", Theme.healthBlue, [], unit: "")
                    row("PM2.5", Theme.healthPurple, series(.pm25), unit: "µg")
                    row("Ozone", Theme.healthPurple, series(.ozone), unit: "ppb")
                    row("Pollen", Theme.healthYellow, pollen, unit: "")
                    row("Flu and illness", Theme.healthYellow, [], unit: "")
                }
            }
            section("Body", "From your logs and Apple Health") {
                VStack(spacing: 0) {
                    dots("Inhaler use", shown.filter { $0.moment == .rescue || $0.moment == .maintenance }
                        .map { ($0.loggedAt, $0.moment == .rescue ? Theme.rescue : Theme.standardSoft) })
                    dots("Felt journal", shown.filter { $0.moment == .note || !($0.voiceTranscript ?? "").isEmpty }
                        .map { ($0.loggedAt, Color.primary) })
                    empty("Activity", "From Apple Health, not connected yet")
                    empty("Heart and breathing", "Heart rate and respiratory rate, empty for now")
                }
            }
        }
        .padding(.horizontal, MenusColumns.page)
        .modifier(MenusWindowGestures(window: $window, width: chartWidth, limits: limits, settle: settle))
    }

    // MARK: Data

    private func series(_ s: Signal) -> [(Date, Double)] {
        shown.compactMap { e in e.conditions?.best(s).map { (e.loggedAt, $0.value) } }
    }

    /// The highest of tree, grass and weed pollen at each moment.
    private var pollen: [(Date, Double)] {
        shown.compactMap { e in
            let v = [Signal.pollenTree, .pollenGrass, .pollenWeed].compactMap { e.conditions?.best($0)?.value }.max()
            return v.map { (e.loggedAt, $0) }
        }
    }

    // MARK: Pieces

    private func section(_ title: String, _ subtitle: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title2.weight(.bold))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            content()
                .padding(.vertical, 12).padding(.horizontal, MenusColumns.card)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(uiColor: .secondarySystemGroupedBackground)))
        }
    }

    private func label(_ name: String, _ ink: Color?) -> some View {
        Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(ink ?? .primary)
            .frame(width: MenusColumns.name, alignment: .leading).lineLimit(2).minimumScaleFactor(0.8)
    }

    private func valueText(_ s: String, dim: Bool = false) -> some View {
        Text(s).font(.caption.weight(.medium).monospacedDigit())
            .foregroundStyle(dim ? .tertiary : .secondary)
            .frame(width: MenusColumns.value, alignment: .trailing)
    }

    /// The reading nearest the playhead, so the value follows you as you move.
    private func reading(_ points: [(Date, Double)]) -> (Date, Double)? {
        points.filter { $0.0 <= window.center.addingTimeInterval(window.span * 0.02) }.max(by: { $0.0 < $1.0 }) ?? points.first
    }

    /// One condition on the window: a soft area in its colour, scaled to its own range (the rows compare shape
    /// and timing, not amounts), rescues as orange rules, the playhead as a dark one.
    private func row(_ name: String, _ ink: Color, _ points: [(Date, Double)], unit: String) -> some View {
        HStack(spacing: MenusColumns.gap) {
            label(name, ink)
            if points.count >= 2 {
                let lo = points.map(\.1).min()!, hi = points.map(\.1).max()!
                let y = { (v: Double) in hi > lo ? (v - lo) / (hi - lo) * 0.8 + 0.2 : 0.5 }
                Chart {
                    ForEach(rescues, id: \.self) { r in
                        RuleMark(x: .value("Rescue", r)).foregroundStyle(Theme.rescue.opacity(0.35)).lineStyle(StrokeStyle(lineWidth: 1))
                    }
                    ForEach(points, id: \.0) { p in
                        AreaMark(x: .value("Time", p.0), yStart: .value("Low", 0), yEnd: .value(name, y(p.1)))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(colors: [ink.opacity(0.55), ink.opacity(0.12)], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Time", p.0), y: .value(name, y(p.1)))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(ink).lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
                    RuleMark(x: .value("Playhead", window.center)).foregroundStyle(Color.primary).lineStyle(StrokeStyle(lineWidth: 1.5))
                }
                .chartXScale(domain: window.domain)
                .chartYScale(domain: 0...1)
                .chartXAxis(.hidden).chartYAxis(.hidden)
                .chartPlotStyle { $0.clipped() }
                .frame(height: 36)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { chartWidth = $0 }
                if let r = reading(points) { valueText("\(Int(r.1.rounded()))\(unit.isEmpty ? "" : " ")\(unit)") }
            } else {
                Text(name == "Pressure" || name == "Flu and illness" ? "Not tracked yet" : "No readings here")
                    .font(.caption).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 36)
                Color.clear.frame(width: MenusColumns.value, height: 1)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reading(points).map { "\(name), \(Int($0.1.rounded())) \(unit)" } ?? "\(name), no readings")
    }

    /// Dots on the window: one per log, in its colour; the playhead as a dark rule.
    private func dots(_ name: String, _ marks: [(Date, Color)]) -> some View {
        let inView = marks.filter { window.domain.contains($0.0) }
        return HStack(spacing: MenusColumns.gap) {
            label(name, nil)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.06)).frame(height: 2)
                    ForEach(Array(inView.enumerated()), id: \.offset) { _, m in
                        Circle().fill(m.1).frame(width: 9, height: 9)
                            .position(x: window.x(m.0, width: g.size.width), y: g.size.height / 2)
                    }
                    Rectangle().fill(Color.primary).frame(width: 1.5, height: g.size.height)
                        .position(x: g.size.width / 2, y: g.size.height / 2)
                }
            }
            .frame(height: 28)
            .clipped()
            valueText(inView.isEmpty ? "None" : "\(inView.count)", dim: inView.isEmpty)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(inView.count) in view")
    }

    private func empty(_ name: String, _ note: String) -> some View {
        HStack(spacing: MenusColumns.gap) {
            label(name, nil)
            Text(note).font(.caption).foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: MenusColumns.value, height: 1)
        }
        .padding(.vertical, 10)
    }
}
