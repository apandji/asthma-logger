import Foundation

/// Design-crit variants, switchable live in Settings › Design crit (Debug builds), so a review can
/// compare options on the phone. Each is a plain @AppStorage value; defaults are the current proposal.
enum Crit {
    enum Header: String, CaseIterable, Identifiable {
        case moment, now, nowWithCounts, lastMoment, dateOnly
        var id: String { rawValue }
        var title: String {
            switch self {
            case .moment: "The moment you're on"
            case .now: "Right now (live)"
            case .nowWithCounts: "Right now + counts"
            case .lastMoment: "Last moment"
            case .dateOnly: "Date only"
            }
        }
        static let key = "crit.header"
    }

    enum InsightsEntry: String, CaseIterable, Identifiable {
        case topBar, ringButton, bottomStrip, edgeTab
        var id: String { rawValue }
        var title: String {
            switch self {
            case .topBar: "Ring at the top, by •••"
            case .ringButton: "Ring button by the +"
            case .bottomStrip: "Bottom peek strip"
            case .edgeTab: "Sideways on the right edge"
            }
        }
        static let key = "crit.insightsEntry"
    }

    /// How a note is captured after a moment (docs/design/ab-tests.md, test A1).
    enum CaptureStyle: String, CaseIterable, Identifiable {
        case chat, journal, sheet
        var id: String { rawValue }
        var title: String {
            switch self {
            case .chat: "Chat: one question at a time"
            case .journal: "Journal: your words and sections"
            case .sheet: "Recorder sheet (current)"
            }
        }
        static let key = "crit.captureStyle"
    }

    /// Whether heard tags are ticked for you or only suggested (test A2).
    enum AutoSelect: String, CaseIterable, Identifiable {
        case ticked, suggested
        var id: String { rawValue }
        var title: String { self == .ticked ? "Ticked as heard" : "Suggested, you tick" }
        static let key = "crit.autoSelect"
    }

    enum LogStyle: String, CaseIterable, Identifiable {
        case pull, menu
        var id: String { rawValue }
        var title: String { self == .pull ? "Pull the + (glass well)" : "System menu" }
        static let key = "crit.logStyle"
    }

    enum CaptureOrder: String, CaseIterable, Identifiable {
        case rescueFirst, standardFirst
        var id: String { rawValue }
        var title: String { self == .rescueFirst ? "Rescue first (short pull)" : "Standard first" }
        static let key = "crit.captureOrder"
    }

    enum CardMarker: String, CaseIterable, Identifiable {
        case quietTab, dot, glow, boldTab
        var id: String { rawValue }
        var title: String {
            switch self {
            case .quietTab: "Quiet tab"
            case .dot: "Dot by the time"
            case .glow: "Color glow, no label"
            case .boldTab: "Bold tab"
            }
        }
        static let key = "crit.cardMarker"
    }

    enum FieldStyle: String, CaseIterable, Identifiable {
        case weather, inks
        var id: String { rawValue }
        var title: String { self == .weather ? "Weather (hue, haze, mist)" : "Original inks" }
        static let key = "crit.fieldStyle"
    }

    /// For the presentation: make Now show an air event the real data hasn't produced today.
    enum DemoEvent: String, CaseIterable, Identifiable {
        case none, storm, smoke, tempDrop, mold
        var id: String { rawValue }
        var title: String {
            switch self {
            case .none: "Off (real data)"
            case .storm: "Thunderstorm with high pollen"
            case .smoke: "Wildfire smoke"
            case .tempDrop: "Sharp temperature drop"
            case .mold: "Rainy, humid and warm (mold)"
            }
        }
        static let key = "crit.demoEvent"
    }

    /// The palette: today's screen colours, or real RISO spot inks only (docs/design/color-review-riso.md).
    enum Inks: String, CaseIterable, Identifiable {
        case print, simple, riso, current
        var id: String { rawValue }
        var title: String {
            switch self {
            case .print: "Print (three inks)"
            case .simple: "Simple"
            case .riso: "RISO inks"
            case .current: "Current"
            }
        }
        static let key = "crit.inks"
    }

    /// The page: black (ink on night) or linen, a warm off-white paper that suits the riso grain.
    enum Paper: String, CaseIterable, Identifiable {
        case black, linen
        var id: String { rawValue }
        var title: String { self == .black ? "Black" : "Linen (light)" }
        static let key = "crit.paper"
    }

    /// Where a layer's color sits: at its own spot in the field (spots), or everywhere, as a haze over the
    /// whole place (vibe), so no particle reads as a position on the map.
    enum LayerSpread: String, CaseIterable, Identifiable {
        case vibe, spots
        var id: String { rawValue }
        var title: String { self == .vibe ? "Haze over the whole place" : "Each layer at its own spot" }
        static let key = "crit.layerSpread"
    }

    /// How the sky is read: a blob under the finger (a spot), or strata (horizontal layers, finger slides up and down).
    enum SkyReading: String, CaseIterable, Identifiable {
        case blob, strata
        var id: String { rawValue }
        var title: String { self == .blob ? "Blob under the finger" : "Strata (layers, slide up and down)" }
        static let key = "crit.skyReading"
    }

    /// The sky's surface: plain, a riso grain, or grain that swells under the finger.
    enum SkyTexture: String, CaseIterable, Identifiable {
        case plain, grain, dots
        var id: String { rawValue }
        var title: String {
            switch self {
            case .plain: "Plain"
            case .grain: "Riso grain (still)"
            case .dots: "Riso grain, answers touch"
            }
        }
        static let key = "crit.skyTexture"
    }

    enum CardStyle: String, CaseIterable, Identifiable {
        case panel, card, open
        var id: String { rawValue }
        var title: String {
            switch self {
            case .panel: "Contained sky (pages)"
            case .card: "Card"
            case .open: "No card (floating)"
            }
        }
        static let key = "crit.cardStyle"
    }

    /// Force the Insights ring for a demo: still learning, or ready with a speech bubble.
    enum InsightsState: String, CaseIterable, Identifiable {
        case auto, learning, learned
        var id: String { rawValue }
        var title: String {
            switch self {
            case .auto: "Real progress"
            case .learning: "Demo: learning (ring filling)"
            case .learned: "Demo: learned (bubble)"
            }
        }
        static let key = "crit.insightsState"
    }

    /// How strongly each pollutant / pollen color shows: one step per level, or rising smoothly with
    /// the amount inside its level (never into the next level's range).
    enum LayerStrength: String, CaseIterable, Identifiable {
        case steps, smooth
        var id: String { rawValue }
        var title: String { self == .steps ? "Steps (by level)" : "Smooth within level" }
        static let key = "crit.layerStrength"
    }

    static let performanceHUD = "crit.performanceHUD"

    /// Three gesture models for the Journal, to compare in a crit.
    enum Gestures: String, CaseIterable, Identifiable {
        case axis, zoom, quiet
        var id: String { rawValue }
        var title: String {
            switch self {
            case .axis: "A · One axis (swipe)"
            case .zoom: "B · Zoom through time (pinch)"
            case .quiet: "C · Quiet (timeline and tap)"
            }
        }
        static let key = "crit.gestures"
    }
}
