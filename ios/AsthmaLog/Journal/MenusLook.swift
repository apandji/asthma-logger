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

// MARK: The air's vocabulary (Sky dials and Season lanes, approved Oct 30)

/// The air at a moment or over a day, as amounts 0…1, from the readings stamped on your moments.
struct MenusAir {
    var temp: Double?
    var tree = 0.0, grass = 0.0, weed = 0.0, ozone = 0.0
    var storm = false
    var cold = false

    init() {}
    init(_ c: Conditions?) {
        temp = c?.best(.temperature)?.value
        if let p = DemoPollen.from(c) {
            func amount(_ k: PollenSample.Kind) -> Double { k.count == 0 ? 0 : Double(k.level.rawValue + 1) / 3 }
            tree = amount(p.tree); grass = amount(p.grass); weed = amount(p.weed)
        }
        ozone = min(1, max(0, ((c?.best(.ozone)?.value ?? 0) - 20) / 60))
        storm = c?.alerts.contains { $0.name.localizedCaseInsensitiveContains("storm") || $0.name.localizedCaseInsensitiveContains("thunder") } ?? false
    }

    /// A day: warmest reading's mean, the most of each layer, any storm.
    static func day(_ events: [LogEvent]) -> MenusAir? {
        let airs = events.compactMap { $0.conditions }.map { MenusAir($0) }
        guard !airs.isEmpty else { return nil }
        var d = MenusAir()
        let temps = airs.compactMap(\.temp)
        d.temp = temps.isEmpty ? nil : temps.reduce(0, +) / Double(temps.count)
        d.tree = airs.map(\.tree).max()!; d.grass = airs.map(\.grass).max()!; d.weed = airs.map(\.weed).max()!
        d.ozone = airs.map(\.ozone).max()!; d.storm = airs.contains { $0.storm }
        return d
    }

    enum Lead { case tree, grass, weed, ozone, storm, calm }
    /// What led the air, and how much.
    var lead: (Lead, Double) {
        let c: [(Lead, Double)] = [(.tree, tree), (.grass, grass), (.weed, weed), (.ozone, ozone * 0.9), (.storm, storm ? 0.75 : 0)]
        let top = c.max { $0.1 < $1.1 }!
        return top.1 > 0.25 ? top : (.calm, 0)
    }

    static func color(_ l: Lead) -> Color {
        switch l {
        case .tree: Theme.airTree.color
        case .grass: Theme.airGrass.color
        case .weed: Theme.airWeed.color
        case .ozone: Theme.airOzone.color
        case .storm: Theme.airStorm.color
        case .calm: Color(white: 0.8)
        }
    }

    /// Temperature as colour: blue cold, green mild, gold warm, red hot.
    static func tempColor(_ t: Double) -> Color {
        let stops: [(Double, (Double, Double, Double))] = [(10, (62, 100, 200)), (35, (127, 178, 229)), (55, (207, 230, 200)),
                                                         (72, (246, 211, 107)), (85, (242, 154, 74)), (98, (217, 87, 59))]
        let x = min(98, max(10, t))
        for i in 1..<stops.count where x <= stops[i].0 {
            let (t0, c0) = stops[i - 1], (t1, c1) = stops[i], f = (x - t0) / (t1 - t0)
            return Color(red: (c0.0 + (c1.0 - c0.0) * f) / 255, green: (c0.1 + (c1.1 - c0.1) * f) / 255, blue: (c0.2 + (c1.2 - c0.2) * f) / 255)
        }
        return .gray
    }
}

