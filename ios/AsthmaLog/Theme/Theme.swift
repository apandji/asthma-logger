import SwiftUI

/// Every color, font and spacing token. Views never hard-code styling.
/// Spec: docs/design/visual-style.md (Apple-native, light and dark, ink only for data).
enum Theme {
    // Inks for data, one per signal family. Light / dark values from the spec.
    static let accent = Color(light: 0xE8336D, dark: 0xFF4F86)   // air (pink); also the primary action
    static let ink2 = Color(light: 0x1F6FD1, dark: 0x4C9BFF)     // weather (blue)
    static let ink3 = Color(light: 0x248A3D, dark: 0x30D158)     // quiet days (system-like green)

    // Moment kinds, matching the watch buttons and the SmartButton caps.
    static let rescue = Color(light: 0xE8701F, dark: 0xFF8A3D)    // orange
    static let standard = Color(light: 0x2B8FD6, dark: 0x4FB0F5)  // blue

    // Weave inks, one per outdoor factor (docs/design/visual-style.md, textile-direction.md).
    static let weaveAir = Color(light: 0xE2477E, dark: 0xFF5A92)
    static let weaveHumidity = Color(light: 0x3B5BDB, dark: 0x7C93FF)
    static let weaveTemperature = Color(light: 0xD9442B, dark: 0xFF6A4D)
    static let weavePollen = Color(light: 0xC9A400, dark: 0xE6C02E)

    /// The ambient Journal stage: soft paper in light, near-black in dark.
    static let stage = Color(light: 0xF2F1EE, dark: 0x0B0B0D)
    static let card = Color(light: 0xFFFFFF, dark: 0x1C1C1F)

    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let secondaryText = Color.secondary

    static let elevated = accent
    static let usual = Color.secondary
    static let quiet = ink3

    static let cornerRadius: CGFloat = 16
    static let padding: CGFloat = 16
    static let spacing: CGFloat = 12

    static let headline = Font.system(.title3, design: .rounded).weight(.semibold)
    /// The one New York sentence per screen (the insight headline). Never bold.
    static let headlineSerif = Font.system(.title3, design: .serif, weight: .medium)
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

extension Color {
    /// A color that follows light / dark mode, from 0xRRGGBB values.
    init(light: UInt32, dark: UInt32) {
        func ui(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }
}
