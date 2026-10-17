import SwiftUI
import UIKit

/// Funnel Sans (Dicotype / Google Fonts, SIL Open Font License; license in Fonts/FunnelSans-OFL.txt).
/// Opt-in via Settings › Type. Static weights are registered under UIAppFonts in project.yml.
/// Default off keeps Recursive (sentence) + SF (UI).
enum FunnelSans {
    /// PostScript names from the bundled static TTFs.
    static func postScriptName(_ weight: Font.Weight) -> String {
        switch weight {
        case .medium: return "FunnelSans-Medium"
        case .semibold: return "FunnelSans-SemiBold"
        case .bold, .heavy, .black: return "FunnelSans-Bold"
        default: return "FunnelSans-Regular"
        }
    }

    static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name = postScriptName(weight)
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight, design: .default)
    }

    /// Dynamic Type–aware UI styles.
    static func text(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        let uiStyle = uiTextStyle(style)
        let size = UIFont.preferredFont(forTextStyle: uiStyle).pointSize
        let name = postScriptName(weight)
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size, relativeTo: style)
        }
        return .system(style, design: .default, weight: weight)
    }

    private static func uiTextStyle(_ style: Font.TextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        default: return .body
        }
    }
}
