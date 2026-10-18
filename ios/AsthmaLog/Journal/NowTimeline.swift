import AsthmaCore
import SwiftUI

/// One track for past and future. Your moments sit on the axis behind the playhead; ahead of it the
/// forecast hours run on as a faint strip of sky color. The playhead reads a *time*, so you can scrub
/// into this evening or tomorrow, and it snaps to a moment when one is close.
struct NowTimeline: View {
    let moments: [LogEvent]
    /// Baseline moments (felt air's own checks): small ticks, so the comparison is visible.
    var baselines: [Date] = []
    /// How the air was at each moment: green / yellow / red, so the rail answers "was that comfortable?"
    /// at a glance. Nil when there was no reading.
    /// 0 light … 1 heavy (nil when there was no reading). Drawn as one ink at three strengths.
    var tint: (LogEvent) -> Double? = { _ in nil }
    /// The forecast ahead of now, hour by hour, in the verdict's colours (nil while still learning).
    var forecastTints: [(Date, Double?)] = []
    /// The verdict's colour for the time under the playhead (Now and ahead), for the chip and the line.
    var verdictTint: Color? = nil
    let hours: [NowHour]
    /// The clock, passed in so the track creeps forward while you watch.
    let now: Date
    /// Nil is now.
    @Binding var focusTime: Date?
    /// True while the track is being dragged or is still gliding.
    @Binding var scrubbing: Bool
    /// Swiping on past the end of the forecast reveals Insights.
    var onPastEnd: () -> Void = {}
    @State private var pastEndArmed = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settle = false

    @State private var position = ScrollPosition(edge: .trailing)
    @State private var centerX: CGFloat = 0
    @State private var viewport: CGFloat = 0
    @State private var dragging = false

    @AppStorage(Crit.Paper.key) private var paper = Crit.Paper.black
    /// The track's ink: white on black paper, near-black on linen.
    @Environment(\.colorScheme) private var scheme
    private var ink: Color { scheme == .light ? Color(red: 0.12, green: 0.1, blue: 0.09) : .white }

    private let dayWidth: CGFloat = 64
    private let axis: CGFloat = 46
    private let hourTick = UISelectionFeedbackGenerator()
    private let height: CGFloat = 86
    private let cal = Calendar.current

