import SwiftUI

/// The first-run tutorial's spotlight: while a tip is showing, everything except what it's about dims.
/// Views mark themselves with `.spotlightTarget("plus")`; the Journal draws the dim with those frames cut out.
@Observable
final class SpotlightFrames {
    var frames: [String: CGRect] = [:]
}

extension View {
    func spotlightTarget(_ id: String, _ store: SpotlightFrames) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { store.frames[id] = $0 }
    }
}

/// A dark veil over the whole screen with soft rounded holes where the targets are.
struct SpotlightDim: View {
    let holes: [CGRect]

    var body: some View {
        Canvas { ctx, size in
            var veil = Path(CGRect(origin: .zero, size: size))
            for r in holes where r.width > 0 {
                let hole = r.insetBy(dx: -10, dy: -10)
                veil.addPath(Path(roundedRect: hole, cornerRadius: min(28, hole.height / 2)))
            }
            ctx.fill(veil, with: .color(.black.opacity(0.62)), style: FillStyle(eoFill: true))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .transition(.opacity)
    }
}
