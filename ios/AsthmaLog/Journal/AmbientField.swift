import AsthmaCore
import SwiftUI

/// Today's outdoor conditions as a soft, slowly drifting colour field behind frosted glass, like the
/// Apple Card's spending hues. One hue per factor (the weave inks); each grows stronger with its level.
/// Purely atmospheric: the numbers live in the cards. Static with Reduce Motion; plain with Reduce Transparency.
struct AmbientField: View {
    let weave: WeaveSpec
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if reduceTransparency {
            Theme.stage
        } else if reduceMotion {
            field(t: 0)
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                field(t: context.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func field(t: Double) -> some View {
        let base = Theme.stage
        // Gentle drift of the inner points, a slow breathing.
        func d(_ phase: Double, _ amp: Float = 0.06) -> Float { Float(sin(t / 7 + phase)) * amp }
        let points: [SIMD2<Float>] = [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.45 + d(1)], [0.5 + d(2), 0.4 + d(3)], [1, 0.5 + d(4)],
            [0, 1], [0.5, 1], [1, 1],
        ]
        let colors: [Color] = [
            hue(.air), hue(.humidity), hue(.temperature),
            hue(.humidity, 0.8), hue(.pollen, 0.9, fallback: hue(.air, 0.6)), hue(.air, 0.8),
            base, base, base,
        ]
        return MeshGradient(width: 3, height: 3, points: points, colors: colors, background: base)
            .overlay(base.opacity(scheme == .dark ? 0.25 : 0.1))
            .accessibilityHidden(true)
    }

    /// The factor's ink at a strength set by its level; a quiet neutral when there's no reading.
    private func hue(_ f: WeaveSpec.Factor, _ scale: Double = 1, fallback: Color? = nil) -> Color {
        guard let level = weave.levels[f] else { return fallback ?? Theme.stage }
        let strength = [0.32, 0.55, 0.85][level.rawValue] * scale
        return WeaveSwatch.ink(f).opacity(strength)
    }
}

extension View {
    /// Frosted glass card over the ambient field: dark-tinted material in dark mode, light material in light.
    func frostedCard(cornerRadius: CGFloat = 22) -> some View {
        modifier(FrostedCard(cornerRadius: cornerRadius))
    }
}

private struct FrostedCard: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(Color.black.opacity(scheme == .dark ? 0.35 : 0), in: shape)
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.strokeBorder(.white.opacity(scheme == .dark ? 0.08 : 0.4), lineWidth: 0.5))
    }
}