/// A Sky dial (after Lupi's Weather Mood): bottom half the temperature, top half what led the air (dots for
/// pollen in its colour, hatching for ozone, a zigzag for a storm), lines across the middle for how strong (0–3),
/// an orange ring for a rescue, a blue tick on top for your standard inhaler, a dot beside it for a note.
enum SkyDial {
    /// The strip's mark, the sky in small: a rounded square in the temperature's colour with the leading air's
    /// pattern over it (pollen dots, ozone hatching, a storm zigzag), and a circle in the middle for what you
    /// felt (rescue orange, standard blue). A dot at the corner for a note.
    static func draw(_ ctx: inout GraphicsContext, at p: CGPoint, r: CGFloat, air: MenusAir, rescue: Bool, standard: Bool, note: Bool) {
        let rect = CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)
        let square = Path(roundedRect: rect, cornerRadius: r * 0.35, style: .continuous)
        var inner = ctx
        inner.clip(to: square)
        inner.fill(square, with: .color(air.temp.map(MenusAir.tempColor) ?? Color(white: 0.9)))
        let (lead, v) = air.lead
        let ink = MenusAir.color(lead)
        switch lead {
        case .tree, .grass, .weed:
            let step = max(2.6, r / (1.5 + 2.5 * v))
            var y = rect.minY + step / 2
            while y < rect.maxY {
                var x = rect.minX + step / 2
                while x < rect.maxX { inner.fill(Path(ellipseIn: CGRect(x: x - 0.8, y: y - 0.8, width: 1.6, height: 1.6)), with: .color(ink)); x += step }
                y += step
            }
        case .ozone:
            let step = max(2.6, r / (1.5 + 2 * v))
            var o = -2 * r
            while o < 2 * r { var l = Path(); l.move(to: CGPoint(x: p.x + o, y: rect.maxY)); l.addLine(to: CGPoint(x: p.x + o + 2 * r, y: rect.minY)); inner.stroke(l, with: .color(ink), lineWidth: 0.8); o += step }
        case .storm:
            var z = Path(); z.move(to: CGPoint(x: rect.minX, y: p.y))
            for i in 1...6 { z.addLine(to: CGPoint(x: rect.minX + CGFloat(i) * r / 3, y: p.y + (i % 2 == 1 ? -r * 0.5 : r * 0.5))) }
            inner.stroke(z, with: .color(ink), lineWidth: 1.2)
        case .calm: break
        }
        ctx.stroke(square, with: .color(Color.primary.opacity(0.12)), lineWidth: 0.5)
        if rescue || standard {
            let c = r * 0.62
            let circle = Path(ellipseIn: CGRect(x: p.x - c, y: p.y - c, width: 2 * c, height: 2 * c))
            ctx.fill(circle, with: .color(rescue ? Theme.rescue : Theme.standardSoft))
            ctx.stroke(circle, with: .color(.white), lineWidth: 1)
        }
        if note { ctx.fill(Path(ellipseIn: CGRect(x: rect.maxX - 1.5, y: rect.minY - 1.5, width: 3.5, height: 3.5)), with: .color(.primary)) }
    }
}

// MARK: Month and Year: Season lanes

/// Month and Year as Season lanes (after Lupi's "My Past"): a lane per condition (tree, grass and weed pollen,
/// ozone, storms, cold snaps), each a band that swells when it's high, day by day, from the readings stamped
/// on your moments. Your moments run along the top: a filled orange square for a rescue, an open blue square
/// for standard, a dot for a note. A day with no readings is empty in every lane, not "low".
struct MenusLanes: View {
    let title: String
    let subtitle: String
    let start: Date
    let end: Date
    let events: [LogEvent]
    let now: Date
    /// Rescues only on the Year, where every standard moment would crowd the lane.
    var rescuesOnly = false
    private let cal = Calendar.current

    private static let lanes: [(String, (MenusAir) -> Double, Color)] = [
        ("Tree", { $0.tree }, Theme.airTree.color), ("Grass", { $0.grass }, Theme.airGrass.color), ("Weed", { $0.weed }, Theme.airWeed.color),
        ("Ozone", { $0.ozone }, Theme.airOzone.color), ("Storms", { $0.storm ? 1 : 0 }, Theme.airStorm.color), ("Cold", { $0.cold ? 1 : 0 }, Theme.airCold.color),
    ]

