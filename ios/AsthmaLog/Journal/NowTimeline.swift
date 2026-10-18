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
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                Color.clear.frame(width: viewport / 2)
                ZStack(alignment: .topLeading) {
                    // The forecast hasn't settled: its slots drift. The past is still.
                    TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion || forecastTints.isEmpty)) { frame in
                    let flux = reduceMotion ? 0 : frame.date.timeIntervalSinceReferenceDate
                    Canvas { ctx, size in
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
                        // The forecast: one slot per hour, the same ink at three strengths (light, a bit like,
                        // matches your flare days). While still learning it's a faint band, so the day's shape shows.
                        for (n, (date, v)) in forecastTints.enumerated() where date >= now {
                            let w = dayWidth / 24 + 0.5
                            // Each hour breathes on its own phase, more the further out it is: not yet known.
                            let far = min(1, date.timeIntervalSince(now) / (48 * 3600))
                            let wave = sin(flux * 1.6 + Double(n) * 0.55)
                            let h = 8 + CGFloat((2 + 4 * far) * wave)
                            let base = v.map { 0.18 + 0.62 * $0 } ?? 0.1
                            let rect = CGRect(x: x(date), y: axis - h / 2, width: w, height: h)
                            ctx.fill(Path(rect), with: .color(ink.opacity(base * (0.8 + 0.2 * (0.5 + 0.5 * wave)))))
                        }
                        // Moments: a tick per moment in the colour of the air that day. Rescue stands taller than
                        // standard, so the kind reads in the shape and the comfort in the colour.
                        for e in moments {
                            let on = e.id == currentMoment?.id
                            // Notes (no inhaler) are short and quiet.
                            let tall: CGFloat = e.moment == .rescue ? 11 : e.moment == .note ? 4 : 7
                            let c = ink.opacity(e.moment == .note ? 0.4 : (tint(e).map { 0.3 + 0.7 * $0 } ?? 0.25))
                            let rect = CGRect(x: x(e.loggedAt) - 1.5, y: axis - tall, width: 3, height: 2 * tall)
                            ctx.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(on ? c : c.opacity(0.85)))
                            // A rescue with nothing said yet: a small hollow ring above it, filled once noted.
                            if e.wantsNote {
                                ctx.stroke(Path(ellipseIn: CGRect(x: x(e.loggedAt) - 3, y: axis - tall - 10, width: 6, height: 6)),
                                           with: .color(Theme.rescueSoft.opacity(0.9)), lineWidth: 1.2)
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
                    .frame(width: contentWidth, height: height)
                    }

                    // Tap targets for the ticks (the marks themselves are drawn above).
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
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(ink.opacity(0.35))
                            .padding(.leading, 22)
                            .offset(y: axis - height / 2)
                    }
            }
        }
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
                // Behind now there's nothing between moments, so the playhead reads the nearest one.
                focusTime = moments.min { abs($0.loggedAt.timeIntervalSince(t)) < abs($1.loggedAt.timeIntervalSince(t)) }?.loggedAt
            } else { focusTime = t }
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
                Capsule().fill(ink).frame(width: 2, height: 30)
                    .offset(y: axis - 15)
                    .allowsHitTesting(false)
                // The pill is a button: tap it to step back through your moments, newest first.
                // Off now, the pill is the way back: it shows how far you are and a return arrow; tap to jump to
                // Now. On Now, a tap steps back to your latest moment.
                Button(action: { focusTime == nil ? stepBack() : go(to: nil) }) {
                    HStack(spacing: 5) {
                        if focusTime != nil, current > now { Image(systemName: "arrow.uturn.backward").font(.caption2.weight(.bold)) }
                        Text(focusTime == nil ? "Now" : relative(current))
                        if focusTime != nil, current < now { Image(systemName: "arrow.uturn.forward").font(.caption2.weight(.bold)) }
                    }
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .tracking(0.2)
                        .foregroundStyle(scheme == .light ? Theme.linen : Color.black)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(ink, in: Capsule())
                        .contentTransition(.numericText())
                        .animation(Theme.snap, value: focusTime == nil)
                        .fixedSize()
                        // A small settle each time the playhead lands on a moment.
                        .scaleEffect(settle ? 1.07 : 1)
                        .animation(Theme.snap, value: settle)
                }
                .buttonStyle(PressStyle())
                .offset(y: axis - 17 - 30)
                .accessibilityLabel(focusTime == nil ? "Previous moment" : "Back to now")
            }
            .frame(maxWidth: .infinity)
        }
        .animation(Theme.snap, value: focusTime == nil)
        .padding(.top, 24)
        .sensoryFeedback(.selection, trigger: currentMoment?.id)
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

    /// From now, the newest moment; from a moment, the one before it. From the forecast, the newest moment.
    private func stepBack() {
        let past = moments.filter { $0.loggedAt < current - 60 }
        guard let target = past.last else { return }
        go(to: target.loggedAt)
    }

    /// "+4h", "−6h", "+40m"; past two days, the day: "Wed 14".
    private func relative(_ t: Date) -> String {
        let s = t.timeIntervalSince(now)
        let sign = s >= 0 ? "+" : "−"
        let a = abs(s)
        if a < 3600 { return "\(sign)\(max(1, Int((a / 60).rounded())))m" }
        if a < 48 * 3600 { return "\(sign)\(Int((a / 3600).rounded()))h" }
        return t.formatted(.dateTime.weekday(.abbreviated).day())
    }

    private func go(to t: Date?) {
        focusTime = t
        withAnimation(.smooth(duration: 0.35)) { position.scrollTo(x: x(t ?? now)) }
    }
}
