import SwiftUI

/// Every color, font and spacing token. Views never hard-code styling.
/// Spec: docs/design/visual-style.md (Apple-native, light and dark, ink only for data).
enum Theme {
    // Inks for data, one per signal family. Light / dark values from the spec.
    static let accent = Color(light: 0xE8336D, dark: 0xFF4F86)   // air (pink); also the primary action
    static let ink2 = Color(light: 0x1F6FD1, dark: 0x4C9BFF)     // weather (blue)
    static let ink3 = Color(light: 0x248A3D, dark: 0x30D158)     // quiet days (system-like green)

    /// Chrome (buttons, links, toolbar). Neutral, so color is reserved for data.
    static let tint = Color.primary

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
    /// Warm off-white paper for the linen look (Design crit › Paper).
    static let linen = Color(light: 0xF3EEE4, dark: 0xF3EEE4)
    /// The page color for the chosen paper.
    static func paper(_ p: Crit.Paper) -> Color { p == .linen ? linen : .black }
    static let card = Color(light: 0xFFFFFF, dark: 0x1C1C1F)

    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    // A step above the system grey: it has to clear WCAG AA over frosted glass on the color field.
    static let secondaryText = Color(light: 0x4A4A52, dark: 0xC2C2CC)

    static let elevated = accent
    static let usual = Color.secondary
    static let quiet = ink3

    static let cornerRadius: CGFloat = 16
    static let padding: CGFloat = 16
    static let spacing: CGFloat = 12

    // MARK: Type. One serif voice (New York) for the sentence, SF for everything else.
    /// The small line above a title: type, time, place.
    static let kicker = Font.subheadline.weight(.medium)
    /// The sentence. Medium, never bold; tracked a touch tight (`Theme.serifKerning`).
    static let serifTitle = Font.system(.title2, design: .serif, weight: .medium)
    static let serifTitleLarge = Font.system(.title, design: .serif, weight: .medium)
    static let serifKerning: CGFloat = -0.4
    /// Numbers that change in place (counts, times).
    static let figures = Font.system(.title3, design: .serif, weight: .medium)

    // MARK: Motion. Three springs, used everywhere, so the whole app moves with one hand.
    /// Small things settling: pills, chips, dots. Quick, a hint of bounce.
    static let snap = Animation.snappy(duration: 0.24, extraBounce: 0.06)
    /// Content changing: headers, skies, pages. No bounce.
    static let smooth = Animation.smooth(duration: 0.45)
    /// Things arriving: toasts, tiles, sheets. A little lift.
    static let lift = Animation.spring(duration: 0.55, bounce: 0.22)

    static let headline = Font.system(.title3, design: .rounded).weight(.semibold)
    /// The one New York sentence per screen (the insight headline). Never bold.
    static let headlineSerif = Font.system(.title3, design: .serif, weight: .medium)
    static let body = Font.body
    static let caption = Font.caption
    static let number = Font.system(.body, design: .rounded).monospacedDigit()
}

/// Press feedback for anything tappable that isn't a system button: a small, quick scale and dim,
/// off with Reduce Motion.
struct PressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Theme.snap, value: configuration.isPressed)
    }
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
    /// `nonisolated`: UIKit resolves dynamic colors off the main thread (e.g. while Swift Charts draws),
    /// so this closure must not be main-actor isolated or the app traps.
    nonisolated init(light: UInt32, dark: UInt32) {
        @Sendable func ui(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        self.init(uiColor: UIColor { @Sendable traits in traits.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }
}
