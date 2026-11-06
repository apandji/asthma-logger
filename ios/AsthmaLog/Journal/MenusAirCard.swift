import SwiftUI

/// Menus look: the air at this moment as one soft gradient, like Apple Card's spending colours. Three bands —
/// Pollution, Weather, Allergens — each as wide as how much of it is in the air. Tap a band to see what it is
/// (owner, Nov 6). The full readings are below, in Environment.
struct MenusAirCard: View {
    struct Item: Identifiable {
        let name: String
        /// What's in it, in a line ("PM2.5 12 µg/m³ · Ozone 30 ppb").
        let value: String
        let ink: Theme.AirInk
        /// How much of a high reading this is, 0…1. Sets its share of the gradient.
        let share: Double
        var id: String { name }
    }

    let items: [Item]

    @State private var tapped: (item: Item, at: CGPoint)?
    @State private var hide: Task<Void, Never>?

    private var present: [Item] { items.filter { $0.share > 0.01 }.sorted { $0.share > $1.share } }

    var body: some View {
        let shown = present
        GeometryReader { geo in
            ZStack {
                // Across: each band's core colour over a span as wide as its share. Down: it melts into its glow.
                LinearGradient(stops: stops(shown, \.glowColor), startPoint: .leading, endPoint: .trailing)
                LinearGradient(stops: stops(shown, \.color), startPoint: .leading, endPoint: .trailing)
                    .mask(LinearGradient(colors: [.black, .black.opacity(0.15)], startPoint: .top, endPoint: .bottom))
            }
            // No hard edges: it fades into the page all round.
            .mask(
                LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.12),
                                       .init(color: .black, location: 0.82), .init(color: .clear, location: 1)],
                               startPoint: .top, endPoint: .bottom)
            )
            .mask(
                LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.08),
                                       .init(color: .black, location: 0.92), .init(color: .clear, location: 1)],
                               startPoint: .leading, endPoint: .trailing)
            )
            .contentShape(Rectangle())
            .onTapGesture { p in
                guard let item = band(at: p.x / max(geo.size.width, 1), shown) else { return }
                withAnimation(.smooth(duration: 0.25)) { tapped = (item, p) }
                hide?.cancel()
                hide = Task {
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    withAnimation(.smooth(duration: 0.4)) { tapped = nil }
                }
            }
            .overlay {
                if let t = tapped {
                    // Centred across the card, just above the finger, so it never runs off the screen.
                    label(t.item)
                        .fixedSize()
                        .position(x: geo.size.width / 2, y: max(t.at.y - 40, 40))
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                        .allowsHitTesting(false)
                }
            }
        }
        .animation(.smooth(duration: 0.6), value: shown.map(\.share))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Outdoor air")
        .accessibilityValue(shown.isEmpty ? "No readings" : shown.map { "\($0.name): \($0.value)" }.joined(separator: ". "))
    }

    private func label(_ item: Item) -> some View {
        HStack(spacing: 8) {
            Circle().fill(item.ink.color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(.subheadline.weight(.semibold))
                if !item.value.isEmpty {
                    Text(item.value).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }

    /// The band under a point across the card (0…1), using the same spans as the gradient.
    private func band(at x: Double, _ shown: [Item]) -> Item? {
        guard !shown.isEmpty else { return nil }
        let total = shown.map(\.share).reduce(0, +)
        var at = 0.0
        for item in shown {
            at += item.share / max(total, 0.0001)
            if x <= at { return item }
        }
        return shown.last
    }

    private func stops(_ shown: [Item], _ color: KeyPath<Theme.AirInk, Color>) -> [Gradient.Stop] {
        guard !shown.isEmpty else {
            return [.init(color: Color(uiColor: .systemGray6), location: 0), .init(color: Color(uiColor: .systemGray5), location: 1)]
        }
        if shown.count == 1 {
            return [.init(color: shown[0].ink[keyPath: color], location: 0.5)]
        }
        let total = shown.map(\.share).reduce(0, +)
        var out: [Gradient.Stop] = []
        var at = 0.0
        for item in shown {
            let w = item.share / max(total, 0.0001)
            out.append(.init(color: item.ink[keyPath: color], location: at + w * 0.5))
            at += w
        }
        return out
    }
}
