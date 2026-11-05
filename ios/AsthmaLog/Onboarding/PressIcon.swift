import SwiftUI

/// A line icon for "press": a short button in slight perspective (top ellipse, two sides, rim), stroked only,
/// with SF's `arrow.down` above it. No SF Symbol fits (`button.horizontal.top.press` is a device's side button).
/// Animated: the arrow comes down, the top sinks toward the rim, both spring back, a pause, again.
/// Reduce Motion: still. Strokes in the text colour, at SF's regular line weight for its size.
struct PressIcon: View {
    var size: CGFloat = 28
    var animated = true

    @State private var pressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let line = max(1.2, size * 0.075)
        VStack(spacing: size * 0.04) {
            Image(systemName: "arrow.down")
                .font(.system(size: size * 0.42, weight: .regular))
                .offset(y: pressed ? size * 0.14 : 0)
            PressButtonShape(depth: pressed ? 0.15 : 1)
                .stroke(style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
                .frame(width: size, height: size * 0.5)
        }
        .foregroundStyle(.primary)
        .frame(width: size, height: size * 1.1)
        .accessibilityHidden(true)
        .task(id: animated && !reduceMotion) {
            guard animated, !reduceMotion else { pressed = false; return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.1))
                withAnimation(.easeIn(duration: 0.18)) { pressed = true }
                try? await Task.sleep(for: .seconds(0.28))
                withAnimation(.spring(duration: 0.45, bounce: 0.4)) { pressed = false }
            }
        }
    }
}

/// The button as a short cylinder: top ellipse, two side lines, and the front half of the rim.
/// `depth` 1 is up; toward 0 the top sinks down to the rim.
nonisolated private struct PressButtonShape: Shape {
    var depth: CGFloat

    var animatableData: CGFloat {
        get { depth }
        set { depth = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let eh = rect.height * 0.46            // ellipse height: the slight perspective
        let rimY = rect.maxY - eh / 2          // centre of the rim ellipse
        let fullTravel = rect.height - eh      // top's centre at full height
        let topY = rimY - fullTravel * depth
        var p = Path()
        p.addEllipse(in: CGRect(x: rect.minX, y: topY - eh / 2, width: rect.width, height: eh))
        p.move(to: CGPoint(x: rect.minX, y: topY))
        p.addLine(to: CGPoint(x: rect.minX, y: rimY))
        p.move(to: CGPoint(x: rect.maxX, y: topY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rimY))
        // The rim's front half (the back is hidden behind the button).
        p.addArc(center: .zero, radius: 1, startAngle: .zero, endAngle: .degrees(180), clockwise: false,
                 transform: CGAffineTransform(translationX: rect.midX, y: rimY).scaledBy(x: rect.width / 2, y: eh / 2))
        return p
    }
}

#Preview {
    HStack(spacing: 24) { PressIcon(); PressIcon(size: 44); PressIcon(animated: false) }.padding()
}
