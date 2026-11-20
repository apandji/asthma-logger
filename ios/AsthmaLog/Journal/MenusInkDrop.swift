import SwiftUI
import UIKit

/// Menus look (owner, Nov 19): the feedback when the felt button (or the watch) logs a moment while the app is
/// open. The timeline's own mark drops into the middle of the page, two soft rings spread from it like ink in
/// water, the words say what was logged, then the mark sinks towards the timeline where the moment now lives.
/// Two soft haptics: one as it lands, a lighter one with the ripple. With the app closed, the Quick Record
/// notification says it instead.
struct MenusInkDrop: View {
    let event: LogEvent
    /// Puffs in this use so far: past one, it says "Puff added".
    var puffs = 1
    /// Called once the drop has settled, to remove it.
    let done: () -> Void

    @State private var landed = false
    @State private var ripple = false
    @State private var words = false
    @State private var sink = false

    private var rescue: Bool { event.moment == .rescue }

    var body: some View {
        GeometryReader { g in
            let mid = CGPoint(x: g.size.width / 2, y: g.size.height * 0.42)
            ZStack {
                // A light veil of paper, so the drop reads over the flowers.
                Color(uiColor: .systemGroupedBackground).opacity(sink ? 0 : 0.72)
                    .ignoresSafeArea()
                // The rings: ink spreading in water.
                ForEach(0..<2, id: \.self) { i in
                    Circle()
                        .stroke(Color.primary.opacity(0.35), lineWidth: 1)
                        .frame(width: 30, height: 30)
                        .scaleEffect(ripple ? (i == 0 ? 4.2 : 2.6) : 0.6)
                        .opacity(ripple ? 0 : 0.9)
                        .animation(.easeOut(duration: 1.3).delay(Double(i) * 0.12), value: ripple)
                        .position(mid)
                }
                // The mark: rescue filled, standard an outline (the timeline's pill).
                Group {
                    if rescue { Capsule().fill(Color.primary) }
                    else { Capsule().strokeBorder(Color.primary, lineWidth: 2) }
                }
                .frame(width: 14, height: 32)
                .scaleEffect(landed ? (sink ? 0.55 : 1) : 0.4)
                .opacity(landed ? (sink ? 0 : 1) : 0)
                .position(x: mid.x, y: sink ? g.size.height * 0.86 : (landed ? mid.y : mid.y - 70))
                VStack(spacing: 3) {
                    Text(puffs > 1 ? "Puff added" : "Moment logged").font(Theme.Figtree.font(size: 19, weight: .medium))
                    Text("\(rescue ? "Rescue" : "Standard") · \(event.loggedAt.formatted(date: .omitted, time: .shortened))\(puffs > 1 ? " · \(puffs) puffs" : "")")
                        .font(Theme.Figtree.font(size: 14)).foregroundStyle(.secondary)
                }
                .opacity(words && !sink ? 1 : 0)
                .offset(y: words ? 0 : 6)
                .position(x: mid.x, y: mid.y + 62)
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("Moment logged, \(rescue ? "rescue" : "standard"), \(event.loggedAt.formatted(date: .omitted, time: .shortened))")
        .task { await play() }
    }

    private func play() async {
        let soft = UIImpactFeedbackGenerator(style: .soft)
        soft.prepare()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) { landed = true }
        try? await Task.sleep(for: .milliseconds(260))
        soft.impactOccurred(intensity: 0.75)          // it lands
        ripple = true
        withAnimation(.easeOut(duration: 0.4).delay(0.1)) { words = true }
        try? await Task.sleep(for: .milliseconds(160))
        soft.impactOccurred(intensity: 0.35)          // the ripple
        try? await Task.sleep(for: .milliseconds(1500))
        withAnimation(.easeIn(duration: 0.55)) { sink = true }
        try? await Task.sleep(for: .milliseconds(600))
        done()
    }
}
