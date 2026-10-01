// swift-tools-version: 6.0
import PackageDescription

// Pure Swift, Foundation only, so it builds and tests on Linux (cloud agents) and on the Mac.
// Apple frameworks (CoreLocation, WeatherKit, HealthKit, FoundationModels) belong in the app target.
let package = Package(
    name: "AsthmaCore",
    platforms: [.iOS("27.0"), .macOS("15.0")],
    products: [
        .library(name: "AsthmaCore", targets: ["AsthmaCore"]),
    ],
    targets: [
        .target(name: "AsthmaCore"),
        .testTarget(name: "AsthmaCoreTests", dependencies: ["AsthmaCore"]),
    ]
)
