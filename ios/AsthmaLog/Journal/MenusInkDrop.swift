import SwiftUI
import UIKit

/// Menus look (owner, Nov 19): the feedback when the felt button (or the watch) logs a moment while the app is
/// open. The timeline's own mark falls into the page like a drop with weight (slow at first, quicker as it
/// falls), gives a little on landing, and the ink spreads from it as a soft wash, not rings (owner, Nov 20:
/// less linear, gradient not lines). The words rise in after it; then everything settles out of view together.
/// Two soft haptics: one as it lands, a lighter one as the wash spreads. With the app closed, the Quick Record
/// notification says it instead.
struct MenusInkDrop: View {
    let event: LogEvent
    /// Puffs in this use so far: past one, it says "Puff added".
    var puffs = 1
    /// Called once the drop has settled, to remove it.
    let done: () -> Void

    /// Where the mark is: 0 above, 1 landed.
    @State private var fall: CGFloat = 0
    /// The squash on landing: 0 at rest, 1 flattest.
    @State private var squash: CGFloat = 0
    /// The wash: 0 a point, 1 spread and faded.
    @State private var spread: CGFloat = 0
    @State private var words = false
    @State private var leaving = false

    private var rescue: Bool { event.moment == .rescue }

    var body: some View {
        GeometryReader { g in
            let mid = CGPoint(x: g.size.width / 2, y: g.size.height * 0.42)
            ZStack {
                // A light veil of paper, so the drop reads over the flowers.
                Color(uiColor: .systemGroupedBackground).opacity(leaving ? 0 : 0.72)
                    .ignoresSafeArea()
                // The wash: ink spreading in water, deepest where it landed and fading to nothing at the edge.
                // Two of them, the second wider and fainter, a beat later.
                ForEach(0..<2, id: \.self) { i in
                    Circle()
                        .fill(RadialGradient(colors: [Color.primary.opacity(i == 0 ? 0.24 : 0.12), Color.primary.opacity(i == 0 ? 0.09 : 0.05), .clear],
                                             center: .center, startRadius: 0, endRadius: 80))
                        .frame(width: 160, height: 160)
                        .scaleEffect(0.15 + spread * (i == 0 ? 1.5 : 2.4))
                        .opacity(Double(1 - spread) * (spread > 0 ? 1 : 0))
                        .blur(radius: 6 + spread * 10)
                        .animation(.timingCurve(0.16, 1, 0.3, 1, duration: i == 0 ? 1.4 : 1.8).delay(Double(i) * 0.12), value: spread)
                        .position(mid)
                }
                // The mark: rescue filled, standard an outline (the timeline's pill). Squashes from its bottom.
                Group {
                    if rescue { Capsule().fill(Color.primary) }
                    else { Capsule().strokeBorder(Color.primary, lineWidth: 2) }
                }
                .frame(width: 14, height: 32)
                .scaleEffect(x: 1 + 0.22 * squash, y: 1 - 0.2 * squash, anchor: .bottom)
                .scaleEffect(leaving ? 0.7 : 1)
                .opacity(leaving ? 0 : min(1, fall * 3))
                .blur(radius: leaving ? 4 : 0)
                .position(x: mid.x, y: mid.y - 120 * (1 - fall) + (leaving ? 10 : 0))
                VStack(spacing: 3) {
                    Text(puffs > 1 ? "Puff added" : "Moment logged").font(Theme.Figtree.font(size: 19, weight: .medium))
                    Text("\(rescue ? "Inhaler" : "Standard") · \(event.loggedAt.formatted(date: .omitted, time: .shortened))\(puffs > 1 ? " · \(puffs) puffs" : "")")
                        .font(Theme.Figtree.font(size: 14)).foregroundStyle(.secondary)
                }
                .opacity(words && !leaving ? 1 : 0)
                .offset(y: words ? 0 : 10)
                .blur(radius: words && !leaving ? 0 : 3)
                .position(x: mid.x, y: mid.y + 62)
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("\(puffs > 1 ? "Puff added" : "Moment logged"), \(rescue ? "inhaler" : "standard"), \(event.loggedAt.formatted(date: .omitted, time: .shortened))")
        .task { await play() }
    }

    private func play() async {
        let soft = UIImpactFeedbackGenerator(style: .soft)
        soft.prepare()
        // The fall: eases in like something with weight, quickest at the bottom.
        withAnimation(.timingCurve(0.5, 0, 0.9, 0.45, duration: 0.42)) { fall = 1 }
        try? await Task.sleep(for: .milliseconds(420))
        soft.impactOccurred(intensity: 0.75)          // it lands
        // It gives on landing and springs back, a small settle rather than a bounce.
        withAnimation(.spring(response: 0.12, dampingFraction: 0.9)) { squash = 1 }
        spread = 1
        try? await Task.sleep(for: .milliseconds(110))
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { squash = 0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { words = true }
        try? await Task.sleep(for: .milliseconds(140))
        soft.impactOccurred(intensity: 0.35)          // the wash spreads
        try? await Task.sleep(for: .milliseconds(1700))
        // Out together: a soft fade with a little blur, no slide down the page.
        withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.6)) { leaving = true }
        try? await Task.sleep(for: .milliseconds(650))
        done()
    }
}