    private var dayAir: [(Date, MenusAir)] {
        let byDay = Dictionary(grouping: events.filter { $0.loggedAt >= start && $0.loggedAt < end }) { cal.startOfDay(for: $0.loggedAt) }
        var out = byDay.compactMap { d, es in MenusAir.day(es).map { (d, $0) } }.sorted { $0.0 < $1.0 }
        for i in out.indices.dropFirst() {
            if let a = out[i - 1].1.temp, let b = out[i].1.temp, a - b > 13, cal.dateComponents([.day], from: out[i - 1].0, to: out[i].0).day == 1 { out[i].1.cold = true }
        }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.weight(.bold))
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            Canvas { ctx, size in draw(&ctx, size) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 14)
                .accessibilityLabel("Season lanes, \(title)")
        }
        .padding(.horizontal, 20).padding(.top, 16)
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let span = end.timeIntervalSince(start)
        let lx: CGFloat = 54, lw = size.width - lx - 4
        let x = { (d: Date) in lx + CGFloat(d.timeIntervalSince(start) / span) * lw }
        let youY: CGFloat = 14
        let laneH = min(54, (size.height - 70) / CGFloat(Self.lanes.count))
        func text(_ s: String, _ p: CGPoint, bold: Bool = false, anchor: UnitPoint = .leading) {
            ctx.draw(Text(s).font(.caption.weight(bold ? .semibold : .medium)).foregroundStyle(bold ? Color.primary : Color.secondary), at: p, anchor: anchor)
        }
        // You
        text("You", CGPoint(x: 0, y: youY), bold: true)
        ctx.fill(Path(CGRect(x: lx, y: youY - 0.4, width: lw, height: 0.8)), with: .color(Color.primary.opacity(0.12)))
        for e in events where e.loggedAt >= start && e.loggedAt < end {
            let mx = x(e.loggedAt)
            switch e.moment {
            case .rescue: ctx.fill(Path(CGRect(x: mx - 3.5, y: youY - 11, width: 7, height: 7)), with: .color(Theme.rescue))
            case .maintenance where !rescuesOnly: ctx.stroke(Path(CGRect(x: mx - 2.5, y: youY + 4, width: 5, height: 5)), with: .color(Theme.standard), lineWidth: 1)
            case .note where !rescuesOnly: ctx.fill(Path(ellipseIn: CGRect(x: mx - 1.5, y: youY + 13, width: 3, height: 3)), with: .color(.primary))
            default: break
            }
        }
        // Lanes
        let air = dayAir
        let dayW = max(1, lw * CGFloat(86_400 / span))
        for (i, lane) in Self.lanes.enumerated() {
            let cy = 48 + CGFloat(i) * laneH + laneH / 2
            text(lane.0, CGPoint(x: 0, y: cy), bold: true)
            ctx.fill(Path(CGRect(x: lx, y: cy - 0.4, width: lw, height: 0.8)), with: .color(Color.primary.opacity(0.08)))
            for (d, a) in air {
                let v = lane.1(a)
                guard v > 0.04 else { continue }
                let h = (laneH - 8) * CGFloat(min(1, v))
                ctx.fill(Path(CGRect(x: x(d), y: cy - h / 2, width: dayW + 0.4, height: h)), with: .color(lane.2))
            }
        }
        // Time axis: weeks on a month, months on a year; ahead of now is faint.
        let bottom = 48 + CGFloat(Self.lanes.count) * laneH
        let monthly = span > 40 * 86_400
        var t = monthly ? cal.dateInterval(of: .month, for: start)!.start : start
        while t < end {
            if t >= start {
                ctx.fill(Path(CGRect(x: x(t), y: 36, width: 0.6, height: bottom - 36)), with: .color(Color.primary.opacity(0.1)))
                text(monthly ? String(t.formatted(.dateTime.month(.narrow))) : t.formatted(.dateTime.day()), CGPoint(x: x(t), y: bottom + 10), anchor: .center)
            }
            t = cal.date(byAdding: monthly ? .month : .day, value: monthly ? 1 : 7, to: t)!
        }
        if now >= start, now < end {
            ctx.fill(Path(CGRect(x: x(now), y: x(now) > 0 ? 0 : 0, width: 1.5, height: bottom)), with: .color(.primary))
            ctx.fill(Path(CGRect(x: x(now), y: 36, width: lx + lw - x(now), height: bottom - 36)), with: .color(Color(uiColor: .systemGroupedBackground).opacity(0.55)))
            text("Now", CGPoint(x: x(now), y: bottom + 24), bold: true, anchor: .center)
        }
    }
}

