import SwiftUI

/// A slow sheen across text that's waiting ("Checking the air near you…"), like Apple's loading labels.
/// Off with Reduce Motion.
struct Shimmer: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if active && !reduceMotion {
            content
                .overlay {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
                        let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.2) / 2.2
                        LinearGradient(stops: [.init(color: .clear, location: 0),
                                               .init(color: .white.opacity(0.55), location: 0.5),
                                               .init(color: .clear, location: 1)],
                                       startPoint: UnitPoint(x: -0.6 + 2.2 * t, y: 0.5),
                                       endPoint: UnitPoint(x: 0.2 + 2.2 * t, y: 0.5))
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                }
        } else {
            content
        }
    }
}

extension View {
    func shimmer(_ active: Bool) -> some View { modifier(Shimmer(active: active)) }
}
