import SwiftUI

/// Home's ⓘ (owner, Nov 19): how the flowers are made, the comparison behind them, and that it isn't medical
/// advice. Plain words first, the equation in one box. No percent risk, no "will", no cause (AGENTS.md §5).
struct MenusHowItWorks: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    section("It learns from you",
                            "Every time you reach for your inhaler, we note the air. We note some ordinary hours too. Over time, we spot what tends to be around when you need it.")

                    section("Bigger and taller: more likely yours",
                            "The more often something shows up when you use your inhaler, the bigger its flower grows. For now it's a sample: pollen first, then PM2.5.")
                    FanDiagram(kind: .rank).padding(.top, -12)

                    section("More open: more of it right now",
                            "A flower opens up as there's more of it in the air. Closed means there's little or none.")
                    FanDiagram(kind: .open).padding(.top, -12)

                    equation

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Patterns, not medical advice", systemImage: "exclamationmark.circle")
                            .font(Theme.Figtree.font(size: 17, weight: .medium))
                        Text("felt air spots what tends to show up together. It can't tell you what caused a flare, or when you'll need your inhaler. For your asthma plan, your clinician knows best.")
                            .font(Theme.Figtree.font(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 22).padding(.vertical, 12).padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("How the flowers work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button(role: .close) { dismiss() } }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Theme.Figtree.font(size: 19, weight: .medium))
            Text(body).font(Theme.Figtree.font(size: 16)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The comparison, as the code does it (docs/predictive-engine.md): a rate on inhaler moments over the
    /// same rate on baselines, and the gate before a pattern counts.
    private var equation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The math").font(Theme.Figtree.font(size: 13, weight: .medium)).foregroundStyle(.secondary)
                .textCase(.uppercase)
            HStack(alignment: .center, spacing: 10) {
                Text("lift  =").font(.system(size: 16, weight: .medium, design: .monospaced))
                VStack(spacing: 4) {
                    fraction("inhaler times with high X", "all inhaler times")
                    Text("÷").font(.system(size: 15, design: .monospaced)).foregroundStyle(.secondary)
                    fraction("ordinary hours with high X", "all ordinary hours")
                }
            }
            Text("Above 1.25, it's a pattern. We wait for at least 8 inhaler logs and 20 ordinary hours before we trust it.")
                .font(Theme.Figtree.font(size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private func fraction(_ top: String, _ bottom: String) -> some View {
        VStack(spacing: 3) {
            Text(top)
            Rectangle().frame(height: 1)
            Text(bottom)
        }
        .font(.system(size: 13, design: .monospaced))
        .fixedSize()
    }
}

/// The ⓘ sheet's small drawings (owner, Nov 19), in the home's own fan: one ink, faded from the base, cloud rim.
/// Rank: three fans stepping down in size and height. Open: one fan at three readings, closed to full.
private struct FanDiagram: View {
    enum Kind { case rank, open }
    let kind: Kind
    private let ink = Color(red: 0.93, green: 0.72, blue: 0.16)

    var body: some View {
        let fans: [(size: CGFloat, height: CGFloat, open: CGFloat, label: String)] = kind == .rank
            ? [(1, 1, 1, "1st"), (0.82, 0.74, 1, "2nd"), (0.63, 0.48, 1, "3rd")]
            : [(0.8, 0.7, 0.04, "Low"), (0.8, 0.7, 0.5, "Mid"), (0.8, 0.7, 1, "High")]
        VStack(spacing: 8) {
            Canvas { ctx, size in
                let ground = size.height - 2
                let colW = size.width / CGFloat(fans.count)
                var g = Path(); g.move(to: CGPoint(x: 0, y: ground)); g.addLine(to: CGPoint(x: size.width, y: ground))
                ctx.stroke(g, with: .color(.secondary.opacity(0.3)), lineWidth: 0.6)
                let R: CGFloat = min(colW * 0.36, size.height * 0.26)
                for (i, f) in fans.enumerated() {
                    let r = R * f.size
                    let x = colW * (CGFloat(i) + 0.5)
                    let pivot = CGPoint(x: x, y: ground - (size.height - R - 8) * f.height)
                    // As on home: a full round's stem stops at its bottom edge.
                    let o = min(1, max(0, (f.open - 0.85) / 0.15))
                    var stem = Path(); stem.move(to: CGPoint(x: x, y: ground)); stem.addLine(to: CGPoint(x: x, y: pivot.y + r * 0.93 * o))
                    ctx.stroke(stem, with: .color(ink.opacity(0.7)), lineWidth: 0.8)
                    let spread = (16 + 344 * Double(f.open)) * .pi / 180
                    let bumps = max(2, Int((spread * 180 / .pi / 40).rounded()))
                    let full = spread >= 2 * .pi - 0.01
                    var w = Path()
                    if !full { w.move(to: pivot) }
                    for j in 0...120 {
                        let t = Double(j) / 120
                        let a = -Double.pi / 2 - spread / 2 + spread * t
                        let p = (t * Double(bumps)).truncatingRemainder(dividingBy: 1)
                        let rr = r * CGFloat(0.93 + 0.07 * (1 - pow(2 * p - 1, 2)).squareRoot())
                        let q = CGPoint(x: pivot.x + cos(a) * rr, y: pivot.y + sin(a) * rr)
                        if full && j == 0 { w.move(to: q) } else { w.addLine(to: q) }
                    }
                    w.closeSubpath()
                    ctx.fill(w, with: .radialGradient(Gradient(stops: [.init(color: ink, location: 0), .init(color: ink.opacity(0.55), location: 0.5),
                                                                       .init(color: ink.opacity(0.08), location: 1)]),
                                                      center: pivot, startRadius: 0, endRadius: r))
                }
            }
            .frame(height: 150)
            HStack(spacing: 0) {
                ForEach(fans.indices, id: \.self) { i in
                    Text(fans[i].label).font(Theme.Figtree.font(size: 13, weight: .medium)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 14).padding(.horizontal, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement()
        .accessibilityLabel(kind == .rank ? "Three flowers, each smaller and lower than the last: first, second, third trigger."
                                          : "One flower at three readings: closed when low, half open, fully open when high.")
    }
}
