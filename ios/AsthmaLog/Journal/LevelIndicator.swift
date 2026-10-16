import AsthmaCore
import SwiftUI

/// Every condition reads as one of three tiers. Low on its own scale is good; the middle band is OK;
/// high (or, for temperature and humidity, away from comfortable) is not good.
enum Tier: Int {
    case good, ok, notGood

    init(_ level: WeaveSpec.Level) {
        self = [.good, .ok, .notGood][level.rawValue]
    }

    var word: String { ["Good", "OK", "Not good"][rawValue] }
}

/// Ways to show a tier, so they can be compared in review (Settings › Level style, or the menu on the
/// details sheet). The reviewer liked the signal bars; the others are alternatives.
enum LevelStyle: String, CaseIterable, Identifiable {
    case signal, word, shape, gauge, track
    var id: String { rawValue }

    var title: String {
        switch self {
        case .signal: "Signal bars"
        case .word: "Word"
        case .shape: "Shape"
        case .gauge: "Gauge"
        case .track: "Track"
        }
    }

    var note: String {
        switch self {
        case .signal: "Like phone signal: three bars is good."
        case .word: "A tinted label, no graphic."
        case .shape: "Smooth when good, spiky when not."
        case .gauge: "A small dial in three parts."
        case .track: "A dot on a three-stop track."
        }
    }

    static let key = "levelStyle"
}

struct LevelIndicator: View {
    let level: WeaveSpec.Level?
    let ink: Color
    let style: LevelStyle

    var body: some View {
        Group {
            if let level {
                let tier = Tier(level)
                switch style {
                case .signal: signal(tier)
                case .word: word(tier)
                case .shape: shape(tier)
                case .gauge: gauge(tier)
                case .track: track(tier)
                }
            } else {
                Circle().strokeBorder(Theme.secondaryText.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .frame(width: 14, height: 14)
            }
        }
        .accessibilityHidden(true)
    }

    private var off: Color { Theme.secondaryText.opacity(0.22) }

    /// Three rising bars; good fills all three, like full signal.
    private func signal(_ t: Tier) -> some View {
        let filled = 3 - t.rawValue
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(i < filled ? ink : off)
                    .frame(width: 5, height: CGFloat(8 + i * 5))
            }
        }
        .frame(width: 26, height: 20, alignment: .bottom)
    }

    private func word(_ t: Tier) -> some View {
        Text(t.word)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .foregroundStyle(t == .good ? ink : .primary)
            .background(ink.opacity([0.16, 0.35, 0.7][t.rawValue]), in: Capsule())
            .fixedSize()
    }

    /// Smooth circle → scalloped → spiky (after Posavec & Quick's air necklaces).
    private func shape(_ t: Tier) -> some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2 - 1
            let inner: CGFloat = [1, 0.82, 0.55][t.rawValue]
            let n = 10
            var p = Path()
            for i in 0..<(n * 2) {
                let a = CGFloat(i) * .pi / CGFloat(n) - .pi / 2
                let rr = i.isMultiple(of: 2) ? r : r * inner
                let pt = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
            p.closeSubpath()
            ctx.fill(t == .good ? Path(ellipseIn: CGRect(x: c.x - r * 0.9, y: c.y - r * 0.9, width: r * 1.8, height: r * 1.8)) : p,
                     with: .color(ink))
        }
        .frame(width: 20, height: 20)
    }

    /// A half dial: good on the left, not good on the right; the current third is filled.
    private func gauge(_ t: Tier) -> some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height - 2)
            let r = size.width / 2 - 3
            for i in 0..<3 {
                var arc = Path()
                let start = Angle.degrees(180 + Double(i) * 60 + 4)
                let end = Angle.degrees(180 + Double(i + 1) * 60 - 4)
                arc.addArc(center: c, radius: r, startAngle: start, endAngle: end, clockwise: false)
                ctx.stroke(arc, with: .color(i == t.rawValue ? ink : off), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
        }
        .frame(width: 28, height: 17)
    }

    /// Good · OK · Not good as three stops; a dot sits on the current one.
    private func track(_ t: Tier) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(i == t.rawValue ? ink : off)
                    .frame(width: i == t.rawValue ? 9 : 5, height: i == t.rawValue ? 9 : 5)
            }
        }
        .frame(width: 30, height: 12)
    }
}
