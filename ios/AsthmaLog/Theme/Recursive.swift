import AsthmaCore
import SwiftUI
import UIKit

/// Recursive (Arrow Type, SIL Open Font License; license in Fonts/Recursive-OFL.txt). One variable file,
/// registered under UIAppFonts in project.yml. Its axes set the voice: the sentence gets more casual as the
/// Settings › Insight voice slider moves from clinical to poetic; figures stay linear and mono.
/// If the file is missing, falls back to New York so nothing breaks.
enum Recursive {
    /// The file's default instance. Every other look is the same font with different axis values.
    static let postScriptName = "Recursive-SansLinearLight"

    struct Axes {
        /// 0 linear (precise) → 1 casual (brushy, handwritten).
        var casual: CGFloat = 0
        /// 0 proportional → 1 monospace.
        var mono: CGFloat = 0
        /// 300 light → 1000 extra black.
        var weight: CGFloat = 400
        /// 0 upright → -15 slanted.
        var slant: CGFloat = 0
        /// Cursive letterforms (single-story a, g…): 0 off, 0.5 only when slanted, 1 always.
        var cursive: CGFloat = 0.5
    }

    /// The sentence, in the voice chosen in Settings.
    static func sentence(size: CGFloat, slanted: Bool = false, voice: NarratorStyle = .current) -> Font {
        var axes = voice.sentenceAxes
        if slanted { axes.slant = -15 }
        return font(size: size, axes)
    }

    /// Numbers that change in place: mono so digits hold their columns, linear so they read exact.
    static func figures(size: CGFloat) -> Font {
        font(size: size, Axes(casual: 0, mono: 1, weight: 400, cursive: 0))
    }

    static func font(size: CGFloat, _ axes: Axes) -> Font {
        guard let base = UIFont(name: postScriptName, size: size) else {
            return .system(size: size, weight: .regular, design: .serif)
        }
        let variations: [UInt32: CGFloat] = [
            tag("CASL"): axes.casual, tag("MONO"): axes.mono, tag("wght"): axes.weight,
            tag("slnt"): axes.slant, tag("CRSV"): axes.cursive,
        ]
        let key = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let descriptor = base.fontDescriptor.addingAttributes([key: variations])
        return Font(UIFont(descriptor: descriptor, size: size) as CTFont)
    }

    /// An axis tag ("wght") as the number Core Text keys variations by.
    private static func tag(_ s: String) -> UInt32 {
        s.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }
}

extension NarratorStyle {
    /// The voice saved in Settings (same key and default as the slider).
    static var current: NarratorStyle {
        let score = UserDefaults.standard.object(forKey: Prefs.narratorStyle) as? Int ?? defaultScore
        return NarratorStyle(score: score)
    }

    /// Clinical is linear; plain and poetic only a little casual, with no cursive letters, so the sentence
    /// keeps its warmth but still sits next to SF Pro. (Fully casual read as a different app.)
    var sentenceAxes: Recursive.Axes {
        switch self {
        case .clinical: Recursive.Axes(casual: 0, cursive: 0)
        case .plain: Recursive.Axes(casual: 0.25, cursive: 0)
        case .poetic: Recursive.Axes(casual: 0.4, cursive: 0)
        }
    }
}
