import Foundation

/// What to say when the air turns, from the FigJam "On Copy" board (Oct 17, 2026).
///
/// - **Warnings now**: a plain fact about the air, then one piece of advice for where you are: *staying put*
///   at Home, *going out* anywhere else (Work included, per the board).
/// - **After a flare**: only what was in the air. Never that it caused anything (owner, Oct 17: "stay with the
///   facts and drop anything causal").
/// - **The advice is a provocation**, not guidance: it goes in front of providers in testing to learn what
///   they'd actually say. Every surface that shows it carries `disclaimer`. See docs/air-advice.md.
public enum AirAdvice {
    /// Where you are decides which advice shows.
    public enum Context: String, Sendable, CaseIterable {
        case stayingPut, goingOut

        /// Home means staying put; Work, a new place or an unknown one means going out.
        public static func at(home: Bool) -> Context { home ? .stayingPut : .goingOut }

        public var label: String { self == .stayingPut ? "Staying put" : "Going out" }
    }

    /// Air that changes the day.
    public enum Event: String, Sendable, CaseIterable {
        case smoke, stormPollen, tempDrop, mold
    }

    /// One pollutant or pollen at a high level.
    public enum Factor: String, Sendable, CaseIterable {
        case pm25, pm10, no2, ozone, treePollen, grassPollen, weedPollen

        /// What it is, in a few words.
        public var whatItIs: String {
            switch self {
            case .pm25: "Fine dust, soot and aerosols."
            case .pm10: "Coarse dust and pollen fragments."
            case .no2: "Traffic exhaust and emissions."
            case .ozone: "Smog, often high on hot, sunny days."
            case .treePollen: "Pollen from trees, mostly in spring."
            case .grassPollen: "Pollen from grasses, mostly in early summer."
            case .weedPollen: "Pollen from weeds like ragweed, mostly in late summer."
            }
        }
    }

    public struct Warning: Sendable, Equatable {
        /// The fact: what's in the air.
        public let headline: String
        public let stayingPut: String
        public let goingOut: String

        public func advice(_ context: Context) -> String { context == .stayingPut ? stayingPut : goingOut }
    }

    /// Shown under any advice.
    public static let disclaimer = "A suggestion, not medical advice. If a flare is severe, get medical help now."

    // MARK: Events

    /// `fallF`: degrees colder than three hours ago, when known.
    public static func warning(_ event: Event, fallF: Double? = nil) -> Warning {
        switch event {
        case .smoke:
            Warning(headline: "Wildfire smoke is drifting into the area.",
                    stayingPut: "Close your windows and set your AC to recirculate to keep smoke out.",
                    goingOut: "If you need to go outside, an N95 mask filters out fine particles.")
        case .stormPollen:
            Warning(headline: "Pollen is high and a thunderstorm is on the way.",
                    stayingPut: "Keep your windows shut until the storm has passed.",
                    goingOut: "If you've been outside, shower and change clothes when you get in, to rinse off pollen.")
        case .tempDrop:
            Warning(headline: fallF.map { "It's \(Int($0.rounded()))° colder than three hours ago." } ?? "The temperature is dropping fast.",
                    stayingPut: "Keep the air indoors humidified if you can.",
                    goingOut: "Bring your inhaler. Breathe through your nose, or wear a loose scarf to warm the air.")
        case .mold:
            Warning(headline: "It's rainy, humid and warm, the kind of day mold grows.",
                    stayingPut: "A dehumidifier can keep indoor humidity below 50%.",
                    goingOut: "Watch for damp, shaded spots, where mold spores gather.")
        }
    }

    /// The fact for a flare moment logged during the event. What was in the air, nothing more.
    public static func afterFlare(_ event: Event, fallF: Double? = nil) -> String {
        switch event {
        case .smoke: "Wildfire smoke was in the air before this."
        case .stormPollen: "A thunderstorm came through while pollen was high."
        case .tempDrop: fallF.map { "It was \(Int($0.rounded()))° colder than three hours before." } ?? "The temperature had dropped fast before this."
        case .mold: "It was rainy, humid and warm before this."
        }
    }

    // MARK: Pollutants and pollen

    public static func warning(_ factor: Factor) -> Warning {
        switch factor {
        case .pm25:
            Warning(headline: "Fine particles are high today.",
                    stayingPut: "Run your indoor air purifier if you have one.",
                    goingOut: "Try to avoid walking along busy main roads.")
        case .pm10:
            Warning(headline: "It's a dusty day.",
                    stayingPut: "A damp cloth clears settled dust from surfaces.",
                    goingOut: "A standard mask can help filter out coarse dust.")
        case .no2:
            Warning(headline: "Traffic pollution is high outside.",
                    stayingPut: "Keep your windows closed during rush hour.",
                    goingOut: "Consider a route through a park or side streets.")
        case .ozone:
            Warning(headline: "Ozone is high today.",
                    stayingPut: "Stay indoors during the hottest part of the day.",
                    goingOut: "Try to move outdoor exercise to the morning.")
        case .treePollen:
            Warning(headline: "Tree pollen is high today.",
                    stayingPut: "Keep your windows closed to keep it out.",
                    goingOut: "Sunglasses help keep pollen out of your eyes.")
        case .grassPollen:
            Warning(headline: "Grass pollen is high today.",
                    stayingPut: "If you have a lawn, try not to mow it today.",
                    goingOut: "Shower and change clothes when you get home.")
        case .weedPollen:
            Warning(headline: "Weed pollen is high today.",
                    stayingPut: "Run your indoor air filter if you have one.",
                    goingOut: "Try to avoid walking through overgrown fields or lots.")
        }
    }

    // MARK: Detection

    /// Rain, humidity over 60% and warmth together: the board's mold rule. Current weather stands in for
    /// "recent rainfall" until hourly precipitation is in the look-back.
    public static func isMoldWeather(condition: String?, humidity: Double?, temperatureF: Double?) -> Bool {
        guard let humidity, humidity > 60, let temperatureF, temperatureF >= 65 else { return false }
        let c = (condition ?? "").lowercased()
        return ["rain", "drizzle", "shower"].contains { c.contains($0) }
    }

    /// Words the copy must never use: no causes, no odds, no "attack" (docs/predictive-engine.md §2).
    public static let bannedWords = ["attack", "trigger", "cause", "likely", "risk", "will have"]
}
