import SwiftUI
import UIKit

/// Funnel Sans (Dicotype / Google Fonts, SIL Open Font License; license in Fonts/FunnelSans-OFL.txt).
/// Opt-in for the big statement only via Settings › Type. Static weights are registered under
/// UIAppFonts in project.yml. UI chrome stays SF.
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
}
