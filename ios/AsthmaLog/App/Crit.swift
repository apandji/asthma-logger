import Foundation

/// Design-crit variants, switchable live in Settings › Design crit (Debug builds), so a review can
/// compare options on the phone. Each is a plain @AppStorage value; defaults are the current proposal.
enum Crit {
    enum Header: String, CaseIterable, Identifiable {
        case now, nowWithCounts, lastMoment, dateOnly
        var id: String { rawValue }
        var title: String {
            switch self {
            case .now: "Right now (live)"
            case .nowWithCounts: "Right now + counts"
            case .lastMoment: "Last moment"
            case .dateOnly: "Date only"
            }
        }
        static let key = "crit.header"
    }

    enum InsightsEntry: String, CaseIterable, Identifiable {
        case bottomStrip, edgeTab
        var id: String { rawValue }
        var title: String { self == .bottomStrip ? "Bottom peek strip" : "Sideways on the right edge" }
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
}
