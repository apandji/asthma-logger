import AsthmaCore
import SwiftUI

/// A moment's outdoor conditions as overprinted density weaves: one ink per factor, sparse dots (low),
/// checker (medium) or fine weave (high), each at its own angle so layers stay distinct without colour.
/// Overlap darkens on light paper (multiply) and glows on night (screen). Spec: docs/design/textile-direction.md.
struct WeaveSwatch: View {
    let weave: WeaveSpec
    var cornerRadius: CGFloat = 22
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Canvas { ctx, size in
            let rect = CGRect(origin: .zero, size: size)
            let shape = Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
            ctx.clip(to: shape)
            ctx.fill(shape, with: .color(Theme.card))
            ctx.blendMode = scheme == .dark ? .screen : .multiply
            for factor in WeaveSpec.Factor.allCases {
                guard let level = weave.levels[factor] else { continue }
                ctx.fill(Self.weavePath(level: level, factor: factor, in: size), with: .color(Self.ink(factor).opacity(0.92)))
            }
        }
        .accessibilityElement()
        .accessibilityLabel(weave.isEmpty ? "No outdoor readings" : weave.summary)
    }

    static func ink(_ f: WeaveSpec.Factor) -> Color {
        switch f {
        case .air: Theme.weaveAir
        case .humidity: Theme.weaveHumidity
        case .temperature: Theme.weaveTemperature
        case .pollen: Theme.weavePollen
        }
    }

    private static func angle(_ f: WeaveSpec.Factor) -> Double {
        switch f { case .air: 0; case .humidity: 45; case .temperature: 22.5; case .pollen: 67.5 }
    }

    /// All the squares for one factor in a single path, rotated about the centre.
    static func weavePath(level: WeaveSpec.Level, factor: WeaveSpec.Factor, in size: CGSize) -> Path {
        let cell: CGFloat = [10, 7, 4.8][level.rawValue]
        let sq: CGFloat = level == .low ? 2.6 : cell / 2
        let extent = max(size.width, size.height) * 1.5
        let offset = CGFloat(WeaveSpec.Factor.allCases.firstIndex(of: factor) ?? 0) * 0.9
        var path = Path()
        var y = -extent / 2
        while y < extent / 2 {
            var x = -extent / 2
            while x < extent / 2 {
                path.addRect(CGRect(x: x + offset, y: y + offset, width: sq, height: sq))
                if level != .low { path.addRect(CGRect(x: x + cell / 2 + offset, y: y + cell / 2 + offset, width: sq, height: sq)) }
                if level == .high { path.addRect(CGRect(x: x + cell / 2 + offset, y: y + offset, width: sq * 0.55, height: sq * 0.55)) }
                x += cell
            }
            y += cell
        }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let t = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: angle(factor) * .pi / 180)
        return path.applying(t)
    }
}

extension LogEvent {
    /// The weave for this moment, or empty when no outdoor value was stamped.
    var weave: WeaveSpec {
        guard let c = conditions else { return WeaveSpec() }
        return WeaveSpec(c.input)
    }
}
