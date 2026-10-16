import AsthmaCore
import SwiftUI

/// One track for past and future. Your moments sit on the axis behind the playhead; ahead of it the
/// forecast hours run on as a faint strip of sky color. The playhead reads a *time*, so you can scrub
/// into this evening or tomorrow, and it snaps to a moment when one is close.
struct NowTimeline: View {
    let moments: [LogEvent]
    let hours: [NowHour]
    /// The clock, passed in so the track creeps forward while you watch.
    let now: Date
    /// Nil is now.
    @Binding var focusTime: Date?

    @State private var position = ScrollPosition(edge: .trailing)
    @State private var centerX: CGFloat = 0
    @State private var viewport: CGFloat = 0
    @State private var dragging = false

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
                    Canvas { ctx, size in
                        // The forecast: a strip of sky color per hour, ahead of now.
                        for h in hours {
                            let t = h.conditions.best(.temperature)?.value
                            var c = WeatherColor.light(WeatherColor.temperature(t ?? 65), at: h.date)
                            if let rh = h.conditions.best(.humidity)?.value, rh > 70 { c = c.opacity(0.9) }
                            let rect = CGRect(x: x(h.date), y: axis - 5, width: dayWidth / 24 + 0.5, height: 10)
                            ctx.fill(Path(rect), with: .color(c.opacity(0.55)))
                        }
                        // Axis.
                        var line = Path()
                        line.move(to: CGPoint(x: 0, y: axis)); line.addLine(to: CGPoint(x: x(now), y: axis))
                        ctx.stroke(line, with: .color(.white.opacity(0.12)), lineWidth: 1)
                        // Now: a short bright tick.
                        var nowTick = Path()
                        nowTick.move(to: CGPoint(x: x(now), y: axis - 12)); nowTick.addLine(to: CGPoint(x: x(now), y: axis + 12))
                        ctx.stroke(nowTick, with: .color(.white.opacity(0.6)), lineWidth: 1.5)
                        // Ticks every 6 h, day names beneath.
                        var t = start
                        while t <= end {
                            let isDay = cal.component(.hour, from: t) == 0
                            let half: CGFloat = isDay ? 10 : 4
                            var p = Path()
                            p.move(to: CGPoint(x: x(t), y: axis - half)); p.addLine(to: CGPoint(x: x(t), y: axis + half))
                            ctx.stroke(p, with: .color(.white.opacity(isDay ? 0.4 : 0.18)), lineWidth: 1)
                            if isDay {
                                let label = cal.isDateInToday(t) ? "Today" : cal.isDateInTomorrow(t) ? "Tomorrow"
                                    : t.formatted(.dateTime.weekday(.abbreviated).day())
                                ctx.draw(Text(label).font(.caption2).foregroundStyle(.white.opacity(t > now ? 0.3 : 0.45)),
                                         at: CGPoint(x: x(t) + dayWidth / 2, y: axis + 26))
                            }
                            t = cal.date(byAdding: .hour, value: 6, to: t)!
                        }
                    }
                    .frame(width: contentWidth, height: height)

                    ForEach(moments) { e in
                        let on = e.id == currentMoment?.id
                        MomentSwatch(event: e, size: on ? 16 : 11, ringWidth: on ? 2.5 : 1.8)
                            .background {
                                if on {
                                    Circle().fill(.white).frame(width: 22, height: 22)
                                        .shadow(color: (e.moment == .rescue ? Theme.rescue : Theme.standard).opacity(0.8), radius: 8)
                                }
                            }
                            .position(x: x(e.loggedAt), y: axis)
                            .animation(.snappy(duration: 0.2), value: on)
                            .onTapGesture { go(to: e.loggedAt) }
                    }
                }
                .frame(width: contentWidth, height: height)
                Color.clear.frame(width: viewport / 2)
            }
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGFloat.self) { $0.containerSize.width } action: { _, w in viewport = w }
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
            // Settle on a moment if one is near the playhead, else exactly on now if near it.
            if phase == .idle, old == .interacting || old == .decelerating {
                if let m = moments.min(by: { abs(x($0.loggedAt) - centerX) < abs(x($1.loggedAt) - centerX) }),
                   abs(x(m.loggedAt) - centerX) < 10 { go(to: m.loggedAt) }
                else if abs(x(now) - centerX) < 10 || time(at: centerX) < now { go(to: focusTime) }
            }
        }
        .overlay(alignment: .top) {
            ZStack(alignment: .top) {
                Capsule().fill(.white).frame(width: 3, height: 34)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .offset(y: axis - 17)
                    .allowsHitTesting(false)
                // The pill is a button: tap it to step back through your moments, newest first.
                Button(action: stepBack) {
                    Text(focusTime == nil ? "Now" : current.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(.white, in: Capsule())
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.2), value: focusTime == nil)
                        .fixedSize()
                }
                .buttonStyle(.plain)
                .offset(y: axis - 17 - 30)
                .accessibilityLabel("Previous moment")
            }
            .frame(maxWidth: .infinity)
        }
        // Off now: a way straight back, at the right end of the track.
        .overlay(alignment: .topTrailing) {
            if focusTime != nil {
                Button { go(to: nil) } label: {
                    Label("Now", systemImage: "arrow.uturn.forward")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
                .offset(y: axis - 17 - 30)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.25), value: focusTime == nil)
        .padding(.top, 24)
        .sensoryFeedback(.selection, trigger: currentMoment?.id)
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

    private func go(to t: Date?) {
        focusTime = t
        withAnimation(.smooth(duration: 0.35)) { position.scrollTo(x: x(t ?? now)) }
    }
}
