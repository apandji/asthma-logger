import SwiftUI

/// Every color, font and spacing token. Views never hard-code styling, so the risograph pass
/// later only has to change this file.
enum Theme {
    // Riso-ish spot inks, used sparingly on a stock dark iOS base.
    static let accent = Color(red: 1.0, green: 0.282, blue: 0.690)   // fluorescent pink
    static let ink2 = Color(red: 0.0, green: 0.471, blue: 0.749)     // riso blue
    static let ink3 = Color(red: 0.0, green: 0.663, blue: 0.361)     // riso green

    static let background = Color.black
    static let surface = Color(white: 0.11)
    static let secondaryText = Color.secondary

    static let elevated = accent
    static let usual = Color.secondary
    static let quiet = ink3

    static let cornerRadius: CGFloat = 16
    static let padding: CGFloat = 16
    static let spacing: CGFloat = 12

    static let headline = Font.system(.title3, design: .rounded).weight(.semibold)
    static let body = Font.body
    static let caption = Font.caption
    static let number = Font.system(.body, design: .rounded).monospacedDigit()
}

/// A rounded surface block used by Insights.
struct Card<Content: View>: View {
    let title: String
    var systemImage: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Label(title, systemImage: systemImage ?? "circle.fill")
                .labelStyle(.titleAndIcon)
                .font(Theme.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.padding)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.cornerRadius))
    }
}

/// Small capsule label, e.g. "Elevated" or "Indoors".
struct Chip: View {
    let text: String
    var color: Color = Theme.secondaryText

    var body: some View {
        Text(text)
            .font(Theme.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: .capsule)
    }
}
