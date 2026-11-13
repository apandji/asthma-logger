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
enum MenusTab: Hashable { case home, moments, map, insights }

// MARK: Top bar

/// ≡ on the left opens the side menu; the scale menu on the right.
struct MenusTopBar: View {
    @Binding var scale: MenusScale
    let openMenu: () -> Void

    var body: some View {
        HStack {
            Button(action: openMenu) {
                Image(systemName: "line.3.horizontal").font(Theme.Figtree.font(.subheadline, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Menu")
            Spacer()
            // No scale menu (owner, Nov 13): Moments has its own Day, Month and Year.
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
            // One ink: rescue filled, standard an outline (owner, Nov 13).
            if rescue {
                ctx.fill(circle, with: .color(.primary))
                ctx.stroke(circle, with: .color(.white), lineWidth: 1)
            } else {
                ctx.stroke(circle, with: .color(.primary), lineWidth: 1.2)
            }
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
            Text(title).font(Theme.Figtree.font(.title2, weight: .bold))
            Text(subtitle).font(Theme.Figtree.font(.subheadline)).foregroundStyle(.secondary)
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
            ctx.draw(Text(s).font(Theme.Figtree.font(.caption, weight: bold ? .semibold : .medium)).foregroundStyle(bold ? Color.primary : Color.secondary), at: p, anchor: anchor)
        }
        // You
        text("You", CGPoint(x: 0, y: youY), bold: true)
        ctx.fill(Path(CGRect(x: lx, y: youY - 0.4, width: lw, height: 0.8)), with: .color(Color.primary.opacity(0.12)))
        for e in events where e.loggedAt >= start && e.loggedAt < end {
            let mx = x(e.loggedAt)
            switch e.moment {
            case .rescue: ctx.fill(Path(CGRect(x: mx - 3.5, y: youY - 11, width: 7, height: 7)), with: .color(.primary))
            case .maintenance where !rescuesOnly: ctx.stroke(Path(CGRect(x: mx - 2.5, y: youY + 4, width: 5, height: 5)), with: .color(.primary), lineWidth: 1)
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
                // Home (the flowers), Moments as a grid of rings, the Map, then Insights (owner, Nov 13).
                segment(firstLabel, AnyView(Image(systemName: firstLabel == "Home" ? "house" : "chart.bar.xaxis")
                                                .font(Theme.Figtree.font(size: 22, weight: .medium))), .home)
                segment("Moments", AnyView(MomentsGridIcon(size: 21)), .moments)
                segment("Map", AnyView(Image(systemName: "map").font(Theme.Figtree.font(size: 22, weight: .medium))), .map)
                segment("Insights", AnyView(Image(systemName: "sparkles").font(Theme.Figtree.font(size: 22, weight: .semibold))), .insights)
            }
            .padding(.horizontal, 6)
            .glassEffect(.regular, in: .capsule)
            Spacer()
            Button { withAnimation(Theme.snap) { open.toggle() } } label: {
                Image(systemName: open ? "xmark" : "plus").font(Theme.Figtree.font(.title2, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 56, height: 56)
                    // Solid ink, like a rescue pill (owner, Nov 13).
                    .background(Circle().fill(Color.black))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
            }
            .buttonStyle(PressStyle())
            .foregroundStyle(.white)
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

    private func segment(_ label: String, _ icon: AnyView, _ t: MenusTab) -> some View {
        Button { withAnimation(Theme.snap) { tab = t } } label: {
            VStack(spacing: 4) {
                icon.frame(height: 28)
                Text(label).font(Theme.Figtree.font(.caption2, weight: .semibold))
            }
            .foregroundStyle(tab == t ? Color.primary : Color.secondary)
            .frame(width: 70, height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(tab == t ? .isSelected : [])
    }

    private var feltCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Felt something?").font(Theme.Figtree.font(.subheadline, weight: .semibold))
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
            .font(Theme.Figtree.font(.body))
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
                Text("felt air").font(Theme.Figtree.font(.title2, weight: .bold))
                Spacer()
                Button(action: close) { Image(systemName: "xmark").font(Theme.Figtree.font(.body, weight: .semibold)).frame(width: 44, height: 44) }
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
                .font(Theme.Figtree.font(.footnote)).foregroundStyle(.secondary)
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
                Image(systemName: symbol).font(Theme.Figtree.font(.body)).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.Figtree.font(.body))
                    if let note { Text(note).font(Theme.Figtree.font(.caption)).foregroundStyle(.secondary) }
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
        .primary   // one ink for the playhead (owner, Nov 13: no rescue colour)
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
/// The day the playhead is on ("Today, November 13"), tap to go back to now, and the line under it: the time,
/// the verdict ahead, and how much the window shows.
struct MenusDayTitle: View {
    let window: MenusWindow
    let now: Date
    let verdict: String?
    let backToNow: () -> Void
    private var atNow: Bool { abs(window.center.timeIntervalSince(now)) < window.span * 0.01 }

    var body: some View {
        VStack(spacing: 2) {
            Button(action: backToNow) {
                HStack(spacing: 6) {
                    Text(Self.title(window.center)).font(Theme.Figtree.font(.title3, weight: .semibold))
                    if !atNow {
                        Image(systemName: window.center > now ? "arrow.uturn.backward" : "arrow.uturn.forward")
                            .font(Theme.Figtree.font(.footnote, weight: .bold)).opacity(0.5)
                    }
                }
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            }
            .buttonStyle(PressStyle())
            .disabled(atNow)
            Text([atNow ? "Now" : window.center.formatted(.dateTime.hour().minute()), window.center >= now.addingTimeInterval(-60) ? verdict : nil, Self.spanLabel(window.span)]
                .compactMap { $0 }.joined(separator: " · "))
                .font(Theme.Figtree.font(.subheadline)).foregroundStyle(.secondary).lineLimit(1)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    static func title(_ d: Date) -> String {
        let cal = Calendar.current
        let day = cal.isDateInToday(d) ? "Today" : cal.isDateInYesterday(d) ? "Yesterday" : cal.isDateInTomorrow(d) ? "Tomorrow"
            : d.formatted(.dateTime.weekday(.wide))
        return "\(day), \(d.formatted(.dateTime.month(.wide).day()))"
    }

    /// How much is on screen: "12 h", "3 days", "2 weeks".
    static func spanLabel(_ span: TimeInterval) -> String {
        let h = span / 3600
        if h < 36 { return "\(Int(h.rounded())) h" }
        let d = h / 24
        return d < 14 ? "\(Int(d.rounded())) days" : "\(Int((d / 7).rounded())) weeks"
    }
}

struct MenusStrip: View {
    @Binding var window: MenusWindow
    let moments: [LogEvent]
    let forecast: [(Date, Double?)]
    let now: Date
    let verdict: String?
    let limits: ClosedRange<Date>
    let settle: () -> Void
    let backToNow: () -> Void
    /// With the combined chart (owner, Nov 13) the day's title sits below the chart instead of above the ticks.
    var titleBelow = false
    @Environment(\.colorScheme) private var scheme
    @State private var width: CGFloat = 1
    private let cal = Calendar.current

    var body: some View {
        VStack(spacing: 2) {
            if !titleBelow {
                MenusDayTitle(window: window, now: now, verdict: verdict, backToNow: backToNow)
            }
            // The whole width is the timeline (owner, Nov 6): the span sits in the line above.
            track
                .padding(.horizontal, titleBelow ? 0 : MenusColumns.page + MenusColumns.card)   // edge to edge with the combined chart (owner, Nov 13)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea(edges: .top))
        .sensoryFeedback(.selection, trigger: cal.startOfDay(for: window.center))
    }

    private var title: String { MenusDayTitle.title(window.center) }
    private var spanLabel: String { MenusDayTitle.spanLabel(window.span) }

    private var track: some View {
        Canvas { ctx, size in
            let w = size.width, mid: CGFloat = 74
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
                    // A baseline ring sits at 9 am and 6 pm: no small tick through it.
                    let hr = cal.component(.hour, from: t)
                    if !isMajor, cal.component(.minute, from: t) == 0, hr == 9 || hr == 18 { t = t.addingTimeInterval(minor); continue }
                    var p = Path(); p.move(to: CGPoint(x: x(t), y: mid - h / 2)); p.addLine(to: CGPoint(x: x(t), y: mid + h / 2))
                    ctx.stroke(p, with: .color(ink.opacity(t > now ? 0.18 : 0.4)), lineWidth: 1)
                    // No day labels above (owner, Nov 13): the day is under the playhead.
                }
                t = t.addingTimeInterval(minor)
            }
            // The forecast ahead: a slot per hour in the verdict's colour.
            let slot = max(1, w * CGFloat(3600 / window.span))
            for (d, v) in forecast where d >= now && d <= window.end {
                let c: Color = v == nil ? ink.opacity(0.08) : (v! >= 1 ? Verdict.red : v! >= 0.5 ? Verdict.yellow : Verdict.green).opacity(0.7)
                ctx.fill(Path(CGRect(x: x(d), y: mid - 4, width: max(1, slot - 1), height: 8)), with: .color(c))
            }
            // Baseline captures (owner, Nov 13, for now): a small dot every day at 9 am and 6 pm, the ordinary
            // moments the patterns compare against. Ahead of now they're faint, still to come. Under the pills.
            var bDay = cal.startOfDay(for: window.start.addingTimeInterval(-86_400))
            while bDay <= window.end {
                for hour in [9, 18] {
                    guard let b = cal.date(bySettingHour: hour, minute: 0, second: 0, of: bDay),
                          b >= window.start.addingTimeInterval(-3600), b <= window.end.addingTimeInterval(3600) else { continue }
                    // An empty ring (owner, Nov 13).
                    let d: CGFloat = 5
                    ctx.stroke(Path(ellipseIn: CGRect(x: x(b) - d / 2, y: mid - d / 2, width: d, height: d)),
                               with: .color(ink.opacity(b <= now ? 0.6 : 0.2)), lineWidth: 1)
                }
                bDay = cal.date(byAdding: .day, value: 1, to: bDay)!
            }
            // Moments: inhaler use as upright pills in one ink (owner, Nov 13): rescue filled, standard an outline,
            // narrower as you zoom out. A note sits as a small dot beside the moment it follows.
            let r: CGFloat = min(10, max(5, w * CGFloat(2.5 * 3600 / window.span)))
            let shown = moments.filter { $0.loggedAt >= window.start.addingTimeInterval(-3600) && $0.loggedAt <= window.end.addingTimeInterval(3600) }
            for m in shown where m.moment == .rescue || m.moment == .maintenance {
                let noted = !(m.voiceTranscript ?? "").isEmpty || shown.contains { $0.moment == .note && abs($0.loggedAt.timeIntervalSince(m.loggedAt)) < 3600 }
                let cx = x(m.loggedAt), pw = min(r, 7) * 1.1, ph = min(r, 7) * 2.8
                let pill = Path(roundedRect: CGRect(x: cx - pw / 2, y: mid - ph / 2, width: pw, height: ph), cornerRadius: pw / 2)
                if m.moment == .rescue {
                    ctx.fill(pill, with: .color(ink))
                } else {
                    ctx.stroke(Path(roundedRect: CGRect(x: cx - pw / 2 + 0.6, y: mid - ph / 2 + 0.6, width: pw - 1.2, height: ph - 1.2),
                                    cornerRadius: (pw - 1.2) / 2), with: .color(ink), lineWidth: 1.2)
                }
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
            var ph = Path(); ph.move(to: CGPoint(x: w / 2, y: mid - 18)); ph.addLine(to: CGPoint(x: w / 2, y: mid + 18))
            ctx.stroke(ph, with: .color(head), lineWidth: 2)
            // The playhead's time, just above its pointer (owner, Nov 13): the time on one line, the day small beneath.
            let atNow = abs(window.center.timeIntervalSince(now)) < 60
            let time = atNow ? "Now" : window.center.formatted(.dateTime.hour().minute())
            let day = atNow ? "" : cal.isDate(window.center, inSameDayAs: now) ? "Today"
                : cal.isDateInYesterday(window.center) ? "Yesterday"
                : window.center.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            // 16 pt time, 13 pt day (owner, Nov 13).
            ctx.draw(Text(time).font(Theme.Figtree.font(size: 16, weight: .medium).monospacedDigit()).foregroundStyle(head),
                     at: CGPoint(x: w / 2, y: day.isEmpty ? mid - 44 : mid - 64))
            ctx.draw(Text(day).font(Theme.Figtree.font(size: 13)).foregroundStyle(head.opacity(0.5)), at: CGPoint(x: w / 2, y: mid - 44))
            // Health's pointer, on the playhead.
            var tri = Path()
            tri.move(to: CGPoint(x: w / 2 - 5, y: mid - 26)); tri.addLine(to: CGPoint(x: w / 2 + 5, y: mid - 26))
            tri.addLine(to: CGPoint(x: w / 2, y: mid - 20)); tri.closeSubpath()
            ctx.fill(tri, with: .color(head))
        }
        .frame(height: 104)
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
    /// 0: Environment's lines together on one line; 1: apart, one row each (from the page's scroll).
    var apart: CGFloat = 0
    /// The combined chart is the home's main visual (no sky above), so it's drawn tall.
    var big = false
    /// The forecast hours ahead of now, so the lines carry on past the playhead.
    var forecast: [(Date, Conditions)] = []
    /// With the combined chart, the day's title sits just below it (owner, Nov 13).
    /// How much each condition is one of your triggers, 0…1: sets each fan's size.
    var triggers: [String: Double] = [:]
    var dayTitle: MenusDayTitle? = nil
    /// The flowers' area height on home: the room between the header and the timeline (owner, Nov 13).
    var bigBand: CGFloat = MenusEnvironment.bigBand
    @State private var chartWidth: CGFloat = 1
    /// A little either side of the window, so lines run off the edges instead of stopping short.
    private var shown: [LogEvent] {
        let pad = window.span * 0.5
        return events.filter { $0.loggedAt >= window.start.addingTimeInterval(-pad) && $0.loggedAt <= window.end.addingTimeInterval(pad) }
    }
    private var rescues: [Date] { shown.filter { $0.moment == .rescue }.map(\.loggedAt) }

    var body: some View {
        VStack(alignment: .leading, spacing: 48) {
            // Environment (owner, Nov 13): every condition on one line first, like a cycle app's hormone chart,
            // and as you scroll down the lines part into their own rows.
            MenusEnvironment(window: window, rescues: rescues, ink: window.ink(events), apart: apart, bandH: big ? bigBand : 132, series: [
                // Each its own hue from the air palette, so the lines stay apart when they overlap.
                .init(name: "Temperature", air: Theme.AirInk(core: Theme.AirPalette.coral, glow: Theme.AirPalette.peach), points: series(.temperature), unit: "°F"),
                .init(name: "Humidity", air: Theme.AirInk(core: Theme.AirPalette.mint, glow: Theme.AirPalette.sky), points: series(.humidity), unit: "%"),
                .init(name: "Wind", air: Theme.AirInk(core: Theme.AirPalette.sky, glow: Theme.AirPalette.mist), points: series(.windSpeed), unit: "mph"),
                .init(name: "Pressure", air: Theme.airStorm, points: [], unit: "", note: "Not tracked yet"),
                .init(name: "PM2.5", air: Theme.airPM25, points: series(.pm25), unit: "µg"),
                .init(name: "Ozone", air: Theme.AirInk(core: Theme.AirPalette.pink, glow: Theme.AirPalette.lilac), points: series(.ozone), unit: "ppb"),
                .init(name: "Pollen", air: Theme.airPollen, points: pollen, unit: "% of a high day"),
                .init(name: "Flu and illness", air: Theme.airIllness, points: [], unit: "", note: "Not tracked yet"),
            ], width: $chartWidth, footer: dayTitle, edge: big, now: now, triggers: triggers)
            section("Body", "From your logs and Apple Health") {
                VStack(spacing: 0) {
                    dots("Inhaler use", shown.filter { $0.moment == .rescue || $0.moment == .maintenance }
                        .map { ($0.loggedAt, Color.primary, $0.moment != .rescue) })
                    dots("Felt journal", shown.filter { $0.moment == .note || !($0.voiceTranscript ?? "").isEmpty }
                        .map { ($0.loggedAt, Color.primary, false) })
                    empty("Activity", "From Apple Health, not connected yet")
                    empty("Heart and breathing", "Heart rate and respiratory rate, empty for now")
                }
            }
        }
        .padding(.horizontal, MenusColumns.page)
        .padding(.top, 20)   // the combined chart sits just under the strip (owner, Nov 13); inside the playhead's overlay
        // One playhead line through every row, continuing the strip's: in the chart column's middle. Behind the
        // content, so the day's title under the combined chart sits over it.
        .background(alignment: .topLeading) {
            GeometryReader { g in
                let x0 = MenusColumns.page + MenusColumns.card
                let w = g.size.width - 2 * (MenusColumns.page + MenusColumns.card)
                // With the combined chart, the line stops at the chart while the lines are together.
                let bandBottom: CGFloat = 20 + bigBand   // the top padding plus the combined chart's height
                let h = big ? g.size.height * apart : g.size.height   // the portrait stands alone at rest; no line through it
                Rectangle().fill(window.ink(events)).frame(width: 2, height: h)
                    .offset(x: x0 + w / 2 - 1)
            }
            .allowsHitTesting(false)
        }
        .modifier(MenusWindowGestures(window: $window, width: chartWidth, limits: limits, settle: settle))
    }

    // MARK: Data

    private func series(_ s: Signal) -> [(Date, Double)] {
        let logged = shown.compactMap { e in e.conditions?.best(s).map { (e.loggedAt, $0.value) } }
        let pad = window.span * 0.5
        let ahead = forecast.filter { $0.0 > now && $0.0 <= window.end.addingTimeInterval(pad) }
            .compactMap { h in h.1.best(s).map { (h.0, $0.value) } }
        return (logged + ahead).sorted { $0.0 < $1.0 }
    }

    /// The highest of tree, grass and weed pollen at each moment.
    /// Pollen at each moment, as the share of a high day (100 = high) for whichever of tree, grass and weed
    /// is closest to high. Demo moments without readings use the display-only demo pollen (owner, Nov 13),
    /// the season from Design crit, or late-summer ragweed when that's off.
    private var pollen: [(Date, Double)] {
        let raw = UserDefaults.standard.string(forKey: DemoPollen.Season.key).flatMap(DemoPollen.Season.init(rawValue:))
        let season: DemoPollen.Season = raw == nil || raw == .off ? .ragweed : raw!
        return shown.compactMap { e in
            let sample = DemoPollen.from(e.conditions) ?? (e.isDemo ? DemoPollen.sample(at: e.loggedAt, season: season) : nil)
            guard let p = sample else { return nil }
            let share = max(Double(p.tree.count) / 213, Double(p.grass.count) / 61, Double(p.weed.count) / 80) * 100
            return (e.loggedAt, share)
        }
    }

    // MARK: Pieces

    private func section(_ title: String, _ subtitle: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.Figtree.font(.title2, weight: .bold))
                Text(subtitle).font(Theme.Figtree.font(.subheadline)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            // No card: the rows sit on the page, inset to the same columns as the strip.
            content()
                .padding(.vertical, 4).padding(.horizontal, MenusColumns.card)
        }
    }

    private func label(_ name: String, _ ink: Color?) -> some View {
        Text(name).font(Theme.Figtree.font(.subheadline, weight: .semibold)).foregroundStyle(ink ?? .primary).lineLimit(1)
    }

    private func valueText(_ s: String, dim: Bool = false) -> some View {
        Text(s).font(Theme.Figtree.font(.caption, weight: .medium).monospacedDigit())
            .foregroundStyle(dim ? .tertiary : .secondary)
    }

    /// The reading nearest the playhead, so the value follows you as you move.
    private func reading(_ points: [(Date, Double)]) -> (Date, Double)? {
        points.filter { $0.0 <= window.center.addingTimeInterval(window.span * 0.02) }.max(by: { $0.0 < $1.0 }) ?? points.first
    }

    /// One condition on the window: a soft area in its colour, scaled to its own range (the rows compare shape
    /// and timing, not amounts), rescues as orange rules, the playhead as a dark one.
    private func row(_ name: String, _ air: Theme.AirInk, _ points: [(Date, Double)], unit: String) -> some View {
        let ink = air.deep
        // Name and reading on one line, the chart the full width beneath, so every row shares the strip's axis.
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                label(name, ink)
                Spacer()
                if points.count >= 2, let r = reading(points) { valueText("\(Int(r.1.rounded()))\(unit.isEmpty ? "" : " ")\(unit)") }
            }
            if points.count >= 2 {
                let lo = points.map(\.1).min()!, hi = points.map(\.1).max()!
                let y = { (v: Double) in hi > lo ? (v - lo) / (hi - lo) * 0.8 + 0.2 : 0.5 }
                Chart {
                    ForEach(rescues, id: \.self) { r in
                        RuleMark(x: .value("Rescue", r)).foregroundStyle(Color.primary.opacity(0.2)).lineStyle(StrokeStyle(lineWidth: 1))
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
            } else {
                Text(name == "Pressure" || name == "Flu and illness" ? "Not tracked yet" : "No readings here")
                    .font(Theme.Figtree.font(.caption)).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reading(points).map { "\(name), \(Int($0.1.rounded())) \(unit)" } ?? "\(name), no readings")
    }

    /// Dots on the window: one per log, in its colour; the playhead as a dark rule.
    /// `marks`: when, the ink, and whether it's hollow (standard inhaler) rather than filled (rescue).
    private func dots(_ name: String, _ marks: [(Date, Color, Bool)]) -> some View {
        let inView = marks.filter { window.domain.contains($0.0) }
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                label(name, nil)
                Spacer()
                valueText(inView.isEmpty ? "None" : "\(inView.count)", dim: inView.isEmpty)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.06)).frame(height: 2)
                    ForEach(Array(inView.enumerated()), id: \.offset) { _, m in
                        Circle().fill(m.2 ? Color.clear : m.1).strokeBorder(m.1, lineWidth: 1.2).frame(width: 9, height: 9)
                            .position(x: window.x(m.0, width: g.size.width), y: g.size.height / 2)
                    }
                }
            }
            .frame(height: 28)
            .clipped()
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(inView.count) in view")
    }

    private func empty(_ name: String, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label(name, nil)
            Text(note).font(Theme.Figtree.font(.caption)).foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }
}

/// Environment on Now (owner, Nov 13). At rest every condition is drawn on one shared baseline as overlapping
/// soft waves, the names stacked on the left in their colours. As you scroll down, the waves part and each settles
/// into its own row with its name and the reading at the playhead, the per-condition view below. Each line is
/// scaled to its own range: the chart compares shape and timing, never amounts across conditions.
struct MenusEnvironment: View {
    struct Series: Identifiable {
        let name: String
        let air: Theme.AirInk
        let points: [(Date, Double)]
        let unit: String
        var note: String = "No readings here"
        var id: String { name }
    }

    let window: MenusWindow
    let rescues: [Date]
    let ink: Color
    /// 0: together on one line. 1: apart, one row each. Follows the page's scroll.
    let apart: CGFloat
    /// The shared band's height at rest.
    let bandH: CGFloat
    let series: [Series]
    @Binding var width: CGFloat
    /// Shown just under the shared band while the lines are together (the day's title), gone as they part.
    var footer: MenusDayTitle? = nil
    /// Edge to edge (the combined chart on home, owner Nov 13): the waves run the full screen width; names and
    /// readings keep a small inset.
    var edge = false
    /// Samples after this are forecast hours, drawn lighter.
    var now: Date = .now
    /// How much each condition is one of your triggers, 0…1, by series name (from the gated lift rows).
    var triggers: [String: Double] = [:]
    /// The portrait's key, shown for the swatch you tap (owner, Nov 13).
    @State private var tapped: (name: String, at: CGPoint)?
    @State private var hideTap: Task<Void, Never>?
    @State private var canvasSize: CGSize = .zero
    /// The fans' opening tween: from, to, and when it started.
    @State private var openFrom: [String: CGFloat] = [:]
    @State private var openTo: [String: CGFloat] = [:]
    @State private var openStart: Date = .distantPast
    private static let openDuration: TimeInterval = 0.75
    /// Hand-drawn timing (owner, Nov 13): the fans move at 12 drawings a second, not smoothly.
    private static let fps: Double = 12

    /// Which drawing of the tween we're on, or nil when it's done (then the fans hold still).
    private func frame(at t: Date) -> Int? {
        let e = t.timeIntervalSince(openStart)
        return e < Self.openDuration ? Int(e * Self.fps) : nil
    }

    /// How far each fan should be open at the playhead, 0…1 (closed with no reading).
    private func targetOpens() -> [String: CGFloat] {
        var out: [String: CGFloat] = [:]
        for s in series where s.note != "Not tracked yet" {
            out[s.name] = reading(s).map { intensity(s.name, $0, s) } ?? 0
        }
        return out
    }

    /// The opening at a moment in the tween, eased in and out.
    private func shownOpens(at t: Date) -> [String: CGFloat] {
        // Stepped to whole drawings, so it moves in small jumps like a flipbook.
        let held = (t.timeIntervalSince(openStart) * Self.fps).rounded(.down) / Self.fps
        let p = CGFloat(min(1, max(0, held / Self.openDuration)))
        let e = p * p * (3 - 2 * p)
        var out: [String: CGFloat] = [:]
        for (k, to) in openTo { out[k] = (openFrom[k] ?? to) + (to - (openFrom[k] ?? to)) * e }
        return out
    }
    @Environment(\.colorScheme) private var scheme
    /// The portrait's height on home: it's the main visual, a square-ish field in the middle of the screen.
    static let bigBand: CGFloat = 430
    private var inset: CGFloat { edge ? MenusColumns.page + MenusColumns.card : 0 }

    private let headerH: CGFloat = 54
    private let rowH: CGFloat = 76

    var body: some View {
        // Tall enough for the rows, and for the shared band while it's together.
        let height = max(headerH + CGFloat(series.count) * rowH, bandH + (footer == nil ? 40 : 110))
        // The fans ease open and closed as you move between moments (owner, Nov 13): a short tween from where
        // they were to where this moment puts them, picked up mid-way if you keep moving.
        TimelineView(.animation(minimumInterval: 1 / Self.fps, paused: Date().timeIntervalSince(openStart) > Self.openDuration + 0.1)) { tl in
            Canvas { ctx, size in draw(ctx, size, opens: shownOpens(at: tl.date), boil: frame(at: tl.date)) }
        }
            .onAppear { let t = targetOpens(); openFrom = t; openTo = t }
            .onChange(of: targetOpens()) { _, new in
                openFrom = shownOpens(at: .now)
                openTo = new
                openStart = .now
            }
            .frame(height: height)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { canvasSize = $0 }
            .contentShape(Rectangle())
            .onTapGesture { p in
                guard edge, apart < 0.3, let w = swatch(at: p) else {
                    withAnimation(.smooth(duration: 0.25)) { tapped = nil }
                    return
                }
                withAnimation(.smooth(duration: 0.25)) { tapped = (w.series.name, CGPoint(x: w.rect.midX, y: w.rect.minY)) }
                hideTap?.cancel()
                hideTap = Task {
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    withAnimation(.smooth(duration: 0.4)) { tapped = nil }
                }
            }
            .overlay(alignment: .topLeading) {
                if let t = tapped, apart < 0.3, let w = portraitLayout(canvasSize, lift: 0).first(where: { $0.series.name == t.name }) {
                    legend(w)
                        .fixedSize()
                        .position(x: min(max(t.at.x, 70), canvasSize.width - 70), y: max(t.at.y - 34, 20))
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .topLeading) {
                // The section title arrives as the rows part.
                VStack(alignment: .leading, spacing: 2) {
                    Text("Environment").font(Theme.Figtree.font(.title2, weight: .bold))
                    Text("Outdoor, at your moments").font(Theme.Figtree.font(.subheadline)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4 + inset)
                .opacity(Double(max(0, apart * 1.6 - 0.6)))
                .offset(y: (1 - apart) * -8)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .top) {
                if let footer {
                    footer
                        .padding(.vertical, 6).padding(.horizontal, 12)
                        .background(Color(uiColor: .systemGroupedBackground))
                        .offset(y: bandH + 16 - apart * 30)
                        .opacity(Double(max(0, 1 - apart * 2.5)))
                        .allowsHitTesting(apart < 0.3)
                }
            }
            .padding(.horizontal, edge ? -MenusColumns.page : MenusColumns.card)
            .onGeometryChange(for: CGFloat.self) { $0.size.width - (edge ? -2 * MenusColumns.page : 2 * MenusColumns.card) } action: { width = $0 }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Environment")
            .accessibilityValue(series.map { s in reading(s).map { "\(s.name) \(Int($0.rounded())) \(s.unit)" } ?? "\(s.name), \(s.note.lowercased())" }.joined(separator: ", "))
    }

    /// The reading nearest the playhead, so the value follows you as you move.
    private func reading(_ s: Series) -> Double? {
        guard s.points.count >= 2 else { return nil }
        return (s.points.filter { $0.0 <= window.center.addingTimeInterval(window.span * 0.02) }.max(by: { $0.0 < $1.0 }) ?? s.points.first)?.1
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize, opens: [String: CGFloat], boil: Int? = nil) {
        // Ease the parting so the samples leave the shared band gently and land softly in their rows.
        let t = apart * apart * (3 - 2 * apart)
        let w = size.width
        let withData = series.filter { $0.points.count >= 2 }
        let slots = max(withData.count, 1)
        let slotH = (bandH - 8) / CGFloat(slots)

        // Rescue moments: faint orange rules through the shared band, then through each row.
        for r in rescues {
            let x = window.x(r, width: w)
            guard x >= 0, x <= w else { continue }
            var rule = Path()
            rule.move(to: CGPoint(x: x, y: lerp(0, headerH, t)))
            rule.addLine(to: CGPoint(x: x, y: lerp(bandH, size.height, t)))
            ctx.stroke(rule, with: .color(Color.primary.opacity(0.18 * (edge ? Double(min(1, max(0, t * 1.6 - 0.3))) : 1))), lineWidth: 1)
        }

        // With the portrait (home), the rows only come in as you scroll; the portrait leaves as they do.
        let portrait = edge
        let rowsShown = portrait ? Double(min(1, max(0, t * 1.6 - 0.3))) : 1
        if portrait, t < 0.7 {
            drawPortrait(ctx, size: size, fade: Double(1 - t / 0.7), lift: t * 60, opens: opens, boil: boil)
        }

        // Each sample is a soft watercolour mark (owner, Nov 13): we only know the air at the moments we
        // snapshotted it, so nothing is drawn between them. Marks sit in one blurred, multiplied layer so
        // overlaps mix like pigment on paper.
        var labels: [(Text, CGPoint, UnitPoint, Double)] = []
        ctx.drawLayer { paint in
            paint.addFilter(.blur(radius: lerp(2.4, 1.1, t)))
            paint.blendMode = scheme == .dark ? .screen : .normal
            for (i, s) in series.enumerated() {
                let rowTop = headerH + CGFloat(i) * rowH
                let legendIndex = withData.firstIndex { $0.name == s.name }
                let slot = CGFloat(legendIndex ?? 0)
                // Its slot: a stripe of the shared band at rest, its own row when apart.
                // At rest every condition sits on the same spot, a little stacked, so each moment is one blended
                // portrait of its air (owner, Nov 13). Apart, each settles into its own row.
                let restY = bandH * 0.62 + (slot - CGFloat(slots - 1) / 2) * min(12, slotH * 0.4)
                let midY = lerp(restY, rowTop + 26 + 18, t)
                let boxH = lerp(slotH, 36, t)

                // Name: on the left of its slot at rest (small), above its row when apart.
                let nameY = lerp(2 + slot * 15, rowTop + 4, t)
                labels.append((Text(s.name).font(Theme.Figtree.font(size: lerp(11, 15, t), weight: .semibold)).foregroundStyle(s.air.deep),
                               CGPoint(x: inset, y: nameY), .topLeading, portrait ? rowsShown : (legendIndex != nil ? 1 : Double(t))))
                guard s.points.count >= 2 else {
                    labels.append((Text(s.note).font(Theme.Figtree.font(.caption)).foregroundStyle(.tertiary), CGPoint(x: inset, y: rowTop + 30), .topLeading, Double(t)))
                    continue
                }
                if let v = reading(s) {
                    labels.append((Text("\(Int(v.rounded()))\(s.unit.isEmpty ? "" : " ")\(s.unit)").font(Theme.Figtree.font(.caption, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary), CGPoint(x: w - inset, y: rowTop + 6), .topTrailing, Double(t)))
                }

                // Its own range: the chart compares when each condition ran high, never amounts across them.
                let lo = s.points.map(\.1).min()!, hi = s.points.map(\.1).max()!
                for p in s.points {
                    let x = window.x(p.0, width: w)
                    guard x > -40, x < w + 40 else { continue }
                    let f = CGFloat(hi > lo ? (p.1 - lo) / (hi - lo) : 0.5)
                    var rng = IslandRNG(seed: UInt64(bitPattern: Int64(p.0.timeIntervalSince1970)) &+ UInt64(i) &* 7919)
                    let jx = CGFloat.random(in: -5...5, using: &rng) * (1 - t * 0.5), jy = CGFloat.random(in: -4...4, using: &rng) * (1 - t * 0.5)
                    // Bigger and deeper when it ran high for this condition.
                    let mh = lerp(min(bandH * 0.42, 16 + 58 * f), boxH * (0.45 + 0.5 * f), t)
                    let mw = max(12, mh * CGFloat.random(in: 0.75...1.15, using: &rng)) * (s.name == "Wind" ? 1.35 : 1)
                    let rect = CGRect(x: x - mw / 2 + jx, y: midY - mh / 2 + jy, width: mw, height: mh)
                    let ahead = p.0 > now
                    let alpha = Double(lerp(0.12 + 0.42 * f, 0.32 + 0.4 * f, t)) * (ahead ? 0.5 : 1) * rowsShown
                    let shape = mark(s.name, rect)
                    paint.fill(shape, with: .color(s.air.color.opacity(alpha)))
                    // Pigment pools low in the wash: a smaller, deeper core towards the bottom.
                    let core = rect.insetBy(dx: mw * 0.2, dy: mh * 0.22).offsetBy(dx: 0, dy: mh * 0.12)
                    paint.fill(mark(s.name, core), with: .color(s.air.color.opacity(alpha * lerp(0.35, 0.6, t))))
                }
            }
        }

        // Paper grain over the washes, so they read as printed pigment rather than a gradient.
        var grain = Path()
        var g = IslandRNG(seed: 0xFE17)
        let top = lerp(0, headerH, t), bottom = lerp(bandH, size.height, t)
        for _ in 0..<Int(w * (bottom - top) / 55) {
            let x = CGFloat.random(in: 0...w, using: &g), y = CGFloat.random(in: top...bottom, using: &g)
            grain.addEllipse(in: CGRect(x: x, y: y, width: 0.9, height: 0.9))
        }
        ctx.fill(grain, with: .color(paper.opacity(0.45)))

        for (text, at, anchor, opacity) in labels where opacity > 0.01 {
            ctx.drawLayer { l in
                l.opacity = opacity
                l.draw(text, at: at, anchor: anchor)
            }
        }
    }

    private var paper: Color { Color(uiColor: .systemGroupedBackground) }

    // MARK: The portrait

    /// How strong each reading is on a fixed scale (not its own range), 0…1: this sets a mark's size and depth.
    /// Temperature counts distance from mild, either way.
    private func intensity(_ name: String, _ v: Double, _ s: Series) -> CGFloat {
        let x: Double
        switch name {
        case "Temperature": x = abs(v - 65) / 35
        case "Humidity": x = v / 100
        case "Wind": x = v / 25
        case "PM2.5": x = v / 35
        case "Ozone": x = v / 70
        case "Pollen": x = v / 100   // share of a high day
        default: x = v / max(s.points.map(\.1).max() ?? 1, 1)
        }
        return CGFloat(min(1, max(0.08, x)))
    }

    /// Coloured-pencil inks for the fans, after the drawing: rose, cobalt, vermilion, teal, ochre, violet, graphite.
    private func pigment(_ name: String, _ v: Double) -> Color {
        switch name {
        case "Temperature": Color(red: 0.86, green: 0.36, blue: 0.30)
        case "Humidity": Color(red: 0.20, green: 0.50, blue: 0.56)
        case "Wind": Color(red: 0.42, green: 0.43, blue: 0.45)
        case "PM2.5": Color(red: 0.18, green: 0.42, blue: 0.78)
        case "Ozone": Color(red: 0.86, green: 0.42, blue: 0.56)
        case "Pollen": Color(red: 0.93, green: 0.74, blue: 0.16)   // yellow (owner, Nov 13)
        default: Color(red: 0.50, green: 0.40, blue: 0.70)
        }
    }

    /// One fan in the portrait: its base (where the stem meets the fan), its reach, how far it's open, and the
    /// random state that roughens its pencil lines. `rect` is what a tap hits.
    private struct Swatch {
        let series: Series; let value: Double?
        let strength: CGFloat   // how far it's open: the reading against your threshold, 0…1
        let weight: CGFloat     // how much it's one of your triggers, 0…1: sets the fan's size
        let base: CGPoint; let reach: CGFloat; let ground: CGFloat
        let rect: CGRect; let rng: IslandRNG
    }

    /// How much each condition is one of yours, 0…1, from the gated rows. Equal for all while still learning.
    private func weight(_ name: String) -> CGFloat {
        guard !triggers.isEmpty else { return 0.45 }
        return CGFloat(min(1, max(0.15, triggers[name] ?? 0.15)))
    }

    /// Where each condition's fan stands, shared by drawing and tapping so a tap finds what you see.
    private func portraitLayout(_ size: CGSize, lift: CGFloat, opens: [String: CGFloat]? = nil) -> [Swatch] {
        // Every condition we track always has its flower (owner, Nov 13). No reading, or a low one: a closed fan.
        let present = series.filter { $0.note != "Not tracked yet" }.map { ($0, reading($0)) }
        guard !present.isEmpty else { return [] }
        let n = present.count
        // On home the ground sits just above the timeline, about 30 pt from its time (owner, Nov 13).
        let ground = bandH - (edge ? 4 : 34) - lift
        let left = inset + 20, right = size.width - inset - 20
        let gap = (right - left) / CGFloat(max(n, 1))
        // Big and small alternate along the row, so the two biggest fans stand well apart (owner, Nov 13:
        // no overlaps): biggest second from the left, the next one second from the right, and so on.
        let order = present.indices.sorted { weight(present[$0].0.name) > weight(present[$1].0.name) }
        let pattern = n == 6 ? [1, 4, 3, 0, 5, 2] : n == 5 ? [1, 3, 2, 0, 4] : Array(0..<n)
        var slots = Array(repeating: 0, count: n)
        for (rank, i) in order.enumerated() { slots[i] = pattern[rank] }

        struct Spot { var x: CGFloat; var y: CGFloat; let r: CGFloat; let w: CGFloat; var rng: IslandRNG }
        let W = right - left
        var spots: [Spot] = present.enumerated().map { i, sv in
            let s = sv.0
            // Seeded by the condition, not the day: each flower keeps its place, stem and size from day to day,
            // and only how far it opens changes (owner, Nov 13).
            var rng = IslandRNG(seed: UInt64(s.name.unicodeScalars.reduce(7) { $0 &* 31 &+ Int($1.value) }.magnitude))
            let w = weight(s.name)
            let slot = slots[i]
            // Sized so that, fully open, every round fits the row without touching (owner, Nov 13 sketch).
            let reach = min(W * (0.055 + 0.17 * w), (bandH - 40) * 0.3)
            // Bigger triggers stand taller; the small ones rise to staggered heights.
            let rise: [CGFloat] = [0.1, 0.4, 0.22, 0.5, 0.06, 0.32]
            let stem = (bandH - 60) * (0.12 + 0.78 * w * w) + (bandH - 60) * rise[slot % rise.count] * (1 - w)
                + CGFloat.random(in: -6...6, using: &rng)
            let x = left + gap * (CGFloat(slot) + 0.5) + CGFloat.random(in: -4...4, using: &rng)
            // Planned as a full round: wholly above the ground and below the top.
            var y = min(max(ground - stem, reach + 10), ground - reach - 14)
            // Your biggest trigger stands highest, near the top (owner, Nov 13).
            if i == order.first { y = reach + 10 }
            return Spot(x: x, y: y, r: reach, w: w, rng: rng)
        }
        // The rest stand clearly lower than your biggest trigger, at least a third of the way down from it.
        if let top = order.first {
            let floorTop = spots[top].y + (ground - spots[top].y) * 0.34
            for k in spots.indices where k != top {
                spots[k].y = min(max(spots[k].y, floorTop), ground - spots[k].r - 14)
            }
        }
        // No two fully open rounds touch (owner, Nov 13). The bigger trigger keeps its spot; the smaller one moves
        // straight down until clear, or up if there's no room below.
        let margin: CGFloat = 8
        let order2 = spots.indices.sorted { spots[$0].w > spots[$1].w }
        for _ in 0..<4 {
            for (bi, big) in order2.enumerated() {
                for small in order2.dropFirst(bi + 1) {
                    let b = spots[big], sm = spots[small]
                    let need = b.r + sm.r + margin
                    let dx = abs(b.x - sm.x)
                    guard dx < need, hypot(b.x - sm.x, b.y - sm.y) < need else { continue }
                    let dy = (need * need - dx * dx).squareRoot()
                    let below = b.y + dy, above = b.y - dy
                    let floor = ground - sm.r - 14, ceiling = sm.r + 10
                    if below <= floor { spots[small].y = below }
                    else if above >= ceiling { spots[small].y = above }
                    else {
                        // Neither fits: slide it sideways, away from the bigger one.
                        let dir: CGFloat = sm.x >= b.x ? 1 : -1
                        spots[small].y = floor
                        let dy2 = abs(b.y - floor)
                        let dxNeed = dy2 < need ? (need * need - dy2 * dy2).squareRoot() : 0
                        spots[small].x = min(max(b.x + dir * dxNeed, left + sm.r), right - sm.r)
                    }
                }
            }
        }
        return present.enumerated().map { i, sv in
            let (s, v) = sv
            let p = spots[i]
            let open = opens?[s.name] ?? v.map { intensity(s.name, $0, s) } ?? 0
            let base = CGPoint(x: p.x, y: p.y)
            let below = open > 0.5 ? p.r * (open - 0.5) * 2 : 0
            let rect = CGRect(x: p.x - p.r, y: base.y - p.r, width: p.r * 2, height: p.r + max(below, 12))
            return Swatch(series: s, value: v, strength: open, weight: p.w, base: base, reach: p.r, ground: ground, rect: rect, rng: p.rng)
        }
    }

    /// Fans in coloured pencil (owner, Nov 13, after a drawing of pencil fans on stems). Each fan is a condition:
    /// its size is how much it's one of your triggers, and how far it opens is today's reading against your
    /// threshold, a closed brush when it's low, a full round when it's at or past it.
    /// `boil`: the drawing number while moving. Each drawing's rim wobbles a little differently, like line
    /// boil in hand-drawn animation; nil holds the rim still.
    private func drawPortrait(_ ctx: GraphicsContext, size: CGSize, fade: Double, lift: CGFloat, opens: [String: CGFloat], boil: Int? = nil) {
        let fans = portraitLayout(size, lift: lift, opens: opens)
        guard let ground = fans.first?.ground else { return }
        ctx.drawLayer { paint in
            paint.opacity = fade
            paint.blendMode = scheme == .dark ? .screen : .multiply
            // The ground: a faint pencil rule the stems stand on.
            var g = Path(); g.move(to: CGPoint(x: inset, y: ground)); g.addLine(to: CGPoint(x: size.width - inset, y: ground))
            paint.stroke(g, with: .color(.secondary.opacity(0.25)), lineWidth: 0.6)
            for f in fans {
                var rng = f.rng
                let ink = pigment(f.series.name, f.value ?? 0)
                // Stem, a little unsteady.
                // It meets the fan at its pivot; as the fan closes into a full round, it stops at the round's
                // bottom edge instead of running through it (owner, Nov 13).
                let o = min(1, max(0, (f.strength - 0.85) / 0.15))
                let top = CGPoint(x: f.base.x, y: f.base.y + f.reach * 0.93 * o * o * (3 - 2 * o))
                var stem = Path(); stem.move(to: CGPoint(x: f.base.x, y: ground))
                stem.addQuadCurve(to: top, control: CGPoint(x: f.base.x + CGFloat.random(in: -3...3, using: &rng), y: (ground + top.y) / 2))
                paint.stroke(stem, with: .color(ink.opacity(0.7)), lineWidth: 0.8)
                // The fan: closed is a narrow brush (16°), fully open a whole round. Deep where it meets the stem,
                // thinning towards a rim of a few wide soft bumps with a faint halo, like a cloud's edge
                // (owner, Nov 13: fade fill, cloud rim).
                let spread = (16 + 344 * Double(f.strength)) * .pi / 180
                func wedge(_ r: CGFloat) -> Path {
                    let bumps = max(2, Int((spread * 180 / .pi / 40).rounded()))
                    let full = spread >= 2 * .pi - 0.01
                    let steps = 160
                    var w = Path()
                    if !full { w.move(to: f.base) }
                    for j in 0...steps {
                        let t = Double(j) / Double(steps)
                        let a = -Double.pi / 2 - spread / 2 + spread * t
                        let p = (t * Double(bumps)).truncatingRemainder(dividingBy: 1)
                        var wob = 0.0
                        if let b = boil {
                            let fb = Double(b)
                            let w1: Double = 0.022 * sin(t * 9 + fb * 2.3)
                            let w2: Double = 0.012 * sin(t * 23 - fb * 1.7)
                            wob = w1 + w2
                        }
                        let bump: Double = (1 - pow(2 * p - 1, 2)).squareRoot()
                        let rr = r * CGFloat(0.93 + 0.07 * bump + wob)
                        let q = CGPoint(x: f.base.x + cos(a) * rr, y: f.base.y + sin(a) * rr)
                        if full && j == 0 { w.move(to: q) } else { w.addLine(to: q) }
                    }
                    w.closeSubpath()
                    return w
                }
                func fade(_ r: CGFloat) -> GraphicsContext.Shading {
                    .radialGradient(Gradient(stops: [.init(color: ink, location: 0), .init(color: ink.opacity(0.55), location: 0.5),
                                                     .init(color: ink.opacity(0.08), location: 1)]),
                                    center: f.base, startRadius: 0, endRadius: r)
                }
                let shape = wedge(f.reach)
                paint.fill(shape, with: fade(f.reach))
                // No halo round the rim (owner, Nov 13).
            }
        }
    }

    /// The swatch under a tap: the smallest one that holds the point, so one sitting on top of a bigger one wins.
    private func swatch(at p: CGPoint) -> Swatch? {
        portraitLayout(canvasSize, lift: 0).filter { $0.rect.insetBy(dx: -6, dy: -6).contains(p) }
            .min { $0.rect.width * $0.rect.height < $1.rect.width * $1.rect.height }
    }

    /// The tap label (owner, Nov 13): an annotation above the fan, like a label on a botanical print. The name
    /// in the fan's own ink, the reading quiet beneath it, no card, on the paper.
    private func legend(_ w: Swatch) -> some View {
        VStack(spacing: 1) {
            Text(w.series.name)
                .font(Theme.Figtree.font(size: 15, weight: .medium))
                .foregroundStyle(pigment(w.series.name, w.value ?? 0).mix(with: .black, by: 0.25))
            Text(Self.readingText(w.value, unit: w.series.unit))
                .font(Theme.Figtree.font(size: 13).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        // A soft glow of paper round the letters, so they read over a petal without a box.
        .shadow(color: Color(uiColor: .systemGroupedBackground), radius: 3)
        .shadow(color: Color(uiColor: .systemGroupedBackground), radius: 6)
        .multilineTextAlignment(.center)
    }

    /// "62 °F", "33 ppb", "90% of a high day", or "No reading".
    static func readingText(_ v: Double?, unit: String) -> String {
        guard let v else { return "No reading" }
        let n = Int(v.rounded())
        if unit.hasPrefix("%") { return "\(n)\(unit)" }
        return unit.isEmpty ? "\(n)" : "\(n) \(unit)"
    }

    /// A watercolour swatch: a few thin glazes of one wobbly shape, paler in the middle, with the pigment
    /// pulled to a darker, ragged rim where the water dried (the edge darkening of a real wash).
    private func swatch(_ ctx: GraphicsContext, name: String, rect r: CGRect, ink: Color, alpha: Double, rng: inout IslandRNG) {
        let base = outline(name, r)
        let c = CGPoint(x: r.midX, y: r.midY)
        let R = max(r.width, r.height) / 2
        // Glazes: the same shape, each a little different, so the body is uneven like pooled water.
        for g in 0..<3 {
            let path = wobble(base, around: c, amount: R * 0.06, rng: &rng)
            let a = alpha * (g == 0 ? 0.55 : 0.28)
            ctx.fill(path, with: .radialGradient(Gradient(colors: [ink.opacity(a * 0.55), ink.opacity(a)]),
                                                 center: CGPoint(x: c.x + CGFloat.random(in: -0.2...0.2, using: &rng) * R,
                                                                 y: c.y - CGFloat.random(in: 0...0.25, using: &rng) * R),
                                                 startRadius: 0, endRadius: R * 1.05))
        }
        // The dried edge: pigment pulled out to the rim, soft on the inside, sharper outside.
        let rim = wobble(base, around: c, amount: R * 0.04, rng: &rng)
        ctx.drawLayer { l in
            l.clip(to: rim)
            l.addFilter(.blur(radius: 2.2))
            l.stroke(rim, with: .color(ink.opacity(min(1, alpha * 0.95))), lineWidth: 5)
        }
        ctx.stroke(rim, with: .color(ink.opacity(alpha * 0.35)), lineWidth: 0.8)
    }

    /// Points round a condition's shape: a soft block, a drop, an oval or a star.
    private func outline(_ name: String, _ r: CGRect) -> [CGPoint] {
        let c = CGPoint(x: r.midX, y: r.midY), rx = r.width / 2, ry = r.height / 2
        let n = 64
        return (0..<n).map { i in
            let a = CGFloat(i) / CGFloat(n) * 2 * .pi
            let (ca, sa) = (cos(a), sin(a))
            switch name {
            case "Pollen":
                let k = 0.72 + 0.28 * cos(6 * a)
                return CGPoint(x: c.x + ca * rx * k, y: c.y + sa * ry * k)
            case "Wind", "Ozone", "Humidity":
                let e: CGFloat = name == "Humidity" ? 2.6 : 2
                return CGPoint(x: c.x + rx * copysign(pow(abs(ca), 2 / e), ca), y: c.y + ry * copysign(pow(abs(sa), 2 / e), sa))
            default:   // a soft-cornered block
                let e: CGFloat = 7
                return CGPoint(x: c.x + rx * copysign(pow(abs(ca), 2 / e), ca), y: c.y + ry * copysign(pow(abs(sa), 2 / e), sa))
            }
        }
    }

    /// The outline pushed in and out by slow random waves, closed with smooth curves.
    private func wobble(_ pts: [CGPoint], around c: CGPoint, amount: CGFloat, rng: inout IslandRNG) -> Path {
        let p1 = CGFloat.random(in: 0...6.28, using: &rng), p2 = CGFloat.random(in: 0...6.28, using: &rng), p3 = CGFloat.random(in: 0...6.28, using: &rng)
        let n = pts.count
        let moved = pts.enumerated().map { i, p -> CGPoint in
            let a = CGFloat(i) / CGFloat(n) * 2 * .pi
            let d = amount * (0.55 * sin(3 * a + p1) + 0.3 * sin(5 * a + p2) + 0.15 * sin(11 * a + p3))
            let dx = p.x - c.x, dy = p.y - c.y, len = max(hypot(dx, dy), 0.001)
            return CGPoint(x: p.x + dx / len * d, y: p.y + dy / len * d)
        }
        var path = Path()
        let mid = { (i: Int) in CGPoint(x: (moved[i % n].x + moved[(i + 1) % n].x) / 2, y: (moved[i % n].y + moved[(i + 1) % n].y) / 2) }
        path.move(to: mid(0))
        for i in 1...n { path.addQuadCurve(to: mid(i), control: moved[i % n]) }
        path.closeSubpath()
        return path
    }

    /// Each condition keeps one shape, so its marks stay findable when columns overlap: blocks for
    /// temperature and particles, a soft drop for humidity, a long oval for wind, a round for ozone, a star for pollen.
    private func mark(_ name: String, _ r: CGRect) -> Path {
        switch name {
        case "Humidity": return Path(roundedRect: r, cornerSize: CGSize(width: r.width / 2, height: r.width / 2))
        case "Wind", "Ozone": return Path(ellipseIn: r)
        case "Pollen":
            var p = Path()
            let c = CGPoint(x: r.midX, y: r.midY), R = min(r.width, r.height) / 2 * 1.1
            for k in 0..<12 {
                let a = CGFloat(k) * .pi / 6 - .pi / 2
                let rr = k.isMultiple(of: 2) ? R : R * 0.58
                let q = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
                k == 0 ? p.move(to: q) : p.addLine(to: q)
            }
            p.closeSubpath()
            return p
        default: return Path(roundedRect: r, cornerSize: CGSize(width: 2, height: 2))
        }
    }

    /// A soft curve through the points (midpoint quadratic smoothing).
    private func smooth(_ p: [CGPoint]) -> Path {
        var path = Path()
        guard let first = p.first else { return path }
        path.move(to: first)
        guard p.count > 2 else { p.dropFirst().forEach { path.addLine(to: $0) }; return path }
        for i in 1..<p.count {
            let mid = CGPoint(x: (p[i - 1].x + p[i].x) / 2, y: (p[i - 1].y + p[i].y) / 2)
            path.addQuadCurve(to: mid, control: p[i - 1])
        }
        path.addLine(to: p[p.count - 1])
        return path
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
                Image(systemName: "inhaler.fill").font(Theme.Figtree.font(size: c * 0.34, weight: .semibold)).foregroundStyle(.white)
            case .standard:
                Circle().fill(Theme.standardSoft)
                Image(systemName: "inhaler.fill").font(Theme.Figtree.font(size: c * 0.34, weight: .semibold)).foregroundStyle(Theme.standard)
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
