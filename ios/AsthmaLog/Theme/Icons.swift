import AsthmaCore

/// Every air symbol in one place, so a thing looks the same everywhere: the rail, the reading label, the
/// advice cards, Personal Insights and the Lock Screen. Add or change a symbol here only.
enum Icons {
    // The groups (rail stops and Insights categories).
    static let weather = "cloud.sun.fill"
    static let particles = "aqi.medium"
    static let biologics = "allergens"
    static let me = "person.fill"
    /// Your voice and your body: their own stops on the rail.
    static let voice = "waveform"
    static let body = "figure.walk"

    /// One symbol per layer of the sky. PM2.5 shares its group's symbol: it's the particle people know.
    static func layer(_ name: String) -> String {
        switch name {
        case "Weather": weather
        case "PM2.5", "Air": particles
        case "PM10": "aqi.low"
        case "NO₂": "car.fill"
        case "Ozone": "sun.haze.fill"
        case "Tree pollen": "tree.fill"
        case "Grass pollen": "leaf.fill"
        case "Weed pollen": "camera.macro"
        default: "circle.fill"
        }
    }

    static func category(_ c: AirProfile.Category) -> String {
        switch c {
        case .weather: weather
        case .particulates: particles
        case .biologics: biologics
        case .exertion: me
        }
    }

    /// An advice card's factor uses the same symbol as its layer.
    static func factor(_ f: AirAdvice.Factor) -> String {
        switch f {
        case .pm25: layer("PM2.5")
        case .pm10: layer("PM10")
        case .no2: layer("NO₂")
        case .ozone: layer("Ozone")
        case .treePollen: layer("Tree pollen")
        case .grassPollen: layer("Grass pollen")
        case .weedPollen: layer("Weed pollen")
        }
    }

    // Air events. Wildfire smoke is the only "smoke": PM2.5 doesn't use it.
    static let storm = "cloud.bolt.rain.fill"
    static let smoke = "smoke.fill"
    static let tempDrop = "thermometer.low"
    static let mold = "cloud.drizzle.fill"

    // Weather readings (Moment details). Wind is only wind; humidity only humidity.
    static let humidity = "humidity"
    static let dewPoint = "drop"
    static let wind = "wind"
    static let uv = "sun.max"

    /// Medication taken (Moment details).
    static let inhaler = "lungs.fill"
}
