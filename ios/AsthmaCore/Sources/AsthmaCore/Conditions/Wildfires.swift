import Foundation

/// Active wildfires near a place, from Ambee's fire data (`/fire/latest/by-lat-lng`), summed up for a sentence:
/// "There are two active wildfires 50 miles north." Distance and direction are to the nearest one.
public struct WildfiresNearby: Sendable, Equatable {
    public let count: Int
    public let nearestMiles: Double
    /// "north", "southwest"…
    public let direction: String

    /// Fires within `withinMiles` of the place; nil when there are none.
    public init?(fires: [Ambee.FireResponse.Fire], latitude: Double, longitude: Double, withinMiles: Double = 150) {
        let near = fires.compactMap { f -> (Double, Double)? in
            guard let lat = f.lat, let lng = f.lng else { return nil }
            let d = Self.miles(latitude, longitude, lat, lng)
            return d <= withinMiles ? (d, Self.bearing(latitude, longitude, lat, lng)) : nil
        }
        guard let nearest = near.min(by: { $0.0 < $1.0 }) else { return nil }
        count = near.count
        nearestMiles = nearest.0
        direction = Self.compass(nearest.1)
    }

    /// "There are two active wildfires 50 miles north." Miles round to 5 past 20, so it doesn't sound surveyed.
    public var sentence: String {
        let miles = nearestMiles < 20 ? Int(nearestMiles.rounded()) : Int((nearestMiles / 5).rounded()) * 5
        let words = ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
        let n = count < words.count ? words[count] : "\(count)"
        return count == 1 ? "There's an active wildfire \(miles) miles \(direction)."
                          : "There are \(n) active wildfires \(miles) miles \(direction)."
    }

    static func miles(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let r = 3958.8, p1 = lat1 * .pi / 180, p2 = lat2 * .pi / 180
        let dp = (lat2 - lat1) * .pi / 180, dl = (lon2 - lon1) * .pi / 180
        let a = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * r * atan2(sqrt(a), sqrt(1 - a))
    }

    static func bearing(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let p1 = lat1 * .pi / 180, p2 = lat2 * .pi / 180, dl = (lon2 - lon1) * .pi / 180
        let y = sin(dl) * cos(p2), x = cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    static func compass(_ degrees: Double) -> String {
        let names = ["north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest"]
        return names[Int((degrees + 22.5) / 45) % 8]
    }
}

extension DemoAmbee {
    /// Two fires about 50 miles north of any place, in Ambee's shape. Display-only, like all demo data.
    public func fires(latitude: Double, longitude: Double) -> [Ambee.FireResponse.Fire] {
        [Ambee.FireResponse.Fire(lat: latitude + 0.72, lng: longitude + 0.05, frp: 41, confidence: "high", fireType: "wildfire"),
         Ambee.FireResponse.Fire(lat: latitude + 0.86, lng: longitude - 0.12, frp: 18, confidence: "nominal", fireType: "wildfire")]
    }
}
