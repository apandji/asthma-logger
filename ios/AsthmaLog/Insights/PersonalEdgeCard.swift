import AsthmaCore
import SwiftUI

/// Your own temperature edge, under the Weather card (docs/design/risk-color.md). Shown three ways for the crit
/// (Settings › Design crit › Your edge): a sentence with the number, words only, or the dots it came from.
/// Appears only when `PersonalEdge` finds an edge that passes its checks.
struct PersonalEdgeCard: View {
    let edge: PersonalEdge
    let flare: [Double]
    let baseline: [Double]
    @AppStorage(Crit.PersonalEdgeStyle.key) private var style = Crit.PersonalEdgeStyle.sentence

    private var colder: Bool { edge.side == .below }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(colder ? "Cold, for you" : "Heat, for you").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            switch style {
            case .sentence:
                (Text("Your flare days often came when it was ") + highlight(edge.phrase(unit: "°F")) + Text("."))
                    .font(Theme.serifTitle)
            case .words:
                (Text("Your flare days often came on days ") + highlight(wordsEdge) + Text("."))
                    .font(Theme.serifTitle)
            case .dots:
                Text(colder ? "Your flare days sat on the cold side of your usual days." : "Your flare days sat on the warm side of your usual days.")
                    .font(.subheadline)
                EdgeDots(edge: edge, flare: flare, baseline: baseline)
                    .frame(height: 128)
            }
            Text(edge.isGeneral ? "Worked out from your moments. It’s where cold starts for most people too." : "Worked out from your moments. For most people, \(colder ? "cold starts at freezing" : "heat starts around 90°F").")
                .font(.caption).foregroundStyle(Theme.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }

    /// "colder than almost all your usual ones", from how few of your baselines were past the edge.
    private var wordsEdge: String {
        let share = Double(edge.baselinePast) / Double(max(edge.nBaseline, 1))
        let word = colder ? "colder" : "warmer"
        return share < 0.15 ? "\(word) than almost all your usual ones" : share < 0.35 ? "\(word) than most of your usual ones" : "on the \(colder ? "cold" : "warm") side"
    }
}

/// The risk highlight: a highlighter swipe behind the words, the ink stays primary.
private func highlight(_ s: String) -> Text {
    var a = AttributedString(s)
    a.backgroundColor = Theme.riskHighlight.opacity(0.55)
    return Text(a)
}

/// A tally on a colder → warmer line: flare moments stack up, usual days stack down. The side past that point
/// is highlighted. No numbers.
private struct EdgeDots: View {
    let edge: PersonalEdge
    let flare: [Double]
    let baseline: [Double]

    var body: some View {
        Canvas { ctx, size in
            let all = flare + baseline
            guard let lo = all.min(), let hi = all.max(), hi > lo else { return }
            let pad: CGFloat = 8, labelW: CGFloat = 0
            let x = { (v: Double) in pad + labelW + CGFloat((v - lo) / (hi - lo)) * (size.width - 2 * pad - labelW) }
            let ex = x(edge.value)
            let band: CGFloat = 104
            let past = edge.side == .below ? CGRect(x: 0, y: 0, width: ex, height: band) : CGRect(x: ex, y: 0, width: size.width - ex, height: band)
            ctx.fill(Path(roundedRect: past, cornerRadius: 6), with: .color(Theme.riskHighlight.opacity(0.28)))
            var line = Path(); line.move(to: CGPoint(x: ex, y: 0)); line.addLine(to: CGPoint(x: ex, y: band))
            ctx.stroke(line, with: .color(.primary.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            // A tally: dots in 2° columns stack away from the middle line, flares up, usual days down.
            func row(_ vs: [Double], base: CGFloat, dir: CGFloat, filled: Bool) {
                var height: [Int: Int] = [:]
                for v in vs.sorted() {
                    let col = Int((v / 2).rounded()); let k = height[col, default: 0]; height[col] = k + 1
                    let r = CGRect(x: x(Double(col) * 2) - 3, y: base + dir * CGFloat(k) * 7 - 3, width: 6, height: 6)
                    if filled { ctx.fill(Path(ellipseIn: r), with: .color(.primary)) }
                    else { ctx.stroke(Path(ellipseIn: r), with: .color(.primary.opacity(0.55)), lineWidth: 1) }
                }
            }
            row(flare, base: 44, dir: -1, filled: true)
            row(baseline, base: 58, dir: 1, filled: false)
            ctx.draw(Text("colder").font(.caption2).foregroundStyle(Theme.secondaryText), at: CGPoint(x: pad, y: 118), anchor: .leading)
            ctx.draw(Text("warmer").font(.caption2).foregroundStyle(Theme.secondaryText), at: CGPoint(x: size.width - pad, y: 118), anchor: .trailing)
            ctx.draw(Text("from here").font(.caption2.weight(.semibold)), at: CGPoint(x: ex, y: 118), anchor: .center)
        }
        .accessibilityLabel("Dots for each flare moment and each usual day, colder to warmer. Your flare moments cluster past your edge.")
    }
}
