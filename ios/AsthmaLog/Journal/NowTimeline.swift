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
    /// The verdict in words for a forecast hour ("A bit like your flare days"): the chip grows to say it.
    /// A label, not a button (Insights has its own).
    var verdictText: String? = nil
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
    /// Ahead of now the track is this many times wider (16 pt an hour): the forecast is read hour by hour,
    /// and at the past's scale an hour was under 3 pt, too fine to land on (owner, Oct 18).
    private let aheadScale: CGFloat = 6
    private let axis: CGFloat = 46
    private let hourTick = UISelectionFeedbackGenerator()
    private let momentTap = UIImpactFeedbackGenerator(style: .medium)
    private let nowThud = UIImpactFeedbackGenerator(style: .heavy)

    /// Where the track can rest (offset space): each moment behind now, now itself, each hour ahead.
    private var stops: [CGFloat] {
        var s = moments.filter { $0.loggedAt < now }.map { x($0.loggedAt) }
        s.append(x(now))
        var h = Calendar.current.dateInterval(of: .hour, for: now)?.start.addingTimeInterval(3600) ?? now
        if h.timeIntervalSince(now) < 20 * 60 { h = h.addingTimeInterval(3600) }   // too close to now to be its own stop
        while h <= end { s.append(x(h)); h = h.addingTimeInterval(3600) }
        return s.sorted()
    }
    private let height: CGFloat = 86
    private let cal = Calendar.current

    private var start: Date {
        cal.startOfDay(for: min(moments.first?.loggedAt ?? now, cal.date(byAdding: .day, value: -3, to: now)!))
    }
    private var end: Date { cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: now))! }
    private var contentWidth: CGFloat { x(end) }
    /// Behind now: a day is `dayWidth`. Ahead: `aheadScale` times that.
    private func x(_ d: Date) -> CGFloat {
        let n = CGFloat(now.timeIntervalSince(start) / 86_400) * dayWidth
        guard d > now else { return CGFloat(d.timeIntervalSince(start) / 86_400) * dayWidth }
        return n + CGFloat(d.timeIntervalSince(now) / 86_400) * dayWidth * aheadScale
    }
    private func time(at x: CGFloat) -> Date {
        let n = CGFloat(now.timeIntervalSince(start) / 86_400) * dayWidth
        guard x > n else { return start.addingTimeInterval(Double(x / dayWidth) * 86_400) }
        return now.addingTimeInterval(Double((x - n) / (dayWidth * aheadScale)) * 86_400)
    }
    private var current: Date { (dragging ? shown : focusTime) ?? now }
    /// What the chip shows while dragging (every frame); `focusTime` lags it on purpose (see the scroll handler).
    @State private var shown: Date?
    @State private var focusKey: Double?
    private var currentMoment: LogEvent? {
        moments.first { abs($0.loggedAt.timeIntervalSince(current)) < 20 * 60 }
    }

    var body: some View {
        ScrollView(.horizontal) { track }
        // The track settles on a stop, never between: your moments behind, now, and the hours ahead.
        .scrollTargetBehavior(StopSnap(stops: stops, now: x(now)))
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        // Only for the first scroll to the current time: the track's own layout never reads it.
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { viewport = $0 }
        // Pulled past the forecast's end (the bounce): open Insights, once per drag.
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x - ($0.contentSize.width - $0.containerSize.width) } action: { _, over in
            if over > 56, dragging, pastEndArmed { pastEndArmed = false; UIImpactFeedbackGenerator(style: .medium).impactOccurred(); onPastEnd() }
            if over < 8 { pastEndArmed = true }
        }
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x } action: { _, cx in scrolled(to: cx) }
        .onScrollPhaseChange { old, phase in phaseChanged(from: old, to: phase) }
        .overlay(alignment: .top) { playhead }
        .animation(Theme.snap, value: focusTime == nil)
        .padding(.top, 24)
        .sensoryFeedback(.selection, trigger: currentMoment?.id)
        // Ahead, a tick per hour: the forecast's grain under the thumb. A generator kept warm for the whole
        // drag, and fired directly: `.sensoryFeedback` drops ticks that come fast, and the thumb crosses hours fast.
        .onChange(of: dragging) { _, d in if d { hourTick.prepare(); momentTap.prepare(); nowThud.prepare() } }
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

    /// Every frame of a drag: the chip follows the thumb from local state (cheap, so it never waits on the
    /// home); the home only hears about it when what it would show changes (a moment, an hour ahead, a few
    /// minutes behind), since per pixel would stall the chip behind the heavy re-render.
    private func scrolled(to cx: CGFloat) {
        centerX = cx
        guard dragging else { return }
        let t = time(at: cx)
        let next: Date?
        if abs(t.timeIntervalSince(now)) < 10 * 60 { next = nil }
        else if t < now {
            // Behind now the playhead moves moment to moment, never in between: the nearest one reads.
            next = moments.filter { $0.loggedAt < now }.min(by: { abs($0.loggedAt.timeIntervalSince(t)) < abs($1.loggedAt.timeIntervalSince(t)) })?.loggedAt
        } else {
            next = Self.hour(t)   // ahead, the forecast is hourly
        }
        if next != shown {
            // Three weights: landing on now is the heaviest, a moment behind is firm, an hour ahead is a tick.
            if next == nil { nowThud.impactOccurred(intensity: 1); nowThud.prepare() }
            else if next! < now { momentTap.impactOccurred(intensity: 0.8); momentTap.prepare() }
            else if shown != nil, shown! > now { hourTick.selectionChanged(); hourTick.prepare() }
            else { hourTick.selectionChanged(); hourTick.prepare() }
        }
        shown = next
        let key: Double? = next.map { $0.timeIntervalSince1970 }
        if key != focusKey { focusKey = key; focusTime = next }
    }

    /// Lifted: settle on a moment if one is near the playhead, else exactly on now if near it.
    private func phaseChanged(from old: ScrollPhase, to phase: ScrollPhase) {
        dragging = phase == .interacting || phase == .decelerating
        scrubbing = dragging
        guard phase == .idle, old == .interacting || old == .decelerating else { return }
        // Settled by StopSnap on a stop: read it.
        let t = time(at: centerX)
        if abs(x(now) - centerX) < 3 { go(to: nil) }
        else if t < now { go(to: moments.min(by: { abs(x($0.loggedAt) - centerX) < abs(x($1.loggedAt) - centerX) })?.loggedAt) }
        else { go(to: Self.hour(t)) }
        shown = focusTime
    }

    /// The scrolling content: half a viewport of room, the drawn track with tap targets, half a viewport more.
    private var track: some View {
        HStack(spacing: 0) {
            // Half a viewport, sized by the container itself (not from state written during layout).
            Color.clear.containerRelativeFrame(.horizontal) { w, _ in w / 2 }
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
            Color.clear.containerRelativeFrame(.horizontal) { w, _ in w / 2 }
                .overlay(alignment: .leading) {
                    Image(systemName: "sparkles").font(.caption).foregroundStyle(ink.opacity(0.35))
                        .padding(.leading, 22).offset(y: axis - height / 2)
                }
        }
    }

    /// The line and the chip over the centre of the track. The chip is the way back (one control, like
    /// Calendar's Today): away from now it carries a return arrow and a tap jumps to Now; on Now it's a label.
    private var playhead: some View {
        ZStack(alignment: .top) {
            Capsule().fill(verdictTint ?? ink).frame(width: 2, height: 30)
                .offset(y: axis - 15)
                .allowsHitTesting(false)
            Button(action: { go(to: nil) }) { chipLabel }
                .buttonStyle(PressStyle())
                .offset(y: axis - 23 - 52)
                .disabled(focusTime == nil)
                .accessibilityLabel(focusTime == nil ? "Now" : "Back to now")
        }
        .frame(maxWidth: .infinity)
    }

    /// The chip's face: the time, a return arrow when away from now, the verdict's colour under the playhead.
    /// With a verdict (now and ahead) it's two bubbles coming together: the verdict on top, the time tucked
    /// under it in the same colour, so the pair reads as one shape and stays short.
    private var chipLabel: some View {
        let ahead = focusTime != nil && current > now
        let behind = focusTime != nil && current < now
        let fill: Color = verdictTint ?? ink
        let text: Color = verdictTint != nil ? .black : (scheme == .light ? Theme.linen : .black)
        let verdict = (ahead || focusTime == nil) ? verdictText : nil
        let time = HStack(spacing: 5) {
            if ahead { Image(systemName: "arrow.uturn.backward").font(.caption2.weight(.bold)) }
            Text(focusTime == nil ? Self.when(now, now: now) : relative(current))
            if behind { Image(systemName: "arrow.uturn.forward").font(.caption2.weight(.bold)) }
        }
        return VStack(spacing: 1) {
            if let verdict {
                Text(verdict).font(.caption.weight(.semibold)).lineLimit(1)
                    .transition(.opacity)
            }
            time
                .font((verdict == nil ? Font.caption : .caption2).weight(verdict == nil ? .semibold : .medium).monospacedDigit())
                .opacity(verdict == nil ? 1 : 0.75)
        }
        .padding(.horizontal, verdict == nil ? 10 : 12)
        .padding(.top, verdict == nil ? 4 : 6)
        .padding(.bottom, verdict == nil ? 4 : 6 + Callout.pointer)
        // One callout: a rounded rectangle with a small pointer down into the playhead line (with a verdict),
        // or the time's capsule alone. Ahead it's a sketch, a dashed edge, so it never reads as a record.
        .background {
            let shape = Callout(pointed: verdict != nil)
            shape.fill(fill)
                .overlay { if ahead { shape.stroke(Color.black.opacity(0.35), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])) } }
        }
        .tracking(0.2)
        .foregroundStyle(text)
        .animation(Theme.smooth, value: verdictTint)
        .animation(Theme.smooth, value: verdict)
        .transaction { if dragging { $0.animation = nil } }   // while scrubbing the chip just changes, no roll
        .animation(Theme.snap, value: focusTime == nil)
        .fixedSize()
        .frame(minWidth: 40)
        // A small settle each time the playhead lands on a moment.
        .scaleEffect(settle ? 1.07 : 1, anchor: .bottom)
        .animation(Theme.snap, value: settle)
        // Grows upward: the bottom stays on the line.
        .frame(height: 52, alignment: .bottom)
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
            // Four thin bars per hour (the hour is wide now), one colour per hour: the texture of the past's
            // scale, the hour still reading as one slot.
            let slot = dayWidth * aheadScale / 24
            let far = min(1, date.timeIntervalSince(now) / (48 * 3600))
            let tint: Color = Self.verdictColor(v, ink: ink)
            let base: Double = v == nil ? 0.1 : 0.7
            for k in 0..<4 {
                // Each bar breathes on its own phase, more the further out it is: not yet known.
                let wave: Double = sin(flux * 1.6 + Double(n * 4 + k) * 0.55)
                let h: CGFloat = 8 + CGFloat((2 + 4 * far) * wave)
                let alpha: Double = base * (0.8 + 0.2 * (0.5 + 0.5 * wave))
                let rect = CGRect(x: x(date) + CGFloat(k) * slot / 4, y: axis - h / 2, width: max(1, slot / 4 - 1.4), height: h)
                ctx.fill(Path(rect), with: .color(tint.opacity(alpha)))
            }
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
                         at: CGPoint(x: (x(t) + x(t.addingTimeInterval(86_400))) / 2, y: axis + 26))
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
            // Not within the playhead's width of now: the line would run through the label.
            if ft > now, abs(x(ft) - x(now)) > 14, [6, 18].contains(cal.component(.hour, from: ft)) {
                let label = Text(ft.formatted(.dateTime.hour())).font(.caption2.weight(.medium)).foregroundStyle(ink.opacity(0.4))
                // Just above the strip (the day names are beneath it, and the chip sits higher still).
                ctx.draw(label, at: CGPoint(x: x(ft), y: axis - 16))
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

/// The playhead chip's outline. Pointed: a rounded rectangle with a small pointer at the bottom centre, aiming
/// into the playhead line (the label belongs to that point in time). Not pointed: a capsule.
nonisolated private struct Callout: Shape {
    static let pointer: CGFloat = 5
    var pointed: Bool

    func path(in rect: CGRect) -> Path {
        guard pointed else { return Path(roundedRect: rect, cornerRadius: rect.height / 2) }
        let body = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - Self.pointer)
        var p = Path(roundedRect: body, cornerRadius: 12, style: .continuous)
        p.move(to: CGPoint(x: rect.midX - 6, y: body.maxY - 0.5))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX + 6, y: body.maxY - 0.5))
        p.closeSubpath()
        return Path(p.cgPath.union(Path(roundedRect: body, cornerRadius: 12, style: .continuous).cgPath))
    }
}

private extension Double {
    func rounded(toMultipleOf m: Double) -> Double { (self / m).rounded() * m }
}

/// Settles the track on the nearest stop: a moment behind now, now, or an hour ahead. Flicks carry to the
/// stop the scroll would have reached, not past it.
private struct StopSnap: ScrollTargetBehavior {
    let stops: [CGFloat]
    let now: CGFloat
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard !stops.isEmpty else { return }
        let x = target.rect.origin.x
        // Now only when you leave it right there. Moved off it, it never pulls you back (owner, Oct 18:
        // "I can't even stay on +1 h"): ahead lands on the nearest hour, behind on the nearest moment.
        if abs(x - now) < 3 { target.rect.origin.x = now; return }
        let side = stops.filter { x > now ? $0 > now + 3 : $0 < now - 3 }
        if let nearest = side.min(by: { abs($0 - x) < abs($1 - x) }) { target.rect.origin.x = nearest }
        else { target.rect.origin.x = now }
    }
}
