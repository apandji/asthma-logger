import AsthmaCore
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
    /// The same two, softened: for the scan ripple, so they don't compete with the particles' inks.
    static let rescueSoft = Color(light: 0xF2B48C, dark: 0xFFC9A3)
    static let standardSoft = Color(light: 0x9CCBEA, dark: 0xB4DCF7)

    // Weave inks, one per outdoor factor (docs/design/visual-style.md, textile-direction.md).
    static let weaveAir = Color(light: 0xE2477E, dark: 0xFF5A92)
    static let weaveHumidity = Color(light: 0x3B5BDB, dark: 0x7C93FF)
    static let weaveTemperature = Color(light: 0xD9442B, dark: 0xFF6A4D)
    static let weavePollen = Color(light: 0xC9A400, dark: 0xE6C02E)

    /// The ambient Journal stage: soft paper in light, near-black in dark.
    static let stage = Color(light: 0xF2F1EE, dark: 0x0B0B0D)
    /// Warm off-white paper for the linen look (Design crit › Paper).
    static let linen = Color(light: 0xF3EEE4, dark: 0xF3EEE4)
    /// The forecast's paper: a warm graphite, a quiet step off black, so crossing into the future is felt
    /// without a flash.
    static let forecastPaper = Color(red: 0.11, green: 0.1, blue: 0.09)
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

    // MARK: Type. SF for UI. The big statement follows Settings › Type (system / Recursive / Funnel Sans).
    // The "serif" names stayed when New York was swapped out; they mean "the sentence's voice".
    /// The small line above a title: type, time, place. Set as tracked small caps, like a dateline.
    static let kicker = Font.system(size: 12, weight: .semibold, design: .default)
    static let kickerTracking: CGFloat = 1.1
    /// The sentence. Typeface from Settings › Type. Recursive's casual look follows Insight voice.
    static var serifTitle: Font { Typeface.sentence(size: 26) }
    static var serifTitleLarge: Font { Typeface.sentence(size: 30) }
    static let serifKerning: CGFloat = -0.5
    /// Numbers that change in place (counts, times).
    static var figures: Font { Typeface.figures(size: 22) }
    /// A verdict byline under the sentence, in the same voice.
    static var bylineSerif: Font { Typeface.sentence(size: 17) }

    // MARK: Motion. Three springs, used everywhere, so the whole app moves with one hand.
    /// Small things settling: pills, chips, dots. Quick, a hint of bounce.
    static let snap = Animation.snappy(duration: 0.24, extraBounce: 0.06)
    /// Content changing: headers, skies, pages. No bounce.
    static let smooth = Animation.smooth(duration: 0.45)
    /// Things arriving: toasts, tiles, sheets. A little lift.
    static let lift = Animation.spring(duration: 0.55, bounce: 0.22)

    /// One family for everything but the sentence: SF.
    static let headline = Font.headline
    /// The sentence on a detail page, a size down from the home.
    static var headlineSerif: Font { Typeface.sentence(size: 22) }
    static let body = Font.body
    static let caption = Font.caption
    static let number = Font.body.monospacedDigit()

    /// Settings › Type: which face draws the big statement. UI chrome stays SF.
    enum Typeface: String, CaseIterable, Identifiable {
        case system
        case recursive
        case funnelSans

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: "System"
            case .recursive: "Recursive"
            case .funnelSans: "Funnel Sans"
            }
        }

        var detail: String {
            switch self {
            case .system: "New York for the sentence, SF for the rest"
            case .recursive: "Bundled Recursive for the sentence"
            case .funnelSans: "Bundled Funnel Sans for the sentence"
            }
        }

        /// Current choice. Default Recursive (today's look). Migrates legacy `useFunnelSans`.
        static var current: Typeface {
            if let raw = UserDefaults.standard.string(forKey: Prefs.statementTypeface),
               let value = Typeface(rawValue: raw) {
                return value
            }
            if UserDefaults.standard.bool(forKey: Prefs.useFunnelSans) {
                return .funnelSans
            }
            return .recursive
        }

        static func sentence(size: CGFloat, slanted: Bool = false, voice: NarratorStyle = .current) -> Font {
            switch current {
            case .system:
                let base = Font.system(size: size, weight: .regular, design: .serif)
                return slanted ? base.italic() : base
            case .recursive:
                return Recursive.sentence(size: size, slanted: slanted, voice: voice)
            case .funnelSans:
                return FunnelSans.font(size: size, weight: .regular)
            }
        }

        static func figures(size: CGFloat) -> Font {
            switch current {
            case .system:
                return .system(size: size, weight: .regular, design: .serif).monospacedDigit()
            case .recursive:
                return Recursive.figures(size: size)
            case .funnelSans:
                return FunnelSans.font(size: size, weight: .regular)
            }
        }
    }
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
