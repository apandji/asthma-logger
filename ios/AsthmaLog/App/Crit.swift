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
        case ringButton, bottomStrip, edgeTab
        var id: String { rawValue }
        var title: String {
            switch self {
            case .ringButton: "Ring button by the +"
            case .bottomStrip: "Bottom peek strip"
            case .edgeTab: "Sideways on the right edge"
            }
        }
        static let key = "crit.insightsEntry"
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
            case .glow: "Colour glow, no label"
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

    /// How strongly each pollutant / pollen colour shows: one step per level, or rising smoothly with
    /// the amount inside its level (never into the next level's range).
    enum LayerStrength: String, CaseIterable, Identifiable {
        case steps, smooth
        var id: String { rawValue }
        var title: String { self == .steps ? "Steps (by level)" : "Smooth within level" }
        static let key = "crit.layerStrength"
    }
}
