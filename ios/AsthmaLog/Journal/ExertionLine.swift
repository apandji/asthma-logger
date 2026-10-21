import AsthmaCore
import SwiftUI

/// "You'd been active in the hour before." and what it came from ("A walk, from Apple Health."), on a
/// moment. Words only: no steps or minutes. Says nothing when not active or unknown. Self prints in the key
/// ink (the text colour), never a new hue.
struct ExertionLine: View {
    let event: LogEvent
    /// On a card (moment details) or bare (the rail's Body panel).
    var card = true

    var body: some View {
        if let line = Exertion.line(active: event.exerted) {
            let row = HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: Icons.body).foregroundStyle(.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(line).font(card ? .body.weight(.medium) : .subheadline)
                    if let detail = Exertion.detail(event.exertedBy) {
                        Text(detail).font(.caption).foregroundStyle(Theme.secondaryText)
                    }
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            if card {
                row.padding(16).frame(maxWidth: .infinity, alignment: .leading).frostedCard()
            } else {
                row
            }
        }
    }
}
