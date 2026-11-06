import SwiftUI

/// Menus look: the air at this moment as one soft gradient, like Apple Card's spending colours. Each reading takes
/// room in proportion to how much of it is in the air; nothing else is drawn. The numbers are below, in Environment
/// (owner, Nov 6: "only the gradient… the user scrolls if they want to see more data").
struct MenusAirCard: View {
    struct Item: Identifiable {
        let name: String
        let value: String
        /// 0 Good, 1 OK, 2 Not good; nil when there's no level to give.
        let tier: Int?
        let ink: Theme.AirInk
        /// How much of a high reading this is, 0…1. Sets its share of the gradient.
        let share: Double
        var id: String { name }
    }

    let items: [Item]

    private var present: [Item] { items.filter { $0.share > 0.01 }.sorted { $0.share > $1.share } }

    var body: some View {
        let shown = present
        ZStack {
            // Across: each reading's core colour over a span as wide as its share. Down: it melts into its glow.
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
        .animation(.smooth(duration: 0.6), value: shown.map(\.share))
        .accessibilityElement()
        .accessibilityLabel("Outdoor air")
        .accessibilityValue(shown.isEmpty ? "No readings" : shown.map { "\($0.name) \($0.value)" }.joined(separator: ", "))
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
