import Foundation

/// The position that leaves the phone for the air services (OpenAQ, AirNow, Ambee), rounded to two decimal
/// places: about a kilometre. The air readings are regional anyway (the nearest monitor is often miles away),
/// so nothing is lost, and the services can't place a request at a home or a street. Requests carry felt
/// air's key, never a name, an account or a device id. The exact fix stays on this iPhone, on the moment.
nonisolated enum Coarse {
    static func round(_ degrees: Double) -> Double { (degrees * 100).rounded() / 100 }
    static func string(_ degrees: Double) -> String { String(format: "%.2f", round(degrees)) }
}