/// Month: this month, day by day, as Season lanes.
struct MenusMonthView: View {
    let events: [LogEvent]
    let now: Date
    var body: some View {
        let m = Calendar.current.dateInterval(of: .month, for: now)!
        MenusLanes(title: now.formatted(.dateTime.month(.wide)), subtitle: now.formatted(.dateTime.year()),
                   start: m.start, end: m.end, events: events, now: now)
    }
}

/// Year: the past 12 months as Season lanes, so each season shows as its own band with a start and an end.
struct MenusYearView: View {
    let events: [LogEvent]
    let now: Date
    var body: some View {
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))!
        let start = cal.date(byAdding: .month, value: -12, to: end)!
        MenusLanes(title: "Past 12 months", subtitle: "\(start.formatted(.dateTime.month(.abbreviated).year())) to \(now.formatted(.dateTime.month(.abbreviated).year()))",
                   start: start, end: end, events: events, now: now, rescuesOnly: true)
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

    /// The playhead's colour: rescue orange on a rescue moment (like its pill), the ink otherwise.
    func ink(_ moments: [LogEvent]) -> Color {
        moments.contains { $0.moment == .rescue && abs($0.loggedAt.timeIntervalSince(center)) < 20 * 60 } ? Theme.rescue : .primary
    }
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
        .padding(.top, 8)
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
            // Moments: inhaler use as upright pills, rescue orange, standard blue (owner, Nov 6), narrower as you
            // zoom out. A note sits as a small dot beside the moment it follows.
            let r: CGFloat = min(10, max(5, w * CGFloat(2.5 * 3600 / window.span)))
            let shown = moments.filter { $0.loggedAt >= window.start.addingTimeInterval(-3600) && $0.loggedAt <= window.end.addingTimeInterval(3600) }
            for m in shown where m.moment == .rescue || m.moment == .maintenance {
                let noted = !(m.voiceTranscript ?? "").isEmpty || shown.contains { $0.moment == .note && abs($0.loggedAt.timeIntervalSince(m.loggedAt)) < 3600 }
                let cx = x(m.loggedAt), pw = r * 1.1, ph = r * 2.8
                let pill = Path(roundedRect: CGRect(x: cx - pw / 2, y: mid - ph / 2, width: pw, height: ph), cornerRadius: pw / 2)
                ctx.fill(pill, with: .color(m.moment == .rescue ? Theme.rescue : Theme.standard))
                if noted {
                    ctx.fill(Path(ellipseIn: CGRect(x: cx + pw / 2 + 2, y: mid - ph / 2, width: 4, height: 4)), with: .color(ink.opacity(0.45)))
                }
            }
            // Now, and the playhead in the middle.
            if now >= window.start, now <= window.end {
                var n = Path(); n.move(to: CGPoint(x: x(now), y: mid - 16)); n.addLine(to: CGPoint(x: x(now), y: mid + 16))
                ctx.stroke(n, with: .color(ink.opacity(0.7)), lineWidth: 1.5)
            }
            let head = window.ink(moments)
            var ph = Path(); ph.move(to: CGPoint(x: w / 2, y: mid - 18)); ph.addLine(to: CGPoint(x: w / 2, y: size.height))
            ctx.stroke(ph, with: .color(head), lineWidth: 2)
            // Health's pointer, on the playhead.
            var tri = Path()
            tri.move(to: CGPoint(x: w / 2 - 5, y: mid - 26)); tri.addLine(to: CGPoint(x: w / 2 + 5, y: mid - 26))
            tri.addLine(to: CGPoint(x: w / 2, y: mid - 20)); tri.closeSubpath()
            ctx.fill(tri, with: .color(head))
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
        VStack(alignment: .leading, spacing: 48) {
            section("Environment", "Outdoor, at your moments") {
                VStack(spacing: 0) {
                    // The same inks as the cube's hazes, so a colour means one reading everywhere.
                    row("Temperature", Theme.airWeather, series(.temperature), unit: "°F")
                    row("Humidity", Theme.airHumidity, series(.humidity), unit: "%")
                    row("Wind", Theme.airWeather, series(.windSpeed), unit: "mph")
                    row("Pressure", Theme.airWeather, [], unit: "")
                    row("PM2.5", Theme.airPM25, series(.pm25), unit: "µg")
                    row("Ozone", Theme.airOzone, series(.ozone), unit: "ppb")
                    row("Pollen", Theme.airPollen, pollen, unit: "")
                    row("Flu and illness", Theme.airIllness, [], unit: "")
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
        .padding(.top, 36)   // inside the playhead's overlay, so the line runs unbroken from the strip
        // One playhead line through every row, continuing the strip's: in the chart column's middle.
        .overlay(alignment: .topLeading) {
            GeometryReader { g in
                let x0 = MenusColumns.page + MenusColumns.card + MenusColumns.name + MenusColumns.gap
                let w = g.size.width - 2 * (MenusColumns.page + MenusColumns.card) - MenusColumns.name - MenusColumns.value - 2 * MenusColumns.gap
                Rectangle().fill(window.ink(events)).frame(width: 2, height: g.size.height)
                    .offset(x: x0 + w / 2 - 1)
            }
            .allowsHitTesting(false)
        }
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
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title2.weight(.bold))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            // No card: the rows sit on the page, inset to the same columns as the strip.
            content()
                .padding(.vertical, 4).padding(.horizontal, MenusColumns.card)
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
    private func row(_ name: String, _ air: Theme.AirInk, _ points: [(Date, Double)], unit: String) -> some View {
        let ink = air.deep
        return HStack(spacing: MenusColumns.gap) {
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
                            .foregroundStyle(LinearGradient(colors: [air.color.opacity(0.8), air.glowColor.opacity(0.15)], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Time", p.0), y: .value(name, y(p.1)))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(ink).lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
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

// MARK: The sky: the environment as a square, what you felt as a circle

/// What you felt at this time, for the circle in the middle.
enum MenusFelt { case rescue, standard, nothing }

/// The Menus look's sky: a square that is the environment, filled with the conditions' gradient (hue from the
/// temperature, light from the hour, softness from the humidity, each pollutant and pollen tinting it as it
/// rises) over a faint map of the place; and a circle in the middle that is you: rescue orange, standard blue,
/// or an empty dashed ring when nothing was logged. A dot beside the circle when there's a note.
struct MenusSkySquare<Field: View, Map: View>: View {
    let felt: MenusFelt
    var noted = false
    /// Ahead of now: lighter, as the forecast is elsewhere.
    var sketch = false
    @ViewBuilder let field: () -> Field
    @ViewBuilder let map: (CGSize) -> Map

    var body: some View {
        GeometryReader { g in
            let d = min(g.size.width - 40, g.size.height - 16)
            let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
            ZStack {
                map(CGSize(width: d, height: d)).saturation(0).opacity(0.45).frame(width: d, height: d)
                field().opacity(sketch ? 0.5 : 0.8).frame(width: d, height: d)
                circle(d * 0.36)
            }
            .frame(width: d, height: d)
            .clipShape(shape)
            .overlay { shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 1) }
            .position(x: g.size.width / 2, y: g.size.height / 2)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder private func circle(_ c: CGFloat) -> some View {
        ZStack {
            switch felt {
            case .rescue:
                Circle().fill(Theme.rescue)
                Image(systemName: "inhaler.fill").font(.system(size: c * 0.34, weight: .semibold)).foregroundStyle(.white)
            case .standard:
                Circle().fill(Theme.standardSoft)
                Image(systemName: "inhaler.fill").font(.system(size: c * 0.34, weight: .semibold)).foregroundStyle(Theme.standard)
            case .nothing:
                Circle().fill(.white.opacity(0.35))
                Circle().strokeBorder(.white, style: StrokeStyle(lineWidth: 2.5, dash: [6, 6]))
            }
        }
        .frame(width: c, height: c)
        .shadow(color: .black.opacity(felt == .nothing ? 0 : 0.15), radius: 10, y: 3)
        .overlay(alignment: .topTrailing) {
            if noted { Circle().fill(Color.primary).frame(width: 9, height: 9).offset(x: 8, y: -2) }
        }
        .accessibilityLabel(felt == .rescue ? "Rescue" : felt == .standard ? "Standard" : "Nothing logged")
    }
}
