import Foundation

/// The position that goes to the air services (OpenAQ, AirNow, Ambee), in one place. Sent precisely (four
/// decimals, about 10 m): hyperlocal air needs it, and Ambee resolves to 500 m (owner, Oct 19: "just admit
/// it"). What makes it not tracking is what's missing: each request carries felt air's key and the position,
/// never a name, an account or a device id, and the services never get your history or your places. Onboarding
/// says exactly this. A proxy (planned) will also hide the phone's IP address from them.
nonisolated enum Coarse {
    static func string(_ degrees: Double) -> String { String(format: "%.4f", degrees) }
}