    private var start: Date {
        cal.startOfDay(for: min(moments.first?.loggedAt ?? now, cal.date(byAdding: .day, value: -3, to: now)!))
    }
    private var end: Date { cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: now))! }
    private var contentWidth: CGFloat { CGFloat(end.timeIntervalSince(start) / 86_400) * dayWidth }
    private func x(_ d: Date) -> CGFloat { CGFloat(d.timeIntervalSince(start) / 86_400) * dayWidth }
    private func time(at x: CGFloat) -> Date { start.addingTimeInterval(Double(x / dayWidth) * 86_400) }
    private var current: Date { focusTime ?? now }
    private var currentMoment: LogEvent? {
        moments.first { abs($0.loggedAt.timeIntervalSince(current)) < 20 * 60 }
    }

    var body: some View {
        ScrollView(.horizontal) { track }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGFloat.self) { $0.containerSize.width } action: { _, w in viewport = w }
        // Pulled past the forecast's end (the bounce): open Insights, once per drag.
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x - ($0.contentSize.width - $0.containerSize.width) } action: { _, over in
            if over > 56, dragging, pastEndArmed { pastEndArmed = false; UIImpactFeedbackGenerator(style: .medium).impactOccurred(); onPastEnd() }
            if over < 8 { pastEndArmed = true }
        }
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x } action: { _, cx in
            centerX = cx
            guard dragging else { return }
            let t = time(at: cx)
            if abs(t.timeIntervalSince(now)) < 15 * 60 { focusTime = nil }
            else if t < now {
                // Behind now: a moment within reach takes the playhead; between moments it reads the time.
                if let m = moments.min(by: { abs($0.loggedAt.timeIntervalSince(t)) < abs($1.loggedAt.timeIntervalSince(t)) }),
                   abs(m.loggedAt.timeIntervalSince(t)) < 30 * 60 { focusTime = m.loggedAt } else { focusTime = t }
            } else {
                // Ahead, the forecast is hourly: the playhead reads whole hours.
                focusTime = t > now ? Self.hour(t) : t
            }
        }
        .onScrollPhaseChange { old, phase in
            dragging = phase == .interacting || phase == .decelerating
            scrubbing = dragging
            // Settle on a moment if one is near the playhead, else exactly on now if near it.
            if phase == .idle, old == .interacting || old == .decelerating {
                if let m = moments.min(by: { abs(x($0.loggedAt) - centerX) < abs(x($1.loggedAt) - centerX) }),
                   abs(x(m.loggedAt) - centerX) < 10 { go(to: m.loggedAt) }
                else if abs(x(now) - centerX) < 10 || time(at: centerX) < now { go(to: focusTime) }
            }
        }
        .overlay(alignment: .top) {
            ZStack(alignment: .top) {
                Capsule().fill(verdictTint ?? ink).frame(width: 2, height: 30)
                    .offset(y: axis - 15)
                    .allowsHitTesting(false)
                // The chip is the way back (one control, like Calendar's Today): away from now it carries a return
                // arrow and a tap jumps to Now. On Now it's a label.
                Button(action: { go(to: nil) }) { chipLabel }
                .buttonStyle(PressStyle())
                .offset(y: axis - 17 - 30)
                .disabled(focusTime == nil)
                .accessibilityLabel(focusTime == nil ? "Now" : "Back to now")
            }
            .frame(maxWidth: .infinity)
        }
        .animation(Theme.snap, value: focusTime == nil)
        .padding(.top, 24)
        .sensoryFeedback(.selection, trigger: currentMoment?.id)
        // Ahead, a tick per hour: the forecast's grain under the thumb. A generator kept warm for the whole
        // drag, and fired directly: `.sensoryFeedback` drops ticks that come fast, and the thumb crosses hours fast.
        .onChange(of: current > now ? Self.hour(current) : nil) { was, next in
            guard dragging, next != nil, was != nil else { return }
            hourTick.selectionChanged()
            hourTick.prepare()
        }
        .onChange(of: dragging) { _, d in if d { hourTick.prepare() } }
        .onChange(of: currentMoment?.id) { _, id in
            guard id != nil else { return }
            settle = true
            Task { try? await Task.sleep(for: .milliseconds(140)); settle = false }
        }
        .onChange(of: focusTime) { _, t in
            if !dragging, abs(x(t ?? now) - centerX) > 1 { withAnimation(.smooth) { position.scrollTo(x: x(t ?? now)) } }
        }
        .task(id: viewport) {
            guard viewport > 0 else { return }
            try? await Task.sleep(for: .milliseconds(80))
            position.scrollTo(x: x(current))
        }
        // Sitting on now, the playhead keeps up with the clock.
        .onChange(of: now) { _, n in if focusTime == nil, !dragging { position.scrollTo(x: x(n)) } }
        .accessibilityElement()
        .accessibilityLabel("Timeline")
        .accessibilityValue(focusTime == nil ? "Now" : current.formatted(date: .abbreviated, time: .shortened))
    }

    /// The scrolling content: half a viewport of room, the drawn track with tap targets, half a viewport more.
    private var track: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: viewport / 2)
            ZStack(alignment: .topLeading) {
                // The forecast hasn't settled: its slots drift. The past is still. Runs while the forecast
                // drifts, and for a moment after a log so the new dot can land.
                let justLogged: Bool = moments.last.map { Date().timeIntervalSince($0.loggedAt) < 1.2 } ?? false
                let paused: Bool = reduceMotion || (forecastTints.isEmpty && !justLogged)
                TimelineView(.animation(minimumInterval: 1 / 24, paused: paused)) { frame in
                    let flux: Double = reduceMotion ? 0 : frame.date.timeIntervalSinceReferenceDate
                    Canvas { ctx, size in draw(&ctx, size: size, frame: frame.date, flux: flux) }
                        .frame(width: contentWidth, height: height)
                }
                // Tap targets for the dots (the marks themselves are drawn above).
                ForEach(moments) { e in
                    Color.clear.frame(width: 22, height: 36).contentShape(Rectangle())
                        .position(x: x(e.loggedAt), y: axis)
                        .onTapGesture { go(to: e.loggedAt) }
                }
            }
            .frame(width: contentWidth, height: height)
            // After the forecast: a hint that there's more this way.
            Color.clear.frame(width: viewport / 2)
                .overlay(alignment: .leading) {
                    Image(systemName: "sparkles").font(.caption).foregroundStyle(ink.opacity(0.35))
                        .padding(.leading, 22).offset(y: axis - height / 2)
                }
        }
    }

    /// The chip's face: the time, a return arrow when away from now, the verdict's colour under the playhead.
    private var chipLabel: some View {
        let ahead = focusTime != nil && current > now
        let behind = focusTime != nil && current < now
        let fill: Color = verdictTint ?? ink
        let text: Color = verdictTint != nil ? .black : (scheme == .light ? Theme.linen : .black)
        return HStack(spacing: 5) {
            if ahead { Image(systemName: "arrow.uturn.backward").font(.caption2.weight(.bold)) }
            Text(focusTime == nil ? Self.when(now, now: now) : relative(current))
            if behind { Image(systemName: "arrow.uturn.forward").font(.caption2.weight(.bold)) }
        }
        .font(.caption.weight(.semibold).monospacedDigit())
        .tracking(0.2)
        .foregroundStyle(text)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(fill, in: Capsule())
        // Ahead: a sketch, like the forecast sky (a dashed edge), so it never reads as a record.
        .overlay { if ahead { Capsule().strokeBorder(Color.black.opacity(0.35), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])) } }
        .animation(Theme.smooth, value: verdictTint)
        .contentTransition(.numericText())
        .animation(Theme.snap, value: focusTime == nil)
        .fixedSize()
        .frame(minWidth: 40)
        // A small settle each time the playhead lands on a moment.
        .scaleEffect(settle ? 1.07 : 1)
        .animation(Theme.snap, value: settle)
    }

    /// Everything on the track, drawn in one pass (a method rather than an inline closure: the type-checker
    /// gives up on a closure this size).
    private func draw(_ ctx: inout GraphicsContext, size: CGSize, frame: Date, flux: Double) {
        // The axis: solid behind now, dotted ahead. The forecast's colours live in the sky
        // and the details, not down here.
        var line = Path()
        line.move(to: CGPoint(x: 0, y: axis)); line.addLine(to: CGPoint(x: x(now), y: axis))
        ctx.stroke(line, with: .color(ink.opacity(0.14)), lineWidth: 1)
        if let last = hours.last {
            var ahead = Path()
            ahead.move(to: CGPoint(x: x(now), y: axis)); ahead.addLine(to: CGPoint(x: x(last.date), y: axis))
            ctx.stroke(ahead, with: .color(ink.opacity(0.14)), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
        }
        // The forecast: one slot per hour in the verdict's colour (green baseline, yellow a bit like,
        // red matches your flare days), so the track reads like the pill. While still learning it's a
        // faint band in the ink, so the day's shape shows.
        for (n, (date, v)) in forecastTints.enumerated() where date >= now {
            // One bar per hour with a hairline gap: the forecast is hourly, and the track says so.
            let w = max(1, dayWidth / 24 - 1.2)
            // Each hour breathes on its own phase, more the further out it is: not yet known.
            let far = min(1, date.timeIntervalSince(now) / (48 * 3600))
            let wave: Double = sin(flux * 1.6 + Double(n) * 0.55)
            let h: CGFloat = 8 + CGFloat((2 + 4 * far) * wave)
            let tint: Color = Self.verdictColor(v, ink: ink)
            let base: Double = v == nil ? 0.1 : 0.7
            let alpha: Double = base * (0.8 + 0.2 * (0.5 + 0.5 * wave))
            let rect = CGRect(x: x(date), y: axis - h / 2, width: w, height: h)
            ctx.fill(Path(rect), with: .color(tint.opacity(alpha)))
        }
        // Moments: a dot on the axis per moment, in the colour of the air that day, so they never
        // read as the hour marks. Rescue is the bigger dot, standard smaller, a note the smallest.
        // A rescue with nothing said yet is hollow; it fills once you've noted it.
        for e in moments {
            let on = e.id == currentMoment?.id
            var r: CGFloat = e.moment == .rescue ? 5 : e.moment == .note ? 2.2 : 3.6
            // Just logged: the dot lands, big then settling, over half a second.
            let age = frame.timeIntervalSince(e.loggedAt)
            if !reduceMotion, age >= 0, age < 0.6 {
                let settle: Double = pow(1 - age / 0.6, 2)
                r *= 1 + 0.8 * CGFloat(settle)
            }
            let strength: Double = e.moment == .note ? 0.45 : (tint(e).map { 0.4 + 0.6 * $0 } ?? 0.3)
            let c: Color = ink.opacity(strength)
            let rect = CGRect(x: x(e.loggedAt) - r, y: axis - r, width: 2 * r, height: 2 * r)
            if e.wantsNote {
                ctx.stroke(Path(ellipseIn: rect.insetBy(dx: 0.8, dy: 0.8)), with: .color(c), lineWidth: 1.6)
            } else {
                ctx.fill(Path(ellipseIn: rect), with: .color(on ? c : c.opacity(0.85)))
            }
            if on {
                ctx.stroke(Path(ellipseIn: CGRect(x: x(e.loggedAt) - 9, y: axis - 9, width: 18, height: 18)),
                           with: .color(ink), lineWidth: 1.5)
            }
        }
        // Now: a short bright tick.
        var nowTick = Path()
        nowTick.move(to: CGPoint(x: x(now), y: axis - 12)); nowTick.addLine(to: CGPoint(x: x(now), y: axis + 12))
        ctx.stroke(nowTick, with: .color(ink.opacity(0.6)), lineWidth: 1.5)
        // Baseline checks: a short, faint tick just under the axis.
        for b in baselines {
            var p = Path()
            p.move(to: CGPoint(x: x(b), y: axis + 3)); p.addLine(to: CGPoint(x: x(b), y: axis + 9))
            ctx.stroke(p, with: .color(ink.opacity(0.35)), lineWidth: 1.5)
        }
        drawForecastClock(&ctx, end: end)
        // Ticks every 6 h, day names beneath.
        var t = start
        while t <= end {
            let isDay = cal.component(.hour, from: t) == 0
            let half: CGFloat = isDay ? 10 : 4
            var p = Path()
            p.move(to: CGPoint(x: x(t), y: axis - half)); p.addLine(to: CGPoint(x: x(t), y: axis + half))
            ctx.stroke(p, with: .color(ink.opacity(isDay ? 0.4 : 0.18)), lineWidth: 1)
            if isDay {
                let label = cal.isDateInToday(t) ? "Today" : cal.isDateInTomorrow(t) ? "Tomorrow"
                    : t.formatted(.dateTime.weekday(.abbreviated).day())
                ctx.draw(Text(label).font(.caption2.weight(.medium)).tracking(0.3).foregroundStyle(ink.opacity(t > now ? 0.3 : 0.45)),
                         at: CGPoint(x: x(t) + dayWidth / 2, y: axis + 26))
            }
            t = cal.date(byAdding: .hour, value: 6, to: t)!
        }
    }

    /// Green baseline, yellow a bit like, red matches your flare days; the ink while still learning.
    private static func verdictColor(_ v: Double?, ink: Color) -> Color {
        guard let v else { return ink }
        return v >= 1 ? Verdict.red : v >= 0.5 ? Verdict.yellow : Verdict.green
    }

    /// Ahead, the hour beneath the track at 6 AM and 6 PM: the forecast has its own clock. (Midnight is the
    /// day name beneath; 6-hourly collides.)
    private func drawForecastClock(_ ctx: inout GraphicsContext, end: Date) {
        let cal = Calendar.current
        var ft = cal.dateInterval(of: .hour, for: now)?.start ?? now
        while ft <= end {
            if ft > now, [6, 18].contains(cal.component(.hour, from: ft)) {
                let label = Text(ft.formatted(.dateTime.hour())).font(.caption2.weight(.medium)).foregroundStyle(ink.opacity(0.4))
                // Beneath the strip, between the day names (midnight), which sit at axis + 26.
                ctx.draw(label, at: CGPoint(x: x(ft), y: axis + 26))
            }
            ft = cal.date(byAdding: .hour, value: 1, to: ft)!
        }
    }

    /// Nearest whole hour.
    static func hour(_ t: Date) -> Date {
        let cal = Calendar.current
        let floor = cal.dateInterval(of: .hour, for: t)?.start ?? t
        return t.timeIntervalSince(floor) >= 1800 ? floor.addingTimeInterval(3600) : floor
    }

    /// "Today, 12:21", "Yesterday, 9:08", "Tomorrow, 3:00 PM", "Mon, 9:00 AM": the same shape behind and
    /// ahead, the time the way the phone writes it.
    static func when(_ t: Date, now: Date) -> String {
        let cal = Calendar.current
        let h = t.formatted(.dateTime.hour().minute())
        let day = cal.isDateInToday(t) ? "Today" : cal.isDateInTomorrow(t) ? "Tomorrow" : cal.isDateInYesterday(t) ? "Yesterday"
            : abs(t.timeIntervalSince(now)) < 6 * 86400 ? t.formatted(.dateTime.weekday(.abbreviated)) : t.formatted(.dateTime.weekday(.abbreviated).day())
        return "\(day), \(h)"
    }

    private func relative(_ t: Date) -> String { Self.when(t, now: now) }

    private func go(to t: Date?) {
        focusTime = t
        withAnimation(.smooth(duration: 0.35)) { position.scrollTo(x: x(t ?? now)) }
    }
}
